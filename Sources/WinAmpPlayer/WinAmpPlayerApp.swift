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
    @StateObject private var skinManager = SkinManager.shared
    
    init() {
        let engine = AudioEngine()
        let controller = VolumeBalanceController(audioEngine: engine.audioEngine)
        engine.setVolumeController(controller)
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: controller)
        
        // Initialize skin system
        Task {
            try? await SkinAssetCache.shared.preloadDefaultSkin()
        }
    }
    
    var body: some Scene {
        WindowGroup("WinAmp Player") {
            SkinnableMainPlayerView()
                .environmentObject(audioEngine)
                .environmentObject(volumeController)
                .environmentObject(skinManager)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove unwanted menu items
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            
            // Add skin menu
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
                
                Button("Get More Skins Online...") {
                    NSWorkspace.shared.open(URL(string: "https://skins.webamp.org/")!)
                }
            }
        }
        
        // Equalizer Window
        WindowGroup("Equalizer", id: "equalizer") {
            Text("Equalizer - Coming Soon")
                .frame(width: 275, height: 116)
                .winAmpWindow(configuration: WinAmpWindowConfiguration(
                    title: "Equalizer",
                    windowType: .equalizer,
                    resizable: false
                ))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // Playlist Window
        WindowGroup("Playlist", id: "playlist") {
            Text("Playlist - Coming Soon")
                .frame(width: 275, height: 232)
                .winAmpWindow(configuration: WinAmpWindowConfiguration(
                    title: "Playlist",
                    windowType: .playlist,
                    resizable: true
                ))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}