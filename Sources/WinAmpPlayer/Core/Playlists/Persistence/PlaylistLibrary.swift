//
//  PlaylistLibrary.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Central playlist management system.
//

import Foundation
import Combine

/// Playlist folder for organization
struct PlaylistFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var playlistIds: [UUID]
    var subfolders: [PlaylistFolder]
    var iconName: String?
    var color: String?
    
    init(name: String, playlistIds: [UUID] = [], subfolders: [PlaylistFolder] = []) {
        self.id = UUID()
        self.name = name
        self.playlistIds = playlistIds
        self.subfolders = subfolders
        self.iconName = nil
        self.color = nil
    }
}

/// Library settings stored in UserDefaults
struct LibrarySettings: Codable {
    var currentPlaylistId: UUID?
    var recentPlaylistIds: [UUID]
    var favoritePlaylistIds: [UUID]
    var defaultNewPlaylistFolder: UUID?
    var sortOrder: PlaylistSortOrder
    var showSystemPlaylists: Bool
    var autoSaveEnabled: Bool
    var maxRecentPlaylists: Int
    
    static let `default` = LibrarySettings(
        currentPlaylistId: nil,
        recentPlaylistIds: [],
        favoritePlaylistIds: [],
        defaultNewPlaylistFolder: nil,
        sortOrder: .dateModified,
        showSystemPlaylists: true,
        autoSaveEnabled: true,
        maxRecentPlaylists: 10
    )
}

/// Sort order for playlists
enum PlaylistSortOrder: String, Codable, CaseIterable {
    case name
    case dateCreated
    case dateModified
    case trackCount
    case duration
    case playCount
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .dateCreated: return "Date Created"
        case .dateModified: return "Date Modified"
        case .trackCount: return "Track Count"
        case .duration: return "Duration"
        case .playCount: return "Play Count"
        }
    }
}

/// Central playlist management
class PlaylistLibrary: ObservableObject {
    // MARK: - Properties
    
    /// Shared instance
    static let shared = PlaylistLibrary()
    
    /// All playlists in the library
    @Published private(set) var playlists: [Playlist] = []
    
    /// Currently active playlist
    @Published var currentPlaylist: Playlist? {
        didSet {
            if let playlist = currentPlaylist {
                settings.currentPlaylistId = playlist.id
                addToRecent(playlist)
                saveSettings()
                
                // Enable auto-save if needed
                if settings.autoSaveEnabled {
                    PlaylistStore.shared.enableAutoSave(for: playlist)
                }
            } else {
                settings.currentPlaylistId = nil
                saveSettings()
                PlaylistStore.shared.disableAutoSave()
            }
        }
    }
    
    /// Playlist organization folders
    @Published var folders: [PlaylistFolder] = []
    
    /// Library settings
    @Published var settings: LibrarySettings {
        didSet {
            saveSettings()
        }
    }
    
    /// System playlists (built-in)
    private(set) var systemPlaylists: [Playlist] = []
    
    /// Default "Now Playing" playlist
    private(set) lazy var nowPlayingPlaylist: Playlist = {
        let playlist = Playlist(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Now Playing",
            tracks: []
        )
        playlist.metadata.description = "Currently playing tracks"
        return playlist
    }()
    
    /// Default "Queue" playlist
    private(set) lazy var queuePlaylist: Playlist = {
        let playlist = Playlist(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Queue",
            tracks: []
        )
        playlist.metadata.description = "Queued tracks"
        return playlist
    }()
    
    /// Recently added tracks playlist
    private(set) lazy var recentlyAddedPlaylist: Playlist = {
        let playlist = Playlist(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Recently Added",
            tracks: [],
            metadata: PlaylistMetadata(
                description: "Tracks added in the last 30 days",
                isSmartPlaylist: true,
                smartRules: [
                    SmartPlaylistRule(
                        ruleType: .dateAdded(Date().addingTimeInterval(-30 * 24 * 60 * 60), .greaterThan),
                        isInclude: true
                    )
                ]
            )
        )
        return playlist
    }()
    
    /// Most played tracks playlist
    private(set) lazy var mostPlayedPlaylist: Playlist = {
        let playlist = Playlist(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "Most Played",
            tracks: [],
            metadata: PlaylistMetadata(
                description: "Your most played tracks",
                isSmartPlaylist: true,
                smartRules: [
                    SmartPlaylistRule(
                        ruleType: .playCount(5, .greaterThan),
                        isInclude: true
                    )
                ]
            )
        )
        return playlist
    }()
    
