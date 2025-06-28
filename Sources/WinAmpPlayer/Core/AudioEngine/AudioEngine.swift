//
//  AudioEngine.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Core audio playback engine for WinAmp Player.
//

import AVFoundation
import Combine
import os.log

/// Errors that can occur during audio playback
enum AudioEngineError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case engineStartFailed(Error)
    case fileLoadFailed(Error)
    case seekFailed
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .fileLoadFailed(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        case .seekFailed:
            return "Failed to seek to position"
        case .invalidURL:
            return "Invalid file URL"
        }
    }
}

/// Playback state of the audio engine
enum PlaybackState {
    case stopped
    case playing
    case paused
    case loading
    case error(Error)
}

/// Manages audio playback, decoding, and processing using AVAudioEngine
/// Provides high-quality audio playback with support for various audio formats
class AudioEngine: ObservableObject {
    // MARK: - Volume Controller Integration
    
    private var volumeController: VolumeBalanceController?
    
    /// Set the volume controller for synchronized volume management
    func setVolumeController(_ controller: VolumeBalanceController) {
        self.volumeController = controller
        // Sync initial volume
        self.volume = controller.volume
    }
    // MARK: - Published Properties
    
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.5 {
        didSet {
            // Use volume controller if available, otherwise set directly
            if let controller = volumeController {
                controller.setVolume(volume)
            } else {
                playerNode.volume = volume
            }
        }
    }
    @Published var currentTrack: Track?
    @Published var isLoading: Bool = false
    
    // MARK: - Computed Properties
    
    var isPlaying: Bool {
        if case .playing = playbackState {
            return true
        }
        return false
    }
    
    var isPaused: Bool {
        if case .paused = playbackState {
            return true
        }
        return false
    }
    
    // MARK: - Private Properties
    
    internal let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var audioFormat: AVAudioFormat?
    private var framePosition: AVAudioFramePosition = 0
    private var frameLength: AVAudioFramePosition = 0
    private var needsFileScheduling = true
    
    private var displayLink: Timer?
    private let updateInterval: TimeInterval = 0.05 // 20 FPS update rate
    
    private let logger = Logger(subsystem: "com.winamp.player", category: "AudioEngine")
    private let audioQueue = DispatchQueue(label: "com.winamp.audioengine", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        
        setupAudioEngine()
        setupNotifications()
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Load and prepare a track for playback
    /// - Parameter track: The track to load
    /// - Throws: AudioEngineError if the track cannot be loaded
    func loadTrack(_ track: Track) async throws {
        // Clean up any existing playback
        await cleanup()
        
        guard let url = track.fileURL else {
            throw AudioEngineError.invalidURL
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioEngineError.fileNotFound
        }
        
        isLoading = true
        playbackState = .loading
        
        do {
            // Load audio file on background queue
            let loadedFile = try await audioQueue.sync {
                try AVAudioFile(forReading: url)
            }
            
            // Validate format
            guard isFormatSupported(loadedFile.fileFormat) else {
                throw AudioEngineError.unsupportedFormat
            }
            
            self.audioFile = loadedFile
            self.audioFormat = loadedFile.processingFormat
            self.frameLength = loadedFile.length
            self.framePosition = 0
            self.needsFileScheduling = true
            
            // Calculate duration
            duration = Double(frameLength) / loadedFile.fileFormat.sampleRate
            currentTime = 0
            
            // Update track info
            currentTrack = track
            
            // Prepare for playback
            try prepareForPlayback()
            
            isLoading = false
            playbackState = .stopped
            
            logger.info("Successfully loaded track: \(track.displayTitle)")
        } catch {
            isLoading = false
            playbackState = .error(error)
            logger.error("Failed to load track: \(error.localizedDescription)")
            throw AudioEngineError.fileLoadFailed(error)
        }
    }
    
    /// Load audio from a URL
    /// - Parameter url: The URL of the audio file to load
    /// - Throws: AudioEngineError if the file cannot be loaded
    func loadURL(_ url: URL) async throws {
        guard let track = Track(from: url) else {
            throw AudioEngineError.fileNotFound
        }
        try await loadTrack(track)
    }
    
    /// Start or resume playback
    /// - Throws: AudioEngineError if playback cannot be started
    func play() throws {
        guard audioFile != nil else {
            logger.warning("Attempted to play without loaded audio file")
            return
        }
        
        // Start the engine if needed
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                logger.info("Audio engine started")
            } catch {
                playbackState = .error(AudioEngineError.engineStartFailed(error))
                throw AudioEngineError.engineStartFailed(error)
            }
        }
        
        // Schedule the file if needed
        if needsFileScheduling {
            try scheduleAudioFile()
        }
        
        // Start playback
        playerNode.play()
        playbackState = .playing
        startDisplayLink()
        
