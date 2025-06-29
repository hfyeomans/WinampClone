//
//  Track.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Data model representing an audio track.
//

import Foundation
import AVFoundation

/// Represents an audio track with metadata and playback information
struct Track: Identifiable, Equatable, Codable {
    // MARK: - Properties
    
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let genre: String?
    let year: Int?
    let duration: TimeInterval
    let fileURL: URL?
    let trackNumber: Int?
    let albumArtwork: Data?
    
    // Audio format information
    let audioFormat: AudioFormat?
    let audioProperties: AudioProperties?
    
    // Extended metadata
    let albumArtist: String?
    let composer: String?
    let comment: String?
    let lyrics: String?
    let bpm: Int?
    let discNumber: Int?
    let totalDiscs: Int?
    let totalTracks: Int?
    let encoder: String?
    
    // File information
    let fileSize: Int64?
    let dateAdded: Date?
    let lastPlayed: Date?
    let playCount: Int?
    
    // MARK: - Computed Properties
    
    /// Display title (falls back to filename if title is empty)
    var displayTitle: String {
        if !title.isEmpty {
            return title
        } else if let url = fileURL {
            return url.deletingPathExtension().lastPathComponent
        } else {
            return "Unknown Track"
        }
    }
    
    /// Display artist (falls back to "Unknown Artist" if nil)
    var displayArtist: String {
        artist ?? "Unknown Artist"
    }
    
    /// Formatted duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        album: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        duration: TimeInterval,
        fileURL: URL? = nil,
        trackNumber: Int? = nil,
        albumArtwork: Data? = nil,
        audioFormat: AudioFormat? = nil,
        audioProperties: AudioProperties? = nil,
        albumArtist: String? = nil,
        composer: String? = nil,
        comment: String? = nil,
        lyrics: String? = nil,
        bpm: Int? = nil,
        discNumber: Int? = nil,
        totalDiscs: Int? = nil,
        totalTracks: Int? = nil,
        encoder: String? = nil,
        fileSize: Int64? = nil,
        dateAdded: Date? = nil,
        lastPlayed: Date? = nil,
        playCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.duration = duration
        self.fileURL = fileURL
        self.trackNumber = trackNumber
        self.albumArtwork = albumArtwork
        self.audioFormat = audioFormat
        self.audioProperties = audioProperties
        self.albumArtist = albumArtist
        self.composer = composer
        self.comment = comment
        self.lyrics = lyrics
        self.bpm = bpm
        self.discNumber = discNumber
        self.totalDiscs = totalDiscs
        self.totalTracks = totalTracks
        self.encoder = encoder
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.playCount = playCount
    }
    
    /// Initialize from a file URL by reading metadata
    init?(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        self.id = UUID()
        self.fileURL = url
        
        // Initialize extended metadata to nil
        self.audioFormat = nil
        self.audioProperties = nil
        self.albumArtist = nil
        self.composer = nil
        self.comment = nil
        self.lyrics = nil
        self.bpm = nil
        self.discNumber = nil
        self.totalDiscs = nil
        self.totalTracks = nil
        self.encoder = nil
        self.fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        self.dateAdded = Date()
        self.lastPlayed = nil
        self.playCount = nil
        
        // Read metadata from file
        let asset = AVAsset(url: url)
        let metadata = asset.commonMetadata
        
        // Extract title
        if let titleItem = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierTitle
        ).first,
           let title = titleItem.stringValue {
            self.title = title
        } else {
            self.title = url.deletingPathExtension().lastPathComponent
        }
        
        // Extract artist
        self.artist = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtist
        ).first?.stringValue
        
        // Extract album
        self.album = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierAlbumName
        ).first?.stringValue
        
        // Extract genre
        self.genre = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .iTunesMetadataKeyUserGenre
        ).first?.stringValue
        
        // Extract year
        if let yearItem = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .iTunesMetadataKeyReleaseDate
        ).first {
            if let dateValue = yearItem.dateValue {
                let calendar = Calendar.current
                self.year = calendar.component(.year, from: dateValue)
            } else if let numberValue = yearItem.numberValue {
                self.year = numberValue.intValue
            } else {
                self.year = nil
            }
        } else {
            self.year = nil
        }
        
        // Extract track number
        if let trackItem = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .iTunesMetadataKeyTrackNumber
        ).first,
           let trackNumber = trackItem.numberValue {
            self.trackNumber = trackNumber.intValue
        } else {
            self.trackNumber = nil
        }
        
        // Extract artwork
        if let artworkItem = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtwork
        ).first,
           let data = artworkItem.dataValue {
            self.albumArtwork = data
        } else {
            self.albumArtwork = nil
        }
        
        // Calculate duration
        self.duration = asset.duration.seconds
    }
}

// MARK: - Extensions

extension Track {
    /// Supported audio file extensions
    static let supportedExtensions = ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg"]
    
    /// Check if a file extension is supported
    static func isSupported(fileExtension: String) -> Bool {
        supportedExtensions.contains(fileExtension.lowercased())
    }
}