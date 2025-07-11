//
//  MetadataExtractor.swift
//  WinAmpPlayer
//
//  Main metadata extraction orchestrator that delegates to format-specific extractors
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import AVFoundation

/// Main class responsible for extracting metadata from audio files
public class MetadataExtractor {
    
    // MARK: - Properties
    
    private let extractors: [MetadataExtractorProtocol]
    private let cache: MetadataCache
    private let queue = DispatchQueue(label: "com.winampplayer.metadata", attributes: .concurrent)
    
    // MARK: - Singleton
    
    public static let shared = MetadataExtractor()
    
    // MARK: - Initialization
    
    public init(extractors: [MetadataExtractorProtocol]? = nil) {
        self.extractors = extractors ?? [
            ID3TagParser(),
            // Add more extractors here as they're implemented
            // MP4MetadataExtractor(),
            // FLACMetadataExtractor(),
            // OggVorbisExtractor()
        ]
        self.cache = MetadataCache()
    }
    
    // MARK: - Public Methods
    
    /// Extract metadata from an audio file
    /// - Parameter url: The URL of the audio file
    /// - Returns: The extracted metadata
    public func extractMetadata(from url: URL) async throws -> AudioMetadata {
        // Check cache first
        if let cachedMetadata = try await cache.metadata(for: url) {
            return cachedMetadata
        }
        
        // Ensure file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MetadataError.fileNotFound(url)
        }
        
        // Get file extension
        let fileExtension = url.pathExtension.lowercased()
        
        // Find appropriate extractor
        guard let extractor = extractors.first(where: { $0.supportedFormats.contains(fileExtension) }) else {
            // Fallback to AVFoundation if no specific extractor is available
            return try await extractUsingAVFoundation(from: url)
        }
        
        // Extract metadata
        var metadata = try await extractor.extractMetadata(from: url)
        
        // Add file information
        metadata.fileURL = url
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            metadata.fileSize = attributes[.size] as? Int64
            metadata.dateModified = attributes[.modificationDate] as? Date
        }
        metadata.dateAdded = Date()
        
        // Cache the result
        try await cache.store(metadata, for: url)
        
        return metadata
    }
    
    /// Extract artwork from an audio file
    /// - Parameter url: The URL of the audio file
    /// - Returns: Array of artwork found in the file
    public func extractArtwork(from url: URL) async throws -> [AudioArtwork] {
        // Check cache first
        if let cachedArtwork = try await cache.artwork(for: url) {
            return cachedArtwork
        }
        
        // Ensure file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MetadataError.fileNotFound(url)
        }
        
        // Get file extension
        let fileExtension = url.pathExtension.lowercased()
        
        // Find appropriate extractor
        guard let extractor = extractors.first(where: { $0.supportedFormats.contains(fileExtension) }) else {
            // Fallback to AVFoundation if no specific extractor is available
            return try await extractArtworkUsingAVFoundation(from: url)
        }
        
        // Extract artwork
        let artwork = try await extractor.extractArtwork(from: url)
        
        // Cache the result
        try await cache.store(artwork, for: url)
        
        return artwork
    }
    
    /// Extract metadata from multiple files concurrently
    /// - Parameter urls: Array of file URLs
    /// - Returns: Dictionary mapping URLs to their metadata
    public func extractMetadata(from urls: [URL]) async -> [URL: Result<AudioMetadata, Error>] {
        await withTaskGroup(of: (URL, Result<AudioMetadata, Error>).self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let metadata = try await self.extractMetadata(from: url)
                        return (url, .success(metadata))
                    } catch {
                        return (url, .failure(error))
                    }
                }
            }
            
            var results = [URL: Result<AudioMetadata, Error>]()
            for await (url, result) in group {
                results[url] = result
            }
            return results
        }
    }
    
    /// Clear the metadata cache
    public func clearCache() async {
        await cache.clear()
    }
    
    /// Get cache statistics
    public func cacheStatistics() async -> MetadataCache.Statistics {
        await cache.statistics()
    }
    
    // MARK: - Private Methods
    
    /// Fallback metadata extraction using AVFoundation
    private func extractUsingAVFoundation(from url: URL) async throws -> AudioMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let asset = AVAsset(url: url)
                    var metadata = AudioMetadata()
                    
                    // Extract basic metadata
                    let commonMetadata = asset.commonMetadata
                    
                    for item in commonMetadata {
                        guard let key = item.commonKey else { continue }
                        
                        switch key {
                        case .commonKeyTitle:
                            metadata.title = item.stringValue
                        case .commonKeyArtist:
                            metadata.artist = item.stringValue
                        case .commonKeyAlbumName:
                            metadata.album = item.stringValue
                        case .commonKeyCreator:
                            metadata.composer = item.stringValue
                        case .commonKeyType:
                            metadata.genre = item.stringValue
                        case .commonKeyCreationDate:
                            if let dateString = item.stringValue,
                               let year = Int(dateString.prefix(4)) {
                                metadata.year = year
                            }
                        default:
                            break
                        }
                    }
                    
                    // Extract duration
                    let duration = asset.duration
                    if duration.isValid && !duration.isIndefinite {
                        metadata.duration = CMTimeGetSeconds(duration)
                    }
                    
                    // Extract technical information
                    if let track = asset.tracks(withMediaType: .audio).first {
                        let desc = track.formatDescriptions.first
                        if let desc = desc {
                            let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc as! CMAudioFormatDescription)
                            if let audioDesc = audioDesc?.pointee {
                                metadata.sampleRate = Int(audioDesc.mSampleRate)
                                metadata.channels = Int(audioDesc.mChannelsPerFrame)
                            }
                        }
                        
                        // Estimate bitrate
                        if let duration = metadata.duration,
                           duration > 0,
                           let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
                            let bitrate = Int((Double(fileSize) * 8.0) / duration / 1000.0)
                            metadata.bitrate = bitrate
                        }
                    }
                    
                    metadata.fileFormat = url.pathExtension.uppercased()
                    
                    // Check for artwork
                    metadata.hasArtwork = !asset.metadata(forFormat: .iTunesMetadata).filter {
                        $0.commonKey == .commonKeyArtwork
                    }.isEmpty
                    
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: MetadataError.extractionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Fallback artwork extraction using AVFoundation
    private func extractArtworkUsingAVFoundation(from url: URL) async throws -> [AudioArtwork] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let asset = AVAsset(url: url)
                    var artworks: [AudioArtwork] = []
                    
                    // Check iTunes metadata format
                    let iTunesMetadata = asset.metadata(forFormat: .iTunesMetadata)
                    for item in iTunesMetadata {
                        if item.commonKey == .commonKeyArtwork,
                           let data = item.dataValue {
                            let artwork = AudioArtwork(data: data, type: .frontCover)
                            artworks.append(artwork)
                        }
                    }
                    
                    // Check ID3 metadata format
                    let id3Metadata = asset.metadata(forFormat: .id3Metadata)
                    for item in id3Metadata {
                        if let data = item.dataValue,
                           let key = item.key as? String,
                           key.hasPrefix("APIC") {
                            let artwork = AudioArtwork(data: data, type: .frontCover)
                            artworks.append(artwork)
                        }
                    }
                    
                    continuation.resume(returning: artworks)
                } catch {
                    continuation.resume(throwing: MetadataError.extractionFailed(error.localizedDescription))
                }
            }
        }
    }
}