        logger.info("Playback started")
    }
    
    /// Pause playback
    func pause() {
        guard case .playing = playbackState else { return }
        
        playerNode.pause()
        playbackState = .paused
        stopDisplayLink()
        
        // Save current position for resuming
        updateFramePosition()
        
        logger.info("Playback paused at \(currentTime)s")
    }
    
    /// Stop playback and reset to beginning
    func stop() {
        playerNode.stop()
        playbackState = .stopped
        currentTime = 0
        framePosition = 0
        needsFileScheduling = true
        stopDisplayLink()
        
        logger.info("Playback stopped")
    }
    
    /// Seek to a specific time in the audio file
    /// - Parameter time: The time to seek to (in seconds)
    /// - Throws: AudioEngineError if seeking fails
    func seek(to time: TimeInterval) throws {
        guard let audioFile = audioFile else {
            throw AudioEngineError.seekFailed
        }
        
        // Clamp time to valid range
        let clampedTime = max(0, min(time, duration))
        
        // Calculate frame position
        let sampleRate = audioFile.fileFormat.sampleRate
        let newFramePosition = AVAudioFramePosition(clampedTime * sampleRate)
        
        // Store playback state
        let wasPlaying = isPlaying
        
        // Stop current playback
        playerNode.stop()
        
        // Update position
        framePosition = newFramePosition
        currentTime = clampedTime
        needsFileScheduling = true
        
        // Resume playback if was playing
        if wasPlaying {
            try play()
        }
        
        logger.info("Seeked to \(clampedTime)s")
    }
    
    /// Toggle between play and pause
    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused, .stopped:
            try? play()
        default:
            break
        }
    }
    
    /// Skip forward by a specified number of seconds
    /// - Parameter seconds: Number of seconds to skip (default: 10)
    func skipForward(by seconds: TimeInterval = 10) {
        try? seek(to: currentTime + seconds)
    }
    
    /// Skip backward by a specified number of seconds
    /// - Parameter seconds: Number of seconds to skip (default: 10)
    func skipBackward(by seconds: TimeInterval = 10) {
        try? seek(to: currentTime - seconds)
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        // Attach player node
        audioEngine.attach(playerNode)
        
        // Connect to main mixer
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMixer, format: nil)
        
        // Set initial volume
        playerNode.volume = volume
        
        // Configure for low latency
        audioEngine.prepare()
        
        logger.info("Audio engine configured")
    }
    
    private func setupNotifications() {
        // Listen for audio route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Listen for interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        logger.info("Audio route changed")
        // Handle route changes if needed
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            logger.info("Audio interruption began")
            pause()
        case .ended:
            logger.info("Audio interruption ended")
            // Optionally resume playback
        @unknown default:
            break
        }
    }
    
    private func prepareForPlayback() throws {
        guard let audioFile = audioFile else {
            throw AudioEngineError.fileNotFound
        }
        
        // Reset the player node
        playerNode.reset()
        
        // Connect with the file's format
        let format = audioFile.processingFormat
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        logger.info("Prepared for playback with format: \(format)")
    }
    
    private func scheduleAudioFile() throws {
        guard let audioFile = audioFile else {
            throw AudioEngineError.fileNotFound
        }
        
        audioFile.framePosition = framePosition
        
        // Calculate remaining frames
        let framesToPlay = frameLength - framePosition
        
        if framesToPlay > 0 {
            playerNode.scheduleSegment(
                audioFile,
                startingFrame: framePosition,
                frameCount: AVAudioFrameCount(framesToPlay),
                at: nil
            ) { [weak self] in
                DispatchQueue.main.async {
                    self?.handlePlaybackCompletion()
                }
            }
            
            needsFileScheduling = false
            logger.info("Scheduled audio file from frame \(framePosition)")
        }
    }
    
    private func isFormatSupported(_ format: AVAudioFormat) -> Bool {
        // Check if the format is supported
        // AVAudioEngine supports most common formats
        return format.sampleRate > 0 && format.channelCount > 0
    }
    
    private func handlePlaybackCompletion() {
        logger.info("Playback completed")
        
        playbackState = .stopped
        currentTime = duration
        framePosition = frameLength
        needsFileScheduling = true
        stopDisplayLink()
        
        // Post completion notification
        NotificationCenter.default.post(
            name: .audioPlaybackCompleted,
            object: self,
            userInfo: ["track": currentTrack as Any]
        )
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func updateCurrentTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              playerTime.sampleRate > 0 else {
            return
        }
        
        let time = Double(playerTime.sampleTime) / playerTime.sampleRate + Double(framePosition) / playerTime.sampleRate
        
        // Only update if time has changed significantly
        if abs(time - currentTime) > 0.01 {
            currentTime = min(time, duration)
        }
    }
    
    private func updateFramePosition() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let audioFile = audioFile else {
            return
        }
        
        let playedFrames = playerTime.sampleTime
        framePosition = min(framePosition + playedFrames, frameLength)
    }
    
    private func cleanup() {
        // Stop playback
        if audioEngine.isRunning {
            playerNode.stop()
            audioEngine.stop()
        }
        
        // Reset state
        playbackState = .stopped
        audioFile = nil
        audioFormat = nil
        framePosition = 0
        frameLength = 0
        currentTime = 0
        duration = 0
        needsFileScheduling = true
        
        // Stop timers
        stopDisplayLink()
        
        logger.info("Audio engine cleaned up")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let audioPlaybackCompleted = Notification.Name("audioPlaybackCompleted")
    static let audioPlaybackStateChanged = Notification.Name("audioPlaybackStateChanged")
    static let audioPlaybackError = Notification.Name("audioPlaybackError")
}

// MARK: - Public Extensions

extension AudioEngine {
    /// Get a formatted string for the current playback time
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    /// Get a formatted string for the total duration
    var formattedDuration: String {
        formatTime(duration)
    }
    
    /// Get the playback progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}