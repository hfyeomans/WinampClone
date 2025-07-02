//
//  ContentViewRefactored.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Main window view with full playlist integration.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import AppKit

// Define supported audio content types
extension UTType {
    static let mp3 = UTType(filenameExtension: "mp3")!
}

struct ContentViewRefactored: View {
    // Supported audio file types
    private let audioContentTypes: [UTType] = [
        .audio,
        .mp3,
        .mpeg4Audio,
        .wav,
        .aiff
    ]
    
    @StateObject private var audioEngine: AudioEngine
    @StateObject private var volumeController: VolumeBalanceController
    @StateObject private var playlistController: PlaylistController
    @StateObject private var playlist: Playlist
    
    @State private var isDraggingSeekBar = false
    @State private var seekPosition: Double = 0
    @State private var showOpenPanel = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPlaylist = false
    
    init() {
        // Initialize audio engine
        let engine = AudioEngine()
        
        // Initialize volume controller
        let volController = VolumeBalanceController(audioEngine: engine.audioEngine)
        engine.setVolumeController(volController)
        
        // Initialize playlist
        let mainPlaylist = Playlist(name: "Main Playlist")
        
        // Initialize playlist controller
        let controller = PlaylistController(audioEngine: engine, volumeController: volController)
        controller.loadPlaylist(mainPlaylist)
        
        // Initialize state objects
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: volController)
        _playlistController = StateObject(wrappedValue: controller)
        _playlist = StateObject(wrappedValue: mainPlaylist)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            TitleBarView(onOpenFile: openFile)
            
            // Display Area with seek bar
            VStack(spacing: 2) {
                DisplayView(
                    isPlaying: playlistController.isPlaying,
                    currentTime: isDraggingSeekBar ? seekPosition : playlistController.currentTime,
                    duration: playlistController.duration,
                    track: playlistController.currentTrack,
                    isLoading: playlistController.isLoading
                )
                
                // Seek bar
                if playlistController.currentTrack != nil {
                    SeekBar(
                        currentTime: $playlistController.currentTime,
                        duration: playlistController.duration,
                        isDragging: $isDraggingSeekBar,
                        seekPosition: $seekPosition,
                        onSeek: { time in
                            try? playlistController.seek(to: time)
                        }
                    )
                    .frame(height: 8)
                    .padding(.horizontal, 4)
                }
            }
            
            // Control Buttons
            ControlsView(
                isPlaying: playlistController.isPlaying,
                onPlayPause: togglePlayPause,
                onPrevious: previousTrack,
                onNext: nextTrack,
                onStop: stopPlayback
            )
            
            // Volume and Balance
            VolumeBalanceView(
                volume: Binding(
                    get: { Double(playlistController.volume) },
                    set: { playlistController.setVolume(Float($0)) }
                ),
                balance: Binding(
                    get: { Double(volumeController.balance) },
                    set: { playlistController.setBalance(Float($0)) }
                )
            )
            
            // Equalizer and Playlist toggles
            ToggleButtonsView(showPlaylist: $showPlaylist)
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
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistView(controller: playlistController, playlist: playlist)
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
                playlistController.handlePlayPauseShortcut()
                return nil
            case 123: // Left arrow
                playlistController.handlePreviousTrackShortcut()
                return nil
            case 124: // Right arrow
                playlistController.handleNextTrackShortcut()
                return nil
            case 125: // Down arrow
                playlistController.handleVolumeDownShortcut()
                return nil
            case 126: // Up arrow
                playlistController.handleVolumeUpShortcut()
                return nil
            case 1: // S key
                playlistController.handleShuffleShortcut()
                return nil
            case 15: // R key
                playlistController.handleRepeatShortcut()
                return nil
            case 35: // P key - toggle playlist
                showPlaylist.toggle()
                return nil
            default:
                return event
            }
        }
    }
    
    // MARK: - Actions
    
    private func togglePlayPause() {
        Task {
            try? await playlistController.togglePlayPause()
        }
    }
    
    private func previousTrack() {
        Task {
            try? await playlistController.playPrevious()
        }
    }
    
    private func nextTrack() {
        Task {
            try? await playlistController.playNext()
        }
    }
    
    private func stopPlayback() {
        playlistController.stop()
    }
    
    private func openFile() {
        showOpenPanel = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                var tracks: [Track] = []
                for url in urls {
                    if let track = Track(from: url) {
                        tracks.append(track)
                    }
                }
                
                if !tracks.isEmpty {
                    // Add all tracks to playlist
                    playlist.addTracks(tracks)
                    
                    // Play the first added track
                    try? await playlistController.playTrack(tracks[0])
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                Task {
                    if let track = Track(from: url) {
                        await MainActor.run {
                            playlist.addTrack(track)
                        }
                        
                        // If it's the first track, play it
                        if playlist.tracks.count == 1 {
                            try? await playlistController.playTrack(track)
                        }
                    }
                }
            }
        }
        
        return true
    }
}

// MARK: - Toggle Buttons View (Updated)

struct ToggleButtonsView: View {
    @State private var showEqualizer = false
    @Binding var showPlaylist: Bool
    
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
    ContentViewRefactored()
}