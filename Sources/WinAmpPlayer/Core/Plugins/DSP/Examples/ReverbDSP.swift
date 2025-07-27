//
//  ReverbDSP.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Example DSP plugin: Simple reverb effect
//

import Foundation
import AVFoundation
import Accelerate

/// Simple reverb DSP plugin using Schroeder reverb algorithm
public final class ReverbDSPPlugin: BaseDSPPlugin {
    
    // Reverb components per channel
    private struct ChannelReverb {
        var combFilters: [CombFilter] = []
        var allpassFilters: [AllpassFilter] = []
        var predelay: DelayLine
        
        init(sampleRate: Double) {
            // Initialize comb filters with different delay times
            let combDelays: [Int] = [1557, 1617, 1491, 1422] // In samples at 44.1kHz
            for delay in combDelays {
                let scaledDelay = Int(Double(delay) * sampleRate / 44100.0)
                combFilters.append(CombFilter(delayLength: scaledDelay))
            }
            
            // Initialize allpass filters
            let allpassDelays: [Int] = [225, 341] // In samples at 44.1kHz
            for delay in allpassDelays {
                let scaledDelay = Int(Double(delay) * sampleRate / 44100.0)
                allpassFilters.append(AllpassFilter(delayLength: scaledDelay))
            }
            
            // Pre-delay (up to 100ms)
            let maxPredelayLength = Int(0.1 * sampleRate)
            predelay = DelayLine(maxLength: maxPredelayLength)
        }
        
        mutating func reset() {
            combFilters.forEach { $0.reset() }
            allpassFilters.forEach { $0.reset() }
            predelay.reset()
        }
    }
    
    private var channelReverbs: [ChannelReverb] = []
    private var wetLevel: Float = 0.3
    private var dryLevel: Float = 0.7
    
    public override var latency: Int {
        // Pre-delay latency
        return Int(parameters.first(where: { $0.id == "predelay" })?.value as? Float ?? 0.0)
    }
    
    public init() {
        let metadata = PluginMetadata(
            identifier: "com.winamp.dsp.reverb",
            name: "Reverb",
            type: .dsp,
            version: "1.0.0",
            author: "WinAmp Team",
            description: "Classic digital reverb effect"
        )
        
        super.init(metadata: metadata)
        
        // Initialize parameters
        parameters = [
            DSPParameter(
                id: "room_size",
                name: "Room Size",
                type: .float(min: 0.0, max: 1.0, defaultValue: 0.5)
            ),
            DSPParameter(
                id: "damping",
                name: "Damping",
                type: .float(min: 0.0, max: 1.0, defaultValue: 0.5)
            ),
            DSPParameter(
                id: "wet_level",
                name: "Wet Level",
                type: .float(min: 0.0, max: 1.0, defaultValue: 0.3)
            ),
            DSPParameter(
                id: "dry_level",
                name: "Dry Level",
                type: .float(min: 0.0, max: 1.0, defaultValue: 0.7)
            ),
            DSPParameter(
                id: "predelay",
                name: "Pre-delay",
                type: .float(min: 0.0, max: 100.0, defaultValue: 20.0),
                unit: "ms"
            ),
            DSPParameter(
                id: "width",
                name: "Stereo Width",
                type: .float(min: 0.0, max: 1.0, defaultValue: 1.0)
            )
        ]
    }
    
    public override func prepare(format: AVAudioFormat, maxFrames: AVAudioFrameCount) throws {
        try super.prepare(format: format, maxFrames: maxFrames)
        
        let channelCount = Int(format.channelCount)
        let sampleRate = format.sampleRate
        
        // Initialize reverb for each channel
        channelReverbs = []
        for _ in 0..<channelCount {
            channelReverbs.append(ChannelReverb(sampleRate: sampleRate))
        }
        
        // Apply current parameter values
        updateReverbParameters()
    }
    
