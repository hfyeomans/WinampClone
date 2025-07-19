//
//  AudioEngineExample.swift
//  WinAmpPlayer
//
//  Example usage of the enhanced AudioEngine
//

import Foundation
import SwiftUI
import Combine

/// Example view demonstrating AudioEngine usage
struct AudioPlayerView: View {
    @StateObject private var audioEngine = AudioEngine()
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Track info
            if let track = audioEngine.currentTrack {
                VStack {
                    Text(track.displayTitle)
                        .font(.headline)
                    Text(track.displayArtist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Time display
            HStack {
                Text(audioEngine.formattedCurrentTime)
                Slider(
                    value: Binding(
                        get: { audioEngine.progress },
                        set: { newValue in
                            try? audioEngine.seek(to: newValue * audioEngine.duration)
                        }
                    ),
                    in: 0...1
                )
                Text(audioEngine.formattedDuration)
            }
            .padding(.horizontal)
            
            // Playback controls
            HStack(spacing: 30) {
                Button(action: {
                    audioEngine.skipBackward()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                
                Button(action: {
                    audioEngine.togglePlayPause()
                }) {
                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                
                Button(action: {
                    audioEngine.skipForward()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
            }
            
            // Volume control
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $audioEngine.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }
            .padding(.horizontal)
            
            // Error display
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Load file button
            Button("Load Audio File") {
                loadAudioFile()
            }
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: .audioPlaybackCompleted)) { _ in
            // Handle playback completion
            print("Playback completed")
        }
    }
    
    private func loadAudioFile() {
        // Example: Load a file from the Music directory
        let musicURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        let fileURL = musicURL.appendingPathComponent("example.mp3")
        
        Task {
            do {
                try await audioEngine.loadURL(fileURL)
                try audioEngine.play()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Usage Examples

/// Example of using AudioEngine programmatically
class AudioEngineUsageExample {
    let audioEngine = AudioEngine()
    
    func demonstrateUsage() async {
        // Load a track
        let track = Track(
            title: "Example Song",
            artist: "Example Artist",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/path/to/audio.mp3")
        )
        
        do {
            // Load the track
            try await audioEngine.loadTrack(track)
            
            // Start playback
            try audioEngine.play()
            
            // Seek to 30 seconds
            try audioEngine.seek(to: 30)
            
            // Pause playback
            audioEngine.pause()
            
            // Resume playback
            try audioEngine.play()
            
            // Stop playback
            audioEngine.stop()
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // Example: Loading from URL
    func loadFromURL() async {
        let url = URL(fileURLWithPath: "/Users/username/Music/song.mp3")
        
        do {
            try await audioEngine.loadURL(url)
            try audioEngine.play()
        } catch {
            switch error {
            case AudioEngineError.fileNotFound:
                print("File not found at URL")
            case AudioEngineError.unsupportedFormat:
                print("Audio format not supported")
            case AudioEngineError.engineStartFailed(let engineError):
                print("Engine failed to start: \(engineError)")
            default:
                print("Unknown error: \(error)")
            }
        }
    }
    
    // Example: Handling playback states
    func observePlaybackState() {
        // Use Combine to observe state changes
        audioEngine.$playbackState
            .sink { state in
                switch state {
                case .stopped:
                    print("Playback stopped")
                case .playing:
                    print("Playing")
                case .paused:
                    print("Paused")
                case .loading:
                    print("Loading...")
                case .error(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
        
        // Observe time updates
        audioEngine.$currentTime
            .sink { time in
                print("Current time: \(time)")
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}