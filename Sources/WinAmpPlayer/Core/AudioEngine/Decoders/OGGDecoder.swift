import Foundation
import AVFoundation

/// OGG decoder for Vorbis and Opus files
public class OGGDecoder: AudioDecoder {
    public let fileURL: URL
    private var audioFile: AVAudioFile?
    
    /// Metadata extracted from the OGG file
    public private(set) var metadata: OGGMetadata
    
    public var fileFormat: AVAudioFormat? {
        return audioFile?.fileFormat
    }
    
    public var processingFormat: AVAudioFormat? {
        return audioFile?.processingFormat
    }
    
    public var frameCount: AVAudioFrameCount {
        return AVAudioFrameCount(audioFile?.length ?? 0)
    }
    
    public var duration: TimeInterval {
        guard let audioFile = audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.processingFormat.sampleRate
    }
    
    public var currentFrame: AVAudioFramePosition {
        return audioFile?.framePosition ?? 0
    }
    
    public var currentTime: TimeInterval {
        guard let audioFile = audioFile else { return 0 }
        return Double(audioFile.framePosition) / audioFile.processingFormat.sampleRate
    }
    
    /// Initialize the OGG decoder with a file URL
    public init(url: URL) throws {
        self.fileURL = url
        self.metadata = OGGMetadata()
        
        // Initialize the audio file
        self.audioFile = try AVAudioFile(forReading: url)
        
        // Parse metadata
        try parseMetadata()
    }
    
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw OGGDecoderError.fileNotOpen
        }
        
        try audioFile.read(into: buffer)
        return buffer.frameLength > 0
    }
    
    public func seek(to frame: AVAudioFramePosition) {
        audioFile?.framePosition = frame
    }
    
    public func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        let frame = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
        seek(to: frame)
    }
    
    // MARK: - Private Methods
    
    private func parseMetadata() throws {
        let data = try Data(contentsOf: fileURL)
        
        // Parse OGG container and Vorbis comments
        parseOGGVorbisComments(from: data)
        
        // Also try to get metadata from AVAsset
        let asset = AVAsset(url: fileURL)
        parseAVAssetMetadata(from: asset)
    }
    
    private func parseOGGVorbisComments(from data: Data) {
        // OGG files start with "OggS"
        guard data.count > 4,
              data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53 else {
            return
        }
        
        // Find Vorbis comment header
        let vorbisCommentMarker = "vorbis".data(using: .utf8)!
        var searchRange = data.startIndex..<data.endIndex
        
        while let range = data.range(of: vorbisCommentMarker, in: searchRange) {
            let headerStart = range.lowerBound
            
            // Check if this is a comment header (type 0x03)
            if headerStart > 0 && data[headerStart - 1] == 0x03 {
                let commentStart = headerStart + vorbisCommentMarker.count
                parseVorbisCommentBlock(from: data, startingAt: commentStart)
                break
            }
            
            searchRange = range.upperBound..<data.endIndex
        }
    }
    
    private func parseVorbisCommentBlock(from data: Data, startingAt offset: Int) {
        var currentOffset = offset
        
        // Skip vendor string length and vendor string
        guard currentOffset + 4 <= data.count else { return }
        let vendorLength = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: currentOffset, as: UInt32.self).littleEndian
        }
        currentOffset += 4 + Int(vendorLength)
        
        // Read number of comments
        guard currentOffset + 4 <= data.count else { return }
        let commentCount = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: currentOffset, as: UInt32.self).littleEndian
        }
        currentOffset += 4
        
        // Parse each comment
        for _ in 0..<commentCount {
            guard currentOffset + 4 <= data.count else { break }
            
            let commentLength = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: currentOffset, as: UInt32.self).littleEndian
            }
            currentOffset += 4
            
            guard currentOffset + Int(commentLength) <= data.count else { break }
            
            let commentData = data.subdata(in: currentOffset..<(currentOffset + Int(commentLength)))
            if let comment = String(data: commentData, encoding: .utf8) {
                parseVorbisComment(comment)
            }
            
            currentOffset += Int(commentLength)
        }
    }
    
    private func parseVorbisComment(_ comment: String) {
        let parts = comment.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { return }
        
        let key = parts[0].uppercased()
        let value = String(parts[1])
        
        switch key {
        case "TITLE":
            metadata.title = value
        case "ARTIST":
            metadata.artist = value
        case "ALBUM":
            metadata.album = value
        case "DATE", "YEAR":
            metadata.year = value
        case "COMMENT", "DESCRIPTION":
            metadata.comment = value
        case "GENRE":
            metadata.genre = value
        case "TRACKNUMBER":
            metadata.track = Int(value.split(separator: "/").first ?? "")
        case "ALBUMARTIST":
            metadata.albumArtist = value
        case "COMPOSER":
            metadata.composer = value
        case "DISCNUMBER":
            metadata.discNumber = Int(value.split(separator: "/").first ?? "")
        case "TOTALDISCS":
            metadata.totalDiscs = Int(value)
        case "TOTALTRACKS":
            metadata.totalTracks = Int(value)
        case "ENCODER":
            metadata.encoder = value
        case "ORGANIZATION", "LABEL":
            metadata.publisher = value
        case "COPYRIGHT":
            metadata.copyright = value
        case "LICENSE":
            metadata.license = value
        case "CONTACT":
            metadata.contact = value
        case "PERFORMER":
            metadata.performer = value
        default:
            // Store in additional fields
            metadata.additionalFields[key] = value
        }
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
            default:
                break
            }
        }
    }
}

// MARK: - OGG Metadata

/// Container for OGG metadata (Vorbis comments)
public struct OGGMetadata {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var year: String?
    public var comment: String?
    public var genre: String?
    public var track: Int?
    public var albumArt: Data?
    public var albumArtist: String?
    public var composer: String?
    public var encoder: String?
    public var discNumber: Int?
    public var totalDiscs: Int?
    public var totalTracks: Int?
    public var publisher: String?
    public var copyright: String?
    public var license: String?
    public var contact: String?
    public var performer: String?
    
    /// Additional metadata fields
    public var additionalFields: [String: String] = [:]
}

// MARK: - Errors

public enum OGGDecoderError: LocalizedError {
    case fileNotOpen
    case invalidFormat
    case readError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .invalidFormat:
            return "Invalid OGG format"
        case .readError(let message):
            return "Read error: \(message)"
        }
    }
}