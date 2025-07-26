//
//  PlaylistIntegrationExample.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Example demonstrating playlist and audio engine integration.
//

import SwiftUI

struct PlaylistIntegrationExample: View {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var volumeController: VolumeBalanceController
    @StateObject private var playlistController: PlaylistController
    @StateObject private var playlist = Playlist(name: "Example Playlist")
    
    init() {
        let engine = AudioEngine()
        let controller = VolumeBalanceController(audioEngine: engine.audioEngine)
        engine.setVolumeController(controller)
        
        let playlistCtrl = PlaylistController(audioEngine: engine, volumeController: controller)
        
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: controller)
        _playlistController = StateObject(wrappedValue: playlistCtrl)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Playlist Integration Example")
                .font(.largeTitle)
            
            // Playback controls
            HStack {
                Button("Previous") {
                    Task {
                        try? await playlistController.playPrevious()
                    }
                }
                
                Button(playlistController.isPlaying ? "Pause" : "Play") {
                    Task {
                        try? await playlistController.togglePlayPause()
                    }
                }
                
                Button("Next") {
                    Task {
                        try? await playlistController.playNext()
                    }
                }
                
                Button("Stop") {
                    playlistController.stop()
                }
            }
            
            // Current track info
            if let track = playlistController.currentTrack {
                VStack {
                    Text("Now Playing: \(track.displayTitle)")
                    Text("Artist: \(track.displayArtist)")
                    Text("Time: \(formatTime(playlistController.currentTime)) / \(formatTime(playlistController.duration))")
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            
            // Volume control
            HStack {
                Text("Volume:")
                Slider(value: Binding(
                    get: { Double(playlistController.volume) },
                    set: { playlistController.setVolume(Float($0)) }
                ))
                .frame(width: 200)
            }
            
            // Playlist controls
            HStack {
                Toggle("Shuffle", isOn: Binding(
                    get: { playlist.shuffleMode != .off },
                    set: { _ in playlistController.toggleShuffle() }
                ))
                
                Button("Repeat: \(repeatModeText)") {
                    playlistController.cycleRepeatMode()
                }
            }
            
            // Queue info
            VStack(alignment: .leading) {
                Text("Play Queue: \(playlistController.playQueue.count) tracks")
                Text("Playlist: \(playlist.tracks.count) tracks")
                Text("Current Index: \(playlist.currentTrackIndex ?? -1)")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Add sample tracks button
            Button("Add Sample Tracks") {
                addSampleTracks()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            playlistController.loadPlaylist(playlist)
        }
    }
    
    private var repeatModeText: String {
        switch playlist.repeatMode {
        case .off: return "Off"
        case .all: return "All"
        case .one: return "One"
        case .abLoop: return "A-B"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func addSampleTracks() {
        // Create sample tracks for testing
        let sampleTracks = [
            Track(
                title: "Sample Track 1",
                artist: "Test Artist",
                album: "Test Album",
                duration: 180
            ),
            Track(
                title: "Sample Track 2",
                artist: "Test Artist",
                album: "Test Album",
                duration: 240
            ),
            Track(
                title: "Sample Track 3",
                artist: "Another Artist",
                album: "Another Album",
                duration: 210
            )
        ]
        
        playlist.addTracks(sampleTracks)
        
        // Play first track if nothing is playing
        if playlistController.currentTrack == nil && !playlist.isEmpty {
            Task {
                try? await playlistController.play()
            }
        }
    }
}

// Removed @main to avoid conflicts with WinAmpPlayerApp
struct PlaylistIntegrationExampleApp: App {
    var body: some Scene {
        WindowGroup {
            PlaylistIntegrationExample()
        }
    }
}