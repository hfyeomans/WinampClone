//
//  FileLoaderExample.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Example demonstrating the integrated file loading system.
//

import Foundation
import AVFoundation
import Combine

/// Example demonstrating how to use the FileLoader integration
class FileLoaderExample {
    
    private let fileLoader = FileLoader()
    private let audioEngine = AudioEngine()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Basic File Loading
    
    /// Example 1: Load a single file with full metadata
    func loadSingleFile() async {
        let fileURL = URL(fileURLWithPath: "/path/to/song.mp3")
        
        do {
            print("Loading file: \(fileURL.lastPathComponent)")
            
            // Load the file with automatic format detection and validation
            let result = try await fileLoader.loadAudioFile(at: fileURL)
            
            // Display track information
            let track = result.track
            print("\nTrack Information:")
            print("  Title: \(track.displayTitle)")
            print("  Artist: \(track.displayArtist)")
            print("  Album: \(track.album ?? "Unknown")")
            print("  Duration: \(track.formattedDuration)")
            print("  Format: \(track.audioFormat?.displayName ?? "Unknown")")
            
            // Display audio properties
            if let properties = track.audioProperties {
                print("\nAudio Properties:")
                print("  Bitrate: \(properties.bitrate ?? 0) bps")
                print("  Sample Rate: \(properties.sampleRate ?? 0) Hz")
                print("  Channels: \(properties.channelCount ?? 0)")
                if let bitDepth = properties.bitDepth {
                    print("  Bit Depth: \(bitDepth) bits")
                }
            }
            
            // Display format detection details
            print("\nFormat Detection:")
            print("  Format: \(result.formatInfo.format.displayName)")
            print("  Confidence: \(Int(result.formatInfo.confidence * 100))%")
            print("  Detection Method: \(result.formatInfo.detectionMethod)")
            
            // Display any warnings
            if !result.warnings.isEmpty {
                print("\nWarnings:")
                for warning in result.warnings {
                    print("  - \(warning)")
                }
            }
            
            // Decoder is ready for playback
            print("\nDecoder ready: \(result.decoder.duration) seconds")
            
        } catch {
            print("Failed to load file: \(error)")
        }
    }
    
    // MARK: - Batch Loading
    
