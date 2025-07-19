//
//  macOSAudioSystemManager.swift
//  WinAmpPlayer
//
//  Created on 2025-07-19.
//  macOS-specific audio system management
//

import Foundation
import AVFoundation
import Combine

/// Manages audio system state on macOS (replaces iOS AVAudioSession)
final class macOSAudioSystemManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = macOSAudioSystemManager()
    
    /// The audio engine being managed
    private var audioEngine: AVAudioEngine?
    
    /// Device manager for handling audio devices
    private let deviceManager = macOSAudioDeviceManager.shared
    
    /// Current audio state
    @Published private(set) var isActive = false
    
    /// Interruption state
    @Published private(set) var isInterrupted = false
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupInterruptionHandling()
        setupDeviceChangeHandling()
    }
    
    // MARK: - Public Methods
    
    /// Configure the audio system for the given engine
    func configure(for engine: AVAudioEngine) {
        self.audioEngine = engine
        
        // Configure for high quality audio
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 2,
            interleaved: false
        )
        
        // Note: On macOS, we don't need to configure an audio session
        // The system handles this automatically
    }
    
    /// Activate the audio system
    func activate() throws {
        isActive = true
        
        // On macOS, activation is handled by starting the audio engine
        // No AVAudioSession equivalent needed
    }
    
    /// Deactivate the audio system
    func deactivate() {
        isActive = false
    }
    
    /// Handle system sleep/wake events
    @objc private func handleSystemSleep(_ notification: Notification) {
        isInterrupted = true
        NotificationCenter.default.post(
            name: .audioSystemInterrupted,
            object: nil,
            userInfo: [
                "type": InterruptionType.began,
                "reason": InterruptionReason.systemSleep
            ]
        )
    }
    
    @objc private func handleSystemWake(_ notification: Notification) {
        isInterrupted = false
        NotificationCenter.default.post(
            name: .audioSystemInterrupted,
            object: nil,
            userInfo: [
                "type": InterruptionType.ended,
                "reason": InterruptionReason.systemWake
            ]
        )
    }
    
    /// Handle application deactivation
    @objc private func handleAppDeactivation(_ notification: Notification) {
        // On macOS, we might want to pause audio when app loses focus
        // This is optional and depends on app requirements
    }
    
    /// Handle application activation
    @objc private func handleAppActivation(_ notification: Notification) {
        // Resume audio if needed when app gains focus
    }
    
    // MARK: - Private Methods
    
    private func setupInterruptionHandling() {
        // System sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // App activation/deactivation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDeactivation),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func setupDeviceChangeHandling() {
        // Subscribe to device changes from the device manager
        deviceManager.deviceChangePublisher
            .sink { [weak self] change in
                self?.handleDeviceChange(change)
            }
            .store(in: &cancellables)
    }
    
    private func handleDeviceChange(_ change: (device: macOSAudioDeviceManager.AudioDevice, connected: Bool)) {
        // Post notification about route change
        NotificationCenter.default.post(
            name: .audioRouteChanged,
            object: nil,
            userInfo: [
                "device": change.device,
                "connected": change.connected
            ]
        )
        
        // If the current device was disconnected, switch to default
        if !change.connected,
           let currentDevice = deviceManager.currentDevice,
           currentDevice.id == change.device.id {
            
            if let defaultDevice = deviceManager.getDefaultOutputDevice(),
               let engine = audioEngine {
                try? deviceManager.setOutputDevice(defaultDevice, for: engine)
            }
        }
    }
}

// MARK: - Interruption Types

extension macOSAudioSystemManager {
    /// Interruption type (mimics AVAudioSession.InterruptionType)
    enum InterruptionType {
        case began
        case ended
    }
    
    /// Interruption reason
    enum InterruptionReason {
        case systemSleep
        case systemWake
        case appBackground
        case appForeground
        case other
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Audio system was interrupted
    static let audioSystemInterrupted = Notification.Name("audioSystemInterrupted")
    
    /// Audio route changed (device connected/disconnected)
    static let audioRouteChanged = Notification.Name("audioRouteChanged")
}

// MARK: - Compatibility Layer

extension macOSAudioSystemManager {
    /// Compatibility method to match iOS API
    func setCategory(_ category: AudioCategory, mode: AudioMode = .default, options: AudioOptions = []) throws {
        // On macOS, we don't need to set categories
        // This is here for API compatibility
        print("Audio category set to: \(category) (no-op on macOS)")
    }
    
    /// Audio categories (for compatibility)
    enum AudioCategory {
        case playback
        case record
        case playAndRecord
        case multiRoute
        case ambient
        case soloAmbient
    }
    
    /// Audio modes (for compatibility)
    enum AudioMode {
        case `default`
        case gameChat
        case measurement
        case moviePlayback
        case spokenAudio
        case videoChat
        case videoRecording
        case voiceChat
    }
    
    /// Audio options (for compatibility)
    struct AudioOptions: OptionSet {
        let rawValue: Int
        
        static let mixWithOthers = AudioOptions(rawValue: 1 << 0)
        static let duckOthers = AudioOptions(rawValue: 1 << 1)
        static let allowBluetooth = AudioOptions(rawValue: 1 << 2)
        static let defaultToSpeaker = AudioOptions(rawValue: 1 << 3)
    }
}