import Foundation
import AVFoundation

/// AIFF decoder with support for ID3 and annotation chunks
public class AIFFDecoder: AudioDecoder {
    public let fileURL: URL
    private var audioFile: AVAudioFile?
    
    /// Metadata extracted from the AIFF file
    public private(set) var metadata: AIFFMetadata
    
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
    
    /// Initialize the AIFF decoder with a file URL
    public init(url: URL) throws {
        self.fileURL = url
        self.metadata = AIFFMetadata()
        
        // Initialize the audio file
        self.audioFile = try AVAudioFile(forReading: url)
        
        // Parse metadata
        try parseMetadata()
    }
    
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw AIFFDecoderError.fileNotOpen
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
        
        // Parse AIFF chunks including ID3, NAME, AUTH, etc.
        parseAIFFChunks(from: data)
        
        // Also try to get metadata from AVAsset
        let asset = AVAsset(url: fileURL)
        parseAVAssetMetadata(from: asset)
    }
    
    private func parseAIFFChunks(from data: Data) {
        // AIFF files start with "FORM" followed by size and "AIFF" or "AIFC"
        guard data.count > 12,
              data[0] == 0x46 && data[1] == 0x4F && data[2] == 0x52 && data[3] == 0x4D else {
            return
        }
        
        let formType = String(data: data.subdata(in: 8..<12), encoding: .ascii) ?? ""
        guard formType == "AIFF" || formType == "AIFC" else {
            return
        }
        
        var offset = 12
        
        while offset + 8 <= data.count {
            // Read chunk ID and size
            let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
            let chunkSize = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset + 4, as: UInt32.self).bigEndian
            }
            
            offset += 8
            
            if offset + Int(chunkSize) <= data.count {
                let chunkData = data.subdata(in: offset..<offset+Int(chunkSize))
                
                switch chunkID {
                case "ID3 ":
                    // Parse ID3v2 tag
                    if let id3Metadata = ID3v2Parser.parse(data: chunkData) {
                        metadata.mergeWithID3(id3Metadata)
                    }
                    
                case "NAME":
                    // Name chunk (title)
                    if let value = parseTextChunk(chunkData) {
                        metadata.title = value
                    }
                    
                case "AUTH":
                    // Author chunk (artist)
                    if let value = parseTextChunk(chunkData) {
                        metadata.artist = value
                    }
                    
                case "ANNO":
                    // Annotation chunk (comment)
                    if let value = parseTextChunk(chunkData) {
                        if metadata.comment == nil {
                            metadata.comment = value
                        } else {
                            metadata.annotations.append(value)
                        }
                    }
                    
                case "COMT":
                    // Comments chunk (structured comments)
                    parseCommentsChunk(chunkData)
                    
                case "(c) ", "©":
                    // Copyright chunk
                    if let value = parseTextChunk(chunkData) {
                        metadata.copyright = value
                    }
                    
                default:
                    // Store unrecognized chunks if they look like text
                    if let value = parseTextChunk(chunkData) {
                        metadata.additionalFields[chunkID.trimmingCharacters(in: .whitespaces)] = value
                    }
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
    
    private func parseTextChunk(_ data: Data) -> String? {
        // Try different encodings
        if let text = String(data: data, encoding: .utf8) {
            return text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let text = String(data: data, encoding: .ascii) {
            return text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let text = String(data: data, encoding: .isoLatin1) {
            return text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func parseCommentsChunk(_ data: Data) {
        guard data.count >= 2 else { return }
        
        let numComments = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: UInt16.self).bigEndian
        }
        
        var offset = 2
        
        for _ in 0..<numComments {
            guard offset + 8 <= data.count else { break }
            
            // Skip timestamp (4 bytes) and marker ID (2 bytes)
            offset += 6
            
            // Read count (2 bytes) - length of text
            let textLength = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt16.self).bigEndian
            }
            offset += 2
            
            if offset + Int(textLength) <= data.count {
                let textData = data.subdata(in: offset..<offset+Int(textLength))
                if let text = parseTextChunk(textData) {
                    metadata.annotations.append(text)
                }
            }
            
            offset += Int(textLength)
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

// MARK: - AIFF Metadata

/// Container for AIFF metadata
public struct AIFFMetadata {
    public var title: String?        // NAME chunk or ID3
    public var artist: String?       // AUTH chunk or ID3
    public var album: String?        // ID3
    public var year: String?         // ID3
    public var comment: String?      // ANNO chunk or ID3
    public var genre: String?        // ID3
    public var track: Int?           // ID3
    public var copyright: String?    // (c) chunk or ID3
    public var albumArt: Data?       // ID3
    public var composer: String?     // ID3
    public var annotations: [String] = []  // Multiple ANNO chunks
    
    /// Additional metadata fields
    public var additionalFields: [String: String] = [:]
    
    /// Merge with ID3 metadata from MP3Metadata
    mutating func mergeWithID3(_ id3: MP3Metadata) {
        title = title ?? id3.title
        artist = artist ?? id3.artist
        album = album ?? id3.album
        year = year ?? id3.year
        comment = comment ?? id3.comment
        genre = genre ?? id3.genre
        track = track ?? id3.track
        albumArt = albumArt ?? id3.albumArt
        composer = composer ?? id3.composer
        
        // Merge additional fields from ID3
        for (key, value) in id3.additionalFields {
            if additionalFields[key] == nil {
                additionalFields[key] = value
            }
        }
    }
}

// MARK: - Errors

public enum AIFFDecoderError: LocalizedError {
    case fileNotOpen
    case invalidFormat
    case readError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .invalidFormat:
            return "Invalid AIFF format"
        case .readError(let message):
            return "Read error: \(message)"
        }
    }
}