//
//  Playlist.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Data model representing a playlist of tracks.
//

import Foundation

// MARK: - Enums

/// Shuffle algorithms for playlist playback
enum ShuffleMode {
    case off
    case random
    case weighted          // Weighted by play count (less played = higher chance)
    case intelligent       // Considers genre, BPM, and other factors
}

/// Repeat modes for playlist playback
enum RepeatMode: Equatable, Codable {
    case off
    case all
    case one
    case abLoop(start: TimeInterval, end: TimeInterval)
}

/// Smart playlist rule types
enum SmartPlaylistRuleType {
    case artist(String)
    case album(String)
    case genre(String)
    case year(Int, ComparisonOperator)
    case playCount(Int, ComparisonOperator)
    case lastPlayed(Date, ComparisonOperator)
    case dateAdded(Date, ComparisonOperator)
    case duration(TimeInterval, ComparisonOperator)
    case rating(Int, ComparisonOperator)
    case bpm(Int, ComparisonOperator)
}

enum ComparisonOperator {
    case equals
    case notEquals
    case greaterThan
    case lessThan
    case contains
    case startsWith
    case endsWith
}

// MARK: - Supporting Structures

/// Represents an item in a playlist with additional metadata
struct PlaylistItem: Identifiable, Codable {
    let id: UUID
    let trackId: UUID
    var customOrder: Int
    var addedDate: Date
    var playCountInPlaylist: Int
    var lastPlayedInPlaylist: Date?
    var rating: Int?  // 1-5 stars
    var customTags: [String]
    var notes: String?
    
    init(
        trackId: UUID,
        customOrder: Int,
        addedDate: Date = Date(),
        playCountInPlaylist: Int = 0,
        lastPlayedInPlaylist: Date? = nil,
        rating: Int? = nil,
        customTags: [String] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.trackId = trackId
        self.customOrder = customOrder
        self.addedDate = addedDate
        self.playCountInPlaylist = playCountInPlaylist
        self.lastPlayedInPlaylist = lastPlayedInPlaylist
        self.rating = rating
        self.customTags = customTags
        self.notes = notes
    }
}

/// Metadata for the playlist itself
struct PlaylistMetadata: Codable {
    var description: String?
    var coverImageData: Data?
    var createdDate: Date
    var modifiedDate: Date
    var totalPlayCount: Int
    var lastPlayedDate: Date?
    var isSmartPlaylist: Bool
    var smartRules: [SmartPlaylistRule]?
    var tags: [String]
    var color: String?  // Hex color for UI theming
    
    init(
        description: String? = nil,
        coverImageData: Data? = nil,
        createdDate: Date = Date(),
        isSmartPlaylist: Bool = false,
        smartRules: [SmartPlaylistRule]? = nil,
        tags: [String] = []
    ) {
        self.description = description
        self.coverImageData = coverImageData
        self.createdDate = createdDate
        self.modifiedDate = createdDate
        self.totalPlayCount = 0
        self.lastPlayedDate = nil
        self.isSmartPlaylist = isSmartPlaylist
        self.smartRules = smartRules
        self.tags = tags
        self.color = nil
    }
}

/// Smart playlist rule definition
struct SmartPlaylistRule: Codable {
    let id: UUID
    let ruleType: SmartPlaylistRuleType
    let isInclude: Bool  // true = include, false = exclude
    
    init(ruleType: SmartPlaylistRuleType, isInclude: Bool = true) {
        self.id = UUID()
        self.ruleType = ruleType
        self.isInclude = isInclude
    }
}

/// Playlist validation result
struct PlaylistValidationResult {
    let isValid: Bool
    let missingFiles: [URL]
    let duplicateTrackIds: [UUID]
    let incompatibleFormats: [String]
    let warnings: [String]
}

/// Represents a playlist containing multiple tracks
class Playlist: ObservableObject, Identifiable, Codable {
    // MARK: - Properties
    
    let id: UUID
    @Published var name: String
    @Published var tracks: [Track]
    @Published var playlistItems: [PlaylistItem]
    @Published var currentTrackIndex: Int?
    @Published var metadata: PlaylistMetadata
    
    // Playback modes
    @Published var shuffleMode: ShuffleMode = .off
    @Published var repeatMode: RepeatMode = .off
    
