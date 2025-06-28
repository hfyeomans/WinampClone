//
//  Playlist.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Data model representing a playlist of tracks.
//

import Foundation

/// Represents a playlist containing multiple tracks
class Playlist: ObservableObject, Identifiable, Codable {
    // MARK: - Properties
    
    let id: UUID
    @Published var name: String
    @Published var tracks: [Track]
    @Published var currentTrackIndex: Int?
    
    // MARK: - Computed Properties
    
    /// The currently selected track
    var currentTrack: Track? {
        guard let index = currentTrackIndex,
              index >= 0 && index < tracks.count else {
            return nil
        }
        return tracks[index]
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
        tracks: [Track] = []
    ) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.currentTrackIndex = nil
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, tracks, currentTrackIndex
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tracks = try container.decode([Track].self, forKey: .tracks)
        currentTrackIndex = try container.decodeIfPresent(Int.self, forKey: .currentTrackIndex)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tracks, forKey: .tracks)
        try container.encodeIfPresent(currentTrackIndex, forKey: .currentTrackIndex)
    }
    
    // MARK: - Track Management
    
    /// Add a track to the playlist
    func addTrack(_ track: Track) {
        tracks.append(track)
    }
    
    /// Add multiple tracks to the playlist
    func addTracks(_ newTracks: [Track]) {
        tracks.append(contentsOf: newTracks)
    }
    
    /// Insert a track at a specific index
    func insertTrack(_ track: Track, at index: Int) {
        guard index >= 0 && index <= tracks.count else { return }
        tracks.insert(track, at: index)
        
        // Adjust current track index if needed
        if let currentIndex = currentTrackIndex, currentIndex >= index {
            currentTrackIndex = currentIndex + 1
        }
    }
    
    /// Remove a track at a specific index
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
        
        // Adjust current track index if needed
        if let currentIndex = currentTrackIndex {
            if currentIndex == index {
                // Current track was removed
                currentTrackIndex = nil
            } else if currentIndex > index {
                currentTrackIndex = currentIndex - 1
            }
        }
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
        currentTrackIndex = nil
    }
    
    // MARK: - Navigation
    
    /// Select the next track
    func selectNextTrack() -> Track? {
        guard !tracks.isEmpty else { return nil }
        
        if let currentIndex = currentTrackIndex {
            let nextIndex = (currentIndex + 1) % tracks.count
            currentTrackIndex = nextIndex
        } else {
            currentTrackIndex = 0
        }
        
        return currentTrack
    }
    
    /// Select the previous track
    func selectPreviousTrack() -> Track? {
        guard !tracks.isEmpty else { return nil }
        
        if let currentIndex = currentTrackIndex {
            let previousIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
            currentTrackIndex = previousIndex
        } else {
            currentTrackIndex = tracks.count - 1
        }
        
        return currentTrack
    }
    
    /// Select a specific track by index
    func selectTrack(at index: Int) -> Track? {
        guard index >= 0 && index < tracks.count else { return nil }
        currentTrackIndex = index
        return currentTrack
    }
    
    /// Shuffle the playlist
    func shuffle() {
        tracks.shuffle()
        // Reset current track index to maintain the current track
        if let currentTrack = currentTrack,
           let newIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = newIndex
        }
    }
    
    /// Sort tracks by a given key path
    func sort<T: Comparable>(by keyPath: KeyPath<Track, T>) {
        tracks.sort { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
        
        // Update current track index
        if let currentTrack = currentTrack,
           let newIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = newIndex
        }
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
}