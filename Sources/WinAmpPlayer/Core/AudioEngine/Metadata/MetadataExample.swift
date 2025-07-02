//
//  MetadataExample.swift
//  WinAmpPlayer
//
//  Example usage of the metadata extraction system
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class MetadataExample {
    
    static func demonstrateUsage() async {
        let extractor = MetadataExtractor.shared
        
        // Example 1: Extract metadata from a single file
        let mp3URL = URL(fileURLWithPath: "/path/to/your/music.mp3")
        
        do {
            // Extract metadata
            let metadata = try await extractor.extractMetadata(from: mp3URL)
            
            print("Title: \(metadata.displayTitle)")
            print("Artist: \(metadata.displayArtist)")
            print("Album: \(metadata.album ?? "Unknown")")
            print("Year: \(metadata.year ?? 0)")
            print("Duration: \(metadata.duration ?? 0) seconds")
            print("Bitrate: \(metadata.bitrate ?? 0) kbps")
            
            // Extract artwork
            let artworks = try await extractor.extractArtwork(from: mp3URL)
            if let firstArtwork = artworks.first,
               let image = firstArtwork.image {
                print("Found artwork: \(image.size)")
            }
            
        } catch {
            print("Error extracting metadata: \(error)")
        }
        
        // Example 2: Extract metadata from multiple files
        let musicFolder = URL(fileURLWithPath: "/path/to/music/folder")
        let mp3Files = try? FileManager.default.contentsOfDirectory(
            at: musicFolder,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "mp3" }
        
        if let files = mp3Files {
            let results = await extractor.extractMetadata(from: files)
            
            for (url, result) in results {
                switch result {
                case .success(let metadata):
                    print("\(url.lastPathComponent): \(metadata.displayTitle) - \(metadata.displayArtist)")
                case .failure(let error):
                    print("\(url.lastPathComponent): Failed - \(error)")
                }
            }
        }
        
        // Example 3: Cache statistics
        let stats = await extractor.cacheStatistics()
        print("Cache contains \(stats.metadataCount) metadata entries")
        print("Cache contains \(stats.artworkCount) artwork entries")
        print("Total cache size: \(stats.totalSize / 1024 / 1024) MB")
    }
    
    // Example: Creating a custom metadata extractor for a new format
    static func demonstrateCustomExtractor() {
        // Define a custom extractor for a hypothetical format
        class CustomFormatExtractor: MetadataExtractorProtocol {
            var supportedFormats: [String] {
                ["custom", "myformat"]
            }
            
            func extractMetadata(from url: URL) async throws -> AudioMetadata {
                var metadata = AudioMetadata()
                metadata.title = "Custom Format Title"
                metadata.artist = "Custom Artist"
                // ... implement actual extraction logic
                return metadata
            }
            
            func extractArtwork(from url: URL) async throws -> [AudioArtwork] {
                // ... implement artwork extraction
                return []
            }
        }
        
        // Create extractor with custom format support
        let customExtractor = MetadataExtractor(extractors: [
            ID3TagParser(),
            CustomFormatExtractor()
            // Add more extractors as needed
        ])
    }
}

// MARK: - Integration with Track model

extension Track {
    /// Populate this track with metadata from the file
    mutating func loadMetadata() async throws {
        let metadata = try await MetadataExtractor.shared.extractMetadata(from: url)
        
        // Update track properties with extracted metadata
        self.title = metadata.displayTitle
        self.artist = metadata.displayArtist
        self.album = metadata.album ?? ""
        self.duration = metadata.duration ?? 0
        
        // Note: You might want to add more properties to the Track model
        // to store additional metadata like genre, year, etc.
    }
    
    /// Get artwork for this track
    #if canImport(UIKit)
    func getArtwork() async throws -> UIImage? {
        let artworks = try await MetadataExtractor.shared.extractArtwork(from: url)
        return artworks.first?.image
    }
    #elseif canImport(AppKit)
    func getArtwork() async throws -> NSImage? {
        let artworks = try await MetadataExtractor.shared.extractArtwork(from: url)
        return artworks.first?.image
    }
    #endif
}