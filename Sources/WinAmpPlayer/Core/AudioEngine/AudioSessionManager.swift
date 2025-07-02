import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Manages AVAudioSession configuration and handles audio-related system events
public final class AudioSessionManager {
    
    // MARK: - Singleton
    
    public static let shared = AudioSessionManager()
    
    // MARK: - Properties
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaServicesResetObserver: NSObjectProtocol?
    private var mediaServicesLostObserver: NSObjectProtocol?
    
    /// Audio output manager instance
    private let outputManager = AudioOutputManager.shared
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Current audio session category
    public private(set) var currentCategory: AVAudioSession.Category = .playback
    
    /// Current audio session mode
    public private(set) var currentMode: AVAudioSession.Mode = .default
    
    /// Whether the session is currently active
    public private(set) var isSessionActive = false
    
    // MARK: - Callbacks
    
    /// Called when audio session is interrupted
    public var onInterruptionBegan: (() -> Void)?
    
    /// Called when audio session interruption ends
    public var onInterruptionEnded: ((Bool) -> Void)? // Bool indicates if playback should resume
    
    /// Called when audio route changes
    public var onRouteChange: ((AVAudioSession.RouteChangeReason, AVAudioSessionRouteDescription?) -> Void)?
    
    /// Called when media services are reset
    public var onMediaServicesReset: (() -> Void)?
    
