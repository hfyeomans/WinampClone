//
//  AudioFormat.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Defines supported audio formats and their properties.
//

import Foundation

/// Supported audio format types
public enum AudioFormat: String, CaseIterable, Codable {
    case mp3 = "mp3"
    case aac = "aac"
    case m4a = "m4a"
    case flac = "flac"
    case ogg = "ogg"
    case wav = "wav"
    case aiff = "aiff"
    case alac = "alac"  // Apple Lossless
    case opus = "opus"
    case unknown = "unknown"
    
    /// File extensions associated with this format
    var fileExtensions: [String] {
        switch self {
        case .mp3:
            return ["mp3", "mp2", "mp1"]
        case .aac:
            return ["aac", "adts"]
        case .m4a:
            return ["m4a", "m4b", "m4p", "m4v", "m4r"]
        case .flac:
            return ["flac"]
        case .ogg:
            return ["ogg", "oga", "ogv"]
        case .wav:
            return ["wav", "wave"]
        case .aiff:
            return ["aiff", "aif", "aifc"]
        case .alac:
            return ["m4a"]  // ALAC is typically in M4A container
        case .opus:
            return ["opus"]
        case .unknown:
            return []
        }
    }
    
    /// MIME types associated with this format
    var mimeTypes: [String] {
        switch self {
        case .mp3:
            return ["audio/mpeg", "audio/mp3", "audio/x-mp3", "audio/mpeg3", "audio/x-mpeg-3"]
        case .aac:
            return ["audio/aac", "audio/x-aac", "audio/mp4", "audio/x-m4a"]
        case .m4a:
            return ["audio/mp4", "audio/x-m4a", "audio/m4a"]
        case .flac:
            return ["audio/flac", "audio/x-flac"]
        case .ogg:
            return ["audio/ogg", "audio/x-ogg", "application/ogg", "audio/vorbis"]
        case .wav:
            return ["audio/wav", "audio/x-wav", "audio/wave"]
        case .aiff:
            return ["audio/aiff", "audio/x-aiff"]
        case .alac:
            return ["audio/mp4", "audio/x-m4a"]
        case .opus:
            return ["audio/opus", "audio/ogg"]
        case .unknown:
            return []
        }
    }
    
    /// Magic bytes (file signatures) for format detection
    var magicBytes: [[UInt8]] {
        switch self {
        case .mp3:
            // ID3v2 tag or MPEG sync word
            return [
                [0x49, 0x44, 0x33],  // "ID3"
                [0xFF, 0xFB],        // MPEG-1 Layer 3
                [0xFF, 0xF3],        // MPEG-2 Layer 3
                [0xFF, 0xF2],        // MPEG-2.5 Layer 3
                [0xFF, 0xFA]         // MPEG-1 Layer 2
            ]
        case .aac:
            return [
                [0xFF, 0xF1],  // AAC with ADTS header
                [0xFF, 0xF9]   // AAC with ADTS header (MPEG-2)
            ]
        case .m4a, .alac:
            // M4A uses MP4 container format
            return [
                // ftyp box with various brand codes
                [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41],  // M4A 
                [0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41],  // M4A variant
                [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D],  // isom
                [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32]   // mp42
            ]
        case .flac:
            return [
                [0x66, 0x4C, 0x61, 0x43]  // "fLaC"
            ]
        case .ogg:
            return [
                [0x4F, 0x67, 0x67, 0x53]  // "OggS"
            ]
        case .wav:
            return [
                [0x52, 0x49, 0x46, 0x46]  // "RIFF"
            ]
        case .aiff:
            return [
                [0x46, 0x4F, 0x52, 0x4D]  // "FORM"
            ]
        case .opus:
            // Opus in Ogg container
            return [
                [0x4F, 0x67, 0x67, 0x53]  // "OggS" - same as Ogg
            ]
        case .unknown:
            return []
        }
    }
    
    /// Whether this format typically uses lossy compression
    var isLossy: Bool {
        switch self {
        case .mp3, .aac, .ogg, .opus:
            return true
        case .flac, .wav, .aiff, .alac:
            return false
        case .m4a:
            return true  // Can be either, but typically AAC (lossy)
        case .unknown:
            return true
        }
    }
    
    /// Human-readable format name
    var displayName: String {
        switch self {
        case .mp3:
            return "MP3"
        case .aac:
            return "AAC"
        case .m4a:
            return "M4A"
        case .flac:
            return "FLAC"
        case .ogg:
            return "Ogg Vorbis"
        case .wav:
            return "WAV"
        case .aiff:
            return "AIFF"
        case .alac:
            return "Apple Lossless"
        case .opus:
            return "Opus"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Initialize from file extension
    init(fileExtension: String) {
        let ext = fileExtension.lowercased()
        self = AudioFormat.allCases.first { format in
            format.fileExtensions.contains(ext)
        } ?? .unknown
    }
    
    /// Initialize from MIME type
    init(mimeType: String) {
        let mime = mimeType.lowercased()
        self = AudioFormat.allCases.first { format in
            format.mimeTypes.contains(mime)
        } ?? .unknown
    }
}

/// Audio format detection result with confidence level
public struct AudioFormatInfo {
    /// Detected audio format
    let format: AudioFormat
    
    /// Confidence level of the detection (0.0 to 1.0)
    let confidence: Double
    
    /// Audio properties if available
    let properties: AudioProperties?
    
    /// Container format if different from codec
    let containerFormat: AudioFormat?
    
    /// Detection method used
    let detectionMethod: DetectionMethod
    
    /// Methods used for format detection
    enum DetectionMethod {
        case fileExtension
        case magicBytes
        case mimeType
        case deepInspection
        case combined
    }
}

/// Audio properties extracted during format detection
public struct AudioProperties: Codable {
    /// Bitrate in bits per second
    let bitrate: Int?
    
    /// Sample rate in Hz
    let sampleRate: Int?
    
    /// Number of audio channels
    let channelCount: Int?
    
    /// Bit depth (for uncompressed formats)
    let bitDepth: Int?
    
    /// Whether the format uses variable bitrate
    let isVariableBitrate: Bool?
    
    /// Codec information if available
    let codec: String?
    
    /// Total duration in seconds
    let duration: TimeInterval?
    
    /// File size in bytes
    let fileSize: Int64?
    
    /// Calculated average bitrate if VBR
    var averageBitrate: Int? {
        guard let duration = duration,
              let fileSize = fileSize,
              duration > 0 else { return nil }
        
        return Int(Double(fileSize * 8) / duration)
    }
}