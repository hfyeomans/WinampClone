//
//  LastFMScrobbler.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Example general plugin: Last.fm scrobbler
//

import Foundation
import SwiftUI
import Combine

/// Last.fm scrobbler plugin
public final class LastFMScrobblerPlugin: BaseGeneralPlugin {
    
    // Configuration
    private var username: String = ""
    private var sessionKey: String = ""
    private var isEnabled: Bool = false
    private var scrobbleAt: Double = 0.5 // Scrobble at 50% by default
    
    // State tracking
    private var currentTrackStartTime: Date?
    private var hasScrobbled: Bool = false
    private var scrobbleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Statistics
    private var totalScrobbles: Int = 0
    private var lastScrobbleDate: Date?
    
    public override var requiredCapabilities: GeneralPluginCapabilities {
        [.playerControl, .networkAccess, .notificationAccess, .preferencesAccess]
    }
    
    public override var menuItems: [PluginMenuItem] {
        [
            PluginMenuItem(
                id: "lastfm_toggle",
                title: isEnabled ? "Disable Scrobbling" : "Enable Scrobbling",
                action: { [weak self] in self?.toggleScrobbling() },
                isEnabled: { [weak self] in self?.isAuthenticated ?? false }
            ),
            PluginMenuItem(
                id: "lastfm_authenticate",
                title: "Authenticate with Last.fm...",
                action: { [weak self] in self?.showAuthenticationWindow() },
                isEnabled: { [weak self] in !(self?.isAuthenticated ?? true) }
            ),
            PluginMenuItem(
                id: "lastfm_stats",
                title: "Scrobbling Statistics...",
                action: { [weak self] in self?.showStatistics() }
            )
        ]
    }
    
    public override var statusBarView: AnyView? {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: isEnabled ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(isEnabled ? .green : .gray)
                    .font(.system(size: 10))
                
                if totalScrobbles > 0 {
                    Text("\(totalScrobbles)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .help(isEnabled ? "Last.fm scrobbling enabled" : "Last.fm scrobbling disabled")
        )
    }
    
    public init() {
        let metadata = PluginMetadata(
            identifier: "com.winamp.plugin.lastfm",
            name: "Last.fm Scrobbler",
            type: .general,
            version: "1.0.0",
            author: "WinAmp Team",
            description: "Scrobble your music to Last.fm",
            website: URL(string: "https://last.fm"),
            iconName: "lastfm_icon"
        )
        
        super.init(metadata: metadata)
    }
    
    public override func pluginDidActivate() {
        loadSettings()
        startMonitoring()
    }
    
    public override func pluginWillDeactivate() {
        stopMonitoring()
        saveSettings()
    }
    
    public override func handlePlayerEvent(_ event: PlayerEvent) {
        guard isEnabled else { return }
        
        switch event {
        case .trackChanged(let track):
            handleTrackChange(track)
            
        case .playbackStateChanged(let state):
            handlePlaybackStateChange(state)
            
        case .positionChanged(let position):
            handlePositionChange(position)
            
        default:
            break
        }
    }
    
    public override func mainView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 20) {
                // Authentication status
                HStack {
                    Image(systemName: isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isAuthenticated ? .green : .red)
                    
                    Text(isAuthenticated ? "Authenticated as \(username)" : "Not authenticated")
                        .font(.headline)
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable scrobbling", isOn: Binding(
                        get: { self.isEnabled },
                        set: { self.isEnabled = $0; self.saveSettings() }
                    ))
                    .disabled(!isAuthenticated)
                    