    // Queue management
    @Published var queue: [PlaylistItem] = []
    @Published var queueIndex: Int?
    
    // History tracking
    @Published var history: [PlaylistItem] = []
    @Published var historyIndex: Int = -1
    
    // Shuffle state
    private var shuffledIndices: [Int] = []
    private var shuffleHistory: [Int] = []
    
    // MARK: - Computed Properties
    
    /// The currently selected track
    var currentTrack: Track? {
        guard let index = currentTrackIndex,
              index >= 0 && index < tracks.count else {
            return nil
        }
        return tracks[index]
    }
    
    /// The current playlist item
    var currentPlaylistItem: PlaylistItem? {
        guard let index = currentTrackIndex,
              index >= 0 && index < playlistItems.count else {
            return nil
        }
        return playlistItems[index]
    }
    
    /// Total file size of all tracks
    var totalFileSize: Int64 {
        tracks.compactMap { $0.fileSize }.reduce(0, +)
    }
    
    /// Formatted total file size
    var formattedTotalFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFileSize)
    }
    
    /// Average track rating
    var averageRating: Double {
        let ratings = playlistItems.compactMap { $0.rating }
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    /// Most played track
    var mostPlayedTrack: (track: Track, playCount: Int)? {
        guard !playlistItems.isEmpty else { return nil }
        
        let sortedItems = playlistItems.sorted { $0.playCountInPlaylist > $1.playCountInPlaylist }
        guard let topItem = sortedItems.first,
              topItem.playCountInPlaylist > 0,
              let track = tracks.first(where: { $0.id == topItem.trackId }) else {
            return nil
        }
        
        return (track, topItem.playCountInPlaylist)
    }
    
    /// Playlist statistics
    var statistics: PlaylistStatistics {
        PlaylistStatistics(
            totalTracks: tracks.count,
            totalDuration: totalDuration,
            totalFileSize: totalFileSize,
            totalPlayCount: metadata.totalPlayCount,
            averageRating: averageRating,
            uniqueArtists: Set(tracks.compactMap { $0.artist }).count,
            uniqueAlbums: Set(tracks.compactMap { $0.album }).count,
            uniqueGenres: Set(tracks.compactMap { $0.genre }).count
        )
    }
    
    /// Total duration of all tracks in the playlist
    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }
    
    /// Formatted total duration string
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let seconds = Int(totalDuration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Number of tracks in the playlist
    var count: Int {
        tracks.count
    }
    
    /// Whether the playlist is empty
    var isEmpty: Bool {
        tracks.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String = "New Playlist",
        tracks: [Track] = [],
        metadata: PlaylistMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.playlistItems = []
        self.currentTrackIndex = nil
        self.metadata = metadata ?? PlaylistMetadata()
        
        // Create playlist items for existing tracks
        for (index, track) in tracks.enumerated() {
            let item = PlaylistItem(trackId: track.id, customOrder: index)
            playlistItems.append(item)
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, tracks, playlistItems, currentTrackIndex, metadata
        case shuffleMode, repeatMode, queue, queueIndex, history, historyIndex
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tracks = try container.decode([Track].self, forKey: .tracks)
        playlistItems = try container.decodeIfPresent([PlaylistItem].self, forKey: .playlistItems) ?? []
        currentTrackIndex = try container.decodeIfPresent(Int.self, forKey: .currentTrackIndex)
        metadata = try container.decodeIfPresent(PlaylistMetadata.self, forKey: .metadata) ?? PlaylistMetadata()
        shuffleMode = try container.decodeIfPresent(ShuffleMode.self, forKey: .shuffleMode) ?? .off
        repeatMode = try container.decodeIfPresent(RepeatMode.self, forKey: .repeatMode) ?? .off
        queue = try container.decodeIfPresent([PlaylistItem].self, forKey: .queue) ?? []
        queueIndex = try container.decodeIfPresent(Int.self, forKey: .queueIndex)
        history = try container.decodeIfPresent([PlaylistItem].self, forKey: .history) ?? []
        historyIndex = try container.decodeIfPresent(Int.self, forKey: .historyIndex) ?? -1
        
        // Ensure playlist items exist for all tracks
        if playlistItems.isEmpty && !tracks.isEmpty {
            playlistItems = tracks.enumerated().map { index, track in
                PlaylistItem(trackId: track.id, customOrder: index)
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(playlistItems, forKey: .playlistItems)
        try container.encodeIfPresent(currentTrackIndex, forKey: .currentTrackIndex)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(shuffleMode, forKey: .shuffleMode)
        try container.encode(repeatMode, forKey: .repeatMode)
        try container.encode(queue, forKey: .queue)
        try container.encodeIfPresent(queueIndex, forKey: .queueIndex)
        try container.encode(history, forKey: .history)
        try container.encode(historyIndex, forKey: .historyIndex)
    }
    
    // MARK: - Track Management
    
    /// Add a track to the playlist
    func addTrack(_ track: Track) {
        tracks.append(track)
        let item = PlaylistItem(trackId: track.id, customOrder: playlistItems.count)
        playlistItems.append(item)
        metadata.modifiedDate = Date()
    }
    
    /// Add multiple tracks to the playlist
    func addTracks(_ newTracks: [Track]) {
        let startOrder = playlistItems.count
        tracks.append(contentsOf: newTracks)
        
        for (index, track) in newTracks.enumerated() {
            let item = PlaylistItem(trackId: track.id, customOrder: startOrder + index)
            playlistItems.append(item)
        }
        metadata.modifiedDate = Date()
    }
    
    /// Insert a track at a specific index
    func insertTrack(_ track: Track, at index: Int) {
        guard index >= 0 && index <= tracks.count else { return }
        tracks.insert(track, at: index)
        
        let item = PlaylistItem(trackId: track.id, customOrder: index)
        playlistItems.insert(item, at: index)
        
        // Update custom order for subsequent items
        for i in (index + 1)..<playlistItems.count {
            playlistItems[i].customOrder = i
        }
        
        // Adjust current track index if needed
        if let currentIndex = currentTrackIndex, currentIndex >= index {
            currentTrackIndex = currentIndex + 1
        }
        
        metadata.modifiedDate = Date()
    }
    
    /// Remove a track at a specific index
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
        playlistItems.remove(at: index)
        
        // Update custom order for subsequent items
        for i in index..<playlistItems.count {
            playlistItems[i].customOrder = i
        }
        
        // Adjust current track index if needed
        if let currentIndex = currentTrackIndex {
            if currentIndex == index {
                // Current track was removed
                currentTrackIndex = nil
            } else if currentIndex > index {
                currentTrackIndex = currentIndex - 1
            }
        }
        
        metadata.modifiedDate = Date()
    }
    
    /// Remove multiple tracks
    func removeTracks(at indices: IndexSet) {
        tracks.remove(atOffsets: indices)
        
        // Reset current track if it was removed
        if let currentIndex = currentTrackIndex,
           indices.contains(currentIndex) {
            currentTrackIndex = nil
        }
    }
    
    /// Move tracks within the playlist
    func moveTracks(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        
        // Adjust current track index if needed
        // This is simplified; in a real implementation you'd need more complex logic
        if let currentIndex = currentTrackIndex {
            if source.contains(currentIndex) {
                let adjustment = destination > currentIndex ? -1 : 0
                currentTrackIndex = destination + adjustment
            }
        }
    }
    
    /// Clear all tracks from the playlist
    func clear() {
        tracks.removeAll()
        playlistItems.removeAll()
        queue.removeAll()
        history.removeAll()
        currentTrackIndex = nil
        queueIndex = nil
        historyIndex = -1
        shuffledIndices.removeAll()
        shuffleHistory.removeAll()
        metadata.modifiedDate = Date()
    }
    
    // MARK: - Navigation
    
    /// Select the next track
    func selectNextTrack() -> Track? {
        guard !tracks.isEmpty else { return nil }
        
        // Check queue first
        if !queue.isEmpty, let qIndex = queueIndex {
            if qIndex + 1 < queue.count {
                queueIndex = qIndex + 1
                if let track = getTrackFromQueueIndex(qIndex + 1) {
                    addToHistory()
                    return track
                }
            } else {
                // Queue finished, return to main playlist
                queue.removeAll()
                queueIndex = nil
            }
        }
        
        // Handle repeat one mode
        if case .one = repeatMode {
            return currentTrack
        }
        
        // Handle shuffle mode
        if shuffleMode != .off {
            return selectNextShuffledTrack()
        }
        
        // Normal sequential playback
        if let currentIndex = currentTrackIndex {
            let nextIndex: Int
            
            if currentIndex + 1 >= tracks.count {
                // End of playlist
                switch repeatMode {
                case .all:
                    nextIndex = 0
                case .off, .one, .abLoop:
                    return nil
                }
            } else {
                nextIndex = currentIndex + 1
            }
            
            currentTrackIndex = nextIndex
            addToHistory()
            updatePlaylistItemStats(at: nextIndex)
        } else {
            currentTrackIndex = 0
            addToHistory()
            updatePlaylistItemStats(at: 0)
        }
        
        return currentTrack
    }
    
    /// Select the previous track
    func selectPreviousTrack() -> Track? {
        guard !tracks.isEmpty else { return nil }
        
        // Check history first
        if historyIndex > 0 && historyIndex - 1 < history.count {
            historyIndex -= 1
            let historyItem = history[historyIndex]
            if let index = playlistItems.firstIndex(where: { $0.id == historyItem.id }) {
                currentTrackIndex = index
                return tracks[index]
            }
        }
        
        // Handle shuffle mode
        if shuffleMode != .off && !shuffleHistory.isEmpty {
            return selectPreviousShuffledTrack()
        }
        
        // Normal sequential playback
        if let currentIndex = currentTrackIndex {
            let previousIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
            currentTrackIndex = previousIndex
            updatePlaylistItemStats(at: previousIndex)
        } else {
            currentTrackIndex = tracks.count - 1
            updatePlaylistItemStats(at: tracks.count - 1)
        }
        
        return currentTrack
    }
    
    /// Select a specific track by index
    func selectTrack(at index: Int) -> Track? {
        guard index >= 0 && index < tracks.count else { return nil }
        currentTrackIndex = index
        return currentTrack
    }
    
    // MARK: - Shuffle Operations
    
    /// Set shuffle mode and prepare shuffle order if needed
    func setShuffleMode(_ mode: ShuffleMode) {
        shuffleMode = mode
        
        if mode != .off {
            prepareShuffleOrder()
        } else {
            shuffledIndices.removeAll()
            shuffleHistory.removeAll()
        }
    }
    
    /// Prepare shuffle order based on current shuffle mode
    private func prepareShuffleOrder() {
        shuffledIndices = Array(0..<tracks.count)
        
        switch shuffleMode {
        case .off:
            break
            
        case .random:
            shuffledIndices.shuffle()
            
        case .weighted:
            // Weight by inverse play count (less played = higher weight)
            let weights = playlistItems.map { item in
                max(1, 10 - item.playCountInPlaylist)
            }
            shuffledIndices = weightedShuffle(indices: shuffledIndices, weights: weights)
            
        case .intelligent:
            // Intelligent shuffle considers genre, BPM, and mood transitions
            shuffledIndices = intelligentShuffle()
        }
        
        // Ensure current track stays in place if playing
        if let currentIndex = currentTrackIndex {
            shuffledIndices.removeAll { $0 == currentIndex }
            shuffledIndices.insert(currentIndex, at: 0)
        }
    }
    
    /// Weighted shuffle algorithm
    private func weightedShuffle(indices: [Int], weights: [Int]) -> [Int] {
        var result: [Int] = []
        var availableIndices = indices
        var availableWeights = weights
        
        while !availableIndices.isEmpty {
            let totalWeight = availableWeights.reduce(0, +)
            let randomValue = Int.random(in: 0..<totalWeight)
            
            var cumulativeWeight = 0
            for (index, weight) in availableWeights.enumerated() {
                cumulativeWeight += weight
                if randomValue < cumulativeWeight {
                    result.append(availableIndices[index])
                    availableIndices.remove(at: index)
                    availableWeights.remove(at: index)
                    break
                }
            }
        }
        
        return result
    }
    
    /// Intelligent shuffle that considers musical flow
    private func intelligentShuffle() -> [Int] {
        // For now, implement a basic version that groups by genre
        // In a real implementation, this would consider BPM, key, mood, etc.
        var indices = Array(0..<tracks.count)
        
        // Group tracks by genre
        var genreGroups: [String: [Int]] = [:]
        for (index, track) in tracks.enumerated() {
            let genre = track.genre ?? "Unknown"
            genreGroups[genre, default: []].append(index)
        }
        
        // Shuffle within genres and then shuffle genre order
        var result: [Int] = []
        for (_, indices) in genreGroups {
            var shuffledIndices = indices
            shuffledIndices.shuffle()
            result.append(contentsOf: shuffledIndices)
        }
        
        return result
    }
    
    /// Select next track in shuffle mode
    private func selectNextShuffledTrack() -> Track? {
        guard !shuffledIndices.isEmpty else { return nil }
        
        let currentShuffleIndex = shuffleHistory.count
        if currentShuffleIndex < shuffledIndices.count {
            let trackIndex = shuffledIndices[currentShuffleIndex]
            currentTrackIndex = trackIndex
            shuffleHistory.append(trackIndex)
            addToHistory()
            updatePlaylistItemStats(at: trackIndex)
            return tracks[trackIndex]
        } else if case .all = repeatMode {
            // Reshuffle for next round
            shuffleHistory.removeAll()
            prepareShuffleOrder()
            return selectNextShuffledTrack()
        }
        
        return nil
    }
    
    /// Select previous track in shuffle mode
    private func selectPreviousShuffledTrack() -> Track? {
        guard !shuffleHistory.isEmpty else { return nil }
        
        if shuffleHistory.count > 1 {
            shuffleHistory.removeLast()
            let previousIndex = shuffleHistory.last!
            currentTrackIndex = previousIndex
            return tracks[previousIndex]
        }
        
        return currentTrack
    }
    
    /// Sort tracks by a given key path
    func sort<T: Comparable>(by keyPath: KeyPath<Track, T>) {
        // Create paired array of tracks and items
        let paired = zip(tracks, playlistItems).map { ($0, $1) }
        let sorted = paired.sorted { $0.0[keyPath: keyPath] < $1.0[keyPath: keyPath] }
        
        tracks = sorted.map { $0.0 }
        playlistItems = sorted.map { $0.1 }
        
        // Update custom order
        for (index, item) in playlistItems.enumerated() {
            playlistItems[index].customOrder = index
        }
        
        // Update current track index
        if let currentTrack = currentTrack,
           let newIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = newIndex
        }
    }
    
    // MARK: - Queue Management
    
    /// Add track to queue
    func addToQueue(_ track: Track) {
        if let item = playlistItems.first(where: { $0.trackId == track.id }) {
            queue.append(item)
        }
    }
    
    /// Add multiple tracks to queue
    func addToQueue(_ tracks: [Track]) {
        for track in tracks {
            addToQueue(track)
        }
    }
    
    /// Clear the queue
    func clearQueue() {
        queue.removeAll()
        queueIndex = nil
    }
    
    /// Get track from queue index
    private func getTrackFromQueueIndex(_ index: Int) -> Track? {
        guard index >= 0 && index < queue.count else { return nil }
        let queueItem = queue[index]
        return tracks.first { $0.id == queueItem.trackId }
    }
    
    // MARK: - History Management
    
    /// Add current track to history
    private func addToHistory() {
        guard let item = currentPlaylistItem else { return }
        
        // Remove any forward history if we're not at the end
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        
        history.append(item)
        historyIndex = history.count - 1
        
        // Limit history size
        if history.count > 100 {
            history.removeFirst()
            historyIndex = history.count - 1
        }
    }
    
    /// Clear history
    func clearHistory() {
        history.removeAll()
        historyIndex = -1
    }
    
    // MARK: - Statistics and Tracking
    
    /// Update playlist item statistics
    private func updatePlaylistItemStats(at index: Int) {
        guard index >= 0 && index < playlistItems.count else { return }
        
        playlistItems[index].playCountInPlaylist += 1
        playlistItems[index].lastPlayedInPlaylist = Date()
        
        metadata.totalPlayCount += 1
        metadata.lastPlayedDate = Date()
    }
    
    /// Set rating for a track
    func setRating(_ rating: Int?, for track: Track) {
        guard let index = playlistItems.firstIndex(where: { $0.trackId == track.id }) else { return }
        playlistItems[index].rating = rating
        metadata.modifiedDate = Date()
    }
    
    /// Add custom tag to track
    func addTag(_ tag: String, to track: Track) {
        guard let index = playlistItems.firstIndex(where: { $0.trackId == track.id }) else { return }
        if !playlistItems[index].customTags.contains(tag) {
            playlistItems[index].customTags.append(tag)
            metadata.modifiedDate = Date()
        }
    }
    
    /// Remove custom tag from track
    func removeTag(_ tag: String, from track: Track) {
        guard let index = playlistItems.firstIndex(where: { $0.trackId == track.id }) else { return }
        playlistItems[index].customTags.removeAll { $0 == tag }
        metadata.modifiedDate = Date()
    }
    
    // MARK: - Validation
    
    /// Validate playlist for missing files and issues
    func validate() -> PlaylistValidationResult {
        var missingFiles: [URL] = []
        var duplicateTrackIds: [UUID] = []
        var incompatibleFormats: [String] = []
        var warnings: [String] = []
        
        // Check for missing files
        for track in tracks {
            if let url = track.fileURL {
                if !FileManager.default.fileExists(atPath: url.path) {
                    missingFiles.append(url)
                }
                
                // Check format compatibility
                let ext = url.pathExtension.lowercased()
                if !Track.supportedExtensions.contains(ext) {
                    incompatibleFormats.append(ext)
                }
            }
        }
        
        // Check for duplicate track IDs
        var seenIds = Set<UUID>()
        for track in tracks {
            if seenIds.contains(track.id) {
                duplicateTrackIds.append(track.id)
            }
            seenIds.insert(track.id)
        }
        
        // Check playlist items consistency
        let trackIds = Set(tracks.map { $0.id })
        let itemTrackIds = Set(playlistItems.map { $0.trackId })
        if trackIds != itemTrackIds {
            warnings.append("Playlist items don't match tracks")
        }
        
        // Check for very large playlists
        if tracks.count > 10000 {
            warnings.append("Playlist contains over 10,000 tracks which may impact performance")
        }
        
        let isValid = missingFiles.isEmpty && duplicateTrackIds.isEmpty && incompatibleFormats.isEmpty
        
        return PlaylistValidationResult(
            isValid: isValid,
            missingFiles: missingFiles,
            duplicateTrackIds: duplicateTrackIds,
            incompatibleFormats: Array(Set(incompatibleFormats)),
            warnings: warnings
        )
    }
    
    /// Remove tracks with missing files
    func removeMissingTracks() {
        let validationResult = validate()
        let missingURLs = Set(validationResult.missingFiles)
        
        // Remove in reverse order to maintain indices
        for index in stride(from: tracks.count - 1, through: 0, by: -1) {
            if let url = tracks[index].fileURL, missingURLs.contains(url) {
                removeTrack(at: index)
            }
        }
    }
    
    /// Find and mark duplicate tracks
    func findDuplicates() -> [(original: Track, duplicates: [Track])] {
        var duplicateGroups: [String: [Track]] = [:]
        
        // Group by title + artist + duration
        for track in tracks {
            let key = "\(track.title.lowercased())_\(track.artist?.lowercased() ?? "")_\(Int(track.duration))"
            duplicateGroups[key, default: []].append(track)
        }
        
        // Filter to only groups with duplicates
        let duplicates = duplicateGroups.values
            .filter { $0.count > 1 }
            .map { tracks -> (original: Track, duplicates: [Track]) in
                let sorted = tracks.sorted { track1, track2 in
                    // Prefer tracks with more metadata
                    let score1 = (track1.album != nil ? 1 : 0) + (track1.year != nil ? 1 : 0) + (track1.albumArtwork != nil ? 1 : 0)
                    let score2 = (track2.album != nil ? 1 : 0) + (track2.year != nil ? 1 : 0) + (track2.albumArtwork != nil ? 1 : 0)
                    return score1 > score2
                }
                return (sorted[0], Array(sorted.dropFirst()))
            }
        
        return duplicates
    }
}

// MARK: - File Format Support

extension Playlist {
    /// Save playlist to M3U format
    func saveAsM3U(to url: URL) throws {
        var m3uContent = "#EXTM3U\n"
        
        for track in tracks {
            if let fileURL = track.fileURL {
                // Add extended info
                m3uContent += "#EXTINF:\(Int(track.duration)),\(track.artist ?? "") - \(track.title)\n"
                // Add file path
                m3uContent += "\(fileURL.path)\n"
            }
        }
        
        try m3uContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Load playlist from M3U format
    static func loadFromM3U(url: URL) throws -> Playlist {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        let playlist = Playlist(name: url.deletingPathExtension().lastPathComponent)
        var tracks: [Track] = []
        
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments (except EXTINF)
            if line.isEmpty || (line.hasPrefix("#") && !line.hasPrefix("#EXTINF:")) {
                continue
            }
            
            // If it's not a comment, it should be a file path
            if !line.hasPrefix("#") {
                let fileURL = URL(fileURLWithPath: line)
                if let track = Track(from: fileURL) {
                    tracks.append(track)
                }
            }
        }
        
        playlist.tracks = tracks
        return playlist
    }
    
    /// Save playlist to PLS format
    func saveAsPLS(to url: URL) throws {
        var plsContent = "[playlist]\n"
        
        for (index, track) in tracks.enumerated() {
            let number = index + 1
            if let fileURL = track.fileURL {
                plsContent += "File\(number)=\(fileURL.path)\n"
                plsContent += "Title\(number)=\(track.artist ?? "") - \(track.title)\n"
                plsContent += "Length\(number)=\(Int(track.duration))\n"
            }
        }
        
        plsContent += "NumberOfEntries=\(tracks.count)\n"
        plsContent += "Version=2\n"
        
        try plsContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Export playlist as JSON
    func exportAsJSON(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    /// Import playlist from JSON
    static func importFromJSON(url: URL) throws -> Playlist {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(Playlist.self, from: data)
    }
}

// MARK: - Supporting Types

/// Playlist statistics
struct PlaylistStatistics {
    let totalTracks: Int
    let totalDuration: TimeInterval
    let totalFileSize: Int64
    let totalPlayCount: Int
    let averageRating: Double
    let uniqueArtists: Int
    let uniqueAlbums: Int
    let uniqueGenres: Int
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let seconds = Int(totalDuration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFileSize)
    }
}

// MARK: - Codable Extensions

extension ShuffleMode: Codable {
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "off": self = .off
        case "random": self = .random
        case "weighted": self = .weighted
        case "intelligent": self = .intelligent
        default: self = .off
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .off: try container.encode("off", forKey: .type)
        case .random: try container.encode("random", forKey: .type)
        case .weighted: try container.encode("weighted", forKey: .type)
        case .intelligent: try container.encode("intelligent", forKey: .type)
        }
    }
}

