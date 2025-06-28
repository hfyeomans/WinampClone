//
//  AudioEngine.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Core audio playback engine for WinAmp Player.
//

import AVFoundation
import Combine

/// Manages audio playback, decoding, and processing
class AudioEngine: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.5
    @Published var currentTrack: Track?
    
    // MARK: - Private Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var timer: Timer?
    
    // MARK: - Initialization
    
    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        
        setupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    /// Load and prepare a track for playback
    /// - Parameter track: The track to load
    func loadTrack(_ track: Track) {
        currentTrack = track
        
        guard let url = track.fileURL else { return }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            
            // Additional setup for the audio file
            prepareForPlayback(audioFile: audioFile)
        } catch {
            print("Error loading track: \(error)")
        }
    }
    
    /// Start playback
    func play() {
        guard playerNode.engine != nil else { return }
        
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                print("Error starting audio engine: \(error)")
            }
        }
        
        playerNode.play()
        isPlaying = true
        startTimer()
    }
    
    /// Pause playback
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimer()
    }
    
    /// Stop playback
    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    /// Seek to a specific time
    /// - Parameter time: The time to seek to
    func seek(to time: TimeInterval) {
        currentTime = time
        // TODO: Implement actual seeking logic
    }
    
    /// Set the volume
    /// - Parameter volume: Volume level (0.0 to 1.0)
    func setVolume(_ volume: Float) {
        self.volume = volume
        playerNode.volume = volume
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMixer, format: nil)
        
        // Configure audio session for macOS
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        // macOS-specific audio configuration
        // Note: AVAudioSession is iOS-specific, so we handle macOS differently
    }
    
    private func prepareForPlayback(audioFile: AVAudioFile) {
        playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.handlePlaybackCompletion()
            }
        }
    }
    
    private func handlePlaybackCompletion() {
        isPlaying = false
        currentTime = 0
        stopTimer()
        
        // Notify that playback has completed
        NotificationCenter.default.post(
            name: .audioPlaybackCompleted,
            object: self
        )
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let audioPlaybackCompleted = Notification.Name("audioPlaybackCompleted")
}