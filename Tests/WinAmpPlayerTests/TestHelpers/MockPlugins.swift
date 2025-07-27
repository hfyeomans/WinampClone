//
//  MockPlugins.swift
//  WinAmpPlayerTests
//
//  Mock plugin implementations for testing
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
@testable import WinAmpPlayer

// MARK: - Base Mock Plugin

class MockPlugin: WAPlugin {
    // Required properties
    let metadata: PluginMetadata
    @Published private(set) var state: PluginState = .unloaded
    
    var statePublisher: AnyPublisher<PluginState, Never> {
        $state.eraseToAnyPublisher()
    }
    
    // Test helpers
    weak var host: PluginHost?
    var initializeCalled = false
    var activateCalled = false
    var deactivateCalled = false
    var shutdownCalled = false
    
    init(name: String, type: PluginType) {
        self.metadata = PluginMetadata(
            identifier: "com.test.\(name.lowercased())",
            name: name,
            type: type,
            version: "1.0",
            author: "Test Suite",
            description: "Mock \(type.rawValue) plugin for testing"
        )
    }
    
    func initialize(host: PluginHost) async throws {
        self.host = host
        self.initializeCalled = true
        state = .loaded
    }
    
    func activate() async throws {
        guard state == .loaded else {
            throw PluginError.invalidState("Must be loaded before activation")
        }
        activateCalled = true
        state = .active
    }
    
    func deactivate() async throws {
        deactivateCalled = true
        state = .loaded
    }
    
    func shutdown() async {
        shutdownCalled = true
        state = .unloaded
    }
    
    func configurationView() -> AnyView? {
        return nil
    }
    
    func exportSettings() -> Data? {
        return nil
    }
    
    func importSettings(_ data: Data) throws {
        // No-op
    }
    
    func handleMessage(_ message: PluginMessage) {
        // No-op
    }
}

// MARK: - Test DSP Plugin

class TestDSPPlugin: MockPlugin {
    var onProcess: ((AVAudioPCMBuffer) -> Void)?
    
    override init(name: String, type: PluginType = .dsp) {
        super.init(name: name, type: type)
    }
    
    func process(_ buffer: AVAudioPCMBuffer) {
        onProcess?(buffer)
    }
}

// MARK: - Test General Plugin

class TestGeneralPlugin: MockPlugin {
    var menuItems: [String] = []
    var onInitialize: ((PluginHost) -> Void)?
    var onActivate: (() -> Void)?
    var onPlayerEvent: ((PlayerEvent) -> Void)?
    
    override init(name: String, type: PluginType = .general) {
        super.init(name: name, type: type)
    }
    
    override func initialize(host: PluginHost) async throws {
        try await super.initialize(host: host)
        onInitialize?(host)
    }
    
    override func activate() async throws {
        try await super.activate()
        onActivate?()
    }
    
    func handlePlayerEvent(_ event: PlayerEvent) {
        onPlayerEvent?(event)
    }
}

// MARK: - Test Crash Plugin

class TestCrashPlugin: MockPlugin {
    override func activate() async throws {
        throw PluginError.activationFailed("Intentional crash for testing")
    }
}

// MARK: - Test Visualization Plugin

class TestVisualizationPlugin: MockPlugin {
    var onRender: ((CGContext) -> Void)?
    var onActivate: (() -> Void)?
    var onDeactivate: (() -> Void)?
    
    override init(name: String, type: PluginType = .visualization) {
        super.init(name: name, type: type)
    }
    
    override func activate() async throws {
        try await super.activate()
        onActivate?()
    }
    
    override func deactivate() async throws {
        try await super.deactivate()
        onDeactivate?()
    }
    
    func render(context: CGContext, size: CGSize, data: AudioVisualizationData) {
        onRender?(context)
    }
}

// MARK: - Plugin Error

enum PluginError: LocalizedError {
    case activationFailed(String)
    case invalidState(String)
    case loadingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .activationFailed(let reason):
            return "Plugin activation failed: \(reason)"
        case .invalidState(let state):
            return "Invalid plugin state: \(state)"
        case .loadingFailed(let reason):
            return "Plugin loading failed: \(reason)"
        }
    }
}

// MARK: - Player Event

enum PlayerEvent {
    case trackStarted
    case trackEnded
    case trackPaused
    case trackResumed
}

// MARK: - PluginManager Test Extensions

extension PluginManager {
    // Test helpers
    static var testOnError: ((Error, LogLevel) -> Void)?
    