// MARK: - Metadata Cache

/// Cache for storing extracted metadata and artwork
private actor MetadataCache {
    private var metadataCache: [MetadataCacheKey: AudioMetadata] = [:]
    private var artworkCache: [MetadataCacheKey: [AudioArtwork]] = [:]
    private let maxCacheSize = 1000
    private let cacheQueue = DispatchQueue(label: "com.winampplayer.metadata.cache")
    
    struct Statistics {
        let metadataCount: Int
        let artworkCount: Int
        let totalSize: Int
    }
    
    func metadata(for url: URL) async throws -> AudioMetadata? {
        guard let modDate = modificationDate(for: url) else { return nil }
        let key = MetadataCacheKey(url: url, modificationDate: modDate)
        return metadataCache[key]
    }
    
    func artwork(for url: URL) async throws -> [AudioArtwork]? {
        guard let modDate = modificationDate(for: url) else { return nil }
        let key = MetadataCacheKey(url: url, modificationDate: modDate)
        return artworkCache[key]
    }
    
    func store(_ metadata: AudioMetadata, for url: URL) async throws {
        guard let modDate = modificationDate(for: url) else { return }
        let key = MetadataCacheKey(url: url, modificationDate: modDate)
        
        // Implement LRU eviction if cache is too large
        if metadataCache.count >= maxCacheSize {
            if let oldestKey = metadataCache.keys.first {
                metadataCache.removeValue(forKey: oldestKey)
            }
        }
        
        metadataCache[key] = metadata
    }
    
    func store(_ artwork: [AudioArtwork], for url: URL) async throws {
        guard let modDate = modificationDate(for: url) else { return }
        let key = MetadataCacheKey(url: url, modificationDate: modDate)
        
        // Implement LRU eviction if cache is too large
        if artworkCache.count >= maxCacheSize {
            if let oldestKey = artworkCache.keys.first {
                artworkCache.removeValue(forKey: oldestKey)
            }
        }
        
        artworkCache[key] = artwork
    }
    
    func clear() async {
        metadataCache.removeAll()
        artworkCache.removeAll()
    }
    
    func statistics() async -> Statistics {
        let artworkSize = artworkCache.values.flatMap { $0 }.reduce(0) { $0 + $1.data.count }
        return Statistics(
            metadataCount: metadataCache.count,
            artworkCount: artworkCache.count,
            totalSize: artworkSize
        )
    }
    
    private func modificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}