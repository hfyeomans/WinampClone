//
//  TestApp.swift
//  WinAmpPlayer
//
//  Example app to demonstrate the WinAmp Player integration
//

import SwiftUI

// Removed @main to avoid conflicts with WinAmpPlayerApp
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 275, idealWidth: 275, maxWidth: 275,
                       minHeight: 116, idealHeight: 116, maxHeight: 116)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}