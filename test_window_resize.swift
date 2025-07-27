#!/usr/bin/env swift

import Cocoa
import SwiftUI

// Test app to verify window resizing behavior
@main
struct TestWindowApp: App {
    var body: some Scene {
        WindowGroup("Test Window") {
            TestView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct TestView: View {
    var body: some View {
        VStack {
            Text("Window Resizing Test")
                .font(.title)
                .padding()
            
            Text("Try resizing from corners")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity,
               minHeight: 200, idealHeight: 300, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}