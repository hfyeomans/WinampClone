//
//  DiscordPresence.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Example general plugin: Discord Rich Presence integration
//

import Foundation
import SwiftUI

/// Discord Rich Presence plugin
public final class DiscordPresencePlugin: BaseGeneralPlugin {
    
    // Configuration
    private var isEnabled: Bool = true
    private var showTrackDetails: Bool = true
    private var showElapsedTime: Bool = true
    private var showAlbumArt: Bool = false
    
    // State
    private var startTime: Date?
    private var currentActivity: DiscordActivity?
    
    public override var requiredCapabilities: GeneralPluginCapabilities {
        [.playerControl, .networkAccess, .preferencesAccess]
    }
    
    public override var menuItems: [PluginMenuItem] {
        [
            PluginMenuItem(
                id: "discord_toggle",
                title: isEnabled ? "Disable Discord Presence" : "Enable Discord Presence",
                action: { [weak self] in self?.togglePresence() }
            ),
            PluginMenuItem(
                id: "discord_settings",
                title: "Discord Presence Settings...",
                action: { [weak self] in self?.showSettings() }
            )
        ]
    }
    
    public init() {
        let metadata = PluginMetadata(
            identifier: "com.winamp.plugin.discord",
            name: "Discord Rich Presence",
            type: .general,
            version: "1.0.0",
            author: "WinAmp Team",
            description: "Show what you're listening to on Discord",
            website: URL(string: "https://discord.com"),
            iconName: "discord_icon"
        )
        
        super.init(metadata: metadata)
    }
    
    public override func pluginDidActivate() {
        loadSettings()
        if isEnabled {
            connectToDiscord()
        }
    }
    
    public override func pluginWillDeactivate() {
        disconnectFromDiscord()
        saveSettings()
    }
    
    public override func handlePlayerEvent(_ event: PlayerEvent) {
        guard isEnabled else { return }
        
        switch event {
        case .trackChanged(let track):
            updatePresence(for: track)
            
        case .playbackStateChanged(let state):
            handlePlaybackStateChange(state)
            
        case .positionChanged:
            // Update timestamps if needed
            break
            
        default:
            break
        }
    }
    
