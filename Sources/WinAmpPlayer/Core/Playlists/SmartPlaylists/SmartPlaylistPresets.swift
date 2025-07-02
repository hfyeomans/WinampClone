//
//  SmartPlaylistPresets.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Common smart playlist presets for easy setup.
//

import Foundation

/// Provides common smart playlist presets
public struct SmartPlaylistPresets {
    
    // MARK: - Recently Added
    
    /// Playlist of tracks added in the last N days
    public static func recentlyAdded(days: Int = 30) -> SmartPlaylist {
        let rule = FilePropertyRule(
            field: .dateAdded,
            operator: .greaterThanOrEqual,
            dateValue: Double(days),
            unit: .days
        )
        
        return SmartPlaylist(
            name: "Recently Added",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .dateAdded, ascending: false),
            limit: nil
        )
    }
    
    /// Playlist of the newest 50 tracks
    public static func newestTracks(limit: Int = 50) -> SmartPlaylist {
        // Match all tracks
        let rule = StringMetadataRule(
            field: .title,
            operator: .notEquals,
            value: "___impossible_title___"
        )
        
        return SmartPlaylist(
            name: "Newest \(limit) Tracks",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .dateAdded, ascending: false),
            limit: limit
        )
    }
    
    // MARK: - Most Played
    
    /// Playlist of most played tracks
    public static func mostPlayed(minimumPlays: Int = 5, limit: Int = 100) -> SmartPlaylist {
        let rule = PlayStatisticsRule(
            field: .playCount,
            operator: .greaterThanOrEqual,
            count: minimumPlays
        )
        
        return SmartPlaylist(
            name: "Most Played",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .playCount, ascending: false),
            limit: limit
        )
    }
    
    /// Playlist of your top tracks (high play count)
    public static func topTracks(limit: Int = 25) -> SmartPlaylist {
        let rule = PlayStatisticsRule(
            field: .playCount,
            operator: .greaterThan,
            count: 0
        )
        
        return SmartPlaylist(
            name: "Top \(limit) Tracks",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .playCount, ascending: false),
            limit: limit
        )
    }
    
    // MARK: - Never/Recently Played
    
    /// Playlist of tracks that have never been played
    public static var neverPlayed: SmartPlaylist {
        let rule = PlayStatisticsRule(
            field: .playCount,
            operator: .equals,
            count: 0
        )
        
        return SmartPlaylist(
            name: "Never Played",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .dateAdded, ascending: true),
            limit: nil
        )
    }
    
    /// Playlist of tracks not played in the last N days
    public static func notRecentlyPlayed(days: Int = 30) -> SmartPlaylist {
        let notPlayedRecently = PlayStatisticsRule(
            field: .lastPlayed,
            operator: .lessThan,
            dateValue: Double(days),
            unit: .days
        )
        
        let neverPlayed = PlayStatisticsRule(
            field: .playCount,
            operator: .equals,
            count: 0
        )
        
        let rule = CombinedRule(
            operator: .or,
            rules: [notPlayedRecently, neverPlayed]
        )
        
        return SmartPlaylist(
            name: "Not Recently Played",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .lastPlayed, ascending: true),
            limit: nil
        )
    }
    
    /// Playlist of recently played tracks
    public static func recentlyPlayed(days: Int = 7, limit: Int = 50) -> SmartPlaylist {
        let rule = PlayStatisticsRule(
            field: .lastPlayed,
            operator: .greaterThanOrEqual,
            dateValue: Double(days),
            unit: .days
        )
        
        return SmartPlaylist(
            name: "Recently Played",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .lastPlayed, ascending: false),
            limit: limit
        )
    }
    
    // MARK: - Top Rated
    
    /// Playlist of top rated tracks
    public static func topRated(minimumRating: Int = 4, limit: Int? = nil) -> SmartPlaylist {
        // Note: Rating functionality would need to be implemented in Track model
        let rule = PlayStatisticsRule(
            field: .rating,
            operator: .greaterThanOrEqual,
            count: minimumRating
        )
        
        return SmartPlaylist(
            name: "Top Rated",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .playCount, ascending: false),
            limit: limit
        )
    }
    
    // MARK: - Random Mix
    
    /// Random mix of tracks
    public static func randomMix(limit: Int = 100) -> SmartPlaylist {
        // Match all tracks
        let rule = StringMetadataRule(
            field: .title,
            operator: .notEquals,
            value: "___impossible_title___"
        )
        
        return SmartPlaylist(
            name: "Random Mix",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .random, ascending: true),
            limit: limit
        )
    }
    
    /// Random mix from specific genre
    public static func genreMix(genre: String, limit: Int = 50) -> SmartPlaylist {
        let rule = StringMetadataRule(
            field: .genre,
            operator: .equals,
            value: genre,
            caseSensitive: false
        )
        
        return SmartPlaylist(
            name: "\(genre) Mix",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .random, ascending: true),
            limit: limit
        )
    }
    
    // MARK: - Artist/Album Based
    
    /// All tracks by a specific artist
    public static func byArtist(_ artist: String) -> SmartPlaylist {
        let rule = StringMetadataRule(
            field: .artist,
            operator: .equals,
            value: artist,
            caseSensitive: false
        )
        
        return SmartPlaylist(
            name: artist,
            rule: rule,
            sorting: SmartPlaylistSorting(field: .album, ascending: true),
            limit: nil
        )
    }
    
    /// All tracks from a specific album
    public static func byAlbum(_ album: String, artist: String? = nil) -> SmartPlaylist {
        let albumRule = StringMetadataRule(
            field: .album,
            operator: .equals,
            value: album,
            caseSensitive: false
        )
        
        if let artist = artist {
            let artistRule = StringMetadataRule(
                field: .artist,
                operator: .equals,
                value: artist,
                caseSensitive: false
            )
            
            let rule = CombinedRule(
                operator: .and,
                rules: [albumRule, artistRule]
            )
            
            return SmartPlaylist(
                name: "\(album) - \(artist)",
                rule: rule,
                sorting: SmartPlaylistSorting(field: .title, ascending: true),
                limit: nil
            )
        } else {
            return SmartPlaylist(
                name: album,
                rule: albumRule,
                sorting: SmartPlaylistSorting(field: .title, ascending: true),
                limit: nil
            )
        }
    }
    
    // MARK: - Year Based
    
    /// Tracks from a specific year
    public static func fromYear(_ year: Int) -> SmartPlaylist {
        let rule = NumericMetadataRule(
            field: .year,
            operator: .equals,
            value: Double(year)
        )
        
        return SmartPlaylist(
            name: "\(year)",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .artist, ascending: true),
            limit: nil
        )
    }
    
    /// Tracks from a decade (e.g., 1980s)
    public static func fromDecade(_ decade: Int) -> SmartPlaylist {
        let rule = NumericMetadataRule(
            field: .year,
            operator: .between,
            value: Double(decade),
            secondValue: Double(decade + 9)
        )
        
        return SmartPlaylist(
            name: "\(decade)s",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .year, ascending: true),
            limit: nil
        )
    }
    
    // MARK: - Format Based
    
    /// High quality audio tracks (lossless formats)
    public static var losslessAudio: SmartPlaylist {
        let rule = FilePropertyRule(
            field: .format,
            operator: .inList,
            format: .flac // This will be converted to string list
        )
        
        // Note: In practice, you'd create a rule that checks for multiple formats
        // like FLAC, ALAC, WAV, AIFF
        return SmartPlaylist(
            name: "Lossless Audio",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .artist, ascending: true),
            limit: nil
        )
    }
    
    // MARK: - Duration Based
    
    /// Short tracks (under 3 minutes)
    public static var shortTracks: SmartPlaylist {
        let rule = NumericMetadataRule(
            field: .duration,
            operator: .lessThan,
            value: 180 // 3 minutes in seconds
        )
        
        return SmartPlaylist(
            name: "Short Tracks",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .duration, ascending: true),
            limit: nil
        )
    }
    
    /// Long tracks (over 6 minutes)
    public static var longTracks: SmartPlaylist {
        let rule = NumericMetadataRule(
            field: .duration,
            operator: .greaterThan,
            value: 360 // 6 minutes in seconds
        )
        
        return SmartPlaylist(
            name: "Long Tracks",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .duration, ascending: false),
            limit: nil
        )
    }
    
    // MARK: - Complex Examples
    
    /// Workout mix: High energy tracks with BPM > 120
    public static func workoutMix(minimumBPM: Int = 120, limit: Int = 60) -> SmartPlaylist {
        let bpmRule = NumericMetadataRule(
            field: .bpm,
            operator: .greaterThan,
            value: Double(minimumBPM)
        )
        
        return SmartPlaylist(
            name: "Workout Mix",
            rule: bpmRule,
            sorting: SmartPlaylistSorting(field: .random, ascending: true),
            limit: limit
        )
    }
    
    /// Discovery playlist: Never played tracks from favorite artists
    public static func discovery(favoriteArtists: [String]) -> SmartPlaylist {
        let neverPlayedRule = PlayStatisticsRule(
            field: .playCount,
            operator: .equals,
            count: 0
        )
        
        let artistsValue = favoriteArtists.joined(separator: ",")
        let artistRule = StringMetadataRule(
            field: .artist,
            operator: .inList,
            value: artistsValue,
            caseSensitive: false
        )
        
        let rule = CombinedRule(
            operator: .and,
            rules: [neverPlayedRule, artistRule]
        )
        
        return SmartPlaylist(
            name: "Discovery",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .random, ascending: true),
            limit: 25
        )
    }
    
    /// Recently added albums (complete albums added in last 30 days)
    public static func recentAlbums(days: Int = 30) -> SmartPlaylist {
        let dateRule = FilePropertyRule(
            field: .dateAdded,
            operator: .greaterThanOrEqual,
            dateValue: Double(days),
            unit: .days
        )
        
        // Note: This would ideally group by album, but for now returns all tracks
        return SmartPlaylist(
            name: "Recent Albums",
            rule: dateRule,
            sorting: SmartPlaylistSorting(field: .album, ascending: true),
            limit: nil
        )
    }
    
    // MARK: - Helper Methods
    
    /// Creates a smart playlist that combines multiple genres
    public static func multiGenrePlaylist(genres: [String], name: String? = nil) -> SmartPlaylist {
        let genreList = genres.joined(separator: ",")
        let rule = StringMetadataRule(
            field: .genre,
            operator: .inList,
            value: genreList,
            caseSensitive: false
        )
        
        let playlistName = name ?? genres.joined(separator: " / ")
        
        return SmartPlaylist(
            name: playlistName,
            rule: rule,
            sorting: SmartPlaylistSorting(field: .random, ascending: true),
            limit: nil
        )
    }
    
    /// Creates a "best of" playlist for an artist
    public static func bestOf(artist: String, minimumPlayCount: Int = 3, limit: Int = 20) -> SmartPlaylist {
        let artistRule = StringMetadataRule(
            field: .artist,
            operator: .equals,
            value: artist,
            caseSensitive: false
        )
        
        let playCountRule = PlayStatisticsRule(
            field: .playCount,
            operator: .greaterThanOrEqual,
            count: minimumPlayCount
        )
        
        let rule = CombinedRule(
            operator: .and,
            rules: [artistRule, playCountRule]
        )
        
        return SmartPlaylist(
            name: "Best of \(artist)",
            rule: rule,
            sorting: SmartPlaylistSorting(field: .playCount, ascending: false),
            limit: limit
        )
    }
}