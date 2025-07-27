//
//  TestClassicUI.swift
//  Test the classic UI components
//

import SwiftUI

@main
struct TestClassicUIApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Classic WinAmp UI Test")
                    .font(.title)
                    .padding()
                
                // Show classic main player
                SkinnableMainPlayerView()
                    .environmentObject(AudioEngine())
                    .environmentObject(VolumeBalanceController(audioEngine: AudioEngine().audioEngine))
                    .environmentObject(SkinManager.shared)
                
                HStack {
                    // Show classic EQ
                    ClassicEQWindow()
                        .environmentObject(AudioEngine())
                        .environmentObject(VolumeBalanceController(audioEngine: AudioEngine().audioEngine))
                        .environmentObject(SkinManager.shared)
                    
                    // Show classic playlist
                    ClassicPlaylistWindow()
                        .environmentObject(AudioEngine())
                        .environmentObject(VolumeBalanceController(audioEngine: AudioEngine().audioEngine))
                        .environmentObject(SkinManager.shared)
                }
            }
            .frame(width: 800, height: 600)
        }
    }
}