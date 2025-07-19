//
//  FormatDetector.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Detects audio format from URLs and data with confidence levels.
//

import Foundation
import AVFoundation
import os.log

/// Detects audio formats from various sources
public class FormatDetector {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.winamp.player", category: "FormatDetector")
    private let queue = DispatchQueue(label: "com.winamp.formatdetector", qos: .userInitiated)
    
    // Wrapper class for caching AudioFormatInfo structs
    private final class AudioFormatInfoWrapper {
        let value: AudioFormatInfo
        init(_ value: AudioFormatInfo) {
            self.value = value
        }
    }
    
    // Cache for format detection results
    private var cache = NSCache<NSURL, AudioFormatInfoWrapper>()
    
    // MARK: - Initialization
    
    public init() {
        cache.countLimit = 100  // Cache up to 100 detection results
    }
    
    // MARK: - Public Methods
    
    /// Detect audio format from a URL
    /// - Parameter url: The URL to analyze
    /// - Returns: Audio format information with confidence level
    public func detectFormat(from url: URL) async throws -> AudioFormatInfo {
        // Check cache first
        if let cached = cache.object(forKey: url as NSURL) {
            logger.debug("Using cached format detection for: \(url.lastPathComponent)")
            return cached.value
        }
        
        // Start with file extension detection (fast path)
        let extensionFormat = detectFormatFromExtension(url: url)
        
        // If high confidence from extension and file exists, do quick validation
        if extensionFormat.confidence >= 0.8,
           FileManager.default.fileExists(atPath: url.path) {
            
            // Read first few bytes for magic byte validation
            if let magicFormat = try? await detectFormatFromMagicBytes(url: url) {
                if magicFormat.format == extensionFormat.format {
                    // Extension and magic bytes match - very high confidence
                    let combinedInfo = AudioFormatInfo(
                        format: extensionFormat.format,
                        confidence: min(1.0, extensionFormat.confidence + 0.1),
                        properties: try? await extractAudioProperties(from: url),
                        containerFormat: magicFormat.containerFormat,
                        detectionMethod: .combined
                    )
                    cache.setObject(AudioFormatInfoWrapper(combinedInfo), forKey: url as NSURL)
                    return combinedInfo
                }
            }
        }
        
        // Do deep inspection for more accurate detection
        let deepInfo = try await performDeepInspection(url: url)
        cache.setObject(AudioFormatInfoWrapper(deepInfo), forKey: url as NSURL)
        return deepInfo
    }
    
    /// Detect audio format from data
    /// - Parameter data: The audio data to analyze
    /// - Returns: Audio format information with confidence level
    public func detectFormat(from data: Data) async throws -> AudioFormatInfo {
        // First try magic bytes detection
        let magicFormat = detectFormatFromMagicBytes(data: data)
        
        // If we have high confidence from magic bytes, use it
        if magicFormat.confidence >= 0.9 {
            return magicFormat
        }
        
        // For lower confidence, try to get more information
        // Write to temporary file for AVAsset inspection
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(magicFormat.format.rawValue)
        
        do {
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            return try await performDeepInspection(url: tempURL)
        } catch {
            // Fall back to magic bytes result
            return magicFormat
        }
    }
    
    /// Detect format from MIME type
    /// - Parameter mimeType: The MIME type string
    /// - Returns: Audio format information
    public func detectFormat(fromMimeType mimeType: String) -> AudioFormatInfo {
        let format = AudioFormat(mimeType: mimeType)
        let confidence = format == .unknown ? 0.0 : 0.7
        
        return AudioFormatInfo(
            format: format,
            confidence: confidence,
            properties: nil,
            containerFormat: nil,
            detectionMethod: .mimeType
        )
    }
    
    // MARK: - Private Methods
    
