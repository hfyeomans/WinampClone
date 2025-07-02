//
//  PlaylistStore.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Main storage interface for playlist persistence.
//

import Foundation
import Combine

/// Errors that can occur during playlist storage operations
enum PlaylistStoreError: LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed
    case migrationFailed(String)
    case fileSystemError(Error)
    case versionMismatch(current: Int, stored: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid playlist storage URL"
        case .encodingFailed:
            return "Failed to encode playlist data"
        case .decodingFailed:
            return "Failed to decode playlist data"
        case .migrationFailed(let reason):
            return "Playlist migration failed: \(reason)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .versionMismatch(let current, let stored):
            return "Version mismatch: current version \(current), stored version \(stored)"
        }
    }
}

/// Versioned playlist container for migration support
struct VersionedPlaylist: Codable {
    let version: Int
    let playlist: Playlist
    let metadata: PlaylistStoreMetadata
    
    enum CodingKeys: String, CodingKey {
        case version
        case playlist
        case metadata
    }
}

/// Metadata for playlist storage
struct PlaylistStoreMetadata: Codable {
    let savedDate: Date
    let appVersion: String
    let systemVersion: String
    let checksum: String?
    
    init(savedDate: Date = Date(), checksum: String? = nil) {
        self.savedDate = savedDate
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.checksum = checksum
    }
}

/// Main storage interface for playlist persistence
class PlaylistStore: ObservableObject {
    // MARK: - Properties
    
    /// Current storage version
    static let currentVersion = 1
    
    /// Shared instance
    static let shared = PlaylistStore()
    
    /// Auto-save publisher
    private var autoSaveCancellable: AnyCancellable?
    
    /// Auto-save delay in seconds
    private let autoSaveDelay: TimeInterval = 5.0
    
    /// File manager
    private let fileManager = FileManager.default
    
