//
//  PlaylistHistory.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Undo/redo support for playlist operations.
//

import Foundation
import Combine

/// Types of playlist changes that can be undone/redone
enum PlaylistChangeType: Codable {
    case addTrack(Track, at: Int)
    case addTracks([Track], at: Int)
    case removeTrack(Track, from: Int)
    case removeTracks([Track], from: IndexSet)
    case moveTrack(from: Int, to: Int)
    case moveTracks(from: IndexSet, to: Int)
    case reorderTracks(oldOrder: [Track], newOrder: [Track])
    case clearAll(tracks: [Track])
    case rename(oldName: String, newName: String)
    case updateMetadata(old: PlaylistMetadata, new: PlaylistMetadata)
    case sort(oldOrder: [Track], newOrder: [Track], sortKey: String)
    case setRating(track: Track, oldRating: Int?, newRating: Int?)
    case addTag(track: Track, tag: String)
    case removeTag(track: Track, tag: String)
    case updatePlaylistItem(old: PlaylistItem, new: PlaylistItem)
}

/// Represents a single change in playlist history
struct PlaylistChange: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let playlistId: UUID
    let changeType: PlaylistChangeType
    let description: String
    
    init(playlistId: UUID, changeType: PlaylistChangeType, description: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.playlistId = playlistId
        self.changeType = changeType
        self.description = description
    }
}

/// History session groups multiple related changes
struct HistorySession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var changes: [PlaylistChange]
    let sessionDescription: String
    
    init(description: String) {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.changes = []
        self.sessionDescription = description
    }
    
    mutating func end() {
        self.endTime = Date()
    }
}

/// Manages undo/redo history for playlists
class PlaylistHistory: ObservableObject {
    // MARK: - Properties
    
    /// Maximum number of history items to keep per playlist
    private let maxHistorySize = 100
    
    /// Maximum memory usage for history (in bytes)
    private let maxMemoryUsage: Int64 = 50 * 1024 * 1024 // 50MB
    
    /// History stacks per playlist
    private var undoStacks: [UUID: [PlaylistChange]] = [:]
    private var redoStacks: [UUID: [PlaylistChange]] = [:]
    
    /// Current sessions per playlist
    private var currentSessions: [UUID: HistorySession] = [:]
    
