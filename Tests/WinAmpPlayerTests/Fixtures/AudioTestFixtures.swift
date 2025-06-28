//
//  AudioTestFixtures.swift
//  WinAmpPlayerTests
//
//  Created on 2025-06-28.
//  Helper utilities for creating test audio files and fixtures.
//

import Foundation
import AVFoundation
@testable import WinAmpPlayer

/// Provides utilities for creating test audio files with various formats and characteristics
public class AudioTestFixtures {
    
    // MARK: - Audio File Creation
    
    /// Creates a test audio file with specified parameters
    /// - Parameters:
    ///   - duration: Duration of the audio file in seconds
    ///   - sampleRate: Sample rate (default: 44100 Hz)
    ///   - channels: Number of channels (default: 2 for stereo)
    ///   - format: Audio format identifier (default: AAC)
    ///   - frequency: Frequency of test tone in Hz (default: 440 Hz for A4)
    /// - Returns: URL of the created test file
    public static func createTestAudioFile(
        duration: TimeInterval = 10.0,
        sampleRate: Double = 44100,
        channels: UInt32 = 2,
        format: AudioFormatID = kAudioFormatMPEG4AAC,
        frequency: Double = 440.0
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create audio format settings
        let settings: [String: Any] = [
            AVFormatIDKey: format,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: 128000
        ]
        
        // Create audio file
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        
        // Generate audio buffer with test tone
        guard let processingFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        ) else {
            throw NSError(domain: "AudioTestFixtures", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create audio format"
            ])
        }
        
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: processingFormat,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "AudioTestFixtures", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create audio buffer"
            ])
        }
        
        buffer.frameLength = frameCount
        
        // Fill buffer with sine wave
        let channelCount = Int(channels)
        let omega = 2.0 * Double.pi * frequency / sampleRate
        
        for channel in 0..<channelCount {
            if let channelData = buffer.floatChannelData?[channel] {
                for frame in 0..<Int(frameCount) {
                    let sample = Float(sin(omega * Double(frame)))
                    channelData[frame] = sample * 0.5 // 50% volume
                }
            }
        }
        
        // Write buffer to file
        try audioFile.write(from: buffer)
        
        return fileURL
    }
    
    /// Creates a silent audio file
    public static func createSilentAudioFile(
        duration: TimeInterval = 10.0,
        sampleRate: Double = 44100,
        channels: UInt32 = 2
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "silent_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels
        ]
        
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        ) else {
            throw NSError(domain: "AudioTestFixtures", code: 1)
        }
        
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "AudioTestFixtures", code: 2)
        }
        
        buffer.frameLength = frameCount
        // Buffer is already silent (zeros)
        
        try audioFile.write(from: buffer)
        
        return fileURL
    }
    
    /// Creates test audio files in various formats
    public static func createMultiFormatTestFiles() throws -> [String: URL] {
        var files: [String: URL] = [:]
        
        // AAC/M4A
        files["aac"] = try createTestAudioFile(
            duration: 5.0,
            format: kAudioFormatMPEG4AAC
        )
        
        // WAV
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).wav")
        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let wavFile = try AVAudioFile(forWriting: wavURL, settings: wavSettings)
        if let format = AVAudioFormat(settings: wavSettings),
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 5) {
            buffer.frameLength = 44100 * 5
            try wavFile.write(from: buffer)
        }
        files["wav"] = wavURL
        
        // AIFF
        let aiffURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).aiff")
        let aiffSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: true
        ]
        let aiffFile = try AVAudioFile(forWriting: aiffURL, settings: aiffSettings)
        if let format = AVAudioFormat(settings: aiffSettings),
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 5) {
            buffer.frameLength = 44100 * 5
            try aiffFile.write(from: buffer)
        }
        files["aiff"] = aiffURL
        
        return files
    }
    
    // MARK: - Track Creation
    
    /// Creates a test track with complete metadata
    public static func createTestTrack(
        title: String = "Test Track",
        artist: String = "Test Artist",
        album: String = "Test Album",
        genre: String = "Test Genre",
        year: Int = 2025,
        duration: TimeInterval = 180.0,
        trackNumber: Int = 1,
        withAudioFile: Bool = false
    ) throws -> Track {
        let fileURL: URL?
        
        if withAudioFile {
            fileURL = try createTestAudioFile(duration: duration)
        } else {
            fileURL = URL(fileURLWithPath: "/test/path/\(title.replacingOccurrences(of: " ", with: "_")).mp3")
        }
        
        return Track(
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            year: year,
            duration: duration,
            fileURL: fileURL,
            trackNumber: trackNumber,
            albumArtwork: createTestArtwork()
        )
    }
    
    /// Creates test album artwork data
    public static func createTestArtwork(size: CGSize = CGSize(width: 300, height: 300)) -> Data? {
        // Create a simple colored square as artwork
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Fill with a gradient
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Add some decoration
        context.setFillColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 0.5)
        let inset = size.width * 0.2
        context.fillEllipse(in: CGRect(
            x: inset,
            y: inset,
            width: size.width - inset * 2,
            height: size.height - inset * 2
        ))
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        // Convert to PNG data
        let ciImage = CIImage(cgImage: cgImage)
        let ciContext = CIContext()
        return ciContext.pngRepresentation(
            of: ciImage,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }
    
    // MARK: - Invalid File Creation
    
    /// Creates an invalid audio file for error testing
    public static func createInvalidAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "invalid_\(UUID().uuidString).mp3"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Write invalid data
        let invalidData = "This is not audio data".data(using: .utf8)!
        try? invalidData.write(to: fileURL)
        
        return fileURL
    }
    
    /// Creates a zero-byte file
    public static func createEmptyFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "empty_\(UUID().uuidString).mp3"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        
        return fileURL
    }
    
    // MARK: - Cleanup
    
    /// Removes test files
    public static func cleanup(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// Removes all test files in temporary directory matching pattern
    public static func cleanupAllTestFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil
            )
            
            let testFiles = contents.filter { url in
                let filename = url.lastPathComponent
                return filename.hasPrefix("test_") ||
                       filename.hasPrefix("silent_") ||
                       filename.hasPrefix("invalid_") ||
                       filename.hasPrefix("empty_")
            }
            
            for file in testFiles {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup test files: \(error)")
        }
    }
}

// MARK: - Performance Test Helpers

extension AudioTestFixtures {
    
    /// Creates a large audio file for performance testing
    public static func createLargeAudioFile(
        duration: TimeInterval = 600.0, // 10 minutes
        sampleRate: Double = 48000,
        channels: UInt32 = 2
    ) throws -> URL {
        return try createTestAudioFile(
            duration: duration,
            sampleRate: sampleRate,
            channels: channels,
            frequency: 1000.0 // 1kHz tone
        )
    }
    
    /// Creates multiple audio files for batch testing
    public static func createBatchTestFiles(
        count: Int = 10,
        durationRange: ClosedRange<TimeInterval> = 30.0...180.0
    ) throws -> [URL] {
        var files: [URL] = []
        
        for i in 0..<count {
            let duration = TimeInterval.random(in: durationRange)
            let frequency = 220.0 * pow(2.0, Double(i) / 12.0) // Musical notes
            
            let file = try createTestAudioFile(
                duration: duration,
                frequency: frequency
            )
            files.append(file)
        }
        
        return files
    }
}