                    HStack {
                        Text("Scrobble at:")
                        Slider(value: Binding(
                            get: { self.scrobbleAt },
                            set: { self.scrobbleAt = $0; self.saveSettings() }
                        ), in: 0.3...0.9, step: 0.1)
                        Text("\(Int(scrobbleAt * 100))%")
                            .frame(width: 40)
                    }
                    .disabled(!isAuthenticated)
                }
                
                Divider()
                
                // Statistics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.headline)
                    
                    Label("\(totalScrobbles) tracks scrobbled", systemImage: "music.note.list")
                    
                    if let lastDate = lastScrobbleDate {
                        Label("Last scrobble: \(lastDate.formatted())", systemImage: "clock")
                    }
                }
                
                Spacer()
                
                // Actions
                HStack {
                    if !isAuthenticated {
                        Button("Authenticate") {
                            self.showAuthenticationWindow()
                        }
                    }
                    
                    Button("View on Last.fm") {
                        if let url = URL(string: "https://last.fm/user/\(self.username)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .disabled(!isAuthenticated)
                }
            }
            .padding()
            .frame(width: 400, height: 300)
        )
    }
    
    public override func contextMenuItems(for track: Track) -> [PluginMenuItem] {
        [
            PluginMenuItem(
                id: "lastfm_love",
                title: "Love Track on Last.fm",
                action: { [weak self] in self?.loveTrack(track) },
                isEnabled: { [weak self] in self?.isEnabled ?? false }
            ),
            PluginMenuItem(
                id: "lastfm_info",
                title: "View on Last.fm",
                action: { [weak self] in self?.viewTrackOnLastFM(track) }
            )
        ]
    }
    
    // MARK: - Private Methods
    
    private var isAuthenticated: Bool {
        !username.isEmpty && !sessionKey.isEmpty
    }
    
    private func handleTrackChange(_ track: Track?) {
        // Submit previous track if needed
        if let startTime = currentTrackStartTime,
           let player = playerControl,
           hasScrobbled {
            let playDuration = Date().timeIntervalSince(startTime)
            updateNowPlaying(nil) // Clear now playing
        }
        
        // Reset for new track
        currentTrackStartTime = track != nil ? Date() : nil
        hasScrobbled = false
        scrobbleTimer?.invalidate()
        
        // Update now playing
        if let track = track {
            updateNowPlaying(track)
            scheduleScrobble(for: track)
        }
    }
    
    private func handlePlaybackStateChange(_ state: PlaybackState) {
        switch state {
        case .playing:
            if currentTrackStartTime == nil {
                currentTrackStartTime = Date()
            }
            
        case .paused, .stopped:
            scrobbleTimer?.invalidate()
            
        default:
            break
        }
    }
    
    private func handlePositionChange(_ position: TimeInterval) {
        // Check if we should scrobble
        guard let player = playerControl,
              let track = player.currentTrack,
              !hasScrobbled,
              player.duration > 30 else { return } // Last.fm requires minimum 30 seconds
        
        let percentage = position / player.duration
        if percentage >= scrobbleAt {
            scrobbleTrack(track)
        }
    }
    
    private func scheduleScrobble(for track: Track) {
        guard let player = playerControl,
              player.duration > 30 else { return }
        
        let scrobbleTime = player.duration * scrobbleAt
        scrobbleTimer = Timer.scheduledTimer(withTimeInterval: scrobbleTime, repeats: false) { [weak self] _ in
            self?.scrobbleTrack(track)
        }
    }
    
    private func updateNowPlaying(_ track: Track?) {
        guard isAuthenticated else { return }
        
        // This would make an API call to Last.fm
        host?.log("Updating now playing: \(track?.displayTitle ?? "None")", level: .info, from: metadata.identifier)
    }
    
    private func scrobbleTrack(_ track: Track) {
        guard isAuthenticated, !hasScrobbled else { return }
        
        hasScrobbled = true
        totalScrobbles += 1
        lastScrobbleDate = Date()
        
        // This would make an API call to Last.fm
        host?.log("Scrobbled: \(track.displayTitle) by \(track.displayArtist)", level: .info, from: metadata.identifier)
        
        // Send notification
        if let uiService = host?.getService(UIService.self) {
            uiService.showAlert(
                title: "Scrobbled to Last.fm",
                message: "\(track.displayTitle) by \(track.displayArtist)"
            )
        }
        
        saveSettings()
    }
    
    private func loveTrack(_ track: Track) {
        guard isAuthenticated else { return }
        
        // This would make an API call to Last.fm
        host?.log("Loved track: \(track.displayTitle)", level: .info, from: metadata.identifier)
    }
    
    private func viewTrackOnLastFM(_ track: Track) {
        let artist = track.artist?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let title = track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "https://last.fm/music/\(artist)/_/\(title)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func toggleScrobbling() {
        isEnabled.toggle()
        saveSettings()
    }
    
    private func showAuthenticationWindow() {
        // This would show an authentication window
        if let uiService = host?.getService(UIService.self) {
            Task {
                if let username = await uiService.requestUserInput(
                    prompt: "Enter your Last.fm username:",
                    defaultValue: nil
                ) {
                    self.username = username
                    self.sessionKey = "mock_session_key" // Would get real key from API
                    self.isEnabled = true
                    saveSettings()
                }
            }
        }
    }
    
    private func showStatistics() {
        if let uiService = host?.getService(UIService.self),
           let view = mainView() {
            uiService.showWindow(
                content: view,
                title: "Last.fm Statistics",
                size: CGSize(width: 400, height: 300)
            )
        }
    }
    
    private func startMonitoring() {
        // Subscribe to player events
        if let host = host {
            host.subscribeToMessages(from: nil) { [weak self] message in
                if message.type == "player.event",
                   let event = message.payload as? PlayerEvent {
                    self?.handlePlayerEvent(event)
                }
            }
            .store(in: &cancellables)
        }
    }
    
    private func stopMonitoring() {
        cancellables.removeAll()
        scrobbleTimer?.invalidate()
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "lastfm_settings"),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            username = settings.username
            sessionKey = settings.sessionKey
            isEnabled = settings.isEnabled
            scrobbleAt = settings.scrobbleAt
            totalScrobbles = settings.totalScrobbles
            lastScrobbleDate = settings.lastScrobbleDate
        }
    }
    
    private func saveSettings() {
        let settings = Settings(
            username: username,
            sessionKey: sessionKey,
            isEnabled: isEnabled,
            scrobbleAt: scrobbleAt,
            totalScrobbles: totalScrobbles,
            lastScrobbleDate: lastScrobbleDate
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "lastfm_settings")
        }
    }
    
    // MARK: - Settings
    
    private struct Settings: Codable {
        let username: String
        let sessionKey: String
        let isEnabled: Bool
        let scrobbleAt: Double
        let totalScrobbles: Int
        let lastScrobbleDate: Date?
    }
}