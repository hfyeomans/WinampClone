//
//  AudioEngineIntegration.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Extension to integrate FileLoader with AudioEngine for seamless playback.
//

import Foundation
import AVFoundation
import Combine
import os.log

// MARK: - AudioEngine Extension

extension AudioEngine {
    
    // MARK: - Properties
    
    private static var fileLoaderKey: UInt8 = 0
    private static var currentDecoderKey: UInt8 = 0
    
    /// Associated file loader instance
    private var fileLoader: FileLoader {
        get {
            if let loader = objc_getAssociatedObject(self, &AudioEngine.fileLoaderKey) as? FileLoader {
                return loader
            }
            let loader = FileLoader()
            objc_setAssociatedObject(self, &AudioEngine.fileLoaderKey, loader, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return loader
        }
    }
    
    /// Current decoder being used for playback
    private var currentDecoder: AudioDecoder? {
        get {
            return objc_getAssociatedObject(self, &AudioEngine.currentDecoderKey) as? AudioDecoder
        }
        set {
            objc_setAssociatedObject(self, &AudioEngine.currentDecoderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Enhanced Loading Methods
    
    /// Load and prepare a track for playback using the integrated file loader
    /// - Parameter url: The URL of the audio file to load
    /// - Throws: Various errors if loading fails
    @MainActor
    public func loadTrack(from url: URL) async throws {
        playbackState = .loading
        isLoading = true
        
        do {
            // Use FileLoader to load the file
            let (track, decoder) = try await fileLoader.prepareForPlayback(url: url)
            
            // Store the decoder
            self.currentDecoder = decoder
            
            // Update current track
            self.currentTrack = track
            
            // Load into the engine using the decoder's format
            if let format = decoder.processingFormat {
                try await loadFile(url, withFormat: format)
            } else {
                try await loadFile(url)
            }
            
            // Update duration from decoder
            self.duration = decoder.duration
            
            playbackState = .stopped
            isLoading = false
            
        } catch {
            playbackState = .error(error)
            isLoading = false
            throw error
        }
    }
    
    /// Load multiple tracks and return results
    /// - Parameter urls: Array of audio file URLs
    /// - Returns: Tuple of successfully loaded tracks and errors
    @MainActor
    public func loadTracks(from urls: [URL]) async -> (tracks: [Track], errors: [(URL, Error)]) {
        let (results, errors) = await fileLoader.loadAudioFiles(at: urls)
        let tracks = results.map { $0.track }
        return (tracks, errors)
    }
    
    /// Seek to a specific time using the current decoder
    /// - Parameter time: The time in seconds to seek to
    public func seekWithDecoder(to time: TimeInterval) {
        guard let decoder = currentDecoder else {
            try? seek(to: time)
            return
        }
        
        // Use decoder's seek method for more accurate seeking
        decoder.seek(to: time)
        
        // Update the player node position
        let sampleRate = audioFile?.processingFormat.sampleRate ?? 44100
        let frame = AVAudioFramePosition(time * sampleRate)
        
        let wasPlaying = isPlaying
        if wasPlaying {
            playerNode.stop()
        }
        
        // Seek in the audio file
        audioFile?.framePosition = frame
        currentTime = time
        
        if wasPlaying {
            // Note: scheduleNextBuffer is private to AudioEngine
            // Need to use public API instead
            try? play()
        }
    }
    
    // MARK: - Format-Specific Loading
    
    /// Load a file with automatic format detection and optimal settings
    private func loadFile(_ url: URL, withFormat format: AVAudioFormat? = nil) async throws {
        // Note: This method needs to be rewritten to use AudioEngine's public API
        // sessionQueue is not available in AudioEngine
        /*
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioEngineError.engineStartFailed(NSError(domain: "AudioEngine", code: -1)))
                    return
                }
                
                do {
                    // Load the file with the specified format or let AVAudioFile determine it
                    if let format = format {
                        self.audioFile = try AVAudioFile(forReading: url, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
                    } else {
                        self.audioFile = try AVAudioFile(forReading: url)
                    }
                    
                    guard let audioFile = self.audioFile else {
                        throw AudioEngineError.fileLoadFailed(NSError(domain: "AudioEngine", code: -1))
                    }
                    
                    self.duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                    self.bufferSize = AVAudioFrameCount(audioFile.processingFormat.sampleRate * 0.1) // 100ms buffer
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AudioEngineError.fileLoadFailed(error))
                }
            }
        }
        */
        
        // Note: AudioEngine doesn't have a public load method
        // This integration needs to be rewritten
        throw AudioEngineError.fileLoadFailed(NSError(domain: "AudioEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Load method not available"]))
    }
}

// MARK: - Enhanced Track Loading

/// Example of how to use the integrated file loading system
public class AudioEngineExample {
    
    private let engine = AudioEngine()
    private var cancellables = Set<AnyCancellable>()
    
    /// Example: Load a single track
    func loadSingleTrack() async {
        let url = URL(fileURLWithPath: "/path/to/audio.mp3")
        
        do {
            // This will automatically:
            // 1. Detect the format
            // 2. Validate the file
            // 3. Extract all metadata
            // 4. Create appropriate decoder
            // 5. Load into AudioEngine
            try await engine.loadTrack(from: url)
            
            // Access the loaded track with all metadata
            if let track = engine.currentTrack {
                print("Loaded: \(track.displayTitle) by \(track.displayArtist)")
                print("Format: \(track.audioFormat?.displayName ?? "Unknown")")
                print("Duration: \(track.formattedDuration)")
                
                if let properties = track.audioProperties {
                    print("Bitrate: \(properties.bitrate ?? 0) bps")
                    print("Sample Rate: \(properties.sampleRate ?? 0) Hz")
                }
            }
            
            // Start playback
            try engine.play()
            
        } catch {
            print("Failed to load track: \(error)")
        }
    }
    
    /// Example: Load an entire folder
    func loadFolder() async {
        let folderURL = URL(fileURLWithPath: "/path/to/music/folder")
        
        do {
            // Find all audio files in the folder
            let audioFiles = try FileLoader.findAudioFiles(in: folderURL)
            print("Found \(audioFiles.count) audio files")
            
            // Load all tracks
            let (tracks, errors) = await engine.loadTracks(from: audioFiles)
            
            print("Successfully loaded \(tracks.count) tracks")
            if !errors.isEmpty {
                print("Failed to load \(errors.count) files:")
                for (url, error) in errors {
                    print("  - \(url.lastPathComponent): \(error)")
                }
            }
            
            // Create a playlist from loaded tracks
            // (This would integrate with your playlist system)
            
        } catch {
            print("Failed to scan folder: \(error)")
        }
    }
    
    /// Example: Monitor playback with enhanced metadata
    func monitorPlayback() {
        // Monitor state changes
        engine.$playbackState
            .sink { state in
                switch state {
                case .loading:
                    print("Loading track...")
                case .playing:
                    if let track = self.engine.currentTrack {
                        print("Now playing: \(track.displayTitle)")
                        print("Format: \(track.audioFormat?.displayName ?? "Unknown")")
                    }
                case .paused:
                    print("Paused")
                case .stopped:
                    print("Stopped")
                case .error(let error):
                    print("Error: \(error)")
                }
            }
            .store(in: &cancellables)
        
        // Monitor time updates
        engine.$currentTime
            .sink { time in
                if let track = self.engine.currentTrack {
                    let progress = time / track.duration
                    print("Progress: \(Int(progress * 100))%")
                }
            }
            .store(in: &cancellables)
    }
}