    /// History storage directory
    private var historyDirectory: URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("PlaylistHistory", isDirectory: true)
    }
    
    /// Published properties for UI binding
    @Published private(set) var canUndo: [UUID: Bool] = [:]
    @Published private(set) var canRedo: [UUID: Bool] = [:]
    
    /// Memory usage tracking
    private var currentMemoryUsage: Int64 = 0
    
    /// JSON encoder/decoder
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Persistence timer
    private var persistenceTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupHistoryDirectory()
        loadPersistedHistory()
        
        // Setup periodic persistence
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.persistHistory()
        }
    }
    
    deinit {
        persistenceTimer?.invalidate()
        persistHistory()
    }
    
    // MARK: - Setup
    
    private func setupHistoryDirectory() {
        guard let historyDir = historyDirectory else { return }
        
        if !FileManager.default.fileExists(atPath: historyDir.path) {
            try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Session Management
    
    /// Begin a new history session
    func beginSession(for playlistId: UUID, description: String) {
        currentSessions[playlistId] = HistorySession(description: description)
    }
    
    /// End current history session
    func endSession(for playlistId: UUID) {
        guard var session = currentSessions[playlistId] else { return }
        session.end()
        
        // If session has changes, add them as a group
        if !session.changes.isEmpty {
            // For now, add individual changes
            // In a more sophisticated implementation, we could group them
            for change in session.changes {
                addToUndoStack(change, for: playlistId)
            }
        }
        
        currentSessions[playlistId] = nil
    }
    
    // MARK: - Recording Changes
    
    /// Record a track addition
    func recordAddTrack(_ track: Track, at index: Int, to playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .addTrack(track, at: index),
            description: "Add \"\(track.displayTitle)\""
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record multiple track additions
    func recordAddTracks(_ tracks: [Track], at index: Int, to playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .addTracks(tracks, at: index),
            description: "Add \(tracks.count) tracks"
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record track removal
    func recordRemoveTrack(_ track: Track, from index: Int, in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .removeTrack(track, from: index),
            description: "Remove \"\(track.displayTitle)\""
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record multiple track removals
    func recordRemoveTracks(_ tracks: [Track], from indices: IndexSet, in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .removeTracks(tracks, from: indices),
            description: "Remove \(tracks.count) tracks"
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record track move
    func recordMoveTrack(from: Int, to: Int, in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .moveTrack(from: from, to: to),
            description: "Move track"
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record playlist clear
    func recordClearAll(_ tracks: [Track], in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .clearAll(tracks: tracks),
            description: "Clear all tracks"
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record playlist rename
    func recordRename(from oldName: String, to newName: String, in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .rename(oldName: oldName, newName: newName),
            description: "Rename playlist"
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record sort operation
    func recordSort(oldOrder: [Track], newOrder: [Track], sortKey: String, in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .sort(oldOrder: oldOrder, newOrder: newOrder, sortKey: sortKey),
            description: "Sort by \(sortKey)"
        )
        addChange(change, to: playlist.id)
    }
    
    /// Record rating change
    func recordSetRating(track: Track, oldRating: Int?, newRating: Int?, in playlist: Playlist) {
        let change = PlaylistChange(
            playlistId: playlist.id,
            changeType: .setRating(track: track, oldRating: oldRating, newRating: newRating),
            description: "Change rating for \"\(track.displayTitle)\""
        )
        addChange(change, to: playlist.id)
    }
    
    // MARK: - Undo/Redo Operations
    
    /// Undo last change for playlist
    func undo(for playlist: Playlist) -> Bool {
        guard let undoStack = undoStacks[playlist.id],
              !undoStack.isEmpty,
              let change = undoStack.last else {
            return false
        }
        
        // Remove from undo stack
        undoStacks[playlist.id]?.removeLast()
        
        // Apply inverse operation
        let success = applyInverseChange(change, to: playlist)
        
        if success {
            // Add to redo stack
            redoStacks[playlist.id, default: []].append(change)
            
            // Update can undo/redo flags
            updateCanUndoRedo(for: playlist.id)
            
            // Limit redo stack size
            limitStackSize(&redoStacks[playlist.id]!)
        }
        
        return success
    }
    
    /// Redo last undone change for playlist
    func redo(for playlist: Playlist) -> Bool {
        guard let redoStack = redoStacks[playlist.id],
              !redoStack.isEmpty,
              let change = redoStack.last else {
            return false
        }
        
        // Remove from redo stack
        redoStacks[playlist.id]?.removeLast()
        
        // Apply original operation
        let success = applyChange(change, to: playlist)
        
        if success {
            // Add back to undo stack
            undoStacks[playlist.id, default: []].append(change)
            
            // Update can undo/redo flags
            updateCanUndoRedo(for: playlist.id)
        }
        
        return success
    }
    
    /// Get description of next undo operation
    func getUndoDescription(for playlistId: UUID) -> String? {
        undoStacks[playlistId]?.last?.description
    }
    
    /// Get description of next redo operation
    func getRedoDescription(for playlistId: UUID) -> String? {
        redoStacks[playlistId]?.last?.description
    }
    
    // MARK: - History Management
    
    /// Clear history for a playlist
    func clearHistory(for playlistId: UUID) {
        undoStacks[playlistId] = nil
        redoStacks[playlistId] = nil
        canUndo[playlistId] = false
        canRedo[playlistId] = false
        
        // Remove persisted history
        if let historyDir = historyDirectory {
            let fileURL = historyDir.appendingPathComponent("\(playlistId.uuidString).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    /// Clear all history
    func clearAllHistory() {
        undoStacks.removeAll()
        redoStacks.removeAll()
        canUndo.removeAll()
        canRedo.removeAll()
        currentMemoryUsage = 0
        
        // Remove all persisted history
        if let historyDir = historyDirectory {
            try? FileManager.default.removeItem(at: historyDir)
            setupHistoryDirectory()
        }
    }
    
    /// Get history for a playlist
    func getHistory(for playlistId: UUID) -> [PlaylistChange] {
        undoStacks[playlistId] ?? []
    }
    
    // MARK: - Private Methods
    
    /// Add change to history
    private func addChange(_ change: PlaylistChange, to playlistId: UUID) {
        // If in a session, add to session instead
        if var session = currentSessions[playlistId] {
            session.changes.append(change)
            currentSessions[playlistId] = session
            return
        }
        
        // Otherwise, add directly to undo stack
        addToUndoStack(change, for: playlistId)
    }
    
    /// Add to undo stack
    private func addToUndoStack(_ change: PlaylistChange, for playlistId: UUID) {
        // Add to undo stack
        undoStacks[playlistId, default: []].append(change)
        
        // Clear redo stack (new change invalidates redo history)
        redoStacks[playlistId] = nil
        
        // Update can undo/redo flags
        updateCanUndoRedo(for: playlistId)
        
        // Limit stack size
        limitStackSize(&undoStacks[playlistId]!)
        
        // Check memory usage
        checkMemoryUsage()
    }
    
    /// Update can undo/redo flags
    private func updateCanUndoRedo(for playlistId: UUID) {
        canUndo[playlistId] = !(undoStacks[playlistId]?.isEmpty ?? true)
        canRedo[playlistId] = !(redoStacks[playlistId]?.isEmpty ?? true)
    }
    
    /// Limit stack size
    private func limitStackSize(_ stack: inout [PlaylistChange]) {
        if stack.count > maxHistorySize {
            stack.removeFirst(stack.count - maxHistorySize)
        }
    }
    
    /// Check and manage memory usage
    private func checkMemoryUsage() {
        // Estimate memory usage (simplified)
        currentMemoryUsage = 0
        
        for (_, stack) in undoStacks {
            currentMemoryUsage += estimateMemoryUsage(of: stack)
        }
        
        for (_, stack) in redoStacks {
            currentMemoryUsage += estimateMemoryUsage(of: stack)
        }
        
        // If over limit, remove oldest entries
        if currentMemoryUsage > maxMemoryUsage {
            trimOldestEntries()
        }
    }
    
    /// Estimate memory usage of a change stack
    private func estimateMemoryUsage(of stack: [PlaylistChange]) -> Int64 {
        // Simplified estimation based on number of tracks
        var usage: Int64 = 0
        
        for change in stack {
            switch change.changeType {
            case .addTrack, .removeTrack:
                usage += 1024 // 1KB per track
            case .addTracks(let tracks, _), .removeTracks(let tracks, _):
                usage += Int64(tracks.count) * 1024
            case .clearAll(let tracks):
                usage += Int64(tracks.count) * 1024
            case .sort(let oldOrder, _, _), .reorderTracks(let oldOrder, _):
                usage += Int64(oldOrder.count) * 512
            default:
                usage += 256 // Small changes
            }
        }
        
        return usage
    }
    
    /// Trim oldest entries to reduce memory usage
    private func trimOldestEntries() {
        for (playlistId, stack) in undoStacks where stack.count > 10 {
            undoStacks[playlistId] = Array(stack.suffix(10))
        }
        
        checkMemoryUsage()
    }
    
    // MARK: - Change Application
    
    /// Apply a change to playlist
    private func applyChange(_ change: PlaylistChange, to playlist: Playlist) -> Bool {
        switch change.changeType {
        case .addTrack(let track, let index):
            playlist.insertTrack(track, at: index)
            return true
            
        case .addTracks(let tracks, let index):
            for (i, track) in tracks.enumerated() {
                playlist.insertTrack(track, at: index + i)
            }
            return true
            
        case .removeTrack(_, let index):
            playlist.removeTrack(at: index)
            return true
            
        case .removeTracks(_, let indices):
            playlist.removeTracks(at: indices)
            return true
            
        case .moveTrack(let from, let to):
            playlist.moveTracks(from: IndexSet(integer: from), to: to)
            return true
            
        case .clearAll:
            playlist.clear()
            return true
            
        case .rename(_, let newName):
            playlist.name = newName
            return true
            
        case .sort(_, let newOrder, _):
            playlist.tracks = newOrder
            return true
            
        case .setRating(let track, _, let newRating):
            playlist.setRating(newRating, for: track)
            return true
            
        case .addTag(let track, let tag):
            playlist.addTag(tag, to: track)
            return true
            
        case .removeTag(let track, let tag):
            playlist.removeTag(tag, from: track)
            return true
            
        default:
            return false
        }
    }
    
    /// Apply inverse of a change to playlist
    private func applyInverseChange(_ change: PlaylistChange, to playlist: Playlist) -> Bool {
        switch change.changeType {
        case .addTrack(_, let index):
            playlist.removeTrack(at: index)
            return true
            
        case .addTracks(let tracks, let index):
            for _ in tracks {
                playlist.removeTrack(at: index)
            }
            return true
            
        case .removeTrack(let track, let index):
            playlist.insertTrack(track, at: index)
            return true
            
        case .removeTracks(let tracks, let indices):
            var sortedIndices = Array(indices).sorted()
            for (i, track) in tracks.enumerated() {
                playlist.insertTrack(track, at: sortedIndices[i])
            }
            return true
            
        case .moveTrack(let from, let to):
            playlist.moveTracks(from: IndexSet(integer: to), to: from)
            return true
            
        case .clearAll(let tracks):
            playlist.tracks = tracks
            return true
            
        case .rename(let oldName, _):
            playlist.name = oldName
            return true
            
        case .sort(let oldOrder, _, _):
            playlist.tracks = oldOrder
            return true
            
        case .setRating(let track, let oldRating, _):
            playlist.setRating(oldRating, for: track)
            return true
            
        case .removeTag(let track, let tag):
            playlist.addTag(tag, to: track)
            return true
            
        case .addTag(let track, let tag):
            playlist.removeTag(tag, from: track)
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Persistence
    
    /// Persist history to disk
    private func persistHistory() {
        guard let historyDir = historyDirectory else { return }
        
        for (playlistId, undoStack) in undoStacks {
            let fileURL = historyDir.appendingPathComponent("\(playlistId.uuidString).json")
            
            let historyData = PlaylistHistoryData(
                playlistId: playlistId,
                undoStack: Array(undoStack.suffix(20)), // Keep last 20 items
                redoStack: redoStacks[playlistId] ?? []
            )
            
            if let data = try? encoder.encode(historyData) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    /// Load persisted history
    private func loadPersistedHistory() {
        guard let historyDir = historyDirectory else { return }
        
        let fileURLs = (try? FileManager.default.contentsOfDirectory(
            at: historyDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        
        for fileURL in fileURLs where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let historyData = try? decoder.decode(PlaylistHistoryData.self, from: data) {
                undoStacks[historyData.playlistId] = historyData.undoStack
                redoStacks[historyData.playlistId] = historyData.redoStack
                updateCanUndoRedo(for: historyData.playlistId)
            }
        }
    }
}

// MARK: - Persistence Structure

private struct PlaylistHistoryData: Codable {
    let playlistId: UUID
    let undoStack: [PlaylistChange]
    let redoStack: [PlaylistChange]
}

// MARK: - Extensions for Codable Support

extension PlaylistChangeType {
    enum CodingKeys: String, CodingKey {
        case type
        case track, tracks
        case index, indices
        case from, to
        case oldOrder, newOrder
        case sortKey
        case oldName, newName
        case oldMetadata, newMetadata
        case oldRating, newRating
        case tag
        case oldItem, newItem
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "addTrack":
            let track = try container.decode(Track.self, forKey: .track)
            let index = try container.decode(Int.self, forKey: .index)
            self = .addTrack(track, at: index)
            
        case "addTracks":
            let tracks = try container.decode([Track].self, forKey: .tracks)
            let index = try container.decode(Int.self, forKey: .index)
            self = .addTracks(tracks, at: index)
            
        case "removeTrack":
            let track = try container.decode(Track.self, forKey: .track)
            let index = try container.decode(Int.self, forKey: .from)
            self = .removeTrack(track, from: index)
            
        case "removeTracks":
            let tracks = try container.decode([Track].self, forKey: .tracks)
            let indices = try container.decode([Int].self, forKey: .indices)
            self = .removeTracks(tracks, from: IndexSet(indices))
            
        case "moveTrack":
            let from = try container.decode(Int.self, forKey: .from)
            let to = try container.decode(Int.self, forKey: .to)
            self = .moveTrack(from: from, to: to)
            
        case "clearAll":
            let tracks = try container.decode([Track].self, forKey: .tracks)
            self = .clearAll(tracks: tracks)
            
        case "rename":
            let oldName = try container.decode(String.self, forKey: .oldName)
            let newName = try container.decode(String.self, forKey: .newName)
            self = .rename(oldName: oldName, newName: newName)
            
        case "sort":
            let oldOrder = try container.decode([Track].self, forKey: .oldOrder)
            let newOrder = try container.decode([Track].self, forKey: .newOrder)
            let sortKey = try container.decode(String.self, forKey: .sortKey)
            self = .sort(oldOrder: oldOrder, newOrder: newOrder, sortKey: sortKey)
            
        case "setRating":
            let track = try container.decode(Track.self, forKey: .track)
            let oldRating = try container.decodeIfPresent(Int.self, forKey: .oldRating)
            let newRating = try container.decodeIfPresent(Int.self, forKey: .newRating)
            self = .setRating(track: track, oldRating: oldRating, newRating: newRating)
            
        case "addTag":
            let track = try container.decode(Track.self, forKey: .track)
            let tag = try container.decode(String.self, forKey: .tag)
            self = .addTag(track: track, tag: tag)
            
        case "removeTag":
            let track = try container.decode(Track.self, forKey: .track)
            let tag = try container.decode(String.self, forKey: .tag)
            self = .removeTag(track: track, tag: tag)
            
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown change type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .addTrack(let track, let index):
            try container.encode("addTrack", forKey: .type)
            try container.encode(track, forKey: .track)
            try container.encode(index, forKey: .index)
            
        case .addTracks(let tracks, let index):
            try container.encode("addTracks", forKey: .type)
            try container.encode(tracks, forKey: .tracks)
            try container.encode(index, forKey: .index)
            
        case .removeTrack(let track, let index):
            try container.encode("removeTrack", forKey: .type)
            try container.encode(track, forKey: .track)
            try container.encode(index, forKey: .from)
            
        case .removeTracks(let tracks, let indices):
            try container.encode("removeTracks", forKey: .type)
            try container.encode(tracks, forKey: .tracks)
            try container.encode(Array(indices), forKey: .indices)
            
        case .moveTrack(let from, let to):
            try container.encode("moveTrack", forKey: .type)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
            
        case .clearAll(let tracks):
            try container.encode("clearAll", forKey: .type)
            try container.encode(tracks, forKey: .tracks)
            
        case .rename(let oldName, let newName):
            try container.encode("rename", forKey: .type)
            try container.encode(oldName, forKey: .oldName)
            try container.encode(newName, forKey: .newName)
            
        case .sort(let oldOrder, let newOrder, let sortKey):
            try container.encode("sort", forKey: .type)
            try container.encode(oldOrder, forKey: .oldOrder)
            try container.encode(newOrder, forKey: .newOrder)
            try container.encode(sortKey, forKey: .sortKey)
            
        case .setRating(let track, let oldRating, let newRating):
            try container.encode("setRating", forKey: .type)
            try container.encode(track, forKey: .track)
            try container.encodeIfPresent(oldRating, forKey: .oldRating)
            try container.encodeIfPresent(newRating, forKey: .newRating)
            
        case .addTag(let track, let tag):
            try container.encode("addTag", forKey: .type)
            try container.encode(track, forKey: .track)
            try container.encode(tag, forKey: .tag)
            
        case .removeTag(let track, let tag):
            try container.encode("removeTag", forKey: .type)
            try container.encode(track, forKey: .track)
            try container.encode(tag, forKey: .tag)
            
        default:
            break
        }
    }
}