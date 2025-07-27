//
//  GeneralPlugin.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Protocol for general purpose plugins that extend WinAmp functionality
//

import Foundation
import SwiftUI
import Combine

// MARK: - Player Events

/// Events that general plugins can listen to
public enum PlayerEvent {
    case trackChanged(Track?)
    case playbackStateChanged(PlaybackState)
    case positionChanged(TimeInterval)
    case volumeChanged(Float)
    case playlistChanged(Playlist?)
    case equalizerChanged([Float])
    case skinChanged(String)
    case windowOpened(String)
    case windowClosed(String)
    case applicationLaunched
    case applicationWillTerminate
}

/// Playback state
public enum PlaybackState {
    case stopped
    case playing
    case paused
    case loading
    case seeking
}

// MARK: - Plugin Capabilities

/// Capabilities that general plugins can request
public struct GeneralPluginCapabilities: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let playerControl = GeneralPluginCapabilities(rawValue: 1 << 0)
    public static let playlistAccess = GeneralPluginCapabilities(rawValue: 1 << 1)
    public static let fileAccess = GeneralPluginCapabilities(rawValue: 1 << 2)
    public static let networkAccess = GeneralPluginCapabilities(rawValue: 1 << 3)
    public static let uiExtension = GeneralPluginCapabilities(rawValue: 1 << 4)
    public static let mediaLibraryAccess = GeneralPluginCapabilities(rawValue: 1 << 5)
    public static let notificationAccess = GeneralPluginCapabilities(rawValue: 1 << 6)
    public static let preferencesAccess = GeneralPluginCapabilities(rawValue: 1 << 7)
    
    public static let basic: GeneralPluginCapabilities = [.playerControl, .playlistAccess]
    public static let full: GeneralPluginCapabilities = [
        .playerControl, .playlistAccess, .fileAccess,
        .networkAccess, .uiExtension, .mediaLibraryAccess,
        .notificationAccess, .preferencesAccess
    ]
}

// MARK: - General Plugin Protocol

/// Protocol for general purpose plugins
public protocol GeneralPlugin: WAPlugin {
    /// Required capabilities
    var requiredCapabilities: GeneralPluginCapabilities { get }
    
    /// Menu items to add to the application
    var menuItems: [PluginMenuItem] { get }
    
    /// Toolbar items to add
    var toolbarItems: [PluginToolbarItem] { get }
    
    /// Status bar item (if any)
    var statusBarView: AnyView? { get }
    
    /// Called when plugin is activated
    func pluginDidActivate()
    
    /// Called when plugin is about to deactivate
    func pluginWillDeactivate()
    
    /// Handle player events
    func handlePlayerEvent(_ event: PlayerEvent)
    
    /// Get main view (for plugins that provide UI)
    func mainView() -> AnyView?
    
    /// Handle file drop
    func handleFileDrop(_ urls: [URL]) -> Bool
    
    /// Provide context menu items for tracks
    func contextMenuItems(for track: Track) -> [PluginMenuItem]
    
    /// Export data (for backup/sync plugins)
    func exportData() async throws -> Data?
    
    /// Import data
    func importData(_ data: Data) async throws
}

// MARK: - Menu Items

/// Menu item provided by a plugin
public struct PluginMenuItem {
    public let id: String
    public let title: String
    public let keyEquivalent: String?
    public let action: () -> Void
    public let isEnabled: () -> Bool
    public let submenu: [PluginMenuItem]?
    
    public init(
        id: String,
        title: String,
        keyEquivalent: String? = nil,
        action: @escaping () -> Void,
        isEnabled: @escaping () -> Bool = { true },
        submenu: [PluginMenuItem]? = nil
    ) {
        self.id = id
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.action = action
        self.isEnabled = isEnabled
        self.submenu = submenu
    }
}

// MARK: - Toolbar Items

/// Toolbar item provided by a plugin
public struct PluginToolbarItem {
    public let id: String
    public let label: String
    public let icon: Image
    public let action: () -> Void
    public let isEnabled: () -> Bool
    
    public init(
        id: String,
        label: String,
        icon: Image,
        action: @escaping () -> Void,
        isEnabled: @escaping () -> Bool = { true }
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.action = action
        self.isEnabled = isEnabled
    }
}

// MARK: - Player Control Protocol

/// Protocol for controlling the player
public protocol PlayerControl {
    /// Current track
    var currentTrack: Track? { get }
    
    /// Current playlist
    var currentPlaylist: Playlist? { get }
    
    /// Playback state
    var playbackState: PlaybackState { get }
    
    /// Current position in seconds
    var currentPosition: TimeInterval { get }
    
    /// Track duration
    var duration: TimeInterval { get }
    
    /// Volume (0.0 - 1.0)
    var volume: Float { get set }
    
    /// Play
    func play()
    
    /// Pause
    func pause()
    