    /// Called when media services are lost
    public var onMediaServicesLost: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        setupRemoteTransportControls()
        setupOutputManagerIntegration()
    }
    
    deinit {
        removeObservers()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Configure audio session for music playback
    @discardableResult
    public func configureForMusicPlayback() -> Bool {
        return configureSession(category: .playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
    }
    
    /// Configure audio session with custom settings
    @discardableResult
    public func configureSession(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode = .default,
        options: AVAudioSession.CategoryOptions = []
    ) -> Bool {
        do {
            try audioSession.setCategory(category, mode: mode, options: options)
            currentCategory = category
            currentMode = mode
            return true
        } catch {
            print("Failed to configure audio session: \(error)")
            return false
        }
    }
    
    /// Activate the audio session
    @discardableResult
    public func activateSession() -> Bool {
        guard !isSessionActive else { return true }
        
        do {
            try audioSession.setActive(true)
            isSessionActive = true
            return true
        } catch {
            print("Failed to activate audio session: \(error)")
            return false
        }
    }
    
    /// Deactivate the audio session
    @discardableResult
    public func deactivateSession() -> Bool {
        guard isSessionActive else { return true }
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
            return true
        } catch {
            print("Failed to deactivate audio session: \(error)")
            return false
        }
    }
    
    /// Enable background audio capability
    public func enableBackgroundAudio() {
        configureSession(category: .playback, mode: .default, options: [.mixWithOthers])
    }
    
    /// Check if headphones are connected
    public var areHeadphonesConnected: Bool {
        return audioSession.currentRoute.outputs.contains { output in
            return output.portType == .headphones || 
                   output.portType == .bluetoothA2DP || 
                   output.portType == .airPlay
        }
    }
    
    /// Get current audio route
    public var currentRoute: AVAudioSessionRouteDescription {
        return audioSession.currentRoute
    }
    
    /// Get available output devices
    public var availableOutputDevices: [AudioOutputManager.AudioOutputDevice] {
        return outputManager.availableOutputDevices
    }
    
    /// Get current output device
    public var currentOutputDevice: AudioOutputManager.AudioOutputDevice? {
        return outputManager.currentOutputDevice
    }
    
    /// Switch to a specific output device
    @discardableResult
    public func switchToOutputDevice(_ device: AudioOutputManager.AudioOutputDevice) -> Bool {
        return outputManager.switchToDevice(device)
    }
    
    /// Enable multi-output for simultaneous playback
    @discardableResult
    public func enableMultiOutput(devices: [AudioOutputManager.AudioOutputDevice], mirroring: Bool = true) -> Bool {
        return outputManager.enableMultiOutput(devices: devices, mirroring: mirroring)
    }
    
    /// Disable multi-output
    public func disableMultiOutput() {
        outputManager.disableMultiOutput()
    }
    
    /// Update Now Playing info
    public func updateNowPlayingInfo(
        title: String?,
        artist: String?,
        albumTitle: String?,
        artwork: MPMediaItemArtwork?,
        duration: TimeInterval?,
        currentTime: TimeInterval?
    ) {
        var nowPlayingInfo = [String: Any]()
        
        if let title = title {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        if let artist = artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }
        if let albumTitle = albumTitle {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        if let artwork = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        if let duration = duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let currentTime = currentTime {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Clear Now Playing info
    public func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Remote Control Events
    
    /// Set up remote control event handlers
    public func setupRemoteControlHandlers(
        playHandler: @escaping () -> MPRemoteCommandHandlerStatus,
        pauseHandler: @escaping () -> MPRemoteCommandHandlerStatus,
        nextHandler: @escaping () -> MPRemoteCommandHandlerStatus,
        previousHandler: @escaping () -> MPRemoteCommandHandlerStatus,
        seekHandler: ((_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus)? = nil
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.addTarget { _ in
            return playHandler()
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.addTarget { _ in
            return pauseHandler()
        }
        
        // Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.addTarget { _ in
            return nextHandler()
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.addTarget { _ in
            return previousHandler()
        }
        
        // Seek command (optional)
        if let seekHandler = seekHandler {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
            commandCenter.changePlaybackPositionCommand.removeTarget(nil)
            commandCenter.changePlaybackPositionCommand.addTarget { event in
                guard let seekEvent = event as? MPChangePlaybackPositionCommandEvent else {
                    return .commandFailed
                }
                return seekHandler(seekEvent)
            }
        } else {
            commandCenter.changePlaybackPositionCommand.isEnabled = false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        let notificationCenter = NotificationCenter.default
        
        // Audio interruption observer
        interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
        
        // Route change observer
        routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        
        // Media services reset observer
        mediaServicesResetObserver = notificationCenter.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesReset()
        }
        
        // Media services lost observer
        mediaServicesLostObserver = notificationCenter.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesLost()
        }
    }
    
    private func removeObservers() {
        let notificationCenter = NotificationCenter.default
        
        if let observer = interruptionObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = mediaServicesResetObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = mediaServicesLostObserver {
            notificationCenter.removeObserver(observer)
        }
    }
    
    private func setupRemoteTransportControls() {
        // Enable remote control events
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        // Set up default handlers that do nothing (can be overridden by the app)
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }
    
    // MARK: - Notification Handlers
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - pause playback
            onInterruptionBegan?()
            
        case .ended:
            // Interruption ended - check if we should resume
            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }
            onInterruptionEnded?(shouldResume)
            
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        var previousRoute: AVAudioSessionRouteDescription?
        if let previousRouteValue = userInfo[AVAudioSessionRouteChangePreviousRouteKey] {
            previousRoute = previousRouteValue as? AVAudioSessionRouteDescription
        }
        
        onRouteChange?(reason, previousRoute)
        
        // Handle specific route change reasons
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged, or device was disconnected
            if let previousRoute = previousRoute {
                let wasUsingHeadphones = previousRoute.outputs.contains { output in
                    return output.portType == .headphones ||
                           output.portType == .bluetoothA2DP
                }
                if wasUsingHeadphones {
                    // Pause playback when headphones are unplugged
                    onInterruptionBegan?()
                }
            }
            
        case .newDeviceAvailable:
            // New device available (e.g., headphones plugged in)
            // Optionally switch to the new device automatically
            if let preferredDevice = outputManager.preferredOutputDevice {
                outputManager.switchToDevice(preferredDevice)
            }
            break
            
        case .override:
            // Route was overridden (e.g., user selected AirPlay)
            break
            
        default:
            break
        }
    }
    
    private func handleMediaServicesReset() {
        // Media services were reset - need to reconfigure audio session
        onMediaServicesReset?()
        
        // Reconfigure the session
        configureForMusicPlayback()
        activateSession()
    }
    
    private func handleMediaServicesLost() {
        // Media services were lost
        onMediaServicesLost?()
        isSessionActive = false
    }
    
    private func setupOutputManagerIntegration() {
        // Subscribe to output manager events
        outputManager.deviceConnectionPublisher
            .sink { [weak self] deviceEvent in
                print("Device \(deviceEvent.device.name) \(deviceEvent.connected ? "connected" : "disconnected")")
                
                // Handle device connections
                if deviceEvent.connected {
                    // Optionally auto-switch to newly connected device based on preferences
                    if deviceEvent.device.portType == .headphones ||
                       deviceEvent.device.portType == .bluetoothA2DP {
                        self?.outputManager.switchToDevice(deviceEvent.device)
                    }
                }
            }
            .store(in: &cancellables)
        
        outputManager.routeChangePublisher
            .sink { [weak self] reason in
                // Additional handling for route changes if needed
                print("Route changed: \(reason)")
            }
            .store(in: &cancellables)
    }
}

// MARK: - AudioEngine Integration Extension

extension AudioSessionManager {
    
    /// Configure and activate session for AudioEngine
    public func prepareForAudioEngine() -> Bool {
        guard configureForMusicPlayback() else { return false }
        return activateSession()
    }
    
    /// Check if any wireless audio device is connected
    public var isWirelessAudioConnected: Bool {
        return outputManager.isBluetoothConnected || outputManager.isAirPlayAvailable
    }
    
    /// Get all wireless audio devices
    public var wirelessAudioDevices: [AudioOutputManager.AudioOutputDevice] {
        return outputManager.bluetoothDevices + outputManager.airPlayDevices
    }
    
    /// Handle AirPlay selection
    public func showAirPlayPicker() {
        // This would typically show the system AirPlay picker
        // Implementation depends on UI framework (UIKit/SwiftUI)
        print("AirPlay picker requested - implement UI integration")
    }
    
    /// Handle AudioEngine state changes
    public func handleAudioEngineStateChange(isPlaying: Bool) {
        if isPlaying {
            activateSession()
        } else {
            // Keep session active for quick resume
            // Only deactivate when app is backgrounded
        }
    }
    
    /// Set up default remote control handlers for AudioEngine
    public func setupDefaultRemoteControlsForAudioEngine(
        audioEngine: AudioEngine
    ) {
        setupRemoteControlHandlers(
            playHandler: {
                audioEngine.play()
                return .success
            },
            pauseHandler: {
                audioEngine.pause()
                return .success
            },
            nextHandler: {
                // Implement next track logic
                return .success
            },
            previousHandler: {
                // Implement previous track logic
                return .success
            },
            seekHandler: { event in
                audioEngine.seek(to: event.positionTime)
                return .success
            }
        )
    }
}