    public override func process(buffer: inout DSPAudioBuffer) throws {
        guard !channelReverbs.isEmpty else {
            throw DSPError.notPrepared
        }
        
        let frameCount = Int(buffer.frameCount)
        let channelCount = buffer.channelCount
        
        // Temporary buffer for wet signal
        var wetBuffer = [Float](repeating: 0, count: frameCount)
        
        // Process each channel
        for channel in 0..<channelCount {
            let channelData = buffer.channel(channel)
            var reverb = channelReverbs[channel]
            
            // Clear wet buffer
            wetBuffer.withUnsafeMutableBufferPointer { ptr in
                ptr.baseAddress?.initialize(repeating: 0, count: frameCount)
            }
            
            // Process each sample
            for i in 0..<frameCount {
                var input = channelData[i]
                
                // Apply pre-delay
                input = reverb.predelay.process(input)
                
                // Process through parallel comb filters
                var combOutput: Float = 0
                for j in 0..<reverb.combFilters.count {
                    combOutput += reverb.combFilters[j].process(input)
                }
                combOutput *= 0.25 // Average the comb outputs
                
                // Process through series allpass filters
                var output = combOutput
                for j in 0..<reverb.allpassFilters.count {
                    output = reverb.allpassFilters[j].process(output)
                }
                
                wetBuffer[i] = output
            }
            
            // Mix wet and dry signals
            for i in 0..<frameCount {
                channelData[i] = channelData[i] * dryLevel + wetBuffer[i] * wetLevel
            }
            
            channelReverbs[channel] = reverb
        }
        
        // Apply stereo width if stereo
        if channelCount == 2 {
            let width = parameters.first(where: { $0.id == "width" })?.value as? Float ?? 1.0
            if width < 1.0 {
                let leftChannel = buffer.channel(0)
                let rightChannel = buffer.channel(1)
                
                for i in 0..<frameCount {
                    let mid = (leftChannel[i] + rightChannel[i]) * 0.5
                    let side = (leftChannel[i] - rightChannel[i]) * 0.5
                    
                    leftChannel[i] = mid + side * width
                    rightChannel[i] = mid - side * width
                }
            }
        }
    }
    
    public override func reset() {
        for i in 0..<channelReverbs.count {
            channelReverbs[i].reset()
        }
    }
    
    public override func setParameter(id: String, value: Any) throws {
        try super.setParameter(id: id, value: value)
        updateReverbParameters()
    }
    
    private func updateReverbParameters() {
        guard let format = format else { return }
        
        let roomSize = parameters.first(where: { $0.id == "room_size" })?.value as? Float ?? 0.5
        let damping = parameters.first(where: { $0.id == "damping" })?.value as? Float ?? 0.5
        let predelayMs = parameters.first(where: { $0.id == "predelay" })?.value as? Float ?? 20.0
        
        wetLevel = parameters.first(where: { $0.id == "wet_level" })?.value as? Float ?? 0.3
        dryLevel = parameters.first(where: { $0.id == "dry_level" })?.value as? Float ?? 0.7
        
        let sampleRate = format.sampleRate
        let predelaySamples = Int(predelayMs * Float(sampleRate) / 1000.0)
        
        // Update reverb parameters
        for i in 0..<channelReverbs.count {
            // Set pre-delay
            channelReverbs[i].predelay.delayTime = predelaySamples
            
            // Update comb filter parameters
            for j in 0..<channelReverbs[i].combFilters.count {
                channelReverbs[i].combFilters[j].feedback = 0.5 + roomSize * 0.45
                channelReverbs[i].combFilters[j].damping = damping
            }
            
            // Update allpass filter parameters
            for j in 0..<channelReverbs[i].allpassFilters.count {
                channelReverbs[i].allpassFilters[j].feedback = 0.5
            }
        }
    }
}

// MARK: - Delay Line

private class DelayLine {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    var delayTime: Int = 0
    
    init(maxLength: Int) {
        buffer = [Float](repeating: 0, count: maxLength)
    }
    
    func process(_ input: Float) -> Float {
        let readIndex = (writeIndex - delayTime + buffer.count) % buffer.count
        let output = buffer[readIndex]
        
        buffer[writeIndex] = input
        writeIndex = (writeIndex + 1) % buffer.count
        
        return output
    }
    
    func reset() {
        buffer.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress?.initialize(repeating: 0, count: buffer.count)
        }
        writeIndex = 0
    }
}

// MARK: - Comb Filter

private class CombFilter {
    private var delayLine: DelayLine
    private var lastOutput: Float = 0
    var feedback: Float = 0.8
    var damping: Float = 0.5
    
    init(delayLength: Int) {
        delayLine = DelayLine(maxLength: delayLength)
        delayLine.delayTime = delayLength
    }
    
    func process(_ input: Float) -> Float {
        let delayed = delayLine.process(input + lastOutput * feedback)
        lastOutput = delayed * (1 - damping) + lastOutput * damping
        return delayed
    }
    
    func reset() {
        delayLine.reset()
        lastOutput = 0
    }
}

// MARK: - Allpass Filter

private class AllpassFilter {
    private var delayLine: DelayLine
    var feedback: Float = 0.5
    
    init(delayLength: Int) {
        delayLine = DelayLine(maxLength: delayLength)
        delayLine.delayTime = delayLength
    }
    
    func process(_ input: Float) -> Float {
        let delayed = delayLine.process(input)
        let output = -input + delayed
        _ = delayLine.process(input + delayed * feedback)
        return output
    }
    
    func reset() {
        delayLine.reset()
    }
}