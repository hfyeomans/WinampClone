import Foundation
import AVFoundation

/// FLAC decoder that wraps AVAudioFile for FLAC playback
public class FLACDecoder {
    private var audioFile: AVAudioFile?
    private let fileURL: URL
    
    /// Metadata extracted from the FLAC file
    public private(set) var metadata: FLACMetadata
    
    /// The audio format of the FLAC file
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
    
    /// Initialize the FLAC decoder with a file URL
    public init(url: URL) throws {
        self.fileURL = url
        self.metadata = FLACMetadata()
        
        // Initialize the audio file
        self.audioFile = try AVAudioFile(forReading: url)
        
        // Parse metadata
        try parseMetadata()
    }
    
    /// Read audio data into a buffer
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw FLACDecoderError.fileNotOpen
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
        let data = try Data(contentsOf: fileURL)
        
        // Parse native FLAC metadata blocks
        if let flacMetadata = FLACMetadataParser.parse(data: data) {
            metadata = flacMetadata
        }
        
        // Also try to get metadata from AVAsset as fallback
        let asset = AVAsset(url: fileURL)
        parseAVAssetMetadata(from: asset)
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
                if metadata.pictures.isEmpty, let data = item.dataValue {
                    let picture = FLACPicture(
                        type: .frontCover,
                        mimeType: "image/jpeg",
                        description: "",
                        width: 0,
                        height: 0,
                        depth: 0,
                        colorCount: 0,
                        data: data
                    )
                    metadata.pictures.append(picture)
                }
            default:
                break
            }
        }
    }
}

// MARK: - FLAC Metadata

/// Container for FLAC metadata
public struct FLACMetadata {
    // Stream info
    public var minBlockSize: UInt16 = 0
    public var maxBlockSize: UInt16 = 0
    public var minFrameSize: UInt32 = 0
    public var maxFrameSize: UInt32 = 0
    public var sampleRate: UInt32 = 0
    public var channels: UInt8 = 0
    public var bitsPerSample: UInt8 = 0
    public var totalSamples: UInt64 = 0
    public var md5Signature: Data?
    
    // Vorbis comments (standard fields)
    public var title: String?
    public var artist: String?
    public var album: String?
    public var date: String?
    public var comment: String?
    public var genre: String?
    public var albumArtist: String?
    public var composer: String?
    public var performer: String?
    public var copyright: String?
    public var license: String?
    public var organization: String?
    public var description: String?
    public var location: String?
    public var contact: String?
    public var isrc: String?
    
    // Track information
    public var trackNumber: Int?
    public var totalTracks: Int?
    public var discNumber: Int?
    public var totalDiscs: Int?
    
    // ReplayGain tags
    public var replayGainAlbumGain: Float?
    public var replayGainAlbumPeak: Float?
    public var replayGainTrackGain: Float?
    public var replayGainTrackPeak: Float?
    
    // Pictures
    public var pictures: [FLACPicture] = []
    
    // Additional Vorbis comment fields
    public var additionalFields: [String: [String]] = [:]
    
    /// Get the primary album artwork
    public var albumArt: Data? {
        // Prefer front cover
        if let frontCover = pictures.first(where: { $0.type == .frontCover }) {
            return frontCover.data
        }
        // Fall back to any picture
        return pictures.first?.data
    }
    
    /// Duration in seconds based on stream info
    public var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(totalSamples) / Double(sampleRate)
    }
}

/// FLAC picture metadata
public struct FLACPicture {
    public let type: PictureType
    public let mimeType: String
    public let description: String
    public let width: UInt32
    public let height: UInt32
    public let depth: UInt32
    public let colorCount: UInt32
    public let data: Data
    
    public enum PictureType: UInt32 {
        case other = 0
        case fileIcon32x32PNG = 1
        case otherFileIcon = 2
        case frontCover = 3
        case backCover = 4
        case leafletPage = 5
        case media = 6
        case leadArtist = 7
        case artist = 8
        case conductor = 9
        case band = 10
        case composer = 11
        case lyricist = 12
        case recordingLocation = 13
        case duringRecording = 14
        case duringPerformance = 15
        case videoScreenCapture = 16
        case brightColoredFish = 17
        case illustration = 18
        case bandLogotype = 19
        case publisherLogotype = 20
    }
}

// MARK: - Errors

public enum FLACDecoderError: LocalizedError {
    case fileNotOpen
    case invalidFormat
    case readError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .invalidFormat:
            return "Invalid FLAC format"
        case .readError(let message):
            return "Read error: \(message)"
        }
    }
}