    /// Example 2: Load multiple files from a folder
    func loadMusicFolder() async {
        let folderURL = URL(fileURLWithPath: "/path/to/music/folder")
        
        do {
            // Find all audio files in the folder
            let audioFiles = try FileLoader.findAudioFiles(in: folderURL)
            print("Found \(audioFiles.count) audio files in folder")
            
            // Load all files in parallel
            let (results, errors) = await fileLoader.loadAudioFiles(at: audioFiles)
            
            print("\nSuccessfully loaded: \(results.count) files")
            print("Failed to load: \(errors.count) files")
            
            // Group tracks by album
            let albumGroups = Dictionary(grouping: results.map { $0.track }) { track in
                track.album ?? "Unknown Album"
            }
            
            print("\nAlbums found:")
            for (album, tracks) in albumGroups.sorted(by: { $0.key < $1.key }) {
                print("\n\(album):")
                for track in tracks.sorted(by: { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }) {
                    let trackNum = track.trackNumber.map { String($0) + ". " } ?? ""
                    print("  \(trackNum)\(track.displayTitle) (\(track.formattedDuration))")
                }
            }
            
            // Report errors
            if !errors.isEmpty {
                print("\nErrors:")
                for (url, error) in errors {
                    print("  \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
        } catch {
            print("Failed to scan folder: \(error)")
        }
    }
    
    // MARK: - Integration with AudioEngine
    
    /// Example 3: Load and play a file using the integrated system
    func loadAndPlay() async {
        let fileURL = URL(fileURLWithPath: "/path/to/song.mp3")
        
        do {
            // Use the enhanced AudioEngine loading
            try await audioEngine.loadTrack(from: fileURL)
            
            // Monitor playback state
            audioEngine.$playbackState
                .sink { state in
                    switch state {
                    case .loading:
                        print("Loading...")
                    case .playing:
                        if let track = self.audioEngine.currentTrack {
                            print("Now playing: \(track.displayTitle) by \(track.displayArtist)")
                        }
                    case .paused:
                        print("Paused")
                    case .stopped:
                        print("Stopped")
                    case .error(let error):
                        print("Playback error: \(error)")
                    }
                }
                .store(in: &cancellables)
            
            // Start playback
            try? audioEngine.play()
            
            // Seek to middle of track
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let midpoint = self.audioEngine.duration / 2
                self.audioEngine.seekWithDecoder(to: midpoint)
                print("Seeked to: \(midpoint) seconds")
            }
            
        } catch {
            print("Failed to load and play: \(error)")
        }
    }
    
    // MARK: - Format-Specific Examples
    
    /// Example 4: Load files with specific format validation
    func loadWithFormatValidation() async {
        let mp3URL = URL(fileURLWithPath: "/path/to/song.mp3")
        let flacURL = URL(fileURLWithPath: "/path/to/song.flac")
        
        // Load MP3 with specific validation
        do {
            let result = try await fileLoader.loadAudioFile(at: mp3URL)
            
            if result.formatInfo.format == .mp3 {
                print("Valid MP3 file loaded")
                
                // Access MP3-specific metadata if using MP3Decoder
                if let mp3Decoder = result.decoder as? MP3Decoder {
                    let metadata = mp3Decoder.metadata
                    print("MP3 Metadata:")
                    print("  Encoder: \(metadata.encoder ?? "Unknown")")
                    if let lyrics = metadata.lyrics {
                        print("  Has lyrics: \(lyrics.count) characters")
                    }
                }
            }
        } catch {
            print("MP3 loading failed: \(error)")
        }
        
        // Load FLAC with validation
        do {
            let result = try await fileLoader.loadAudioFile(at: flacURL)
            
            if result.formatInfo.format == .flac {
                print("\nValid FLAC file loaded")
                
                // FLAC files should have lossless properties
                if let properties = result.track.audioProperties {
                    print("FLAC Properties:")
                    print("  Sample Rate: \(properties.sampleRate ?? 0) Hz")
                    print("  Bit Depth: \(properties.bitDepth ?? 0) bits")
                    print("  Lossless: \(!result.track.audioFormat!.isLossy)")
                }
            }
        } catch {
            print("FLAC loading failed: \(error)")
        }
    }
    
    // MARK: - Error Handling
    
    /// Example 5: Comprehensive error handling
    func demonstrateErrorHandling() async {
        let testFiles = [
            URL(fileURLWithPath: "/path/to/valid.mp3"),
            URL(fileURLWithPath: "/path/to/corrupted.mp3"),
            URL(fileURLWithPath: "/path/to/wrong_extension.txt"),
            URL(fileURLWithPath: "/path/to/nonexistent.mp3")
        ]
        
        for fileURL in testFiles {
            print("\nTesting: \(fileURL.lastPathComponent)")
            
            do {
                let result = try await fileLoader.loadAudioFile(at: fileURL)
                print("  ✓ Loaded successfully")
                print("  Format: \(result.formatInfo.format.displayName)")
                print("  Confidence: \(Int(result.formatInfo.confidence * 100))%")
                
            } catch let error as FileLoaderError {
                print("  ✗ FileLoader error:")
                switch error {
                case .fileNotFound(let url):
                    print("    File not found: \(url.lastPathComponent)")
                case .fileNotAccessible(let url):
                    print("    Cannot access file: \(url.lastPathComponent)")
                case .invalidFormat(let errors):
                    print("    Invalid format:")
                    for err in errors {
                        print("      - \(err)")
                    }
                case .metadataExtractionFailed(let err):
                    print("    Metadata extraction failed: \(err)")
                case .decoderCreationFailed(let err):
                    print("    Decoder creation failed: \(err)")
                case .unknownError(let err):
                    print("    Unknown error: \(err)")
                }
            } catch {
                print("  ✗ Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Usage

/// How to use the FileLoaderExample
func demonstrateFileLoaderUsage() {
    let example = FileLoaderExample()
    
    Task {
        print("=== File Loader Integration Demo ===\n")
        
        // Run examples
        await example.loadSingleFile()
        print("\n" + String(repeating: "-", count: 50) + "\n")
        
        await example.loadMusicFolder()
        print("\n" + String(repeating: "-", count: 50) + "\n")
        
        await example.loadAndPlay()
        print("\n" + String(repeating: "-", count: 50) + "\n")
        
        await example.loadWithFormatValidation()
        print("\n" + String(repeating: "-", count: 50) + "\n")
        
        await example.demonstrateErrorHandling()
    }
}