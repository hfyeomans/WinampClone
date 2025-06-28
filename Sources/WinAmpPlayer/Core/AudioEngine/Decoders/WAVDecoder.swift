import Foundation
import AVFoundation

/// WAV decoder with support for LIST INFO chunks
public class WAVDecoder: AudioDecoder {
    public let fileURL: URL
    private var audioFile: AVAudioFile?
    
    /// Metadata extracted from the WAV file
    public private(set) var metadata: WAVMetadata
    
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
    
    /// Initialize the WAV decoder with a file URL
    public init(url: URL) throws {
        self.fileURL = url
        self.metadata = WAVMetadata()
        
        // Initialize the audio file
        self.audioFile = try AVAudioFile(forReading: url)
        
        // Parse metadata
        try parseMetadata()
    }
    
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw WAVDecoderError.fileNotOpen
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
        
        // Parse WAV chunks including LIST INFO
        parseWAVChunks(from: data)
        
        // Also try to get metadata from AVAsset
        let asset = AVAsset(url: fileURL)
        parseAVAssetMetadata(from: asset)
    }
    
    private func parseWAVChunks(from data: Data) {
        // WAV files start with "RIFF"
        guard data.count > 12,
              data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46,
              data[8] == 0x57 && data[9] == 0x41 && data[10] == 0x56 && data[11] == 0x45 else {
            return
        }
        
        var offset = 12
        
        while offset + 8 <= data.count {
            // Read chunk ID and size
            let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
            let chunkSize = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset + 4, as: UInt32.self).littleEndian
            }
            
            offset += 8
            
            if chunkID == "LIST" && offset + 4 <= data.count {
                let listType = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
                
                if listType == "INFO" {
                    parseListInfoChunk(from: data, startingAt: offset + 4, size: Int(chunkSize) - 4)
                }
            }
            
            // Move to next chunk (align to word boundary)
            offset += Int(chunkSize)
            if chunkSize % 2 == 1 {
                offset += 1
            }
            
            if offset >= data.count {
                break
            }
        }
    }
    
    private func parseListInfoChunk(from data: Data, startingAt startOffset: Int, size: Int) {
        var offset = startOffset
        let endOffset = min(startOffset + size, data.count)
        
        while offset + 8 <= endOffset {
            // Read sub-chunk ID and size
            let subChunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
            let subChunkSize = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset + 4, as: UInt32.self).littleEndian
            }
            
            offset += 8
            
            if offset + Int(subChunkSize) <= data.count {
                let valueData = data.subdata(in: offset..<offset+Int(subChunkSize))
                
                // Remove null terminator if present
                let value = String(data: valueData, encoding: .ascii)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let value = value, !value.isEmpty {
                    switch subChunkID {
                    case "INAM": // Name/Title
                        metadata.title = value
                    case "IART": // Artist
                        metadata.artist = value
                    case "IPRD": // Product/Album
                        metadata.album = value
                    case "ICRD": // Creation date
                        metadata.creationDate = value
                    case "IGNR": // Genre
                        metadata.genre = value
                    case "ICMT": // Comment
                        metadata.comment = value
                    case "ICOP": // Copyright
                        metadata.copyright = value
                    case "IENG": // Engineer
                        metadata.engineer = value
                    case "ISFT": // Software
                        metadata.software = value
                    case "ITCH": // Technician
                        metadata.technician = value
                    case "ISRC": // Source
                        metadata.source = value
                    case "ISRF": // Source form
                        metadata.sourceForm = value
                    case "IKEY": // Keywords
                        metadata.keywords = value
                    case "IMED": // Medium
                        metadata.medium = value
                    case "ISBJ": // Subject
                        metadata.subject = value
                    case "ITRK": // Track number
                        metadata.track = Int(value)
                    default:
                        // Store unrecognized INFO tags
                        metadata.additionalFields[subChunkID] = value
                    }
                }
            }
            
            // Move to next sub-chunk (align to word boundary)
            offset += Int(subChunkSize)
            if subChunkSize % 2 == 1 {
                offset += 1
            }
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

// MARK: - WAV Metadata

/// Container for WAV metadata (LIST INFO chunks)
public struct WAVMetadata {
    public var title: String?          // INAM
    public var artist: String?         // IART
    public var album: String?          // IPRD
    public var creationDate: String?   // ICRD
    public var genre: String?          // IGNR
    public var comment: String?        // ICMT
    public var copyright: String?      // ICOP
    public var engineer: String?       // IENG
    public var software: String?       // ISFT
    public var technician: String?     // ITCH
    public var source: String?         // ISRC
    public var sourceForm: String?     // ISRF
    public var keywords: String?       // IKEY
    public var medium: String?         // IMED
    public var subject: String?        // ISBJ
    public var track: Int?             // ITRK
    public var albumArt: Data?
    
    /// Additional metadata fields
    public var additionalFields: [String: String] = [:]
}

// MARK: - Errors

public enum WAVDecoderError: LocalizedError {
    case fileNotOpen
    case invalidFormat
    case readError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .invalidFormat:
            return "Invalid WAV format"
        case .readError(let message):
            return "Read error: \(message)"
        }
    }
}