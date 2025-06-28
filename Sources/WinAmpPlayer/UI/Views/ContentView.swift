//
//  ContentView.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Main window view for the WinAmp Player.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import AppKit

// Define supported audio content types
extension UTType {
    static let mp3 = UTType(filenameExtension: "mp3")!
}

struct ContentView: View {
    // Supported audio file types
    private let audioContentTypes: [UTType] = [
        .audio,
        .mp3,
        .mpeg4Audio,
        .wav,
        .aiff
    ]
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var volumeController: VolumeBalanceController
    
    @State private var isDraggingSeekBar = false
    @State private var seekPosition: Double = 0
    @State private var showOpenPanel = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    init() {
        let engine = AudioEngine()
        let controller = VolumeBalanceController(audioEngine: engine.audioEngine)
        engine.setVolumeController(controller)
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: controller)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            TitleBarView(onOpenFile: openFile)
            
            // Display Area with seek bar
            VStack(spacing: 2) {
                DisplayView(
                    isPlaying: audioEngine.isPlaying,
                    currentTime: isDraggingSeekBar ? seekPosition : audioEngine.currentTime,
                    duration: audioEngine.duration,
                    track: audioEngine.currentTrack,
                    isLoading: audioEngine.isLoading
                )
                
                // Seek bar
                if audioEngine.currentTrack != nil {
                    SeekBar(
                        currentTime: $audioEngine.currentTime,
                        duration: audioEngine.duration,
                        isDragging: $isDraggingSeekBar,
                        seekPosition: $seekPosition,
                        onSeek: { time in
                            try? audioEngine.seek(to: time)
                        }
                    )
                    .frame(height: 8)
                    .padding(.horizontal, 4)
                }
            }
            
            // Control Buttons
            ControlsView(
                isPlaying: audioEngine.isPlaying,
                onPlayPause: togglePlayPause,
                onPrevious: previousTrack,
                onNext: nextTrack,
                onStop: stopPlayback
            )
            
            // Volume and Balance
            VolumeBalanceView(
                volume: Binding(
                    get: { Double(volumeController.volume) },
                    set: { volumeController.setVolume(Float($0)) }
                ),
                balance: Binding(
                    get: { Double(volumeController.balance) },
                    set: { volumeController.setBalance(Float($0)) }
                )
            )
            
            // Equalizer and Playlist toggles
            ToggleButtonsView()
        }
        .background(Color.black)
        .frame(width: 275, height: 116)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onReceive(audioEngine.$playbackState) { state in
            if case .error(let error) = state {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .fileImporter(
            isPresented: $showOpenPanel,
            allowedContentTypes: audioContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }
    
    private func setupKeyboardShortcuts() {
        // Add keyboard shortcuts
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 49: // Space bar
                togglePlayPause()
                return nil
            case 123: // Left arrow
                previousTrack()
                return nil
            case 124: // Right arrow
                nextTrack()
                return nil
            case 125: // Down arrow
                volumeController.setVolume(max(0, volumeController.volume - 0.05))
                return nil
            case 126: // Up arrow
                volumeController.setVolume(min(1, volumeController.volume + 0.05))
                return nil
            default:
                return event
            }
        }
    }
    
    // MARK: - Actions
    
    private func togglePlayPause() {
        if audioEngine.currentTrack == nil {
            // No track loaded, open file dialog
            showOpenPanel = true
            return
        }
        
        audioEngine.togglePlayPause()
    }
    
    private func previousTrack() {
        // Skip backward 10 seconds for now
        // In a full implementation, this would go to the previous track in a playlist
        audioEngine.skipBackward()
    }
    
    private func nextTrack() {
        // Skip forward 10 seconds for now
        // In a full implementation, this would go to the next track in a playlist
        audioEngine.skipForward()
    }
    
    private func stopPlayback() {
        audioEngine.stop()
    }
    
    private func openFile() {
        showOpenPanel = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    try await audioEngine.loadURL(url)
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            Task {
                do {
                    try await audioEngine.loadURL(url)
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
        
        return true
    }
}

// MARK: - Subviews

struct TitleBarView: View {
    let onOpenFile: () -> Void
    
    var body: some View {
        HStack {
            Text("WINAMP")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            
            Spacer()
            
            // Open file button
            Button(action: onOpenFile) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundColor(.green)
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
    let track: Track?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            // Track info display
            if isLoading {
                Text("Loading...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
            } else if let track = track {
                VStack(spacing: 1) {
                    Text(track.displayTitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if track.artist != nil {
                        Text(track.displayArtist)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            } else {
                Text("No file loaded")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Time display
            HStack(spacing: 4) {
                Text(timeString(from: currentTime))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                
                if duration > 0 {
                    Text("/")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green.opacity(0.6))
                    
                    Text(timeString(from: duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
            }
        }
        .padding(4)
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
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12))
            }
            .help("Previous / Skip Backward")
            
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
            }
            .help(isPlaying ? "Pause" : "Play")
            
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
            }
            .help("Stop")
            
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12))
            }
            .help("Next / Skip Forward")
        }
        .buttonStyle(.plain)
        .foregroundColor(.green)
        .padding(4)
    }
}

struct VolumeBalanceView: View {
    @Binding var volume: Double
    @Binding var balance: Double
    
    var body: some View {
        HStack(spacing: 8) {
            // Volume slider
            VStack(spacing: 2) {
                Slider(value: $volume, in: 0...1)
                    .frame(width: 80)
                    .accentColor(.green)
                Text("VOL: \(Int(volume * 100))%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            // Balance slider
            VStack(spacing: 2) {
                Slider(value: $balance, in: -1...1)
                    .frame(width: 60)
                    .accentColor(.green)
                Text("BAL: \(balanceText)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
    
    private var balanceText: String {
        if abs(balance) < 0.05 {
            return "C"
        } else if balance < 0 {
            return "L\(Int(abs(balance) * 100))"
        } else {
            return "R\(Int(balance * 100))"
        }
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

// MARK: - Seek Bar

struct SeekBar: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    @Binding var isDragging: Bool
    @Binding var seekPosition: Double
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                // Progress
                Rectangle()
                    .fill(Color.green)
                    .frame(width: progressWidth(in: geometry.size.width))
            }
            .overlay(
                // Draggable thumb
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .position(
                        x: thumbPosition(in: geometry.size.width),
                        y: geometry.size.height / 2
                    )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        seekPosition = progress * duration
                    }
                    .onEnded { _ in
                        isDragging = false
                        onSeek(seekPosition)
                    }
            )
        }
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = isDragging ? seekPosition / duration : currentTime / duration
        return CGFloat(progress) * totalWidth
    }
    
    private func thumbPosition(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = isDragging ? seekPosition / duration : currentTime / duration
        return CGFloat(progress) * totalWidth
    }
}

#Preview {
    ContentView()
}