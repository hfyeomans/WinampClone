//
//  AudioEngineLogger.swift
//  WinAmpPlayer
//
//  Logging extension for AudioEngine to help diagnose playback issues
//

import Foundation
import os.log

extension AudioEngine {
    /// Enhanced logging for debugging
    func logPlaybackState() {
        logger.info("=== AudioEngine State ===")
        logger.info("Playback State: \(String(describing: self.playbackState))")
        logger.info("Is Playing: \(self.isPlaying)")
        logger.info("Current Track: \(self.currentTrack?.displayTitle ?? "None")")
        logger.info("Duration: \(self.duration)")
        logger.info("Current Time: \(self.currentTime)")
        logger.info("Volume: \(self.volume)")
        logger.info("Audio File: \(self.audioFile != nil ? "Loaded" : "Not Loaded")")
        logger.info("Audio Engine Running: \(self.audioEngine.isRunning)")
        logger.info("Player Node Playing: \(self.playerNode.isPlaying)")
        logger.info("========================")
    }
}

// Add console output for debugging
extension OSLog {
    static let audioPlayback = OSLog(subsystem: "com.winamp.player", category: "AudioPlayback")
}

// Helper to print to console for debugging
func debugPrint(_ message: String) {
    #if DEBUG
    print("[WinAmpPlayer] \(message)")
    #endif
}