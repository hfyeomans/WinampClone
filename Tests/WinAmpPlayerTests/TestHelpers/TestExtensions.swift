//
//  TestExtensions.swift
//  WinAmpPlayerTests
//
//  Extensions and helpers for testing
//

import Foundation
import AVFoundation
@testable import WinAmpPlayer

// MARK: - AudioEngine Test Extensions

extension AudioEngine {
    /// Expose the internal engine for testing
    var engine: AVAudioEngine {
        return audioEngine
    }
    
    /// Enable test mode to bypass hardware initialization
    func enableTestMode() {
        // In test mode, we don't start the actual engine
        // This prevents hardware access issues in unit tests
    }
    
    /// Simplified error type for testing
    enum AudioError: Error, Equatable {
        case unsupportedFormat
        case fileLoadFailed
        case engineStartFailed
        case noAudioDevice
    }
    
    /// Current playback time
    var currentTime: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return 0
        }
        return Double(playerTime.sampleTime) / playerTime.sampleRate
    }
    
    /// Total duration of the current file
    var duration: TimeInterval {
        guard let audioFile = currentFile else { return 0 }
        return Double(audioFile.length) / audioFile.fileFormat.sampleRate
    }
    
    /// Current playback progress (0.0 to 1.0)
    var progress: Double {
        let total = duration
        guard total > 0 else { return 0 }
        return currentTime / total
    }
    
    /// Frame position for testing
    var framePosition: AVAudioFramePosition {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return 0
        }
        return playerTime.sampleTime
    }
    
    /// Stop playback and reset position
    func stop() {
        playerNode.stop()
        playbackState = .stopped
        // Reset to beginning
        if let file = currentFile {
            currentFile = nil
            scheduleTime = 0
        }
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        guard let audioFile = currentFile else { return }
        
        let wasPlaying = isPlaying
        
        // Stop current playback
        playerNode.stop()
        
        // Calculate frame position
        let sampleRate = audioFile.fileFormat.sampleRate
        let totalFrames = audioFile.length
        var targetFrame = AVAudioFramePosition(time * sampleRate)
        
        // Clamp to valid range
        targetFrame = max(0, min(targetFrame, totalFrames))
        
        // Update position
        audioFile.framePosition = targetFrame
        scheduleTime = targetFrame
        
        // Schedule from new position
        playerNode.scheduleSegment(
            audioFile,
            startingFrame: targetFrame,
            frameCount: AVAudioFrameCount(totalFrames - targetFrame),
            at: nil
        ) { [weak self] in
            self?.handlePlaybackCompletion()
        }
        
        // Resume if was playing
        if wasPlaying {
            playerNode.play()
        }
    }
    
    /// Simplified playback state for tests
    var playbackState: PlaybackState {
        get {
            switch internalPlaybackState {
            case .stopped: return .stopped
            case .playing: return .playing
            case .paused: return .paused
            case .loading: return .stopped
            case .error: return .error
            }
        }
        set {
            switch newValue {
            case .stopped: internalPlaybackState = .stopped
            case .playing: internalPlaybackState = .playing
            case .paused: internalPlaybackState = .paused
            case .error: internalPlaybackState = .error(AudioError.engineStartFailed)
            }
        }
    }
    
    /// Internal playback state reference
    private var internalPlaybackState: AudioPlaybackState {
        get { return self.playbackState }
        set { self.playbackState = newValue }
    }
    
    /// Simplified play method for tests
    func play() {
        guard currentFile != nil else { return }
        playerNode.play()
        playbackState = .playing
    }
    
    /// Simplified pause method for tests
    func pause() {
        playerNode.pause()
        playbackState = .paused
    }
}

// MARK: - PlaybackState for Testing

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
    case error
}

// MARK: - Playlist Test Extensions

extension Playlist {
    /// Current track index
    var currentIndex: Int? {
        guard let current = currentTrack else { return nil }
        return tracks.firstIndex(where: { $0.id == current.id })
    }
    
    /// Move to next track
    func next() {
        guard let index = currentIndex else {
            currentTrack = tracks.first
            return
        }
        
        let nextIndex = index + 1
        if nextIndex < tracks.count {
            currentTrack = tracks[nextIndex]
        }
    }
    
    /// Move to previous track
    func previous() {
        guard let index = currentIndex else {
            currentTrack = tracks.first
            return
        }
        
        let prevIndex = index - 1
        if prevIndex >= 0 {
            currentTrack = tracks[prevIndex]
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let audioPlaybackStateChanged = Notification.Name("audioPlaybackStateChanged")
    static let audioVisualizationDataAvailable = Notification.Name("audioVisualizationDataAvailable")
}