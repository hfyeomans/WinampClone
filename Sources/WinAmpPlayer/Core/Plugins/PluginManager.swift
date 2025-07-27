//
//  PluginManager.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Central manager for all plugin types
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

/// Central plugin manager that handles all plugin types
public final class PluginManager: ObservableObject {
    
    /// Shared instance
    public static let shared = PluginManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var visualizationPlugins: [VisualizationPlugin] = []
    @Published public private(set) var dspPlugins: [DSPPlugin] = []
    @Published public private(set) var generalPlugins: [GeneralPlugin] = []
    
    @Published public private(set) var activeVisualization: VisualizationPlugin?
    @Published public private(set) var activeDSPChain = DSPChain()
    @Published public private(set) var activeGeneralPlugins: [GeneralPlugin] = []
    
    @Published public private(set) var isScanning = false
    @Published public private(set) var lastScanDate: Date?
    
    // MARK: - Private Properties
    
    private let pluginHost = PluginHostImpl()
    private let queue = DispatchQueue(label: "com.winamp.pluginmanager", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // Plugin directories
    private let pluginDirectories: [URL]
    
    // Loaded plugin bundles
    private var loadedBundles: [String: PluginBundle] = [:]
    
    // Plugin instances
    private var allPlugins: [String: WAPlugin] = [:]
    
    private init() {
        // Setup plugin directories
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let winampDir = appSupport.appendingPathComponent("WinAmpPlayer")
        let pluginsDir = winampDir.appendingPathComponent("Plugins")
        
        // Create plugins directory if needed
        try? FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        
        // Built-in plugins directory (in app bundle)
        let builtInPluginsDir = Bundle.main.url(forResource: "Plugins", withExtension: nil) ?? Bundle.main.bundleURL
        
        self.pluginDirectories = [pluginsDir, builtInPluginsDir]
        
        // Load built-in plugins
        loadBuiltInPlugins()
        
        // Scan for external plugins
        Task {
            await scanForPlugins()
        }
    }
    
    // MARK: - Public Methods
    
    /// Scan for plugins in the plugin directories
    public func scanForPlugins() async {
        await MainActor.run {
            isScanning = true
        }
        
        defer {
            Task { @MainActor in
                isScanning = false
                lastScanDate = Date()
            }
        }
        
        // Scan each directory
        for directory in pluginDirectories {
            await scanDirectory(directory)
        }
    }
    
    /// Load a plugin from URL
    public func loadPlugin(from url: URL) async throws {
        let bundle = try await loadPluginBundle(from: url)
        
        // Create plugin instance
        if let plugin = try? bundle.loadPlugin() {
            try await initializePlugin(plugin)
        }
    }
    
    /// Unload a plugin
    public func unloadPlugin(_ plugin: WAPlugin) async {
        await plugin.shutdown()
        
        await MainActor.run {
            let id = plugin.metadata.identifier
            
            // Remove from type-specific arrays
            visualizationPlugins.removeAll { $0.metadata.identifier == id }
            dspPlugins.removeAll { $0.metadata.identifier == id }
            generalPlugins.removeAll { $0.metadata.identifier == id }
            
            // Remove from active lists
            if activeVisualization?.metadata.identifier == id {
                activeVisualization = nil
            }
            
            activeDSPChain.removeEffect(dspPlugins.first { $0.metadata.identifier == id }!)
            activeGeneralPlugins.removeAll { $0.metadata.identifier == id }
            
            // Remove from all plugins
            allPlugins.removeValue(forKey: id)
            loadedBundles.removeValue(forKey: id)
        }
    }
    
    /// Activate a visualization plugin
    public func activateVisualization(_ plugin: VisualizationPlugin) async {
        // Deactivate current
        if let current = activeVisualization {
            await current.deactivate()
        }
        
        // Activate new
        do {
            try await plugin.activate()
            await MainActor.run {
                activeVisualization = plugin
            }
        } catch {
            pluginHost.log("Failed to activate visualization: \(error)", level: .error, from: "PluginManager")
        }
    }
    
    /// Add a DSP plugin to the chain
    public func addDSPToChain(_ plugin: DSPPlugin) {
        activeDSPChain.addEffect(plugin)
    }
    
    /// Remove a DSP plugin from the chain
    public func removeDSPFromChain(_ plugin: DSPPlugin) {
        activeDSPChain.removeEffect(plugin)
    }
    
    /// Activate a general plugin
    public func activateGeneralPlugin(_ plugin: GeneralPlugin) async {
        do {
            try await plugin.activate()
            await MainActor.run {
                if !activeGeneralPlugins.contains(where: { $0.metadata.identifier == plugin.metadata.identifier }) {
                    activeGeneralPlugins.append(plugin)
                }
            }
        } catch {
            pluginHost.log("Failed to activate general plugin: \(error)", level: .error, from: "PluginManager")
        }
    }
    
    /// Deactivate a general plugin
    public func deactivateGeneralPlugin(_ plugin: GeneralPlugin) async {
        do {
            try await plugin.deactivate()
            await MainActor.run {
                activeGeneralPlugins.removeAll { $0.metadata.identifier == plugin.metadata.identifier }
            }
        } catch {
            pluginHost.log("Failed to deactivate general plugin: \(error)", level: .error, from: "PluginManager")
        }
    }
    
    /// Process audio through visualization
    public func processVisualizationData(_ audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        activeVisualization?.render(audioData: audioData, context: context)
    }
    
    /// Process audio through DSP chain
    public func processDSPAudio(_ buffer: inout DSPAudioBuffer) throws {
        try activeDSPChain.process(buffer: &buffer)
    }
    
    /// Send event to general plugins
    public func sendPlayerEvent(_ event: PlayerEvent) {
        for plugin in activeGeneralPlugins {
            plugin.handlePlayerEvent(event)
        }
    }
    
    /// Get menu items from all plugins
    public var allPluginMenuItems: [PluginMenuItem] {
        activeGeneralPlugins.flatMap { $0.menuItems }
    }
    
    /// Get toolbar items from all plugins
    public var allPluginToolbarItems: [PluginToolbarItem] {
        activeGeneralPlugins.flatMap { $0.toolbarItems }
    }
    
    // MARK: - Private Methods
    
    private func loadBuiltInPlugins() {
        // Built-in visualizations
        let spectrum = SpectrumVisualizationPlugin()
        let oscilloscope = OscilloscopeVisualizationPlugin()
        let matrix = MatrixRainVisualizationPlugin()
        
        Task {
            try? await initializePlugin(spectrum)
            try? await initializePlugin(oscilloscope)
            try? await initializePlugin(matrix)
        }
        
        // Built-in DSP
        let equalizer = EqualizerDSPPlugin()
        let reverb = ReverbDSPPlugin()
        
        Task {
            try? await initializePlugin(equalizer)
            try? await initializePlugin(reverb)
        }
        
        // Built-in general plugins
        let lastfm = LastFMScrobblerPlugin()
        let discord = DiscordPresencePlugin()
        
        Task {
            try? await initializePlugin(lastfm)
            try? await initializePlugin(discord)
        }
    }
    
    private func scanDirectory(_ directory: URL) async {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "waplugin" {
                do {
                    try await loadPlugin(from: fileURL)
                } catch {
                    pluginHost.log("Failed to load plugin at \(fileURL): \(error)", level: .error, from: "PluginManager")
                }
            }
        }
    }
    