    /// Detect format from file extension
    private func detectFormatFromExtension(url: URL) -> AudioFormatInfo {
        let ext = url.pathExtension.lowercased()
        let format = AudioFormat(fileExtension: ext)
        
        // High confidence for common formats, lower for ambiguous ones
        let confidence: Double
        switch format {
        case .mp3, .flac, .wav, .aiff, .ogg:
            confidence = 0.8
        case .m4a:
            confidence = 0.7  // Could be AAC or ALAC
        case .aac:
            confidence = 0.75
        case .unknown:
            confidence = 0.0
        default:
            confidence = 0.6
        }
        
        return AudioFormatInfo(
            format: format,
            confidence: confidence,
            properties: nil,
            containerFormat: nil,
            detectionMethod: .fileExtension
        )
    }
    
    /// Detect format from magic bytes in file
    private func detectFormatFromMagicBytes(url: URL) async throws -> AudioFormatInfo {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        // Read first 64 bytes (enough for most format detection)
        let data = try handle.read(upToCount: 64) ?? Data()
        return detectFormatFromMagicBytes(data: data)
    }
    
    /// Detect format from magic bytes in data
    private func detectFormatFromMagicBytes(data: Data) -> AudioFormatInfo {
        guard data.count >= 4 else {
            return AudioFormatInfo(
                format: .unknown,
                confidence: 0.0,
                properties: nil,
                containerFormat: nil,
                detectionMethod: .magicBytes
            )
        }
        
        let bytes = Array(data.prefix(64))
        
        // Check each format's magic bytes
        for format in AudioFormat.allCases {
            for signature in format.magicBytes {
                if matchesSignature(bytes: bytes, signature: signature) {
                    // Special handling for container formats
                    if format == .m4a {
                        // Try to detect if it's ALAC or AAC
                        let codec = detectM4ACodec(data: data)
                        return AudioFormatInfo(
                            format: codec,
                            confidence: 0.9,
                            properties: nil,
                            containerFormat: .m4a,
                            detectionMethod: .magicBytes
                        )
                    } else if format == .ogg {
                        // Check if it's Opus or Vorbis
                        let codec = detectOggCodec(data: data)
                        return AudioFormatInfo(
                            format: codec,
                            confidence: 0.9,
                            properties: nil,
                            containerFormat: codec == .opus ? .ogg : nil,
                            detectionMethod: .magicBytes
                        )
                    }
                    
                    return AudioFormatInfo(
                        format: format,
                        confidence: 0.95,
                        properties: nil,
                        containerFormat: nil,
                        detectionMethod: .magicBytes
                    )
                }
            }
        }
        
        return AudioFormatInfo(
            format: .unknown,
            confidence: 0.0,
            properties: nil,
            containerFormat: nil,
            detectionMethod: .magicBytes
        )
    }
    
    /// Check if bytes match a signature
    private func matchesSignature(bytes: [UInt8], signature: [UInt8]) -> Bool {
        guard bytes.count >= signature.count else { return false }
        
        for i in 0..<signature.count {
            if bytes[i] != signature[i] {
                return false
            }
        }
        return true
    }
    
    /// Detect codec in M4A container
    private func detectM4ACodec(data: Data) -> AudioFormat {
        // Look for codec atoms in the M4A/MP4 structure
        // This is a simplified check - real implementation would parse atoms properly
        
        let dataArray = Array(data)
        
        // Look for "alac" atom
        if let alacRange = data.range(of: "alac".data(using: .ascii)!) {
            return .alac
        }
        
        // Look for "mp4a" atom (AAC)
        if let mp4aRange = data.range(of: "mp4a".data(using: .ascii)!) {
            return .aac
        }
        
        // Default to AAC for M4A
        return .aac
    }
    
    /// Detect codec in Ogg container
    private func detectOggCodec(data: Data) -> AudioFormat {
        // Look for codec identification in Ogg pages
        
        // Check for Opus signature
        if let opusRange = data.range(of: "OpusHead".data(using: .ascii)!) {
            return .opus
        }
        
        // Check for Vorbis signature
        if let vorbisRange = data.range(of: "vorbis".data(using: .ascii)!) {
            return .ogg
        }
        
        // Default to Vorbis
        return .ogg
    }
    