    /// Playlist change publisher
    let playlistsChanged = PassthroughSubject<Void, Never>()
    
    /// Storage reference
    private let store = PlaylistStore.shared
    
    /// User defaults for settings
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private let settingsKey = "PlaylistLibrarySettings"
    private let foldersKey = "PlaylistLibraryFolders"
    
    // MARK: - Initialization
    
    private init() {
        // Load settings
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(LibrarySettings.self, from: data) {
            self.settings = settings
        } else {
            self.settings = .default
        }
        
        // Load folders
        if let data = userDefaults.data(forKey: foldersKey),
           let folders = try? JSONDecoder().decode([PlaylistFolder].self, from: data) {
            self.folders = folders
        }
        
        // Initialize system playlists
        systemPlaylists = [
            nowPlayingPlaylist,
            queuePlaylist,
            recentlyAddedPlaylist,
            mostPlayedPlaylist
        ]
        
        // Load all playlists
        loadAllPlaylists()
        
        // Restore current playlist
        if let currentId = settings.currentPlaylistId {
            currentPlaylist = findPlaylist(by: currentId)
        }
    }
    
    // MARK: - Playlist Management
    
    /// Create a new playlist
    func createPlaylist(name: String, tracks: [Track] = [], inFolder: UUID? = nil) -> Playlist {
        let playlist = Playlist(name: name, tracks: tracks)
        
        // Add to library
        playlists.append(playlist)
        
        // Add to folder if specified
        if let folderId = inFolder ?? settings.defaultNewPlaylistFolder {
            addToFolder(playlist: playlist, folderId: folderId)
        }
        
        // Save immediately
        do {
            try store.save(playlist)
        } catch {
            print("Failed to save new playlist: \(error)")
        }
        
        playlistsChanged.send()
        return playlist
    }
    
    /// Duplicate a playlist
    func duplicatePlaylist(_ playlist: Playlist) -> Playlist {
        let duplicatedTracks = playlist.tracks
        let newPlaylist = Playlist(
            name: "\(playlist.name) Copy",
            tracks: duplicatedTracks,
            metadata: playlist.metadata
        )
        
        playlists.append(newPlaylist)
        
        // Save immediately
        do {
            try store.save(newPlaylist)
        } catch {
            print("Failed to save duplicated playlist: \(error)")
        }
        
        playlistsChanged.send()
        return newPlaylist
    }
    
    /// Delete a playlist
    func deletePlaylist(_ playlist: Playlist) {
        guard !isSystemPlaylist(playlist) else {
            print("Cannot delete system playlist")
            return
        }
        
        // Remove from library
        playlists.removeAll { $0.id == playlist.id }
        
        // Remove from folders
        removeFromAllFolders(playlistId: playlist.id)
        
        // Remove from recent and favorites
        settings.recentPlaylistIds.removeAll { $0 == playlist.id }
        settings.favoritePlaylistIds.removeAll { $0 == playlist.id }
        
        // Clear current if it was deleted
        if currentPlaylist?.id == playlist.id {
            currentPlaylist = nil
        }
        
        // Delete from disk
        do {
            try store.delete(playlistId: playlist.id)
        } catch {
            print("Failed to delete playlist from disk: \(error)")
        }
        
        playlistsChanged.send()
    }
    
    /// Rename a playlist
    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        playlist.name = newName
        playlist.metadata.modifiedDate = Date()
        
        // Save changes
        do {
            try store.save(playlist)
        } catch {
            print("Failed to save renamed playlist: \(error)")
        }
        