    private func loadPluginBundle(from url: URL) async throws -> PluginBundle {
        // Read Info.plist
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw PluginError.loadingFailed("Invalid Info.plist")
        }
        
        // Parse metadata
        guard let identifier = plist["CFBundleIdentifier"] as? String,
              let typeString = plist["WAPluginType"] as? String,
              let type = PluginType(rawValue: typeString),
              let name = plist["WAPluginName"] as? String,
              let version = plist["WAPluginVersion"] as? String,
              let author = plist["WAPluginAuthor"] as? String else {
            throw PluginError.loadingFailed("Missing required metadata")
        }
        
        let metadata = PluginMetadata(
            identifier: identifier,
            name: name,
            type: type,
            version: version,
            author: author,
            description: plist["WAPluginDescription"] as? String ?? ""
        )
        
        let bundle = PluginBundle(
            url: url,
            metadata: metadata,
            bundleIdentifier: identifier,
            executableURL: url.appendingPathComponent("Contents/MacOS/\(url.deletingPathExtension().lastPathComponent)"),
            resourcesURL: url.appendingPathComponent("Contents/Resources"),
            isBuiltIn: false
        )
        
        loadedBundles[identifier] = bundle
        return bundle
    }
    
    private func initializePlugin(_ plugin: WAPlugin) async throws {
        // Check if already loaded
        let id = plugin.metadata.identifier
        if allPlugins[id] != nil {
            return
        }
        
        // Initialize with host
        try await plugin.initialize(host: pluginHost)
        
        // Store plugin
        allPlugins[id] = plugin
        
        // Add to appropriate type array
        await MainActor.run {
            switch plugin.metadata.type {
            case .visualization:
                if let vizPlugin = plugin as? VisualizationPlugin {
                    visualizationPlugins.append(vizPlugin)
                }
                
            case .dsp:
                if let dspPlugin = plugin as? DSPPlugin {
                    dspPlugins.append(dspPlugin)
                }
                
            case .general:
                if let generalPlugin = plugin as? GeneralPlugin {
                    generalPlugins.append(generalPlugin)
                }
                
            default:
                break
            }
        }
        
        pluginHost.log("Loaded plugin: \(plugin.metadata.name) v\(plugin.metadata.version)", level: .info, from: "PluginManager")
    }
}

// MARK: - Plugin Host Implementation

private class PluginHostImpl: PluginHost {
    var hostVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var capabilities: Set<String> {
        Set([
            "player_control",
            "playlist_access",
            "file_access",
            "network_access",
            "ui_extension",
            "media_library_access",
            "notification_access",
            "preferences_access"
        ])
    }
    
    private let messageSubject = PassthroughSubject<PluginMessage, Never>()
    
    func log(_ message: String, level: LogLevel, from plugin: String) {
        let prefix = "[\(plugin)]"
        
        switch level {
        case .debug:
            #if DEBUG
            print("🔍 \(prefix) \(message)")
            #endif
        case .info:
            print("ℹ️ \(prefix) \(message)")
        case .warning:
            print("⚠️ \(prefix) \(message)")
        case .error:
            print("❌ \(prefix) \(message)")
        }
    }
    
    func requestCapability(_ capability: String) -> Bool {
        capabilities.contains(capability)
    }
    
    func getService<T>(_ serviceType: T.Type) -> T? {
        // Return appropriate service implementations
        // This would be connected to the actual services in the app
        return nil
    }
    
    func sendMessage(_ message: PluginMessage, to recipient: String?) {
        messageSubject.send(message)
    }
    
    func subscribeToMessages(from sender: String?, handler: @escaping (PluginMessage) -> Void) -> AnyCancellable {
        messageSubject
            .filter { message in
                sender == nil || message.sender == sender
            }
            .sink { message in
                handler(message)
            }
    }
}