    public override func mainView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 20) {
                // Status
                HStack {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    Text(isEnabled ? "Discord Presence Active" : "Discord Presence Inactive")
                        .font(.headline)
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Discord Presence", isOn: Binding(
                        get: { self.isEnabled },
                        set: { 
                            self.isEnabled = $0
                            if $0 {
                                self.connectToDiscord()
                            } else {
                                self.disconnectFromDiscord()
                            }
                            self.saveSettings()
                        }
                    ))
                    
                    Toggle("Show track details", isOn: Binding(
                        get: { self.showTrackDetails },
                        set: { self.showTrackDetails = $0; self.saveSettings(); self.refreshPresence() }
                    ))
                    .disabled(!isEnabled)
                    
                    Toggle("Show elapsed time", isOn: Binding(
                        get: { self.showElapsedTime },
                        set: { self.showElapsedTime = $0; self.saveSettings(); self.refreshPresence() }
                    ))
                    .disabled(!isEnabled)
                    
                    Toggle("Show album art", isOn: Binding(
                        get: { self.showAlbumArt },
                        set: { self.showAlbumArt = $0; self.saveSettings(); self.refreshPresence() }
                    ))
                    .disabled(!isEnabled)
                }
                
                Divider()
                
                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.headline)
                    
                    if let activity = currentActivity {
                        DiscordActivityPreview(activity: activity)
                    } else {
                        Text("No activity")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 400, height: 350)
        )
    }
    
    // MARK: - Private Methods
    
    private func connectToDiscord() {
        // In a real implementation, this would connect to Discord IPC
        host?.log("Connecting to Discord...", level: .info, from: metadata.identifier)
        
        // Update with current track if playing
        if let track = playerControl?.currentTrack {
            updatePresence(for: track)
        }
    }
    
    private func disconnectFromDiscord() {
        // Clear presence
        currentActivity = nil
        host?.log("Disconnected from Discord", level: .info, from: metadata.identifier)
    }
    
    private func updatePresence(for track: Track?) {
        guard isEnabled else { return }
        
        if let track = track {
            startTime = Date()
            
            var activity = DiscordActivity(
                details: showTrackDetails ? track.displayTitle : "Listening to music",
                state: showTrackDetails ? "by \(track.displayArtist)" : nil,
                timestamps: showElapsedTime ? DiscordTimestamps(start: startTime!) : nil,
                assets: DiscordAssets(
                    largeImage: "winamp_icon",
                    largeText: "WinAmp Player",
                    smallImage: playerControl?.playbackState == .playing ? "play" : "pause",
                    smallText: playerControl?.playbackState == .playing ? "Playing" : "Paused"
                )
            )
            
            currentActivity = activity
            sendActivityUpdate(activity)
        } else {
            currentActivity = nil
            clearPresence()
        }
    }
    
    private func handlePlaybackStateChange(_ state: PlaybackState) {
        guard let activity = currentActivity else { return }
        
        var updatedActivity = activity
        updatedActivity.assets.smallImage = state == .playing ? "play" : "pause"
        updatedActivity.assets.smallText = state == .playing ? "Playing" : "Paused"
        
        if state == .paused {
            updatedActivity.timestamps = nil // Don't show time when paused
        } else if state == .playing && showElapsedTime {
            updatedActivity.timestamps = DiscordTimestamps(start: startTime ?? Date())
        }
        
        currentActivity = updatedActivity
        sendActivityUpdate(updatedActivity)
    }
    
    private func refreshPresence() {
        if let track = playerControl?.currentTrack {
            updatePresence(for: track)
        }
    }
    
    private func sendActivityUpdate(_ activity: DiscordActivity) {
        // In a real implementation, this would send to Discord IPC
        host?.log("Updated Discord presence: \(activity.details)", level: .debug, from: metadata.identifier)
    }
    
    private func clearPresence() {
        // In a real implementation, this would clear Discord presence
        host?.log("Cleared Discord presence", level: .debug, from: metadata.identifier)
    }
    
    private func togglePresence() {
        isEnabled.toggle()
        if isEnabled {
            connectToDiscord()
        } else {
            disconnectFromDiscord()
        }
        saveSettings()
    }
    
    private func showSettings() {
        if let uiService = host?.getService(UIService.self),
           let view = mainView() {
            uiService.showWindow(
                content: view,
                title: "Discord Presence Settings",
                size: CGSize(width: 400, height: 350)
            )
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "discord_presence_settings"),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            isEnabled = settings.isEnabled
            showTrackDetails = settings.showTrackDetails
            showElapsedTime = settings.showElapsedTime
            showAlbumArt = settings.showAlbumArt
        }
    }
    
    private func saveSettings() {
        let settings = Settings(
            isEnabled: isEnabled,
            showTrackDetails: showTrackDetails,
            showElapsedTime: showElapsedTime,
            showAlbumArt: showAlbumArt
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "discord_presence_settings")
        }
    }
    
    // MARK: - Types
    
    private struct Settings: Codable {
        let isEnabled: Bool
        let showTrackDetails: Bool
        let showElapsedTime: Bool
        let showAlbumArt: Bool
    }
    
    private struct DiscordActivity {
        var details: String
        var state: String?
        var timestamps: DiscordTimestamps?
        var assets: DiscordAssets
    }
    
    private struct DiscordTimestamps {
        let start: Date
        var end: Date?
    }
    
    private struct DiscordAssets {
        var largeImage: String
        var largeText: String
        var smallImage: String
        var smallText: String
    }
}

// MARK: - Discord Activity Preview

private struct DiscordActivityPreview: View {
    let activity: DiscordPresencePlugin.DiscordActivity
    
    var body: some View {
        HStack(spacing: 12) {
            // Large image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("WinAmp Player")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(activity.details)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                if let state = activity.state {
                    Text(state)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let timestamps = activity.timestamps {
                    Text(formatElapsedTime(since: timestamps.start))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatElapsedTime(since start: Date) -> String {
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d elapsed", minutes, seconds)
    }
}