    /// Perform deep inspection using AVAsset
    private func performDeepInspection(url: URL) async throws -> AudioFormatInfo {
        let asset = AVAsset(url: url)
        
        // Load asset properties
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw FormatDetectionError.notPlayable
        }
        
        // Get tracks
        let tracks = try await asset.load(.tracks)
        guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
            throw FormatDetectionError.noAudioTrack
        }
        
        // Load format descriptions
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        guard let formatDesc = formatDescriptions.first else {
            throw FormatDetectionError.noFormatDescription
        }
        
        // Extract codec information
        let format = detectFormatFromFormatDescription(formatDesc)
        
        // Extract properties
        let properties = try await extractAudioProperties(from: url, asset: asset, track: audioTrack)
        
        return AudioFormatInfo(
            format: format,
            confidence: 1.0,  // Deep inspection gives highest confidence
            properties: properties,
            containerFormat: nil,
            detectionMethod: .deepInspection
        )
    }
    
    /// Detect format from CMFormatDescription
    private func detectFormatFromFormatDescription(_ desc: CMFormatDescription) -> AudioFormat {
        let audioStreamBasicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
        
        guard let asbd = audioStreamBasicDesc?.pointee else {
            return .unknown
        }
        
        // Check format ID
        switch asbd.mFormatID {
        case kAudioFormatMPEGLayer3:
            return .mp3
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2:
            return .aac
        case kAudioFormatAppleLossless:
            return .alac
        case kAudioFormatFLAC:
            return .flac
        case kAudioFormatLinearPCM:
            // Could be WAV or AIFF - check further
            if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
                return .aiff
            } else {
                return .wav
            }
        case kAudioFormatOpus:
            return .opus
        default:
            return .unknown
        }
    }
    
    /// Extract audio properties from asset
    private func extractAudioProperties(from url: URL, asset: AVAsset? = nil, track: AVAssetTrack? = nil) async throws -> AudioProperties {
        let finalAsset = asset ?? AVAsset(url: url)
        let duration = try await finalAsset.load(.duration).seconds
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        
        if let audioTrack = track ?? try await finalAsset.load(.tracks).first(where: { $0.mediaType == .audio }) {
            let bitrate = try? await audioTrack.load(.estimatedDataRate)
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            
            if let formatDesc = formatDescriptions.first,
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                
                return AudioProperties(
                    bitrate: bitrate != nil ? Int(bitrate!) : nil,
                    sampleRate: Int(asbd.mSampleRate),
                    channelCount: Int(asbd.mChannelsPerFrame),
                    bitDepth: asbd.mBitsPerChannel > 0 ? Int(asbd.mBitsPerChannel) : nil,
                    isVariableBitrate: nil,  // Would need deeper inspection
                    codec: getCodecString(from: asbd.mFormatID),
                    duration: duration,
                    fileSize: fileSize
                )
            }
        }
        
        return AudioProperties(
            bitrate: nil,
            sampleRate: nil,
            channelCount: nil,
            bitDepth: nil,
            isVariableBitrate: nil,
            codec: nil,
            duration: duration,
            fileSize: fileSize
        )
    }
    
    /// Get codec string from format ID
    private func getCodecString(from formatID: AudioFormatID) -> String {
        switch formatID {
        case kAudioFormatMPEGLayer3: return "MP3"
        case kAudioFormatMPEG4AAC: return "AAC"
        case kAudioFormatMPEG4AAC_HE: return "HE-AAC"
        case kAudioFormatMPEG4AAC_HE_V2: return "HE-AACv2"
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatLinearPCM: return "PCM"
        case kAudioFormatOpus: return "Opus"
        default: return "Unknown"
        }
    }
}

// MARK: - Errors

/// Errors that can occur during format detection
public enum FormatDetectionError: LocalizedError {
    case notPlayable
    case noAudioTrack
    case noFormatDescription
    case insufficientData
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .notPlayable:
            return "File is not playable"
        case .noAudioTrack:
            return "No audio track found"
        case .noFormatDescription:
            return "No format description available"
        case .insufficientData:
            return "Insufficient data for format detection"
        case .invalidData:
            return "Invalid audio data"
        }
    }
}