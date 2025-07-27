#!/usr/bin/env swift

import Foundation
import AVFoundation

// Simple diagnostic script to test audio playback

class AudioDiagnostic {
    let audioEngine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    
    func testMP3Playback(url: URL) {
        print("🔍 Testing MP3 playback for: \(url.lastPathComponent)")
        
        do {
            // Check file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ File does not exist at path: \(url.path)")
                return
            }
            print("✅ File exists")
            
            // Try to load the file
            let audioFile = try AVAudioFile(forReading: url)
            print("✅ Successfully loaded audio file")
            print("   Format: \(audioFile.fileFormat)")
            print("   Sample Rate: \(audioFile.fileFormat.sampleRate)")
            print("   Channels: \(audioFile.fileFormat.channelCount)")
            print("   Duration: \(Double(audioFile.length) / audioFile.fileFormat.sampleRate) seconds")
            
            // Setup audio engine
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
            
            // Start engine
            try audioEngine.start()
            print("✅ Audio engine started")
            
            // Schedule and play
            playerNode.scheduleFile(audioFile, at: nil)
            playerNode.play()
            print("✅ Playback started")
            
            // Wait a bit
            Thread.sleep(forTimeInterval: 2)
            
            if playerNode.isPlaying {
                print("✅ Audio is playing correctly")
            } else {
                print("⚠️ Player node is not playing")
            }
            
            // Stop
            playerNode.stop()
            audioEngine.stop()
            print("✅ Playback stopped")
            
        } catch {
            print("❌ Error: \(error)")
            print("   Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("   Error code: \(nsError.code)")
                print("   Error domain: \(nsError.domain)")
            }
        }
    }
}

// Get file path from command line or use default
let args = CommandLine.arguments
let filePath: String

if args.count > 1 {
    filePath = args[1]
} else {
    print("Usage: swift diagnose_playback.swift <path_to_mp3>")
    print("No file specified, using test mode...")
    exit(1)
}

let url = URL(fileURLWithPath: filePath)
let diagnostic = AudioDiagnostic()
diagnostic.testMP3Playback(url: url)