import Foundation
import AVFoundation

/// AAC/M4A decoder that wraps AVAudioFile for AAC and M4A playback
public class AACDecoder {
    private var audioFile: AVAudioFile?
    private let fileURL: URL
    
    /// Metadata extracted from the AAC/M4A file
    public private(set) var metadata: AACMetadata
    
    /// The audio format of the AAC/M4A file
    public var fileFormat: AVAudioFormat? {
        return audioFile?.fileFormat
    }
    
    /// The processing format for audio playback
    public var processingFormat: AVAudioFormat? {
        return audioFile?.processingFormat
    }
    
    /// The total number of frames in the audio file
    public var frameCount: AVAudioFrameCount {
        return AVAudioFrameCount(audioFile?.length ?? 0)
    }
    
    /// Duration of the audio file in seconds
    public var duration: TimeInterval {
        guard let audioFile = audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.processingFormat.sampleRate
    }
    
    /// Codec type (AAC or ALAC)
    public var codecType: AACCodecType {
        return metadata.codecType
    }
    
    /// Initialize the AAC decoder with a file URL
    public init(url: URL) throws {
        self.fileURL = url
        self.metadata = AACMetadata()
        
        // Initialize the audio file
        self.audioFile = try AVAudioFile(forReading: url)
        
        // Parse metadata
        try parseMetadata()
    }
    
    /// Read audio data into a buffer
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw AACDecoderError.fileNotOpen
        }
        
        try audioFile.read(into: buffer)
        return buffer.frameLength > 0
    }
    
    /// Seek to a specific frame position
    public func seek(to frame: AVAudioFramePosition) {
        audioFile?.framePosition = frame
    }
    
    /// Seek to a specific time in seconds
    public func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        let frame = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
        seek(to: frame)
    }
    
    /// Get the current playback position in frames
    public var currentFrame: AVAudioFramePosition {
        return audioFile?.framePosition ?? 0
    }
    
    /// Get the current playback position in seconds
    public var currentTime: TimeInterval {
        guard let audioFile = audioFile else { return 0 }
        return Double(audioFile.framePosition) / audioFile.processingFormat.sampleRate
    }
    
    // MARK: - Private Methods
    
    private func parseMetadata() throws {
        // Parse MP4/M4A metadata using custom parser
        let parser = MP4MetadataParser()
        if let mp4Metadata = try? parser.parse(fileURL: fileURL) {
            metadata = mp4Metadata
        }
        
        // Also try to get metadata from AVAsset as fallback
        let asset = AVAsset(url: fileURL)
        parseAVAssetMetadata(from: asset)
        
        // Detect codec type
        detectCodecType(from: asset)
    }
    
    private func parseAVAssetMetadata(from asset: AVAsset) {
        let metadataItems = asset.commonMetadata
        
        for item in metadataItems {
            guard let key = item.commonKey else { continue }
            
            switch key {
            case .commonKeyTitle:
                if metadata.title == nil {
                    metadata.title = item.stringValue
                }
            case .commonKeyArtist:
                if metadata.artist == nil {
                    metadata.artist = item.stringValue
                }
            case .commonKeyAlbumName:
                if metadata.album == nil {
                    metadata.album = item.stringValue
                }
            case .commonKeyArtwork:
                if metadata.albumArt == nil, let data = item.dataValue {
                    metadata.albumArt = data
                }
            case .commonKeyCreationDate:
                if metadata.year == nil {
                    metadata.year = item.stringValue
                }
            default:
                break
            }
        }
        
        // Parse iTunes-specific metadata
        let iTunesMetadata = asset.metadata(forFormat: .iTunesMetadata)
        for item in iTunesMetadata {
            guard let key = item.key as? String else { continue }
            
            // Handle custom metadata
            if key.hasPrefix("----") {
                let components = key.split(separator: ":")
                if components.count >= 3 {
                    let customKey = String(components[2])
                    if let value = item.stringValue {
                        metadata.customMetadata[customKey] = value
                    }
                }
            }
        }
    }
    
    private func detectCodecType(from asset: AVAsset) {
        guard let track = asset.tracks(withMediaType: .audio).first else { return }
        
        for desc in track.formatDescriptions {
            let formatDesc = desc as! CMFormatDescription
            let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee
            
            if let asbd = audioStreamBasicDescription {
                switch asbd.mFormatID {
                case kAudioFormatMPEG4AAC,
                     kAudioFormatMPEG4AAC_HE,
                     kAudioFormatMPEG4AAC_HE_V2,
                     kAudioFormatMPEG4AAC_LD,
                     kAudioFormatMPEG4AAC_ELD,
                     kAudioFormatMPEG4AAC_ELD_SBR,
                     kAudioFormatMPEG4AAC_ELD_V2:
                    metadata.codecType = .aac
                case kAudioFormatAppleLossless:
                    metadata.codecType = .alac
                default:
                    // Try to determine from file extension as fallback
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "m4a" {
                        // Default to AAC for M4A files if we can't determine
                        metadata.codecType = .aac
                    }
                }
            }
        }
    }
}