    /// JSON encoder with pretty printing
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    /// JSON decoder
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    /// Playlist storage directory
    private var playlistsDirectory: URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("Playlists", isDirectory: true)
    }
    
    /// Backup directory
    private var backupDirectory: URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("PlaylistBackups", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDirectories()
    }
    
    // MARK: - Directory Setup
    
    /// Setup required directories
    private func setupDirectories() {
        guard let playlistsDir = playlistsDirectory,
              let backupDir = backupDirectory else {
            print("Failed to get directory URLs")
            return
        }
        
        do {
            if !fileManager.fileExists(atPath: playlistsDir.path) {
                try fileManager.createDirectory(at: playlistsDir, withIntermediateDirectories: true)
            }
            
            if !fileManager.fileExists(atPath: backupDir.path) {
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            }
        } catch {
            print("Failed to create directories: \(error)")
        }
    }
    
    // MARK: - Save Operations
    
    /// Save a playlist to disk
    func save(_ playlist: Playlist) throws {
        guard let playlistsDir = playlistsDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let fileURL = playlistsDir.appendingPathComponent("\(playlist.id.uuidString).json")
        
        // Create backup before overwriting
        if fileManager.fileExists(atPath: fileURL.path) {
            try createBackup(for: playlist.id)
        }
        
        // Create versioned container
        let metadata = PlaylistStoreMetadata()
        let versionedPlaylist = VersionedPlaylist(
            version: Self.currentVersion,
            playlist: playlist,
            metadata: metadata
        )
        
        do {
            let data = try encoder.encode(versionedPlaylist)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PlaylistStoreError.encodingFailed
        }
    }
    
    /// Save multiple playlists
    func save(_ playlists: [Playlist]) throws {
        for playlist in playlists {
            try save(playlist)
        }
    }
    
    /// Enable auto-save for a playlist
    func enableAutoSave(for playlist: Playlist) {
        // Cancel existing auto-save
        autoSaveCancellable?.cancel()
        
        // Setup new auto-save with debounce
        autoSaveCancellable = playlist.objectWillChange
            .debounce(for: .seconds(autoSaveDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                do {
                    try self?.save(playlist)
                    print("Auto-saved playlist: \(playlist.name)")
                } catch {
                    print("Auto-save failed: \(error)")
                }
            }
    }
    
    /// Disable auto-save
    func disableAutoSave() {
        autoSaveCancellable?.cancel()
        autoSaveCancellable = nil
    }
    
    // MARK: - Load Operations
    
    /// Load a playlist by ID
    func load(playlistId: UUID) throws -> Playlist {
        guard let playlistsDir = playlistsDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let fileURL = playlistsDir.appendingPathComponent("\(playlistId.uuidString).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PlaylistStoreError.fileSystemError(
                NSError(domain: "PlaylistStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist file not found"])
            )
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let versionedPlaylist = try decoder.decode(VersionedPlaylist.self, from: data)
            
            // Check version and migrate if needed
            if versionedPlaylist.version != Self.currentVersion {
                return try migrate(versionedPlaylist)
            }
            
            return versionedPlaylist.playlist
        } catch {
            throw PlaylistStoreError.decodingFailed
        }
    }
    
    /// Load all playlists
    func loadAll() throws -> [Playlist] {
        guard let playlistsDir = playlistsDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let fileURLs = try fileManager.contentsOfDirectory(
            at: playlistsDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        
        var playlists: [Playlist] = []
        
        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let versionedPlaylist = try decoder.decode(VersionedPlaylist.self, from: data)
                
                let playlist = versionedPlaylist.version != Self.currentVersion
                    ? try migrate(versionedPlaylist)
                    : versionedPlaylist.playlist
                
                playlists.append(playlist)
            } catch {
                print("Failed to load playlist from \(fileURL): \(error)")
                continue
            }
        }
        
        return playlists
    }
    
    /// Load playlists metadata without full content
    func loadMetadata() throws -> [(id: UUID, name: String, trackCount: Int, lastModified: Date)] {
        guard let playlistsDir = playlistsDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let fileURLs = try fileManager.contentsOfDirectory(
            at: playlistsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        
        var metadata: [(id: UUID, name: String, trackCount: Int, lastModified: Date)] = []
        
        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let versionedPlaylist = try decoder.decode(VersionedPlaylist.self, from: data)
                let playlist = versionedPlaylist.playlist
                
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let lastModified = attributes[.modificationDate] as? Date ?? Date()
                
                metadata.append((
                    id: playlist.id,
                    name: playlist.name,
                    trackCount: playlist.tracks.count,
                    lastModified: lastModified
                ))
            } catch {
                continue
            }
        }
        
        return metadata.sorted { $0.lastModified > $1.lastModified }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a playlist
    func delete(playlistId: UUID) throws {
        guard let playlistsDir = playlistsDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let fileURL = playlistsDir.appendingPathComponent("\(playlistId.uuidString).json")
        
        // Create backup before deletion
        try createBackup(for: playlistId)
        
        // Delete the file
        try fileManager.removeItem(at: fileURL)
    }
    
    /// Delete multiple playlists
    func delete(playlistIds: [UUID]) throws {
        for id in playlistIds {
            try delete(playlistId: id)
        }
    }
    
    // MARK: - Backup Operations
    
    /// Create a backup of a playlist
    private func createBackup(for playlistId: UUID) throws {
        guard let playlistsDir = playlistsDirectory,
              let backupDir = backupDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let sourceURL = playlistsDir.appendingPathComponent("\(playlistId.uuidString).json")
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return // No file to backup
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = backupDir.appendingPathComponent("\(playlistId.uuidString)_\(timestamp).json")
        
        try fileManager.copyItem(at: sourceURL, to: backupURL)
        
        // Clean up old backups (keep last 5)
        try cleanupBackups(for: playlistId, keepCount: 5)
    }
    
    /// Clean up old backups
    private func cleanupBackups(for playlistId: UUID, keepCount: Int) throws {
        guard let backupDir = backupDirectory else { return }
        
        let backupFiles = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.lastPathComponent.hasPrefix(playlistId.uuidString) }
        
        if backupFiles.count > keepCount {
            let sortedFiles = backupFiles.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            for fileURL in sortedFiles.dropFirst(keepCount) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    /// Restore from backup
    func restoreFromBackup(playlistId: UUID, backupDate: Date) throws -> Playlist {
        guard let backupDir = backupDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        let backupFiles = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.lastPathComponent.hasPrefix(playlistId.uuidString) }
        
        // Find closest backup to requested date
        var closestBackup: URL?
        var closestDifference = TimeInterval.greatestFiniteMagnitude
        
        for backupURL in backupFiles {
            if let timestamp = extractTimestamp(from: backupURL.lastPathComponent),
               let date = ISO8601DateFormatter().date(from: timestamp) {
                let difference = abs(date.timeIntervalSince(backupDate))
                if difference < closestDifference {
                    closestDifference = difference
                    closestBackup = backupURL
                }
            }
        }
        
        guard let backupURL = closestBackup else {
            throw PlaylistStoreError.fileSystemError(
                NSError(domain: "PlaylistStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "No backup found"])
            )
        }
        
        let data = try Data(contentsOf: backupURL)
        let versionedPlaylist = try decoder.decode(VersionedPlaylist.self, from: data)
        
        return versionedPlaylist.version != Self.currentVersion
            ? try migrate(versionedPlaylist)
            : versionedPlaylist.playlist
    }
    
    /// Extract timestamp from backup filename
    private func extractTimestamp(from filename: String) -> String? {
        let components = filename.components(separatedBy: "_")
        guard components.count >= 2 else { return nil }
        return components[1].replacingOccurrences(of: ".json", with: "")
    }
    
    // MARK: - Migration
    
    /// Migrate playlist from older version
    private func migrate(_ versionedPlaylist: VersionedPlaylist) throws -> Playlist {
        let fromVersion = versionedPlaylist.version
        let toVersion = Self.currentVersion
        
        guard fromVersion < toVersion else {
            throw PlaylistStoreError.versionMismatch(current: toVersion, stored: fromVersion)
        }
        
        var playlist = versionedPlaylist.playlist
        
        // Apply migrations sequentially
        for version in (fromVersion + 1)...toVersion {
            playlist = try applyMigration(to: playlist, version: version)
        }
        
        // Save migrated version
        try save(playlist)
        
        return playlist
    }
    
    /// Apply specific version migration
    private func applyMigration(to playlist: Playlist, version: Int) throws -> Playlist {
        switch version {
        case 1:
            // Version 1 is the initial version, no migration needed
            return playlist
        default:
            throw PlaylistStoreError.migrationFailed("Unknown version \(version)")
        }
    }
    
    // MARK: - Import/Export
    
    /// Export playlist to a specific format
    func export(_ playlist: Playlist, to url: URL, format: ExportFormat) throws {
        switch format {
        case .m3u:
            try playlist.saveAsM3U(to: url)
        case .pls:
            try playlist.saveAsPLS(to: url)
        case .json:
            try playlist.exportAsJSON(to: url)
        case .xspf:
            // XSPF export would be implemented here
            throw PlaylistStoreError.encodingFailed
        }
    }
    
    /// Import playlist from file
    func importPlaylist(from url: URL) throws -> Playlist {
        let format = detectFormat(from: url)
        
        switch format {
        case .m3u:
            return try Playlist.loadFromM3U(url: url)
        case .pls:
            // PLS import would be implemented here
            throw PlaylistStoreError.decodingFailed
        case .json:
            return try Playlist.importFromJSON(url: url)
        case .xspf:
            // XSPF import would be implemented here
            throw PlaylistStoreError.decodingFailed
        }
    }
    
    /// Detect playlist format from file extension
    private func detectFormat(from url: URL) -> ExportFormat {
        switch url.pathExtension.lowercased() {
        case "m3u", "m3u8":
            return .m3u
        case "pls":
            return .pls
        case "json":
            return .json
        case "xspf":
            return .xspf
        default:
            return .json
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up orphaned playlist files
    func cleanupOrphaned() throws {
        // This would remove playlist files that are no longer referenced
        // Implementation depends on how playlists are tracked in the app
    }
    
    /// Calculate total storage used by playlists
    func calculateStorageUsed() throws -> Int64 {
        guard let playlistsDir = playlistsDirectory,
              let backupDir = backupDirectory else {
            throw PlaylistStoreError.invalidURL
        }
        
        var totalSize: Int64 = 0
        
        // Calculate playlists directory size
        let playlistFiles = try fileManager.contentsOfDirectory(
            at: playlistsDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        for fileURL in playlistFiles {
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            totalSize += Int64(fileSize)
        }
        
        // Calculate backup directory size
        let backupFiles = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        for fileURL in backupFiles {
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
}

// MARK: - Export Formats

enum ExportFormat {
    case m3u
    case pls
    case xspf
    case json
}