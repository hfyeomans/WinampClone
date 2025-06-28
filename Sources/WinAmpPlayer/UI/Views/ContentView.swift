//
//  ContentView.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Main window view for the WinAmp Player.
//

import SwiftUI

struct ContentView: View {
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var volume: Double = 0.5
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            TitleBarView()
            
            // Display Area
            DisplayView(
                isPlaying: isPlaying,
                currentTime: currentTime,
                duration: duration
            )
            
            // Control Buttons
            ControlsView(
                isPlaying: $isPlaying,
                onPrevious: previousTrack,
                onNext: nextTrack,
                onStop: stopPlayback
            )
            
            // Volume and Balance
            VolumeBalanceView(volume: $volume)
            
            // Equalizer and Playlist toggles
            ToggleButtonsView()
        }
        .background(Color.black)
        .frame(width: 275, height: 116)
    }
    
    // MARK: - Actions
    
    private func previousTrack() {
        // TODO: Implement previous track functionality
    }
    
    private func nextTrack() {
        // TODO: Implement next track functionality
    }
    
    private func stopPlayback() {
        isPlaying = false
        currentTime = 0
        // TODO: Stop audio engine
    }
}

// MARK: - Subviews

struct TitleBarView: View {
    var body: some View {
        HStack {
            Text("WINAMP")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            Spacer()
            // Window control buttons
        }
        .padding(.horizontal, 4)
        .frame(height: 14)
        .background(Color.gray.opacity(0.2))
    }
}

struct DisplayView: View {
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    var body: some View {
        VStack {
            // Track info display
            Text("No file loaded")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green)
            
            // Time display
            Text(timeString(from: currentTime))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ControlsView: View {
    @Binding var isPlaying: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
            }
            
            Button(action: { isPlaying.toggle() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            
            Button(action: onStop) {
                Image(systemName: "stop.fill")
            }
            
            Button(action: onNext) {
                Image(systemName: "forward.fill")
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.green)
        .padding(4)
    }
}

struct VolumeBalanceView: View {
    @Binding var volume: Double
    
    var body: some View {
        HStack {
            Slider(value: $volume, in: 0...1)
                .frame(width: 100)
            Text("VOL")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
    }
}

struct ToggleButtonsView: View {
    @State private var showEqualizer = false
    @State private var showPlaylist = false
    
    var body: some View {
        HStack {
            Toggle("EQ", isOn: $showEqualizer)
                .toggleStyle(.button)
            
            Toggle("PL", isOn: $showPlaylist)
                .toggleStyle(.button)
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(4)
    }
}

#Preview {
    ContentView()
}