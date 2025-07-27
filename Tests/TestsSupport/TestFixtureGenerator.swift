//
//  TestFixtureGenerator.swift
//  WinAmpPlayerTests
//
//  Created on 2025-07-27.
//  Generates test fixtures for comprehensive testing
//

import Foundation
import AVFoundation
import Accelerate

/// Generates test fixtures for the WinAmp Player test suite
public class TestFixtureGenerator {
    
    /// Generates all required test fixtures
    public static func generateAllFixtures() throws {
        print("Generating test fixtures...")
        
        // Create directories
        try createDirectoryStructure()
        
        // Generate audio files
        try generateAudioFixtures()
        
        // Generate skin files
        try generateSkinFixtures()
        
        // Generate plugin files
        try generatePluginFixtures()
        
        print("All test fixtures generated successfully!")
    }
    
    // MARK: - Directory Structure
    
    private static func createDirectoryStructure() throws {
        let baseURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        
        let directories = [
            "Audio",
            "Skins",
            "Plugins"
        ]
        
        for dir in directories {
            let dirURL = baseURL.appendingPathComponent(dir)
            try FileManager.default.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    // MARK: - Audio Fixtures
    
    private static func generateAudioFixtures() throws {
        let baseURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Audio")
        
        // Generate 44k stereo WAV
        try generateWAVFile(
            filename: "44k_stereo.wav",
            sampleRate: 44100,
            channels: 2,
            duration: 5.0,
            frequency: 440.0,
            at: baseURL
        )
        
        // Generate 48k stereo FLAC (as WAV for now, would need FLAC encoder)
        try generateWAVFile(
            filename: "48k_stereo.wav",
            sampleRate: 48000,
            channels: 2,
            duration: 5.0,
            frequency: 880.0,
            at: baseURL
        )
        
        // Generate 96k stereo AIFF
        try generateAIFFFile(
            filename: "96k_stereo.aiff",
            sampleRate: 96000,
            channels: 2,
            duration: 3.0,
            frequency: 220.0,
            at: baseURL
        )
        
        // Generate mono 16k WAV
        try generateWAVFile(
            filename: "mono_16k.wav",
            sampleRate: 16000,
            channels: 1,
            duration: 2.0,
            frequency: 440.0,
            at: baseURL
        )
        
        // Create invalid text file
        let invalidURL = baseURL.appendingPathComponent("invalid.txt")
        try "This is not an audio file".write(to: invalidURL, atomically: true, encoding: .utf8)
        
        // Create corrupt MP3 (actually a truncated WAV)
        try generateCorruptAudioFile(
            filename: "corrupt.mp3",
            at: baseURL
        )
    }
    
    // MARK: - WAV Generation
    
    private static func generateWAVFile(
        filename: String,
        sampleRate: Double,
        channels: Int,
        duration: Double,
        frequency: Double,
        at directory: URL
    ) throws {
        let url = directory.appendingPathComponent(filename)
        
        // Calculate sizes
        let numSamples = Int(sampleRate * duration)
        let bytesPerSample = 2 // 16-bit
        let dataSize = numSamples * channels * bytesPerSample
        
        // Generate sine wave samples
        var samples = [Int16]()
        for i in 0..<numSamples {
            let time = Double(i) / sampleRate
            let value = sin(2.0 * .pi * frequency * time)
            let sample = Int16(value * Double(Int16.max) * 0.5) // 50% volume
            
            for _ in 0..<channels {
                samples.append(sample)
            }
        }
        
        // Create WAV file
        var data = Data()
        
        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        data.append(littleEndian: UInt32(36 + dataSize))
        data.append("WAVE".data(using: .ascii)!)
        
        // Format chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(littleEndian: UInt32(16)) // Chunk size
        data.append(littleEndian: UInt16(1))  // PCM format
        data.append(littleEndian: UInt16(channels))
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(sampleRate * Double(channels * bytesPerSample)))
        data.append(littleEndian: UInt16(channels * bytesPerSample))
        data.append(littleEndian: UInt16(16)) // Bits per sample
        
        // Data chunk
        data.append("data".data(using: .ascii)!)
        data.append(littleEndian: UInt32(dataSize))
        
        // Append samples
        for sample in samples {
            data.append(littleEndian: sample)
        }
        
        try data.write(to: url)
        print("Generated WAV: \(filename)")
    }
    
    // MARK: - AIFF Generation
    
    private static func generateAIFFFile(
        filename: String,
        sampleRate: Double,
        channels: Int,
        duration: Double,
        frequency: Double,
        at directory: URL
    ) throws {
        let url = directory.appendingPathComponent(filename)
        
        // Calculate sizes
        let numSamples = Int(sampleRate * duration)
        let bytesPerSample = 2 // 16-bit
        let dataSize = numSamples * channels * bytesPerSample
        
        // Generate sine wave samples
        var samples = [Int16]()
        for i in 0..<numSamples {
            let time = Double(i) / sampleRate
            let value = sin(2.0 * .pi * frequency * time)
            let sample = Int16(value * Double(Int16.max) * 0.5) // 50% volume
            
            for _ in 0..<channels {
                samples.append(sample)
            }
        }
        
        // Create AIFF file
        var data = Data()
        
        // FORM header
        data.append("FORM".data(using: .ascii)!)
        data.append(bigEndian: UInt32(4 + 8 + 18 + 8 + 8 + dataSize))
        data.append("AIFF".data(using: .ascii)!)
        
        // Common chunk
        data.append("COMM".data(using: .ascii)!)
        data.append(bigEndian: UInt32(18))
        data.append(bigEndian: UInt16(channels))
        data.append(bigEndian: UInt32(numSamples))
        data.append(bigEndian: UInt16(16)) // Bits per sample
        
        // Sample rate as 80-bit IEEE extended precision
        let sampleRateBytes = ieee80BitExtended(from: sampleRate)
        data.append(contentsOf: sampleRateBytes)
        
        // Sound data chunk
        data.append("SSND".data(using: .ascii)!)
        data.append(bigEndian: UInt32(dataSize + 8))
        data.append(bigEndian: UInt32(0)) // Offset
        data.append(bigEndian: UInt32(0)) // Block size
        
        // Append samples (big-endian)
        for sample in samples {
            data.append(bigEndian: sample)
        }
        
        try data.write(to: url)
        print("Generated AIFF: \(filename)")
    }
    
    // MARK: - Corrupt File Generation
    
    private static func generateCorruptAudioFile(filename: String, at directory: URL) throws {
        let url = directory.appendingPathComponent(filename)
        
        // Create a truncated WAV header
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(littleEndian: UInt32(1000)) // Wrong size
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        // Truncate here - incomplete file
        
        try data.write(to: url)
        print("Generated corrupt file: \(filename)")
    }
    
    // MARK: - Skin Fixtures
    
    private static func generateSkinFixtures() throws {
        let baseURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Skins")
        
        // Generate classic skin
        try generateClassicSkin(at: baseURL)
        
        // Generate multi-skin pack
        try generateSkinPack(at: baseURL)
        
        // Generate corrupt skin
        try generateCorruptSkin(at: baseURL)
    }
    
    private static func generateClassicSkin(at directory: URL) throws {
        let skinURL = directory.appendingPathComponent("classic.wsz")
        
        // Create a minimal valid skin archive
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create skin.xml
        let skinXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <WinampAbstractionLayer version="1.35">
            <skininfo>
                <version>1</version>
                <name>Classic Test Skin</name>
                <author>Test Suite</author>
                <comment>Generated for testing</comment>
            </skininfo>
            <include file="player-normal.xml"/>
        </WinampAbstractionLayer>
        """
        
        let skinXMLURL = tempDir.appendingPathComponent("skin.xml")
        try skinXML.write(to: skinXMLURL, atomically: true, encoding: .utf8)
        
        // Create player-normal.xml
        let playerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <layout id="normal" w="275" h="116">
            <layer id="main.background" image="main.bmp" x="0" y="0"/>
        </layout>
        """
        
        let playerXMLURL = tempDir.appendingPathComponent("player-normal.xml")
        try playerXML.write(to: playerXMLURL, atomically: true, encoding: .utf8)
        
        // Create a minimal BMP file (main.bmp)
        let bmpData = generateMinimalBMP(width: 275, height: 116)
        let bmpURL = tempDir.appendingPathComponent("main.bmp")
        try bmpData.write(to: bmpURL)
        
        // Create ZIP archive
        try createZipArchive(from: tempDir, to: skinURL)
        print("Generated classic skin: classic.wsz")
    }
    
    private static func generateSkinPack(at directory: URL) throws {
        let packURL = directory.appendingPathComponent("generated.zip")
        
        // Create temp directory for skins
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Generate 3 simple skins
        for i in 1...3 {
            let skinDir = tempDir.appendingPathComponent("skin\(i)")
            try FileManager.default.createDirectory(at: skinDir, withIntermediateDirectories: true)
            
            let skinXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <WinampAbstractionLayer version="1.35">
                <skininfo>
                    <version>1</version>
                    <name>Generated Skin \(i)</name>
                    <author>Test Suite</author>
                </skininfo>
            </WinampAbstractionLayer>
            """
            
            let xmlURL = skinDir.appendingPathComponent("skin.xml")
            try skinXML.write(to: xmlURL, atomically: true, encoding: .utf8)
        }
        
        // Create ZIP archive
        try createZipArchive(from: tempDir, to: packURL)
        print("Generated skin pack: generated.zip")
    }
    
    private static func generateCorruptSkin(at directory: URL) throws {
        let corruptURL = directory.appendingPathComponent("corrupt.wsz")
        
        // Create invalid ZIP data
        var data = Data()
        data.append("PK".data(using: .ascii)!) // ZIP signature
        data.append(contentsOf: [0x03, 0x04]) // Version
        // Truncate - invalid ZIP
        
        try data.write(to: corruptURL)
        print("Generated corrupt skin: corrupt.wsz")
    }
    
    // MARK: - Plugin Fixtures
    
    private static func generatePluginFixtures() throws {
        let baseURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Plugins")
        
        // Generate dummy visualization plugin
        try generateDummyPlugin(
            name: "dummyViz.waplugin",
            type: "visualization",
            at: baseURL
        )
        
        // Generate dummy DSP plugin
        try generateDummyPlugin(
            name: "dummyDSP.waplugin",
            type: "dsp",
            at: baseURL
        )
        
        // Generate crash plugin
        try generateCrashPlugin(at: baseURL)
    }
    
    private static func generateDummyPlugin(name: String, type: String, at directory: URL) throws {
        let pluginURL = directory.appendingPathComponent(name)
        
        // Create plugin bundle structure
        try FileManager.default.createDirectory(at: pluginURL, withIntermediateDirectories: true)
        
        // Create Info.plist
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.winamp.test.\(type)</string>
            <key>CFBundleName</key>
            <string>Test \(type.capitalized) Plugin</string>
            <key>PluginType</key>
            <string>\(type)</string>
            <key>PluginVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """
        
        let plistURL = pluginURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: plistURL, atomically: true, encoding: .utf8)
        
        print("Generated dummy plugin: \(name)")
    }
    
    private static func generateCrashPlugin(at directory: URL) throws {
        let pluginURL = directory.appendingPathComponent("crashPlugin.waplugin")
        
        // Create plugin bundle
        try FileManager.default.createDirectory(at: pluginURL, withIntermediateDirectories: true)
        
        // Create Info.plist with invalid data to trigger error
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.winamp.test.crash</string>
            <key>PluginType</key>
            <string>crash</string>
            <key>CrashOnActivate</key>
            <true/>
        </dict>
        </plist>
        """
        
        let plistURL = pluginURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: plistURL, atomically: true, encoding: .utf8)
        
        print("Generated crash plugin: crashPlugin.waplugin")
    }
    
    // MARK: - Helper Functions
    
    private static func generateMinimalBMP(width: Int, height: Int) -> Data {
        var data = Data()
        
        // BMP Header
        data.append("BM".data(using: .ascii)!) // Signature
        data.append(littleEndian: UInt32(54 + width * height * 3)) // File size
        data.append(littleEndian: UInt32(0)) // Reserved
        data.append(littleEndian: UInt32(54)) // Data offset
        
        // DIB Header
        data.append(littleEndian: UInt32(40)) // Header size
        data.append(littleEndian: Int32(width))
        data.append(littleEndian: Int32(height))
        data.append(littleEndian: UInt16(1)) // Planes
        data.append(littleEndian: UInt16(24)) // Bits per pixel
        data.append(littleEndian: UInt32(0)) // Compression
        data.append(littleEndian: UInt32(width * height * 3)) // Image size
        data.append(littleEndian: Int32(2835)) // X pixels per meter
        data.append(littleEndian: Int32(2835)) // Y pixels per meter
        data.append(littleEndian: UInt32(0)) // Colors used
        data.append(littleEndian: UInt32(0)) // Important colors
        
        // Pixel data (solid color)
        for _ in 0..<(width * height) {
            data.append(contentsOf: [0x40, 0x40, 0x40]) // Gray color (BGR)
        }
        
        return data
    }
    
    private static func createZipArchive(from sourceURL: URL, to destinationURL: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        task.arguments = ["-r", destinationURL.path, "."]
        task.currentDirectoryURL = sourceURL
        
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestFixtureGenerator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create ZIP archive"
            ])
        }
    }
    
    private static func ieee80BitExtended(from value: Double) -> [UInt8] {
        // Simplified implementation - returns 80-bit IEEE extended precision
        // For testing purposes, this is a rough approximation
        var bytes = [UInt8](repeating: 0, count: 10)
        
        // Set exponent (biased by 16383)
        let exponent = 16383 + 14 // For 44100/48000/96000 range
        bytes[0] = UInt8((exponent >> 8) & 0xFF)
        bytes[1] = UInt8(exponent & 0xFF)
        
        // Set mantissa (simplified)
        let mantissa = UInt64(value * 65536)
        for i in 0..<8 {
            bytes[9 - i] = UInt8((mantissa >> (i * 8)) & 0xFF)
        }
        
        return bytes
    }
}

// MARK: - Data Extensions

extension Data {
    mutating func append<T>(littleEndian value: T) where T: FixedWidthInteger {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
    
    mutating func append<T>(bigEndian value: T) where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}