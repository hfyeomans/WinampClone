//
//  FileLoader.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Unified file loading system that integrates format detection, validation, metadata extraction, and decoding.
//

import Foundation
import AVFoundation
import Combine
import os.log

/// Result of loading an audio file
public struct AudioFileLoadResult {
    /// The loaded track with all metadata
    let track: Track
    
    /// The decoder ready for playback
    let decoder: AudioDecoder
    
    /// Detailed format information
    let formatInfo: AudioFormatInfo
    
    /// Any warnings encountered during loading
    let warnings: [String]
}

/// Unified file loader that handles format detection, validation, metadata extraction, and decoder creation
public class FileLoader {
    
    // MARK: - Properties
    
    private let formatDetector: FormatDetector
    private let formatValidator: FormatValidator
    private let metadataExtractor: MetadataExtractor
    private let logger = Logger(subsystem: "com.winamp.player", category: "FileLoader")
    
    // MARK: - Initialization
    
    public init() {
        self.formatDetector = FormatDetector()
        self.formatValidator = FormatValidator()
        self.metadataExtractor = MetadataExtractor()
    }
    
    // MARK: - Public Methods
    
    /// Load an audio file from the given URL
    /// - Parameter url: The URL of the audio file to load
    /// - Returns: AudioFileLoadResult containing the track, decoder, and format info
    /// - Throws: Various errors if loading fails
    public func loadAudioFile(at url: URL) async throws -> AudioFileLoadResult {
        logger.info("Loading audio file at: \(url.path)")
        
        // Step 1: Validate file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileLoaderError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileLoaderError.fileNotAccessible(url)
        }
        
        // Step 2: Detect format
        let formatInfo = try await detectFormat(at: url)
        logger.info("Detected format: \(formatInfo.format.displayName) with confidence: \(formatInfo.confidence)")
        
        // Step 3: Validate format
        let validationResult = try await validateFormat(at: url, format: formatInfo.format)
        if !validationResult.isValid {
            var errorMessages: [String] = []
            
            // Extract error messages from validation details
            for error in validationResult.details.formatValidation.errors {
                errorMessages.append(error.localizedDescription)
            }
            
            for error in validationResult.details.integrityCheck.errors {
                errorMessages.append(error.localizedDescription)
            }
            
            throw FileLoaderError.invalidFormat(errorMessages)
        }
        
        var warnings: [String] = []
        
        // Add validation issues as warnings if any
        for issue in validationResult.issues {
            switch issue {
            case .formatMismatch:
                warnings.append("Format mismatch detected")
            case .structureErrors(let errors):
                for error in errors {
                    warnings.append("Structure error: \(error.localizedDescription)")
                }
            case .integrityErrors(let errors):
                for error in errors {
                    warnings.append("Integrity error: \(error.localizedDescription)")
                }
            }
        }
        
        // Step 4: Extract metadata
        let metadata = try await extractMetadata(at: url, format: formatInfo.format)
        
        // Step 5: Create decoder
        let decoder = try await createDecoder(for: url, format: formatInfo.format)
        
        // Step 6: Build track object
        let track = try buildTrack(
            from: url,
            metadata: metadata,
            format: formatInfo.format,
            properties: formatInfo.properties,
            decoder: decoder
        )
        
