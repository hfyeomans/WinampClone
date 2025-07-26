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
public struct Track: Identifiable, Equatable, Codable, Hashable {
    // MARK: - Properties
    
    public let id: UUID
    public let title: String
    public let artist: String?
    public let album: String?
    public let genre: String?
    public let year: Int?
    public let duration: TimeInterval
    public let fileURL: URL?
    public let trackNumber: Int?
    public let albumArtwork: Data?
    
    // Audio format information
    public let audioFormat: AudioFormat?
    public let audioProperties: AudioProperties?
    
    // Extended metadata
    public let albumArtist: String?
    public let composer: String?
    public let comment: String?
    public let lyrics: String?
    public let bpm: Int?
    public let discNumber: Int?
    public let totalDiscs: Int?
    public let totalTracks: Int?
    public let encoder: String?
    
    // File information
    public let fileSize: Int64?
    public let dateAdded: Date?
    public let lastPlayed: Date?
    public let playCount: Int?
    
    // MARK: - Computed Properties
    
    /// Display title (falls back to filename if title is empty)
    public var displayTitle: String {
        if !title.isEmpty {
            return title
        } else if let url = fileURL {
            return url.deletingPathExtension().lastPathComponent
        } else {
            return "Unknown Track"
        }
    }
    
    /// Display artist (falls back to "Unknown Artist" if nil)
    public var displayArtist: String {
        artist ?? "Unknown Artist"
    }
    
    /// Formatted duration string (MM:SS)
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    
    public init(
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
        
        // Set default values - metadata will be loaded asynchronously
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = nil
        self.album = nil
        self.genre = nil
        self.year = nil
        self.trackNumber = nil
        self.albumArtwork = nil
        self.duration = 0
        
        // Note: Cannot load metadata asynchronously in struct initializer
        // Metadata should be loaded externally and passed to init
        // Task {
        //     await loadMetadata()
        // }
    }
    
    /// Load metadata asynchronously
    /// Note: This method cannot work as designed because Track is a struct
    /// and properties are immutable. Metadata loading should be done externally.
    /*
    private func loadMetadata() async {
        guard let url = fileURL else { return }
        let asset = AVAsset(url: url)
        
        do {
            // Load common metadata
            let metadata = try await asset.load(.commonMetadata)
            
            // Extract title
            if let titleItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierTitle
            ).first,
               let title = try? await titleItem.load(.stringValue) {
                self.title = title
            }
            
            // Extract artist
            if let artistItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierArtist
            ).first,
               let artist = try? await artistItem.load(.stringValue) {
                self.artist = artist
            }
            
            // Extract album
            if let albumItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierAlbumName
            ).first,
               let album = try? await albumItem.load(.stringValue) {
                self.album = album
            }
            
            // Extract genre
            if let genreItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .iTunesMetadataKeyUserGenre
            ).first,
               let genre = try? await genreItem.load(.stringValue) {
                self.genre = genre
            }
            
            // Extract year
            if let yearItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .iTunesMetadataKeyReleaseDate
            ).first {
                if let dateValue = try? await yearItem.load(.dateValue) {
                    let calendar = Calendar.current
                    self.year = calendar.component(.year, from: dateValue)
                } else if let numberValue = try? await yearItem.load(.numberValue) {
                    self.year = numberValue.intValue
                }
            }
            
            // Extract track number
            if let trackItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .iTunesMetadataKeyTrackNumber
            ).first,
               let trackNumber = try? await trackItem.load(.numberValue) {
                self.trackNumber = trackNumber.intValue
            }
            
            // Extract artwork
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierArtwork
            ).first,
               let data = try? await artworkItem.load(.dataValue) {
                self.albumArtwork = data
            }
            
            // Load duration
            let duration = try await asset.load(.duration)
            self.duration = duration.seconds
        } catch {
            // If loading fails, keep default values
        }
    }
    */
}

// MARK: - Hashable Conformance

extension Track {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        // Only hash the id since it's unique
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