    // Provide access to chain count for tests
    var activeDSPChainCount: Int {
        return activeDSPChain.allEffects.count
    }
    
    func reset() {
        // Clear all plugins and state
        if let viz = activeVisualization {
            Task { try? await viz.deactivate() }
        }
        activeVisualization = nil
        
        activeDSPChain.removeAll()
        activeGeneralPlugins.removeAll()
        
        // Clear registered plugins (this would need to be implemented in actual PluginManager)
        visualizationPlugins.removeAll()
        dspPlugins.removeAll()
        generalPlugins.removeAll()
    }
    
    func registerPlugin(_ plugin: WAPlugin) {
        switch plugin.metadata.type {
        case .visualization:
            if let vizPlugin = plugin as? VisualizationPlugin {
                visualizationPlugins.append(vizPlugin)
            }
        case .dsp:
            dspPlugins.append(plugin)
        case .general:
            generalPlugins.append(plugin)
        default:
            break
        }
    }
    
    func sendPlayerEvent(_ event: PlayerEvent) {
        for plugin in activeGeneralPlugins {
            if let generalPlugin = plugin as? TestGeneralPlugin {
                generalPlugin.handlePlayerEvent(event)
            }
        }
    }
    
    func processVisualizationData(_ data: AudioVisualizationData) {
        // Process visualization data through active visualization
        if let viz = activeVisualization as? TestVisualizationPlugin {
            // Create a mock context
            let size = CGSize(width: 512, height: 256)
            if let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                viz.render(context: context, size: size, data: data)
            }
        }
    }
    
    func processDSPChain(_ buffer: AVAudioPCMBuffer) {
        for plugin in activeDSPChain {
            if let dspPlugin = plugin as? TestDSPPlugin {
                dspPlugin.process(buffer)
            }
        }
    }
    
    func getMenuItems(for plugin: WAPlugin) -> [String] {
        if let generalPlugin = plugin as? TestGeneralPlugin {
            return generalPlugin.menuItems
        }
        return []
    }
    
    // DSP management methods for testing
    func addDSP(_ plugin: WAPlugin) async throws {
        guard let dspPlugin = plugin as? DSPPlugin else {
            throw PluginError.invalidState("Not a DSP plugin")
        }
        
        if plugin.state != .active {
            try await plugin.initialize(host: self)
            try await plugin.activate()
        }
        
        activeDSPChain.addEffect(dspPlugin)
    }
    
    func removeDSP(_ plugin: WAPlugin) {
        guard let dspPlugin = plugin as? DSPPlugin else { return }
        activeDSPChain.removeEffect(dspPlugin)
    }
    
    // Visualization activation for testing
    func activateVisualization(_ plugin: WAPlugin) async throws {
        guard plugin.metadata.type == .visualization else {
            throw PluginError.invalidState("Not a visualization plugin")
        }
        
        // Deactivate current
        if let current = activeVisualization {
            try await current.deactivate()
        }
        
        // Activate new
        if plugin.state != .active {
            try await plugin.initialize(host: self)
            try await plugin.activate()
        }
        
        activeVisualization = plugin
    }
    
    // General plugin activation for testing
    func activateGeneralPlugin(_ plugin: WAPlugin) async throws {
        guard plugin.metadata.type == .general else {
            throw PluginError.invalidState("Not a general plugin")
        }
        
        if plugin.state != .active {
            try await plugin.initialize(host: self)
            try await plugin.activate()
        }
        
        activeGeneralPlugins.append(plugin)
    }
}

// MARK: - PluginManager as PluginHost

extension PluginManager: PluginHost {
    public var hostVersion: String {
        return "1.0.0"
    }
    
    public var capabilities: Set<String> {
        return ["audio_playback", "visualization", "dsp_processing"]
    }
    
    public func log(_ message: String, level: LogLevel, from plugin: String) {
        print("[\(level.rawValue)] \(plugin): \(message)")
        
        // Call test error handler if error
        if level == .error {
            PluginManager.testOnError?(NSError(domain: plugin, code: 0, userInfo: [NSLocalizedDescriptionKey: message]), level)
        }
    }
    
    public func requestCapability(_ capability: String) -> Bool {
        return capabilities.contains(capability)
    }
    
    public func getService<T>(_ serviceType: T.Type) -> T? {
        return nil
    }
    
    public func sendMessage(_ message: PluginMessage, to recipient: String?) {
        // Not implemented for tests
    }
    
    public func subscribeToMessages(from sender: String?, handler: @escaping (PluginMessage) -> Void) -> AnyCancellable {
        return AnyCancellable({})
    }
}