//
//  DSPPlugin.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Protocol and types for DSP (Digital Signal Processing) plugins
//

import Foundation
import AVFoundation
import Accelerate
import Combine
import SwiftUI

// MARK: - DSP Configuration

/// Parameter types for DSP effects
public enum DSPParameterType {
    case float(min: Float, max: Float, defaultValue: Float)
    case int(min: Int, max: Int, defaultValue: Int)
    case bool(defaultValue: Bool)
    case selection(options: [String], defaultIndex: Int)
}

/// A parameter that can be adjusted in a DSP effect
public struct DSPParameter {
    public let id: String
    public let name: String
    public let type: DSPParameterType
    public let unit: String?
    public private(set) var value: Any
    
    public init(id: String, name: String, type: DSPParameterType, unit: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.unit = unit
        
        // Set default value based on type
        switch type {
        case .float(_, _, let defaultValue):
            self.value = defaultValue
        case .int(_, _, let defaultValue):
            self.value = defaultValue
        case .bool(let defaultValue):
            self.value = defaultValue
        case .selection(_, let defaultIndex):
            self.value = defaultIndex
        }
    }
    
    public mutating func setValue(_ newValue: Any) throws {
        switch type {
        case .float(let min, let max, _):
            guard let floatValue = newValue as? Float,
                  floatValue >= min && floatValue <= max else {
                throw DSPError.invalidParameterValue
            }
            value = floatValue
            
        case .int(let min, let max, _):
            guard let intValue = newValue as? Int,
                  intValue >= min && intValue <= max else {
                throw DSPError.invalidParameterValue
            }
            value = intValue
            
        case .bool:
            guard let boolValue = newValue as? Bool else {
                throw DSPError.invalidParameterValue
            }
            value = boolValue
            
        case .selection(let options, _):
            guard let intValue = newValue as? Int,
                  intValue >= 0 && intValue < options.count else {
                throw DSPError.invalidParameterValue
            }
            value = intValue
        }
    }
}

// MARK: - Audio Buffer

/// Wrapper for audio buffer data
public struct DSPAudioBuffer {
    public let format: AVAudioFormat
    public var data: UnsafeMutablePointer<Float>
    public let frameCount: AVAudioFrameCount
    public let channelCount: Int
    
    /// Get a channel's data
    public func channel(_ index: Int) -> UnsafeMutablePointer<Float> {
        guard index < channelCount else { return data }
        return data.advanced(by: index * Int(frameCount))
    }
    
    /// Create from AVAudioPCMBuffer
    public init?(from buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return nil }
        
        self.format = buffer.format
        self.frameCount = buffer.frameLength
        self.channelCount = Int(format.channelCount)
        self.data = floatData[0]
    }
    
    /// Convert back to AVAudioPCMBuffer
    public func toAVAudioPCMBuffer() -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else { return nil }
        
        for channel in 0..<channelCount {
            let sourceData = self.channel(channel)
            let destData = channelData[channel]
            memcpy(destData, sourceData, Int(frameCount) * MemoryLayout<Float>.size)
        }
        
        return buffer
    }
}

// MARK: - DSP Plugin Protocol

/// Protocol for DSP (Digital Signal Processing) plugins
public protocol DSPPlugin: WAPlugin {
    /// Processing latency in samples
    var latency: Int { get }
    
    /// Supported sample rates (empty = all rates supported)
    var supportedSampleRates: [Double] { get }
    
    /// Supported channel configurations (empty = all configurations supported)
    var supportedChannelCounts: [Int] { get }
    
    /// Whether the DSP can process in-place
    var canProcessInPlace: Bool { get }
    
    /// Current bypass state
    var isBypassed: Bool { get set }
    
    /// Available parameters
    var parameters: [DSPParameter] { get }
    
    /// Prepare for processing with given format
    func prepare(format: AVAudioFormat, maxFrames: AVAudioFrameCount) throws
    
    /// Process audio buffer
    func process(buffer: inout DSPAudioBuffer) throws
    
    /// Process with separate input/output buffers
    func process(input: DSPAudioBuffer, output: inout DSPAudioBuffer) throws
    
    /// Reset internal state
    func reset()
    
    /// Get parameter by ID
    func parameter(withId id: String) -> DSPParameter?
    
    /// Set parameter value
    func setParameter(id: String, value: Any) throws
    
    /// Get current processing load (0.0 - 1.0)
    func getCurrentLoad() -> Float
}

// MARK: - DSP Chain

/// Manages a chain of DSP effects
public class DSPChain {
    private var effects: [DSPPlugin] = []
    private let queue = DispatchQueue(label: "com.winamp.dspchain", attributes: .concurrent)
    private var format: AVAudioFormat?
    private var intermediateBuffers: [DSPAudioBuffer] = []
    
    /// Add an effect to the chain
    public func addEffect(_ effect: DSPPlugin) {
        queue.async(flags: .barrier) {
            self.effects.append(effect)
            
            // Prepare effect if format is already set
            if let format = self.format {
                try? effect.prepare(format: format, maxFrames: 4096)
            }
        }
    }
    
    /// Remove an effect from the chain
    public func removeEffect(_ effect: DSPPlugin) {
        queue.async(flags: .barrier) {
            self.effects.removeAll { $0.metadata.identifier == effect.metadata.identifier }
        }
    }
    