        playlistsChanged.send()
    }
    
    /// Save playlist changes
    func savePlaylist(_ playlist: Playlist) {
        do {
            try store.save(playlist)
            playlistsChanged.send()
        } catch {
            print("Failed to save playlist: \(error)")
        }
    }
    
    /// Find playlist by ID
    func findPlaylist(by id: UUID) -> Playlist? {
        // Check regular playlists
        if let playlist = playlists.first(where: { $0.id == id }) {
            return playlist
        }
        
        // Check system playlists
        if settings.showSystemPlaylists {
            return systemPlaylists.first(where: { $0.id == id })
        }
        
        return nil
    }
    
    /// Check if playlist is a system playlist
    func isSystemPlaylist(_ playlist: Playlist) -> Bool {
        systemPlaylists.contains(where: { $0.id == playlist.id })
    }
    
    // MARK: - Recent Playlists
    
    /// Get recently played playlists
    var recentPlaylists: [Playlist] {
        settings.recentPlaylistIds.compactMap { findPlaylist(by: $0) }
    }
    
    /// Add playlist to recent
    private func addToRecent(_ playlist: Playlist) {
        // Don't add system playlists to recent
        guard !isSystemPlaylist(playlist) else { return }
        
        // Remove if already exists
        settings.recentPlaylistIds.removeAll { $0 == playlist.id }
        
        // Add to front
        settings.recentPlaylistIds.insert(playlist.id, at: 0)
        
        // Limit size
        if settings.recentPlaylistIds.count > settings.maxRecentPlaylists {
            settings.recentPlaylistIds = Array(settings.recentPlaylistIds.prefix(settings.maxRecentPlaylists))
        }
    }
    
    // MARK: - Favorite Playlists
    
    /// Get favorite playlists
    var favoritePlaylists: [Playlist] {
        settings.favoritePlaylistIds.compactMap { findPlaylist(by: $0) }
    }
    
    /// Toggle favorite status
    func toggleFavorite(_ playlist: Playlist) {
        if settings.favoritePlaylistIds.contains(playlist.id) {
            settings.favoritePlaylistIds.removeAll { $0 == playlist.id }
        } else {
            settings.favoritePlaylistIds.append(playlist.id)
        }
    }
    
    /// Check if playlist is favorite
    func isFavorite(_ playlist: Playlist) -> Bool {
        settings.favoritePlaylistIds.contains(playlist.id)
    }
    
    // MARK: - Folder Management
    
    /// Create a new folder
    func createFolder(name: String, parent: UUID? = nil) -> PlaylistFolder {
        let folder = PlaylistFolder(name: name)
        
        if let parentId = parent {
            // Add as subfolder
            addSubfolder(folder, to: parentId)
        } else {
            // Add to root
            folders.append(folder)
        }
        
        saveFolders()
        return folder
    }
    
    /// Add playlist to folder
    func addToFolder(playlist: Playlist, folderId: UUID) {
        func addToFolder(_ folders: inout [PlaylistFolder], playlistId: UUID, targetId: UUID) -> Bool {
            for i in 0..<folders.count {
                if folders[i].id == targetId {
                    if !folders[i].playlistIds.contains(playlistId) {
                        folders[i].playlistIds.append(playlistId)
                    }
                    return true
                } else if addToFolder(&folders[i].subfolders, playlistId: playlistId, targetId: targetId) {
                    return true
                }
            }
            return false
        }
        
        _ = addToFolder(&folders, playlistId: playlist.id, targetId: folderId)
        saveFolders()
    }
    
    /// Remove playlist from all folders
    private func removeFromAllFolders(playlistId: UUID) {
        func removeFromFolders(_ folders: inout [PlaylistFolder], playlistId: UUID) {
            for i in 0..<folders.count {
                folders[i].playlistIds.removeAll { $0 == playlistId }
                removeFromFolders(&folders[i].subfolders, playlistId: playlistId)
            }
        }
        
        removeFromFolders(&folders, playlistId: playlistId)
        saveFolders()
    }
    
    /// Add subfolder
    private func addSubfolder(_ subfolder: PlaylistFolder, to parentId: UUID) {
        func addSubfolder(_ folders: inout [PlaylistFolder], subfolder: PlaylistFolder, targetId: UUID) -> Bool {
            for i in 0..<folders.count {
                if folders[i].id == targetId {
                    folders[i].subfolders.append(subfolder)
                    return true
                } else if addSubfolder(&folders[i].subfolders, subfolder: subfolder, targetId: targetId) {
                    return true
                }
            }
            return false
        }
        
        _ = addSubfolder(&folders, subfolder: subfolder, targetId: parentId)
        saveFolders()
    }
    
    /// Get playlists in folder
    func getPlaylists(in folder: PlaylistFolder) -> [Playlist] {
        folder.playlistIds.compactMap { findPlaylist(by: $0) }
    }
    
    /// Get all playlists (sorted)
    var sortedPlaylists: [Playlist] {
        let allPlaylists = settings.showSystemPlaylists ? playlists + systemPlaylists : playlists
        
        return allPlaylists.sorted { playlist1, playlist2 in
            switch settings.sortOrder {
            case .name:
                return playlist1.name < playlist2.name
            case .dateCreated:
                return playlist1.metadata.createdDate > playlist2.metadata.createdDate
            case .dateModified:
                return playlist1.metadata.modifiedDate > playlist2.metadata.modifiedDate
            case .trackCount:
                return playlist1.tracks.count > playlist2.tracks.count
            case .duration:
                return playlist1.totalDuration > playlist2.totalDuration
            case .playCount:
                return playlist1.metadata.totalPlayCount > playlist2.metadata.totalPlayCount
            }
        }
    }
    
    // MARK: - Smart Playlist Updates
    
    /// Update all smart playlists
    func updateSmartPlaylists(with allTracks: [Track]) {
        let smartPlaylists = (playlists + systemPlaylists).filter { $0.metadata.isSmartPlaylist }
        
        for playlist in smartPlaylists {
            playlist.updateSmartPlaylist(from: allTracks)
            
            // Save if it's not a system playlist
            if !isSystemPlaylist(playlist) {
                savePlaylist(playlist)
            }
        }
    }
    
    // MARK: - Import/Export
    
    /// Import playlist from file
    func importPlaylist(from url: URL) throws -> Playlist {
        let playlist = try store.importPlaylist(from: url)
        playlists.append(playlist)
        
        // Save to library
        try store.save(playlist)
        
        playlistsChanged.send()
        return playlist
    }
    
    /// Export playlist to file
    func exportPlaylist(_ playlist: Playlist, to url: URL, format: ExportFormat) throws {
        try store.export(playlist, to: url, format: format)
    }
    
    // MARK: - Persistence
    
    /// Load all playlists from disk
    private func loadAllPlaylists() {
        do {
            playlists = try store.loadAll()
        } catch {
            print("Failed to load playlists: \(error)")
            playlists = []
        }
    }
    
    /// Save settings to UserDefaults
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    /// Save folders to UserDefaults
    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            userDefaults.set(data, forKey: foldersKey)
        }
    }
    
    /// Reload library from disk
    func reload() {
        loadAllPlaylists()
        playlistsChanged.send()
    }
    
    // MARK: - Search
    
    /// Search playlists by name
    func searchPlaylists(query: String) -> [Playlist] {
        guard !query.isEmpty else { return sortedPlaylists }
        
        let lowercasedQuery = query.lowercased()
        return sortedPlaylists.filter { playlist in
            playlist.name.lowercased().contains(lowercasedQuery) ||
            (playlist.metadata.description?.lowercased().contains(lowercasedQuery) ?? false) ||
            playlist.metadata.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    /// Search for playlists containing specific track
    func playlistsContaining(track: Track) -> [Playlist] {
        (playlists + (settings.showSystemPlaylists ? systemPlaylists : [])).filter { playlist in
            playlist.tracks.contains { $0.id == track.id }
        }
    }
    
    // MARK: - Statistics
    
    /// Get library statistics
    var libraryStatistics: LibraryStatistics {
        let allPlaylists = playlists + (settings.showSystemPlaylists ? systemPlaylists : [])
        let allTracks = Set(allPlaylists.flatMap { $0.tracks })
        
        return LibraryStatistics(
            totalPlaylists: playlists.count,
            totalTracks: allTracks.count,
            totalDuration: allTracks.reduce(0) { $0 + $1.duration },
            totalFileSize: allTracks.compactMap { $0.fileSize }.reduce(0, +),
            averagePlaylistSize: playlists.isEmpty ? 0 : playlists.reduce(0) { $0 + $1.tracks.count } / playlists.count,
            mostCommonGenre: findMostCommonGenre(in: Array(allTracks)),
            storageUsed: (try? store.calculateStorageUsed()) ?? 0
        )
    }
    
    /// Find most common genre
    private func findMostCommonGenre(in tracks: [Track]) -> String? {
        let genres = tracks.compactMap { $0.genre }
        guard !genres.isEmpty else { return nil }
        
        let genreCounts = genres.reduce(into: [:]) { counts, genre in
            counts[genre, default: 0] += 1
        }
        
        return genreCounts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Library Statistics

struct LibraryStatistics {
    let totalPlaylists: Int
    let totalTracks: Int
    let totalDuration: TimeInterval
    let totalFileSize: Int64
    let averagePlaylistSize: Int
    let mostCommonGenre: String?
    let storageUsed: Int64
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFileSize)
    }
    
    var formattedStorageUsed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: storageUsed)
    }
}