extension RepeatMode: Codable {
    enum CodingKeys: String, CodingKey {
        case type, start, end
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "off": self = .off
        case "all": self = .all
        case "one": self = .one
        case "abLoop":
            let start = try container.decode(TimeInterval.self, forKey: .start)
            let end = try container.decode(TimeInterval.self, forKey: .end)
            self = .abLoop(start: start, end: end)
        default: self = .off
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .off: try container.encode("off", forKey: .type)
        case .all: try container.encode("all", forKey: .type)
        case .one: try container.encode("one", forKey: .type)
        case .abLoop(let start, let end):
            try container.encode("abLoop", forKey: .type)
            try container.encode(start, forKey: .start)
            try container.encode(end, forKey: .end)
        }
    }
}

extension SmartPlaylistRuleType: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value, comparison
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "artist":
            let value = try container.decode(String.self, forKey: .value)
            self = .artist(value)
        case "album":
            let value = try container.decode(String.self, forKey: .value)
            self = .album(value)
        case "genre":
            let value = try container.decode(String.self, forKey: .value)
            self = .genre(value)
        case "year":
            let value = try container.decode(Int.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .year(value, comparison)
        case "playCount":
            let value = try container.decode(Int.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .playCount(value, comparison)
        case "lastPlayed":
            let value = try container.decode(Date.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .lastPlayed(value, comparison)
        case "dateAdded":
            let value = try container.decode(Date.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .dateAdded(value, comparison)
        case "duration":
            let value = try container.decode(TimeInterval.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .duration(value, comparison)
        case "rating":
            let value = try container.decode(Int.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .rating(value, comparison)
        case "bpm":
            let value = try container.decode(Int.self, forKey: .value)
            let comparison = try container.decode(ComparisonOperator.self, forKey: .comparison)
            self = .bpm(value, comparison)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown rule type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .artist(let value):
            try container.encode("artist", forKey: .type)
            try container.encode(value, forKey: .value)
        case .album(let value):
            try container.encode("album", forKey: .type)
            try container.encode(value, forKey: .value)
        case .genre(let value):
            try container.encode("genre", forKey: .type)
            try container.encode(value, forKey: .value)
        case .year(let value, let comparison):
            try container.encode("year", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        case .playCount(let value, let comparison):
            try container.encode("playCount", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        case .lastPlayed(let value, let comparison):
            try container.encode("lastPlayed", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        case .dateAdded(let value, let comparison):
            try container.encode("dateAdded", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        case .duration(let value, let comparison):
            try container.encode("duration", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        case .rating(let value, let comparison):
            try container.encode("rating", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        case .bpm(let value, let comparison):
            try container.encode("bpm", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(comparison, forKey: .comparison)
        }
    }
}

extension ComparisonOperator: Codable {}

// MARK: - Smart Playlist Support

extension Playlist {
    /// Apply smart playlist rules to filter tracks
    func applySmartRules(_ rules: [SmartPlaylistRule], to allTracks: [Track]) -> [Track] {
        guard !rules.isEmpty else { return allTracks }
        
        var filteredTracks = allTracks
        
        for rule in rules {
            filteredTracks = filteredTracks.filter { track in
                let matches = evaluateRule(rule.ruleType, for: track)
                return rule.isInclude ? matches : !matches
            }
        }
        
        return filteredTracks
    }
    
    /// Evaluate a single rule against a track
    private func evaluateRule(_ ruleType: SmartPlaylistRuleType, for track: Track) -> Bool {
        switch ruleType {
        case .artist(let value):
            return track.artist?.lowercased().contains(value.lowercased()) ?? false
            
        case .album(let value):
            return track.album?.lowercased().contains(value.lowercased()) ?? false
            
        case .genre(let value):
            return track.genre?.lowercased().contains(value.lowercased()) ?? false
            
        case .year(let value, let comparison):
            guard let trackYear = track.year else { return false }
            return compare(trackYear, to: value, using: comparison)
            
        case .playCount(let value, let comparison):
            guard let item = playlistItems.first(where: { $0.trackId == track.id }) else { return false }
            return compare(item.playCountInPlaylist, to: value, using: comparison)
            
        case .lastPlayed(let value, let comparison):
            guard let item = playlistItems.first(where: { $0.trackId == track.id }),
                  let lastPlayed = item.lastPlayedInPlaylist else { return false }
            return compare(lastPlayed, to: value, using: comparison)
            
        case .dateAdded(let value, let comparison):
            guard let item = playlistItems.first(where: { $0.trackId == track.id }) else { return false }
            return compare(item.addedDate, to: value, using: comparison)
            
        case .duration(let value, let comparison):
            return compare(track.duration, to: value, using: comparison)
            
        case .rating(let value, let comparison):
            guard let item = playlistItems.first(where: { $0.trackId == track.id }),
                  let rating = item.rating else { return false }
            return compare(rating, to: value, using: comparison)
            
        case .bpm(let value, let comparison):
            guard let trackBPM = track.bpm else { return false }
            return compare(trackBPM, to: value, using: comparison)
        }
    }
    
    /// Generic comparison helper
    private func compare<T: Comparable>(_ lhs: T, to rhs: T, using op: ComparisonOperator) -> Bool {
        switch op {
        case .equals:
            return lhs == rhs
        case .notEquals:
            return lhs != rhs
        case .greaterThan:
            return lhs > rhs
        case .lessThan:
            return lhs < rhs
        case .contains, .startsWith, .endsWith:
            // These operators are only valid for strings
            return false
        }
    }
    
    /// Update smart playlist with new tracks
    func updateSmartPlaylist(from allTracks: [Track]) {
        guard metadata.isSmartPlaylist,
              let rules = metadata.smartRules else { return }
        
        let filteredTracks = applySmartRules(rules, to: allTracks)
        
        // Clear existing tracks
        clear()
        
        // Add filtered tracks
        addTracks(filteredTracks)
        
        metadata.modifiedDate = Date()
    }
}