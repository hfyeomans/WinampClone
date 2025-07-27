#!/usr/bin/env swift

import Cocoa
import SwiftUI

print("Starting WinAmp test...")

// Create a simple window to test
@main
struct SimpleTestApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("WinAmp Player Test")
                    .font(.largeTitle)
                    .padding()
                
                Button("Exit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding()
            }
            .frame(width: 400, height: 200)
        }
    }
}

print("App launched successfully")