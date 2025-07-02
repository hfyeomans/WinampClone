//
//  SmartPlaylistEngine.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Engine for evaluating smart playlist rules with performance optimizations.
//

import Foundation
import Combine

/// Engine that evaluates smart playlist rules against a track library
public final class SmartPlaylistEngine {
    
    // MARK: - Properties
    
    /// Shared instance for the application
    public static let shared = SmartPlaylistEngine()
    
    /// The track library to evaluate against
    private var trackLibrary: [Track] = []
    
    /// Indexes for fast filtering
    private var indexes = TrackIndexes()
    
    /// Active smart playlists that update automatically
    private var activePlaylists: [UUID: SmartPlaylist] = [:]
    
    /// Publisher for playlist updates
    private let playlistUpdatesSubject = PassthroughSubject<SmartPlaylistUpdate, Never>()
    public var playlistUpdates: AnyPublisher<SmartPlaylistUpdate, Never> {
        playlistUpdatesSubject.eraseToAnyPublisher()
    }
    
    /// Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.winampplayer.smartplaylist", qos: .userInitiated, attributes: .concurrent)
    
    /// Serial queue for index updates
    private let indexQueue = DispatchQueue(label: "com.winampplayer.smartplaylist.index", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Public API
    
    /// Updates the track library and rebuilds indexes
    public func updateTrackLibrary(_ tracks: [Track]) {
        processingQueue.async(flags: .barrier) {
            self.trackLibrary = tracks
            self.rebuildIndexes()
            self.updateAllActivePlaylists()
        }
    }
    
    /// Adds a track to the library
    public func addTrack(_ track: Track) {
        processingQueue.async(flags: .barrier) {
            self.trackLibrary.append(track)
            self.indexQueue.async {
                self.indexes.addTrack(track)
            }
            self.updatePlaylistsForTrackChange(track, changeType: .added)
        }
    }
    
    /// Updates a track in the library
    public func updateTrack(_ track: Track) {
        processingQueue.async(flags: .barrier) {
            if let index = self.trackLibrary.firstIndex(where: { $0.id == track.id }) {
                let oldTrack = self.trackLibrary[index]
                self.trackLibrary[index] = track
                self.indexQueue.async {
                    self.indexes.updateTrack(oldTrack: oldTrack, newTrack: track)
                }
                self.updatePlaylistsForTrackChange(track, changeType: .updated)
            }
        }
    }
    
    /// Removes a track from the library
    public func removeTrack(id: UUID) {
        processingQueue.async(flags: .barrier) {
            if let index = self.trackLibrary.firstIndex(where: { $0.id == id }) {
                let track = self.trackLibrary.remove(at: index)
                self.indexQueue.async {
                    self.indexes.removeTrack(track)
                }
                self.updatePlaylistsForTrackChange(track, changeType: .removed)
            }
        }
    }
    
    /// Evaluates a smart playlist and returns matching tracks
    public func evaluate(playlist: SmartPlaylist, completion: @escaping ([Track]) -> Void) {
        processingQueue.async {
            let matches = self.evaluateRules(playlist.rootRule, against: self.trackLibrary)
            
            // Apply sorting
            let sorted = self.applySorting(matches, sorting: playlist.sorting)
            
            // Apply limit
            let limited = playlist.limit.map { Array(sorted.prefix($0)) } ?? sorted
            
            DispatchQueue.main.async {
                completion(limited)
            }
        }
    }
    
    /// Evaluates a rule and returns matching tracks synchronously (for testing)
    public func evaluateSync(rule: any SmartPlaylistRule) -> [Track] {
        processingQueue.sync {
            evaluateRules(rule, against: trackLibrary)
        }
    }
    
    /// Registers a smart playlist for automatic updates
    public func registerPlaylist(_ playlist: SmartPlaylist) {
        processingQueue.async(flags: .barrier) {
            self.activePlaylists[playlist.id] = playlist
            self.evaluate(playlist: playlist) { tracks in
                self.playlistUpdatesSubject.send(SmartPlaylistUpdate(
                    playlistId: playlist.id,
                    tracks: tracks,
                    changeType: .fullUpdate
                ))
            }
        }
    }
    
    /// Unregisters a smart playlist from automatic updates
    public func unregisterPlaylist(id: UUID) {
        processingQueue.async(flags: .barrier) {
            self.activePlaylists.removeValue(forKey: id)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Setup observers for track metadata changes if needed
    }
    
    private func rebuildIndexes() {
        indexQueue.sync {
            indexes = TrackIndexes()
            for track in trackLibrary {
                indexes.addTrack(track)
            }
        }
    }
    
    private func evaluateRules(_ rule: any SmartPlaylistRule, against tracks: [Track]) -> [Track] {
        // Use indexes for certain rule types if available
        if rule.requiresIndexing, let optimizedResults = evaluateWithIndexes(rule) {
            return optimizedResults
        }
        
        // Fall back to linear evaluation
        return tracks.filter { rule.evaluate(track: $0) }
    }
    
    private func evaluateWithIndexes(_ rule: any SmartPlaylistRule) -> [Track]? {
        // Implement index-based evaluation for specific rule types
        if let stringRule = rule as? StringMetadataRule {
            return evaluateStringRuleWithIndex(stringRule)
        }
        
        // Add more index-based evaluations as needed
        return nil
    }
    
    private func evaluateStringRuleWithIndex(_ rule: StringMetadataRule) -> [Track]? {
        guard rule.operator == .contains || rule.operator == .startsWith else {
            return nil
        }
        
        return indexQueue.sync {
            switch rule.field {
            case .artist:
                return indexes.searchArtist(rule.value, operator: rule.operator)
            case .album:
                return indexes.searchAlbum(rule.value, operator: rule.operator)
            case .genre:
                return indexes.searchGenre(rule.value, operator: rule.operator)
            default:
                return nil
            }
        }
    }
    
    private func applySorting(_ tracks: [Track], sorting: SmartPlaylistSorting?) -> [Track] {
        guard let sorting = sorting else { return tracks }
        
        return tracks.sorted { track1, track2 in
            let comparison: ComparisonResult = {
                switch sorting.field {
                case .title:
                    return track1.title.compare(track2.title)
                case .artist:
                    return (track1.artist ?? "").compare(track2.artist ?? "")
                case .album:
                    return (track1.album ?? "").compare(track2.album ?? "")
                case .dateAdded:
                    let date1 = track1.dateAdded ?? Date.distantPast
                    let date2 = track2.dateAdded ?? Date.distantPast
                    return date1.compare(date2)
                case .lastPlayed:
                    let date1 = track1.lastPlayed ?? Date.distantPast
                    let date2 = track2.lastPlayed ?? Date.distantPast
                    return date1.compare(date2)
                case .playCount:
                    let count1 = track1.playCount ?? 0
                    let count2 = track2.playCount ?? 0
                    return count1 < count2 ? .orderedAscending : count1 > count2 ? .orderedDescending : .orderedSame
                case .duration:
                    return track1.duration < track2.duration ? .orderedAscending : track1.duration > track2.duration ? .orderedDescending : .orderedSame
                case .random:
                    return Bool.random() ? .orderedAscending : .orderedDescending
                }
            }()
            
            return sorting.ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }
    
    private func updateAllActivePlaylists() {
        for (_, playlist) in activePlaylists {
            evaluate(playlist: playlist) { tracks in
                self.playlistUpdatesSubject.send(SmartPlaylistUpdate(
                    playlistId: playlist.id,
                    tracks: tracks,
                    changeType: .fullUpdate
                ))
            }
        }
    }
    
    private func updatePlaylistsForTrackChange(_ track: Track, changeType: TrackChangeType) {
        for (_, playlist) in activePlaylists {
            processingQueue.async {
                let wasIncluded = self.wasTrackIncluded(track.id, in: playlist)
                let shouldBeIncluded = playlist.rootRule.evaluate(track: track)
                
                if wasIncluded != shouldBeIncluded || changeType == .updated {
                    self.evaluate(playlist: playlist) { tracks in
                        self.playlistUpdatesSubject.send(SmartPlaylistUpdate(
                            playlistId: playlist.id,
                            tracks: tracks,
                            changeType: .incrementalUpdate(added: shouldBeIncluded ? [track] : [], removed: wasIncluded ? [track.id] : [])
                        ))
                    }
                }
            }
        }
    }
    
    private func wasTrackIncluded(_ trackId: UUID, in playlist: SmartPlaylist) -> Bool {
        // This would need to maintain state of current playlist contents
        // For now, we'll trigger full updates
        return false
    }
}

// MARK: - Supporting Types

/// Smart playlist model
public struct SmartPlaylist: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let rootRule: AnySmartPlaylistRule
    public let sorting: SmartPlaylistSorting?
    public let limit: Int?
    
    public init(id: UUID = UUID(), name: String, rule: any SmartPlaylistRule, sorting: SmartPlaylistSorting? = nil, limit: Int? = nil) {
        self.id = id
        self.name = name
        self.rootRule = AnySmartPlaylistRule(rule)
        self.sorting = sorting
        self.limit = limit
    }
}

/// Sorting options for smart playlists
public struct SmartPlaylistSorting: Codable {
    public enum Field: String, Codable, CaseIterable {
        case title, artist, album, dateAdded, lastPlayed, playCount, duration, random
    }
    
    public let field: Field
    public let ascending: Bool
    
    public init(field: Field, ascending: Bool = true) {
        self.field = field
        self.ascending = ascending
    }
}

/// Update notification for smart playlists
public struct SmartPlaylistUpdate {
    public enum ChangeType {
        case fullUpdate
        case incrementalUpdate(added: [Track], removed: [UUID])
    }
    
    public let playlistId: UUID
    public let tracks: [Track]
    public let changeType: ChangeType
}

/// Track change types
private enum TrackChangeType {
    case added, updated, removed
}

// MARK: - Indexing

/// Indexes for fast track filtering
private struct TrackIndexes {
    // Text indexes for string fields
    var artistIndex = TextIndex()
    var albumIndex = TextIndex()
    var genreIndex = TextIndex()
    
    // Value indexes for numeric/date fields
    var yearIndex = ValueIndex<Int>()
    var dateAddedIndex = ValueIndex<Date>()
    var playCountIndex = ValueIndex<Int>()
    
    mutating func addTrack(_ track: Track) {
        if let artist = track.artist {
            artistIndex.add(track, for: artist)
        }
        if let album = track.album {
            albumIndex.add(track, for: album)
        }
        if let genre = track.genre {
            genreIndex.add(track, for: genre)
        }
        if let year = track.year {
            yearIndex.add(track, for: year)
        }
        if let dateAdded = track.dateAdded {
            dateAddedIndex.add(track, for: dateAdded)
        }
        if let playCount = track.playCount {
            playCountIndex.add(track, for: playCount)
        }
    }
    
    mutating func removeTrack(_ track: Track) {
        if let artist = track.artist {
            artistIndex.remove(track, for: artist)
        }
        if let album = track.album {
            albumIndex.remove(track, for: album)
        }
        if let genre = track.genre {
            genreIndex.remove(track, for: genre)
        }
        if let year = track.year {
            yearIndex.remove(track, for: year)
        }
        if let dateAdded = track.dateAdded {
            dateAddedIndex.remove(track, for: dateAdded)
        }
        if let playCount = track.playCount {
            playCountIndex.remove(track, for: playCount)
        }
    }
    
    mutating func updateTrack(oldTrack: Track, newTrack: Track) {
        removeTrack(oldTrack)
        addTrack(newTrack)
    }
    
    func searchArtist(_ query: String, operator: ComparisonOperator) -> [Track] {
        artistIndex.search(query, operator: `operator`)
    }
    
    func searchAlbum(_ query: String, operator: ComparisonOperator) -> [Track] {
        albumIndex.search(query, operator: `operator`)
    }
    
    func searchGenre(_ query: String, operator: ComparisonOperator) -> [Track] {
        genreIndex.search(query, operator: `operator`)
    }
}

/// Text index for string searches
private struct TextIndex {
    private var index: [String: Set<UUID>] = [:]
    private var tracks: [UUID: Track] = [:]
    
    mutating func add(_ track: Track, for text: String) {
        tracks[track.id] = track
        
        // Index whole text
        let normalized = text.lowercased()
        index[normalized, default: Set()].insert(track.id)
        
        // Index words for contains searches
        let words = normalized.split(separator: " ")
        for word in words {
            index[String(word), default: Set()].insert(track.id)
        }
    }
    
    mutating func remove(_ track: Track, for text: String) {
        tracks.removeValue(forKey: track.id)
        
        let normalized = text.lowercased()
        index[normalized]?.remove(track.id)
        
        let words = normalized.split(separator: " ")
        for word in words {
            index[String(word)]?.remove(track.id)
        }
    }
    
    func search(_ query: String, operator: ComparisonOperator) -> [Track] {
        let normalized = query.lowercased()
        var matchingIds = Set<UUID>()
        
        switch `operator` {
        case .contains:
            // Search for tracks containing the query
            for (key, ids) in index {
                if key.contains(normalized) {
                    matchingIds.formUnion(ids)
                }
            }
        case .startsWith:
            // Search for tracks starting with the query
            for (key, ids) in index {
                if key.hasPrefix(normalized) {
                    matchingIds.formUnion(ids)
                }
            }
        default:
            break
        }
        
        return matchingIds.compactMap { tracks[$0] }
    }
}

/// Value index for comparable types
private struct ValueIndex<T: Comparable> {
    private var sortedValues: [(value: T, trackId: UUID)] = []
    private var tracks: [UUID: Track] = [:]
    
    mutating func add(_ track: Track, for value: T) {
        tracks[track.id] = track
        
        let entry = (value: value, trackId: track.id)
        let insertIndex = sortedValues.firstIndex { $0.value > value } ?? sortedValues.count
        sortedValues.insert(entry, at: insertIndex)
    }
    
    mutating func remove(_ track: Track, for value: T) {
        tracks.removeValue(forKey: track.id)
        sortedValues.removeAll { $0.trackId == track.id }
    }
    
    func tracksWithValue(greaterThan value: T) -> [Track] {
        let startIndex = sortedValues.firstIndex { $0.value > value } ?? sortedValues.count
        return sortedValues[startIndex...].compactMap { tracks[$0.trackId] }
    }
    
    func tracksWithValue(lessThan value: T) -> [Track] {
        let endIndex = sortedValues.firstIndex { $0.value >= value } ?? sortedValues.count
        return sortedValues[..<endIndex].compactMap { tracks[$0.trackId] }
    }
}