        // Step 7: Return result
        return AudioFileLoadResult(
            track: track,
            decoder: decoder,
            formatInfo: formatInfo,
            warnings: warnings
        )
    }
    
    /// Load multiple audio files in parallel
    /// - Parameter urls: Array of file URLs to load
    /// - Returns: Array of successfully loaded results and array of errors
    public func loadAudioFiles(at urls: [URL]) async -> (results: [AudioFileLoadResult], errors: [(URL, Error)]) {
        var results: [AudioFileLoadResult] = []
        var errors: [(URL, Error)] = []
        
        await withTaskGroup(of: (URL, Result<AudioFileLoadResult, Error>).self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let result = try await self.loadAudioFile(at: url)
                        return (url, .success(result))
                    } catch {
                        return (url, .failure(error))
                    }
                }
            }
            
            for await (url, result) in group {
                switch result {
                case .success(let loadResult):
                    results.append(loadResult)
                case .failure(let error):
                    errors.append((url, error))
                }
            }
        }
        
        return (results, errors)
    }
    
    // MARK: - Private Methods
    
    private func detectFormat(at url: URL) async throws -> AudioFormatInfo {
        return try await formatDetector.detectFormat(from: url)
    }
    
    private func validateFormat(at url: URL, format: AudioFormat) async throws -> ValidationResult {
        return try await formatValidator.validate(url: url, expectedFormat: format)
    }
    
    private func extractMetadata(at url: URL, format: AudioFormat) async throws -> AudioMetadata {
        return try await metadataExtractor.extractMetadata(from: url)
    }
    
    private func createDecoder(for url: URL, format: AudioFormat) async throws -> AudioDecoder {
        return try await AudioDecoderFactory.createDecoder(for: url, format: format)
    }
    
    private func buildTrack(
        from url: URL,
        metadata: AudioMetadata,
        format: AudioFormat,
        properties: AudioProperties?,
        decoder: AudioDecoder
    ) throws -> Track {
        // Get file attributes
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64
        
        // Use decoder duration if available, otherwise fall back to metadata
        let duration = decoder.duration > 0 ? decoder.duration : metadata.duration ?? 0
        
        // Create track with all available information
        return Track(
            id: UUID(),
            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
            artist: metadata.artist,
            album: metadata.album,
            genre: metadata.genre,
            year: metadata.year != nil ? Int(metadata.year!) : nil,
            duration: duration,
            fileURL: url,
            trackNumber: metadata.trackNumber != nil ? Int(metadata.trackNumber!) : nil,
            albumArtwork: nil, // AudioMetadata doesn't store artwork data
            audioFormat: format,
            audioProperties: properties,
            albumArtist: metadata.albumArtist,
            composer: metadata.composer,
            comment: metadata.comment,
            lyrics: metadata.lyrics,
            bpm: metadata.bpm != nil ? Int(metadata.bpm!) : nil,
            discNumber: metadata.discNumber != nil ? Int(metadata.discNumber!) : nil,
            totalDiscs: metadata.totalDiscs != nil ? Int(metadata.totalDiscs!) : nil,
            totalTracks: metadata.totalTracks != nil ? Int(metadata.totalTracks!) : nil,
            encoder: metadata.encodedBy,
            fileSize: fileSize,
            dateAdded: Date(),
            lastPlayed: nil,
            playCount: 0
        )
    }
    
    // MARK: - Helper Methods
    
    /// Check if a file is likely to be an audio file based on extension
    public static func isAudioFile(at url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return AudioFormat(fileExtension: fileExtension) != .unknown
    }
    
    /// Get all audio files in a directory
    public static func findAudioFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        return contents.filter { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
                return resourceValues.isRegularFile == true && isAudioFile(at: url)
            } catch {
                return false
            }
        }
    }
}

// MARK: - Errors

/// Errors that can occur during file loading
public enum FileLoaderError: LocalizedError {
    case fileNotFound(URL)
    case fileNotAccessible(URL)
    case invalidFormat([String])
    case metadataExtractionFailed(Error)
    case decoderCreationFailed(Error)
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileNotAccessible(let url):
            return "File not accessible: \(url.lastPathComponent)"
        case .invalidFormat(let errors):
            return "Invalid format: \(errors.joined(separator: ", "))"
        case .metadataExtractionFailed(let error):
            return "Failed to extract metadata: \(error.localizedDescription)"
        case .decoderCreationFailed(let error):
            return "Failed to create decoder: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions

extension FileLoader {
    
    /// Convenience method to load a file and prepare it for playback
    /// - Parameter url: The URL of the audio file
    /// - Returns: A tuple containing the track and decoder
    public func prepareForPlayback(url: URL) async throws -> (track: Track, decoder: AudioDecoder) {
        let result = try await loadAudioFile(at: url)
        
        // Log any warnings
        for warning in result.warnings {
            logger.warning("File loading warning: \(warning)")
        }
        
        return (result.track, result.decoder)
    }
    
    /// Load a playlist file (M3U, PLS, etc.)
    /// - Parameter url: The URL of the playlist file
    /// - Returns: Array of track URLs found in the playlist
    public func loadPlaylist(at url: URL) async throws -> [URL] {
        // This is a placeholder for playlist loading functionality
        // Would need to implement M3U/PLS parsing
        throw FileLoaderError.unknownError(NSError(domain: "FileLoader", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Playlist loading not yet implemented"
        ]))
    }
}