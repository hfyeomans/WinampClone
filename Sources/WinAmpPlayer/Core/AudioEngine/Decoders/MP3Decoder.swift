import Foundation
import AVFoundation

/// MP3 decoder that wraps AVAudioFile for MP3 playback
public class MP3Decoder {
    private var audioFile: AVAudioFile?
    internal let url: URL
    
    /// Metadata extracted from the MP3 file
    public private(set) var metadata: MP3Metadata
    
    /// The audio format of the MP3 file
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
    
    /// Initialize the MP3 decoder with a file URL
    public init(url: URL) throws {
        self.url = url
        self.metadata = MP3Metadata()
        
        // Initialize the audio file
        self.audioFile = try AVAudioFile(forReading: url)
        
        // Parse metadata
        try parseMetadata()
    }
    
    /// Read audio data into a buffer
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw MP3DecoderError.fileNotOpen
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
        
        // Try to parse ID3v2 tags first (at the beginning of the file)
        if let id3v2Metadata = ID3v2Parser.parse(data: data) {
            metadata.merge(with: id3v2Metadata)
        }
        
        // Try to parse ID3v1 tags (last 128 bytes)
        if let id3v1Metadata = ID3v1Parser.parse(data: data) {
            // Only use ID3v1 data if ID3v2 didn't provide it
            metadata.mergeIfMissing(with: id3v1Metadata)
        }
        
        // Also try to get metadata from AVAsset
        let asset = AVAsset(url: fileURL)
        parseAVAssetMetadata(from: asset)
    }
    
    private func parseAVAssetMetadata(from asset: AVAsset) {
        Task {
            do {
                let metadataItems = try await asset.load(.commonMetadata)
                
                for item in metadataItems {
                    guard let key = item.commonKey else { continue }
                    
                    switch key {
                    case .commonKeyTitle:
                        if metadata.title == nil, let value = try? await item.load(.stringValue) {
                            metadata.title = value
                        }
                    case .commonKeyArtist:
                        if metadata.artist == nil, let value = try? await item.load(.stringValue) {
                            metadata.artist = value
                        }
                    case .commonKeyAlbumName:
                        if metadata.album == nil, let value = try? await item.load(.stringValue) {
                            metadata.album = value
                        }
                    case .commonKeyArtwork:
                        if metadata.albumArt == nil, let data = try? await item.load(.dataValue) {
                            metadata.albumArt = data
                        }
                    default:
                        break
                    }
                }
            } catch {
                // Handle error if needed
            }
        }
    }
}

// MARK: - MP3 Metadata

/// Container for MP3 metadata
public struct MP3Metadata {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var year: String?
    public var comment: String?
    public var genre: String?
    public var track: Int?
    public var albumArt: Data?
    public var lyrics: String?
    public var albumArtist: String?
    public var composer: String?
    public var encoder: String?
    public var bpm: Int?
    public var discNumber: Int?
    public var totalDiscs: Int?
    public var totalTracks: Int?
    
    /// Additional metadata fields
    public var additionalFields: [String: String] = [:]
    
    /// Merge with another metadata object, preferring non-nil values from the other object
    mutating func merge(with other: MP3Metadata) {
        title = other.title ?? title
        artist = other.artist ?? artist
        album = other.album ?? album
        year = other.year ?? year
        comment = other.comment ?? comment
        genre = other.genre ?? genre
        track = other.track ?? track
        albumArt = other.albumArt ?? albumArt
        lyrics = other.lyrics ?? lyrics
        albumArtist = other.albumArtist ?? albumArtist
        composer = other.composer ?? composer
        encoder = other.encoder ?? encoder
        bpm = other.bpm ?? bpm
        discNumber = other.discNumber ?? discNumber
        totalDiscs = other.totalDiscs ?? totalDiscs
        totalTracks = other.totalTracks ?? totalTracks
        
        // Merge additional fields
        for (key, value) in other.additionalFields {
            additionalFields[key] = value
        }
    }
    
    /// Merge with another metadata object only if the current value is nil
    mutating func mergeIfMissing(with other: MP3Metadata) {
        title = title ?? other.title
        artist = artist ?? other.artist
        album = album ?? other.album
        year = year ?? other.year
        comment = comment ?? other.comment
        genre = genre ?? other.genre
        track = track ?? other.track
        albumArt = albumArt ?? other.albumArt
        lyrics = lyrics ?? other.lyrics
        albumArtist = albumArtist ?? other.albumArtist
        composer = composer ?? other.composer
        encoder = encoder ?? other.encoder
        bpm = bpm ?? other.bpm
        discNumber = discNumber ?? other.discNumber
        totalDiscs = totalDiscs ?? other.totalDiscs
        totalTracks = totalTracks ?? other.totalTracks
        
        // Merge additional fields if missing
        for (key, value) in other.additionalFields {
            if additionalFields[key] == nil {
                additionalFields[key] = value
            }
        }
    }
}

// MARK: - Errors

public enum MP3DecoderError: LocalizedError {
    case fileNotOpen
    case invalidFormat
    case readError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .invalidFormat:
            return "Invalid audio format"
        case .readError(let message):
            return "Read error: \(message)"
        }
    }
}