    /// Reorder effects
    public func reorderEffects(_ newOrder: [String]) {
        queue.async(flags: .barrier) {
            let effectsDict = Dictionary(uniqueKeysWithValues: self.effects.map { ($0.metadata.identifier, $0) })
            self.effects = newOrder.compactMap { effectsDict[$0] }
        }
    }
    
    /// Prepare the chain for processing
    public func prepare(format: AVAudioFormat, maxFrames: AVAudioFrameCount) throws {
        try queue.sync(flags: .barrier) {
            self.format = format
            
            // Prepare all effects
            for effect in effects {
                try effect.prepare(format: format, maxFrames: maxFrames)
            }
            
            // Allocate intermediate buffers
            intermediateBuffers = []
            if effects.count > 1 {
                for _ in 0..<(effects.count - 1) {
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames),
                          let dspBuffer = DSPAudioBuffer(from: buffer) else {
                        throw DSPError.bufferAllocationFailed
                    }
                    intermediateBuffers.append(dspBuffer)
                }
            }
        }
    }
    
    /// Process audio through the chain
    public func process(buffer: inout DSPAudioBuffer) throws {
        try queue.sync {
            guard !effects.isEmpty else { return }
            
            // Process through each effect
            for (index, effect) in effects.enumerated() {
                if !effect.isBypassed {
                    if effect.canProcessInPlace {
                        try effect.process(buffer: &buffer)
                    } else if index < effects.count - 1 {
                        // Use intermediate buffer
                        var outputBuffer = intermediateBuffers[index]
                        try effect.process(input: buffer, output: &outputBuffer)
                        buffer = outputBuffer
                    } else {
                        // Last effect, process in place anyway
                        try effect.process(buffer: &buffer)
                    }
                }
            }
        }
    }
    
    /// Get total latency of the chain
    public var totalLatency: Int {
        queue.sync {
            effects.reduce(0) { $0 + ($1.isBypassed ? 0 : $1.latency) }
        }
    }
    
    /// Get all effects in order
    public var allEffects: [DSPPlugin] {
        queue.sync { effects }
    }
}

// MARK: - DSP Errors

/// Errors specific to DSP processing
public enum DSPError: LocalizedError {
    case unsupportedFormat
    case invalidParameterValue
    case processingFailed(String)
    case bufferAllocationFailed
    case notPrepared
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Audio format not supported by this DSP"
        case .invalidParameterValue:
            return "Invalid parameter value"
        case .processingFailed(let reason):
            return "DSP processing failed: \(reason)"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .notPrepared:
            return "DSP not prepared for processing"
        }
    }
}

// MARK: - Built-in DSP Base Class

/// Base class for built-in DSP effects
open class BaseDSPPlugin: DSPPlugin {
    // WAPlugin requirements
    public let metadata: PluginMetadata
    public private(set) var state: PluginState = .unloaded
    private let stateSubject = CurrentValueSubject<PluginState, Never>(.unloaded)
    public var statePublisher: AnyPublisher<PluginState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    // DSP specific
    public var latency: Int { 0 }
    public var supportedSampleRates: [Double] { [] }
    public var supportedChannelCounts: [Int] { [] }
    public var canProcessInPlace: Bool { true }
    public var isBypassed: Bool = false
    public internal(set) var parameters: [DSPParameter] = []
    
    internal var format: AVAudioFormat?
    internal var maxFrames: AVAudioFrameCount = 0
    internal weak var host: PluginHost?
    
    public init(metadata: PluginMetadata) {
        self.metadata = metadata
    }
    
    // WAPlugin methods
    public func initialize(host: PluginHost) async throws {
        self.host = host
        state = .loaded
        stateSubject.send(.loaded)
    }
    
    public func activate() async throws {
        state = .active
        stateSubject.send(.active)
    }
    
    public func deactivate() async throws {
        state = .loaded
        stateSubject.send(.loaded)
    }
    
    public func shutdown() async {
        reset()
        state = .unloaded
        stateSubject.send(.unloaded)
    }
    
    public func configurationView() -> AnyView? {
        nil // Override in subclasses
    }
    
    public func exportSettings() -> Data? {
        // Export parameter values
        let settings = parameters.reduce(into: [String: Any]()) { result, param in
            result[param.id] = param.value
        }
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    public func importSettings(_ data: Data) throws {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PluginError.invalidConfiguration
        }
        
        for (id, value) in settings {
            try? setParameter(id: id, value: value)
        }
    }
    
    public func handleMessage(_ message: PluginMessage) {
        // Override in subclasses if needed
    }
    
    // DSP methods
    public func prepare(format: AVAudioFormat, maxFrames: AVAudioFrameCount) throws {
        self.format = format
        self.maxFrames = maxFrames
    }
    
    public func process(buffer: inout DSPAudioBuffer) throws {
        // Override in subclasses
    }
    
    public func process(input: DSPAudioBuffer, output: inout DSPAudioBuffer) throws {
        // Default implementation copies input to output then processes in place
        memcpy(output.data, input.data, Int(input.frameCount) * input.channelCount * MemoryLayout<Float>.size)
        try process(buffer: &output)
    }
    
    public func reset() {
        // Override in subclasses
    }
    
    public func parameter(withId id: String) -> DSPParameter? {
        parameters.first { $0.id == id }
    }
    
    public func setParameter(id: String, value: Any) throws {
        guard let index = parameters.firstIndex(where: { $0.id == id }) else {
            throw DSPError.invalidParameterValue
        }
        try parameters[index].setValue(value)
    }
    
    public func getCurrentLoad() -> Float {
        0.0 // Override in subclasses to provide actual measurement
    }
}