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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 275, idealWidth: 275, maxWidth: .infinity,
                       minHeight: 116, idealHeight: 116, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Custom menu commands can be added here
        }
    }
}