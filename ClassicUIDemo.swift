//
//  ClassicUIDemo.swift
//  Demo of the classic WinAmp UI
//

import SwiftUI
import AppKit

// Simple color definitions for the demo
struct DemoColors {
    static let background = Color(red: 58/255, green: 58/255, blue: 58/255)
    static let backgroundLight = Color(red: 74/255, green: 74/255, blue: 74/255)
    static let darkBorder = Color(red: 31/255, green: 31/255, blue: 31/255)
    static let lightBorder = Color(red: 165/255, green: 165/255, blue: 165/255)
    static let text = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let lcdBackground = Color.black
    static let lcdText = Color(red: 0, green: 1, blue: 0)
    static let buttonNormal = Color(red: 74/255, green: 74/255, blue: 74/255)
}

// Simple beveled border
struct DemoBeveledBorder: View {
    let raised: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            
            // Top and left edges
            Path { path in
                path.move(to: CGPoint(x: 0, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: 0))
            }
            .stroke(raised ? DemoColors.lightBorder : DemoColors.darkBorder, lineWidth: 1)
            
            // Bottom and right edges
            Path { path in
                path.move(to: CGPoint(x: rect.width, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: rect.height))
            }
            .stroke(raised ? DemoColors.darkBorder : DemoColors.lightBorder, lineWidth: 1)
        }
    }
}

// Demo main player
struct DemoMainPlayer: View {
    @State private var isPlaying = false
    @State private var currentTime = "0:00"
    @State private var volume: Double = 0.7
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("WINAMP")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(DemoColors.text)
                    .padding(.leading, 6)
                Spacer()
                HStack(spacing: 0) {
                    Button("_") { }
                    Button("X") { NSApplication.shared.terminate(nil) }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DemoColors.text)
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 3)
            }
            .frame(height: 14)
            .background(LinearGradient(colors: [DemoColors.backgroundLight, DemoColors.background], startPoint: .top, endPoint: .bottom))
            
            // Main content
            VStack(spacing: 2) {
                // LCD Display area
                HStack(spacing: 4) {
                    // Song info
                    Text("1. DJ Mike Llama - Llama Whippin' Intro")
                        .font(.custom("Monaco", size: 11))
                        .foregroundColor(DemoColors.lcdText)
                        .lineLimit(1)
                        .frame(width: 154, height: 11)
                        .background(DemoColors.lcdBackground)
                        .overlay(DemoBeveledBorder(raised: false))
                    
                    // Visualization
                    HStack(spacing: 1) {
                        ForEach(0..<19) { _ in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(DemoColors.lcdText)
                                    .frame(width: 3, height: CGFloat.random(in: 2...16))
                            }
                        }
                    }
                    .frame(width: 76, height: 16)
                    .background(DemoColors.lcdBackground)
                    .overlay(DemoBeveledBorder(raised: false))
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                
                // Time display
                HStack(spacing: 2) {
                    Text(currentTime)
                        .font(.custom("Monaco", size: 20))
                        .foregroundColor(DemoColors.lcdText)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text("128 kbps 44 kHz Stereo")
                        .font(.system(size: 8))
                        .foregroundColor(DemoColors.lcdText)
                }
                .frame(width: 154, height: 13)
                .background(DemoColors.lcdBackground)
                .overlay(DemoBeveledBorder(raised: false))
                .padding(.horizontal, 6)
                
                // Position slider
                Slider(value: .constant(0.3))
                    .frame(height: 10)
                    .padding(.horizontal, 16)
                
                // Control buttons
                HStack(spacing: 0) {
                    ForEach(["backward.fill", "play.fill", "pause.fill", "stop.fill", "forward.fill"], id: \.self) { icon in
                        Button(action: {}) {
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .foregroundColor(DemoColors.text)
                                .frame(width: 23, height: 18)
                                .background(DemoColors.buttonNormal)
                                .overlay(DemoBeveledBorder(raised: true))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DemoColors.text)
                            .frame(width: 22, height: 16)
                            .background(DemoColors.buttonNormal)
                            .overlay(DemoBeveledBorder(raised: true))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 6)
                }
                .padding(.horizontal, 6)
                
                // Volume and balance
                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("VOL")
                            .font(.system(size: 7))
                            .foregroundColor(DemoColors.text)
                        Slider(value: $volume)
                            .frame(width: 68, height: 13)
                    }
                    
                    VStack(spacing: 0) {
                        Text("BAL")
                            .font(.system(size: 7))
                            .foregroundColor(DemoColors.text)
                        Slider(value: .constant(0.5))
                            .frame(width: 38, height: 13)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Button("EQ") {}
                        Button("PL") {}
                    }
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(DemoColors.text)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .frame(width: 275, height: 116)
        .background(DemoColors.background)
        .overlay(DemoBeveledBorder(raised: true))
        .onAppear {
            // Animate time
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                let components = currentTime.split(separator: ":")
                if let minutes = Int(components[0]), let seconds = Int(components[1]) {
                    let totalSeconds = minutes * 60 + seconds + 1
                    currentTime = String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
                }
            }
        }
    }
}

@main
struct ClassicUIDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoMainPlayer()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}