    /// Stop
    func stop()
    
    /// Next track
    func next()
    
    /// Previous track
    func previous()
    
    /// Seek to position
    func seek(to position: TimeInterval)
    
    /// Load and play a track
    func loadTrack(_ track: Track)
    
    /// Load and play a URL
    func loadURL(_ url: URL)
}

// MARK: - Media Library Access

/// Protocol for accessing the media library
public protocol MediaLibraryAccess {
    /// Get all tracks
    func getAllTracks() async -> [Track]
    
    /// Search tracks
    func searchTracks(query: String) async -> [Track]
    
    /// Get track by ID
    func getTrack(id: String) async -> Track?
    
    /// Add track to library
    func addTrack(_ track: Track) async throws
    
    /// Update track metadata
    func updateTrack(_ track: Track) async throws
    
    /// Delete track from library
    func deleteTrack(id: String) async throws
    
    /// Get all playlists
    func getAllPlaylists() async -> [Playlist]
    
    /// Create playlist
    func createPlaylist(name: String) async throws -> Playlist
    
    /// Update playlist
    func updatePlaylist(_ playlist: Playlist) async throws
    
    /// Delete playlist
    func deletePlaylist(id: String) async throws
}

// MARK: - Base General Plugin

/// Base implementation for general plugins
open class BaseGeneralPlugin: GeneralPlugin {
    // WAPlugin requirements
    public let metadata: PluginMetadata
    public private(set) var state: PluginState = .unloaded
    private let stateSubject = CurrentValueSubject<PluginState, Never>(.unloaded)
    public var statePublisher: AnyPublisher<PluginState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    // General plugin specifics
    public var requiredCapabilities: GeneralPluginCapabilities { .basic }
    public var menuItems: [PluginMenuItem] { [] }
    public var toolbarItems: [PluginToolbarItem] { [] }
    public var statusBarView: AnyView? { nil }
    
    protected weak var host: PluginHost?
    protected var playerControl: PlayerControl?
    protected var mediaLibrary: MediaLibraryAccess?
    
    public init(metadata: PluginMetadata) {
        self.metadata = metadata
    }
    
    // WAPlugin methods
    public func initialize(host: PluginHost) async throws {
        self.host = host
        
        // Request services
        playerControl = host.getService(PlayerControl.self)
        mediaLibrary = host.getService(MediaLibraryAccess.self)
        
        // Verify capabilities
        for capability in requiredCapabilities.toStrings() {
            if !host.requestCapability(capability) {
                throw PluginError.missingCapability(capability)
            }
        }
        
        state = .loaded
        stateSubject.send(.loaded)
    }
    
    public func activate() async throws {
        state = .active
        stateSubject.send(.active)
        pluginDidActivate()
    }
    
    public func deactivate() async throws {
        pluginWillDeactivate()
        state = .loaded
        stateSubject.send(.loaded)
    }
    
    public func shutdown() async {
        state = .unloaded
        stateSubject.send(.unloaded)
    }
    
    public func configurationView() -> AnyView? {
        nil // Override in subclasses
    }
    
    public func exportSettings() -> Data? {
        nil // Override in subclasses
    }
    
    public func importSettings(_ data: Data) throws {
        // Override in subclasses
    }
    
    public func handleMessage(_ message: PluginMessage) {
        // Override in subclasses
    }
    
    // General plugin methods
    public func pluginDidActivate() {
        // Override in subclasses
    }
    
    public func pluginWillDeactivate() {
        // Override in subclasses
    }
    
    public func handlePlayerEvent(_ event: PlayerEvent) {
        // Override in subclasses
    }
    
    public func mainView() -> AnyView? {
        nil // Override in subclasses
    }
    
    public func handleFileDrop(_ urls: [URL]) -> Bool {
        false // Override in subclasses
    }
    
    public func contextMenuItems(for track: Track) -> [PluginMenuItem] {
        [] // Override in subclasses
    }
    
    public func exportData() async throws -> Data? {
        nil // Override in subclasses
    }
    
    public func importData(_ data: Data) async throws {
        // Override in subclasses
    }
}

// MARK: - Helper Extensions

extension GeneralPluginCapabilities {
    func toStrings() -> [String] {
        var capabilities: [String] = []
        
        if contains(.playerControl) { capabilities.append("player_control") }
        if contains(.playlistAccess) { capabilities.append("playlist_access") }
        if contains(.fileAccess) { capabilities.append("file_access") }
        if contains(.networkAccess) { capabilities.append("network_access") }
        if contains(.uiExtension) { capabilities.append("ui_extension") }
        if contains(.mediaLibraryAccess) { capabilities.append("media_library_access") }
        if contains(.notificationAccess) { capabilities.append("notification_access") }
        if contains(.preferencesAccess) { capabilities.append("preferences_access") }
        
        return capabilities
    }
}