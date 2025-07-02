//
//  VisualizationTest.swift
//  WinAmpPlayer
//
//  Test to verify visualization integration in MainPlayerView
//

import SwiftUI

@main
struct VisualizationTestApp: App {
    var body: some Scene {
        WindowGroup {
            MainPlayerView()
                .preferredColorScheme(.dark)
        }
    }
}