//
//  Playlist+Sorting.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Sorting and organization extensions for Playlist
//

import Foundation

/// Playlist sorting field options
enum PlaylistSortField {
    case title
    case artist
    case album
    case duration
}

extension Playlist {
    // MARK: - Sorting
    
    /// Sort tracks by the specified field
    func sortTracks(by field: PlaylistSortField, ascending: Bool = true) {
        let sortedPairs = zip(tracks, playlistItems).sorted { pair1, pair2 in
            let track1 = pair1.0
            let track2 = pair2.0
            
            let comparison: Bool
            switch field {
            case .title:
                comparison = track1.title.localizedCaseInsensitiveCompare(track2.title) == .orderedAscending
            case .artist:
                let artist1 = track1.artist ?? ""
                let artist2 = track2.artist ?? ""
                comparison = artist1.localizedCaseInsensitiveCompare(artist2) == .orderedAscending
            case .album:
                let album1 = track1.album ?? ""
                let album2 = track2.album ?? ""
                comparison = album1.localizedCaseInsensitiveCompare(album2) == .orderedAscending
            case .duration:
                let duration1 = track1.duration
                let duration2 = track2.duration
                comparison = duration1 < duration2
            }
            
            return ascending ? comparison : !comparison
        }
        
        tracks = sortedPairs.map { $0.0 }
        playlistItems = sortedPairs.map { $0.1 }
        
        // Update current track index
        if let currentTrack = currentTrack {
            currentTrackIndex = tracks.firstIndex(where: { $0.id == currentTrack.id })
        }
        
        // Update metadata through proper method if available
    }
    
    /// Shuffle all tracks randomly
    func shuffleTracks() {
        let shuffledIndices = Array(0..<tracks.count).shuffled()
        let shuffledTracks = shuffledIndices.map { tracks[$0] }
        let shuffledItems = shuffledIndices.map { playlistItems[$0] }
        
        tracks = shuffledTracks
        playlistItems = shuffledItems
        
        // Update current track index
        if let currentTrack = currentTrack {
            currentTrackIndex = tracks.firstIndex(where: { $0.id == currentTrack.id })
        }
        
        // Update metadata through proper method if available
    }
    
    /// Move a single track from one position to another
    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0 && sourceIndex < tracks.count,
              destinationIndex >= 0 && destinationIndex <= tracks.count else {
            return
        }
        
        let track = tracks.remove(at: sourceIndex)
        let item = playlistItems.remove(at: sourceIndex)
        
        let insertIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        tracks.insert(track, at: insertIndex)
        playlistItems.insert(item, at: insertIndex)
        
        // Update current track index if affected
        if let currentIndex = currentTrackIndex {
            if currentIndex == sourceIndex {
                currentTrackIndex = insertIndex
            } else if sourceIndex < currentIndex && insertIndex >= currentIndex {
                currentTrackIndex = currentIndex - 1
            } else if sourceIndex > currentIndex && insertIndex <= currentIndex {
                currentTrackIndex = currentIndex + 1
            }
        }
        
        // Update metadata through proper method if available
    }
    
    /// Reverse the order of all tracks
    func reverseTracks() {
        tracks.reverse()
        playlistItems.reverse()
        
        // Update current track index
        if let currentIndex = currentTrackIndex {
            currentTrackIndex = tracks.count - 1 - currentIndex
        }
        
        // Update metadata through proper method if available
    }
}