// MARK: - AAC Metadata

/// Container for AAC/M4A metadata
public struct AACMetadata {
    // Common metadata fields
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var composer: String?
    public var genre: String?
    public var year: String?
    public var comment: String?
    public var copyright: String?
    public var encoder: String?
    public var lyrics: String?
    
    // Track and disc information
    public var track: Int?
    public var totalTracks: Int?
    public var disc: Int?
    public var totalDiscs: Int?
    
    // Additional metadata
    public var bpm: Int?
    public var compilation: Bool = false
    public var gapless: Bool = false
    public var podcast: Bool = false
    
    // Album artwork
    public var albumArt: Data?
    public var albumArtMimeType: String?
    
    // Technical information
    public var codecType: AACCodecType = .unknown
    public var bitrate: Int?
    public var sampleRate: Int?
    public var channels: Int?
    
    // Custom metadata fields (for ---- atoms)
    public var customMetadata: [String: String] = [:]
    
    /// Merge with another metadata object, preferring non-nil values from the other object
    mutating func merge(with other: AACMetadata) {
        title = other.title ?? title
        artist = other.artist ?? artist
        album = other.album ?? album
        albumArtist = other.albumArtist ?? albumArtist
        composer = other.composer ?? composer
        genre = other.genre ?? genre
        year = other.year ?? year
        comment = other.comment ?? comment
        copyright = other.copyright ?? copyright
        encoder = other.encoder ?? encoder
        lyrics = other.lyrics ?? lyrics
        
        track = other.track ?? track
        totalTracks = other.totalTracks ?? totalTracks
        disc = other.disc ?? disc
        totalDiscs = other.totalDiscs ?? totalDiscs
        
        bpm = other.bpm ?? bpm
        compilation = other.compilation || compilation
        gapless = other.gapless || gapless
        podcast = other.podcast || podcast
        
        albumArt = other.albumArt ?? albumArt
        albumArtMimeType = other.albumArtMimeType ?? albumArtMimeType
        
        codecType = other.codecType != .unknown ? other.codecType : codecType
        bitrate = other.bitrate ?? bitrate
        sampleRate = other.sampleRate ?? sampleRate
        channels = other.channels ?? channels
        
        // Merge custom metadata
        for (key, value) in other.customMetadata {
            customMetadata[key] = value
        }
    }
}

// MARK: - Codec Type

public enum AACCodecType: String {
    case aac = "AAC"
    case alac = "ALAC"
    case unknown = "Unknown"
}

// MARK: - Errors

public enum AACDecoderError: LocalizedError {
    case fileNotOpen
    case invalidFormat
    case readError(String)
    case unsupportedCodec
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .invalidFormat:
            return "Invalid audio format"
        case .readError(let message):
            return "Read error: \(message)"
        case .unsupportedCodec:
            return "Unsupported codec type"
        }
    }
}