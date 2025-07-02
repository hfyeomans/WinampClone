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
    
    init() {
        let engine = AudioEngine()
        let controller = VolumeBalanceController(audioEngine: engine.audioEngine)
        engine.setVolumeController(controller)
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: controller)
    }
    
    var body: some Scene {
        WindowGroup("WinAmp Player") {
            MainPlayerView()
                .environmentObject(audioEngine)
                .environmentObject(volumeController)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove unwanted menu items
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
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