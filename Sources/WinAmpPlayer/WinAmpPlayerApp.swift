//
//  WinAmpPlayerApp.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  A modern macOS recreation of the classic WinAmp player.
//

import SwiftUI

@main
struct WinAmpPlayerApp: App {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var volumeController: VolumeBalanceController
    @StateObject private var playlistController: PlaylistController
    @StateObject private var skinManager = SkinManager.shared
    @StateObject private var pluginManager = PluginManager.shared
    
    init() {
        let engine = AudioEngine()
        let controller = VolumeBalanceController(audioEngine: engine.audioEngine)
        engine.setVolumeController(controller)
        let playlist = PlaylistController(audioEngine: engine, volumeController: controller)
        
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: controller)
        _playlistController = StateObject(wrappedValue: playlist)
        
        // Initialize skin system
        Task {
            try? await SkinAssetCache.shared.preloadDefaultSkin()
        }
        
        // Setup DSP processing in audio engine
        engine.setupDSPProcessing()
    }
    
    var body: some Scene {
        Group {
            mainWindow
            equalizerWindow
            playlistWindow
        }
        .commands {
            fileMenuCommands
            skinMenuCommands
            pluginMenuCommands
        }
    }
    
    // MARK: - Scene Components
    
    private var mainWindow: some Scene {
        WindowGroup("WinAmp Player") {
            VStack(spacing: 0) {
                // Custom title bar with skin-based chrome
                CustomTitleBar()
                    .frame(height: 14)
                
                // Main player content
                mainPlayerView
                    .frame(width: 275, height: 102) // Reduced by title bar height
            }
            .frame(width: 275, height: 116)
            .environmentObject(audioEngine)
            .environmentObject(volumeController)
            .environmentObject(playlistController)
            .environmentObject(skinManager)
            .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    private var equalizerWindow: some Scene {
        WindowGroup("Equalizer", id: "equalizer") {
            ClassicEQWindow()
                .environmentObject(audioEngine)
                .environmentObject(volumeController)
                .environmentObject(skinManager)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    private var playlistWindow: some Scene {
        WindowGroup("Playlist", id: "playlist") {
            ClassicPlaylistWindow()
                .environmentObject(audioEngine)
                .environmentObject(volumeController)
                .environmentObject(playlistController)
                .environmentObject(skinManager)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    private var mainPlayerView: some View {
        SkinnableMainPlayerView()
            .environmentObject(audioEngine)
            .environmentObject(volumeController)
            .environmentObject(playlistController)
            .environmentObject(skinManager)
            .preferredColorScheme(.dark)
    }
    
    // MARK: - Command Menus
    
    @CommandsBuilder
    private var fileMenuCommands: some Commands {
        CommandMenu("File") {
            Button("Open Audio File...") {
                let panel = NSOpenPanel()
                panel.allowedFileTypes = ["mp3", "m4a", "wav", "flac", "aac"]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                
                if panel.runModal() == .OK, let url = panel.url {
                    Task {
                        do {
                            try await audioEngine.loadURL(url)
                            print("🎵 Audio file loaded successfully: \(url.lastPathComponent)")
                        } catch {
                            print("🎵 ❌ Failed to load audio file: \(error)")
                        }
                    }
                }
            }
            .keyboardShortcut("O", modifiers: [.command])
        }
    }
    
    @CommandsBuilder
    private var skinMenuCommands: some Commands {
        CommandMenu("Skins") {
            ForEach(skinManager.availableSkins.prefix(10)) { skin in
                Button(skin.name) {
                    Task {
                        try? await skinManager.applySkin(skin)
                    }
                }
                .disabled(skinManager.currentSkin.id == skin.id)
            }
            
            if skinManager.availableSkins.count > 10 {
                Divider()
                Text("More skins available...")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button("Browse Skins...") {
                SecondaryWindowManager.shared.openSkinBrowser()
            }
            .keyboardShortcut("K", modifiers: [.command, .shift])
            
            Button("Load Skin File...") {
                let panel = NSOpenPanel()
                panel.allowedFileTypes = ["wsz", "zip"]
                panel.allowsMultipleSelection = false
                
                if panel.runModal() == .OK, let url = panel.url {
                    Task {
                        if let skin = try? await skinManager.installSkin(from: url) {
                            try? await skinManager.applySkin(skin)
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Generate Skin...") {
                SecondaryWindowManager.shared.openSkinGenerator()
            }
            .keyboardShortcut("G", modifiers: [.command, .shift])
            
            Button("Get More Skins Online...") {
                NSWorkspace.shared.open(URL(string: "https://skins.webamp.org/")!)
            }
        }
    }
    
    @CommandsBuilder
    private var pluginMenuCommands: some Commands {
        CommandMenu("Plugins") {
            // Visualization plugins
            Menu("Visualization") {
                ForEach(pluginManager.visualizationPlugins, id: \.metadata.identifier) { plugin in
                    Button(action: {
                        Task {
                            await pluginManager.activateVisualization(plugin)
                        }
                    }) {
                        HStack {
                            Text(plugin.metadata.name)
                            if pluginManager.activeVisualization?.metadata.identifier == plugin.metadata.identifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // DSP plugins
            Menu("DSP Effects") {
                ForEach(pluginManager.dspPlugins, id: \.metadata.identifier) { plugin in
                    let isActive = pluginManager.activeDSPChain.allEffects.contains { $0.metadata.identifier == plugin.metadata.identifier }
                    Button(action: {
                        if isActive {
                            pluginManager.removeDSPFromChain(plugin)
                        } else {
                            pluginManager.addDSPToChain(plugin)
                        }
                    }) {
                        HStack {
                            Text(plugin.metadata.name)
                            if isActive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // General plugins
            ForEach(pluginManager.generalPlugins, id: \.metadata.identifier) { plugin in
                let isActive = pluginManager.activeGeneralPlugins.contains { $0.metadata.identifier == plugin.metadata.identifier }
                Button(action: {
                    Task {
                        if isActive {
                            await pluginManager.deactivateGeneralPlugin(plugin)
                        } else {
                            await pluginManager.activateGeneralPlugin(plugin)
                        }
                    }
                }) {
                    HStack {
                        Text(plugin.metadata.name)
                        if isActive {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            // Plugin preferences
            Button("Plugin Preferences...") {
                SecondaryWindowManager.shared.openPluginPreferences()
            }
            .keyboardShortcut("P", modifiers: [.command, .shift])
        }
    }
}

