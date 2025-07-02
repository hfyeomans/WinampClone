//
//  MetadataProtocol.swift
//  WinAmpPlayer
//
//  Defines the unified protocol for metadata extraction across different audio formats
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Represents metadata extracted from an audio file
public struct AudioMetadata: Equatable, Codable {
    // Basic metadata
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var composer: String?
    public var year: Int?
    public var genre: String?
    public var trackNumber: Int?
    public var totalTracks: Int?
    public var discNumber: Int?
    public var totalDiscs: Int?
    
    // Additional metadata
    public var comment: String?
    public var lyrics: String?
    public var bpm: Int?
    public var isrc: String? // International Standard Recording Code
    public var publisher: String?
    public var copyright: String?
    public var encodedBy: String?
    
    // Technical metadata
    public var duration: TimeInterval?
    public var bitrate: Int? // in kbps
    public var sampleRate: Int? // in Hz
    public var channels: Int?
    public var fileFormat: String?
    
    // Artwork (stored separately to avoid encoding large data)
    public var hasArtwork: Bool = false
    
    // File information
    public var fileURL: URL?
    public var fileSize: Int64?
    public var dateAdded: Date?
    public var dateModified: Date?
    
    public init() {}
    
    /// Generates a display title, falling back to filename if no title metadata exists
    public var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        
        if let url = fileURL {
            let filename = url.deletingPathExtension().lastPathComponent
            // Clean up common patterns in filenames
            let cleaned = filename
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " - ")
            return cleaned
        }
        
        return "Unknown"
    }
    
    /// Generates a display artist
    public var displayArtist: String {
        artist ?? albumArtist ?? "Unknown Artist"
    }
}

/// Represents album artwork extracted from audio files
public struct AudioArtwork: Equatable {
    public let data: Data
    public let mimeType: String?
    public let type: ArtworkType
    
    public enum ArtworkType: String, Codable {
        case frontCover = "Front Cover"
        case backCover = "Back Cover"
        case artist = "Artist"
        case other = "Other"
    }
    
    /// Converts the artwork data to a platform image
    #if canImport(UIKit)
    public var image: UIImage? {
        UIImage(data: data)
    }
    #elseif canImport(AppKit)
    public var image: NSImage? {
        NSImage(data: data)
    }
    #endif
    
    public init(data: Data, mimeType: String? = nil, type: ArtworkType = .frontCover) {
        self.data = data
        self.mimeType = mimeType
        self.type = type
    }
}

/// Protocol for format-specific metadata extractors
public protocol MetadataExtractorProtocol {
    /// The audio formats this extractor supports (e.g., ["mp3", "mp4", "m4a"])
    var supportedFormats: [String] { get }
    
    /// Extract metadata from the given file URL
    func extractMetadata(from url: URL) async throws -> AudioMetadata
    
    /// Extract artwork from the given file URL
    func extractArtwork(from url: URL) async throws -> [AudioArtwork]
}

/// Errors that can occur during metadata extraction
public enum MetadataError: LocalizedError {
    case unsupportedFormat(String)
    case fileNotFound(URL)
    case corruptedMetadata
    case extractionFailed(String)
    case noMetadataFound
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format)"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .corruptedMetadata:
            return "The metadata appears to be corrupted"
        case .extractionFailed(let reason):
            return "Failed to extract metadata: \(reason)"
        case .noMetadataFound:
            return "No metadata found in file"
        }
    }
}

/// Cache key for metadata storage
public struct MetadataCacheKey: Hashable {
    public let url: URL
    public let modificationDate: Date
    
    public init(url: URL, modificationDate: Date) {
        self.url = url
        self.modificationDate = modificationDate
    }
}