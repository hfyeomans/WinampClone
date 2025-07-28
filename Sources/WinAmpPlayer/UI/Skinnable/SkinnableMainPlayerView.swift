//
//  SkinnableMainPlayerView.swift
//  WinAmpPlayer
//
//  Classic WinAmp main player interface
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SkinnableMainPlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var volumeController: VolumeBalanceController
    @EnvironmentObject var playlistController: PlaylistController
    @EnvironmentObject var skinManager: SkinManager
    
    @State private var currentTime: TimeInterval = 0
    @State private var isRemainingTime = false
    @State private var isDragging = false
    @State private var isMinimized = false
    @State private var volume: Float = 0.75
    @State private var balance: Float = 0.5
    @State private var position: Double = 0
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            if !isMinimized {
                // Main display area
                HStack(spacing: 0) {
                    // Left edge
                    Rectangle()
                        .fill(WinAmpColors.background)
                        .frame(width: 6)
                    
                    VStack(spacing: 2) {
                        // Song info display
                        LCDSongDisplay(
                            artist: audioEngine.currentTrack?.artist ?? "",
                            title: audioEngine.currentTrack?.title ?? "WinAmp"
                        )
                        .frame(width: 154, height: 11)
                        .padding(.top, 4)
                        
                        // Time display
                        LCDTimeDisplay(
                            currentTime: formatTime(currentTime),
                            totalTime: formatTime(audioEngine.duration),
                            kbps: "128",
                            khz: "44",
                            mode: "Stereo",
                            isRemainingTime: $isRemainingTime
                        )
                        
                        // Visualization
                        ClassicVisualization()
                            .padding(.vertical, 2)
                    }
                    
                    // Right side controls
                    VStack(spacing: 2) {
                        // Volume and balance
                        HStack(spacing: 2) {
                            SkinnableVolumeSlider(volume: $volume) { newValue in
                                audioEngine.volume = newValue
                                volumeController.setVolume(newValue)
                            }
                            .frame(width: 68)
                            
                            SkinnableBalanceSlider(balance: $balance) { newValue in
                                volumeController.setBalance(newValue)
                            }
                            .frame(width: 38)
                        }
                        .padding(.top, 4)
                        
                        // Windows buttons
                        HStack(spacing: 0) {
                            ClassicToggleButton(icon: "EQ", isOn: .constant(false))
                            ClassicToggleButton(icon: "PL", isOn: .constant(false))
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Right edge
                    Rectangle()
                        .fill(WinAmpColors.background)
                        .frame(width: 6)
                }
                
                // Position slider
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(WinAmpColors.background)
                        .frame(width: 16)
                    
                    SkinnablePositionSlider(
                        position: $position,
                        duration: audioEngine.duration,
                        onSeek: { newValue in
                            try? audioEngine.seek(to: newValue)
                        }
                    )
                    .frame(height: 10)
                    
                    Rectangle()
                        .fill(WinAmpColors.background)
                        .frame(width: 16)
                }
                .frame(height: 14)
                
                // Control buttons
                HStack(spacing: 0) {
                    // Left padding
                    Rectangle()
                        .fill(WinAmpColors.background)
                        .frame(width: 6)
                    
                    SkinnableButton(
                        normal: .previousButton(.normal),
                        pressed: .previousButton(.pressed),
                        action: { previousTrack() }
                    )
                    
                    SkinnableButton(
                        normal: .playButton(.normal),
                        pressed: .playButton(.pressed),
                        action: { togglePlayPause() }
                    )
                    
                    SkinnableButton(
                        normal: .pauseButton(.normal),
                        pressed: .pauseButton(.pressed),
                        action: { togglePlayPause() }
                    )
                    
                    SkinnableButton(
                        normal: .stopButton(.normal),
                        pressed: .stopButton(.pressed),
                        action: { audioEngine.stop() }
                    )
                    
                    SkinnableButton(
                        normal: .nextButton(.normal),
                        pressed: .nextButton(.pressed),
                        action: { nextTrack() }
                    )
                    
                    SkinnableButton(
                        normal: .ejectButton(.normal),
                        pressed: .ejectButton(.pressed),
                        action: { openFile() }
                    )
                    
                    Spacer()
                    
                    // Options buttons
                    HStack(spacing: 0) {
                        ClassicToggleButton(icon: "REP", isOn: .constant(false), width: 26)
                        ClassicToggleButton(icon: "SHUF", isOn: .constant(false), width: 26)
                    }
                    
                    // Right padding
                    Rectangle()
                        .fill(WinAmpColors.background)
                        .frame(width: 6)
                }
                .frame(height: 18)
            }
        }
        .frame(width: 275, height: isMinimized ? 0 : 102) // 102 = 116 - 14 (title bar)
        .background(
            // Use a custom background renderer that tiles or stretches properly
            BackgroundSpriteView()
        )
        .onReceive(timer) { _ in
            if !isDragging && audioEngine.isPlaying {
                currentTime = audioEngine.currentTime
                position = audioEngine.duration > 0 ? currentTime / audioEngine.duration : 0
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func togglePlayPause() {
        audioEngine.togglePlayPause()
    }
    
    private func previousTrack() {
        Task {
            do {
                try await playlistController.playPrevious()
            } catch {
                print("Failed to play previous track: \(error)")
            }
        }
    }
    
    private func nextTrack() {
        Task {
            do {
                try await playlistController.playNext()
            } catch {
                print("Failed to play next track: \(error)")
            }
        }
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose Audio File"
        panel.showsResizeIndicator = true
        panel.showsHiddenFiles = false
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff"]
        
        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                Task {
                    do {
                        // For now, just load the first file directly into the audio engine
                        // This matches the toolbar implementation
                        if let firstURL = urls.first {
                            try await audioEngine.loadURL(firstURL)
                            print("🎵 Audio file loaded successfully: \(firstURL.lastPathComponent)")
                        }
                        
                        // If we have multiple files, we can add them to the playlist
                        if urls.count > 1, let playlist = playlistController.currentPlaylist {
                            for url in urls {
                                let track = Track(fileURL: url)
                                playlist.addTrack(track)
                            }
                        } else if urls.count > 1 {
                            // Create a new playlist with all tracks
                            let tracks = urls.map { Track(fileURL: $0) }
                            let playlist = Playlist(name: "Current Playlist", tracks: tracks)
                            playlistController.setPlaylist(playlist)
                        }
                    } catch {
                        print("🎵 ❌ Failed to load audio file: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Background Sprite View

struct BackgroundSpriteView: View {
    @StateObject private var skinManager = SkinManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            if let sprite = skinManager.getSprite(.mainBackground) {
                // Convert NSImage to Image and tile/stretch it to fill the entire area
                Image(nsImage: sprite)
                    .resizable()
                    .interpolation(.none) // Preserve pixel art
                    .aspectRatio(contentMode: .fill) // Fill the entire area
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped() // Clip any overflow
            } else {
                // Fallback to WinAmp classic background color
                Rectangle()
                    .fill(WinAmpColors.background)
            }
        }
    }
}

// MARK: - Title Bar

struct ClassicTitleBar: View {
    @Binding var isMinimized: Bool
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 0) {
            // WinAmp text
            Text("WINAMP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(WinAmpColors.text)
                .padding(.leading, 6)
            
            Spacer()
            
            // Window controls
            HStack(spacing: 0) {
                // Minimize
                Button(action: { isMinimized.toggle() }) {
                    Text("_")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 9, height: 9)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Close
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("X")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 9, height: 9)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.trailing, 3)
        }
        .frame(height: 14)
        .background(
            LinearGradient(
                colors: [WinAmpColors.backgroundLight, WinAmpColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .stroke(WinAmpColors.darkBorder, lineWidth: 1)
                .padding(.top, 1)
        )
    }
}

// MARK: - Control Buttons

enum ControlIcon {
    case previous, play, pause, stop, next, eject
}

struct ClassicControlButton: View {
    let action: () -> Void
    let icon: ControlIcon
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Button background
                RoundedRectangle(cornerRadius: 0)
                    .fill(isPressed ? WinAmpColors.buttonPressed : WinAmpColors.buttonNormal)
                    .frame(width: 23, height: 18)
                
                // Icon
                iconView
                    .foregroundColor(WinAmpColors.text)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(BeveledBorder(raised: !isPressed))
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    @ViewBuilder
    var iconView: some View {
        switch icon {
        case .previous:
            HStack(spacing: 1) {
                Rectangle().frame(width: 2, height: 8)
                Path { path in
                    path.move(to: CGPoint(x: 6, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 4))
                    path.addLine(to: CGPoint(x: 6, y: 8))
                }
                .fill()
                .frame(width: 6, height: 8)
            }
        case .play:
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 8))
                path.addLine(to: CGPoint(x: 7, y: 4))
                path.closeSubpath()
            }
            .fill()
            .frame(width: 7, height: 8)
        case .pause:
            HStack(spacing: 2) {
                Rectangle().frame(width: 3, height: 8)
                Rectangle().frame(width: 3, height: 8)
            }
        case .stop:
            Rectangle()
                .frame(width: 8, height: 8)
        case .next:
            HStack(spacing: 1) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 6, y: 4))
                    path.addLine(to: CGPoint(x: 0, y: 8))
                }
                .fill()
                .frame(width: 6, height: 8)
                Rectangle().frame(width: 2, height: 8)
            }
        case .eject:
            VStack(spacing: 1) {
                Path { path in
                    path.move(to: CGPoint(x: 4, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 4))
                    path.addLine(to: CGPoint(x: 8, y: 4))
                    path.closeSubpath()
                }
                .fill()
                .frame(width: 8, height: 4)
                Rectangle().frame(width: 8, height: 2)
            }
        }
    }
}

// MARK: - Toggle Buttons

struct ClassicToggleButton: View {
    let icon: String
    @Binding var isOn: Bool
    var width: CGFloat = 23
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(icon)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(isOn ? WinAmpColors.lcdText : WinAmpColors.textSecondary)
                .frame(width: width, height: 12)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(isOn ? WinAmpColors.buttonPressed : WinAmpColors.buttonNormal)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(BeveledBorder(raised: !isOn))
    }
}