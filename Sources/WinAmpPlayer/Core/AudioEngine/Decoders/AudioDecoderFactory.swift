//
//  AudioDecoderFactory.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Factory for creating appropriate audio decoders based on format.
//

import Foundation
import AVFoundation

/// Protocol that all audio decoders must conform to
public protocol AudioDecoder {
    /// The file URL being decoded
    var fileURL: URL { get }
    
    /// The audio format of the file
    var fileFormat: AVAudioFormat? { get }
    
    /// The processing format for playback
    var processingFormat: AVAudioFormat? { get }
    
    /// Total number of frames in the audio file
    var frameCount: AVAudioFrameCount { get }
    
    /// Duration of the audio file in seconds
    var duration: TimeInterval { get }
    
    /// Current playback position in frames
    var currentFrame: AVAudioFramePosition { get }
    
    /// Current playback position in seconds
    var currentTime: TimeInterval { get }
    
    /// Read audio data into a buffer
    /// - Parameter buffer: The buffer to read into
    /// - Returns: true if data was read, false if end of file
    func read(into buffer: AVAudioPCMBuffer) throws -> Bool
    
    /// Seek to a specific frame position
    /// - Parameter frame: The frame position to seek to
    func seek(to frame: AVAudioFramePosition)
    
    /// Seek to a specific time in seconds
    /// - Parameter time: The time in seconds to seek to
    func seek(to time: TimeInterval)
}

/// Generic decoder that uses AVAudioFile for supported formats
public class GenericAudioDecoder: AudioDecoder {
    public let fileURL: URL
    private var audioFile: AVAudioFile?
    
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
    
    public init(url: URL) throws {
        self.fileURL = url
        self.audioFile = try AVAudioFile(forReading: url)
    }
    
    public func read(into buffer: AVAudioPCMBuffer) throws -> Bool {
        guard let audioFile = audioFile else {
            throw AudioDecoderError.fileNotOpen
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
}

/// MP3 decoder adapter to conform to AudioDecoder protocol
extension MP3Decoder: AudioDecoder {
    public var fileURL: URL {
        return self.fileURL
    }
}

/// Factory for creating appropriate audio decoders based on format
public class AudioDecoderFactory {
    
    /// Supported decoder types with their creation functions
    private static let decoderTypes: [AudioFormat: (URL) throws -> AudioDecoder] = [
        .mp3: { url in try MP3Decoder(url: url) },
        .aac: { url in try GenericAudioDecoder(url: url) },
        .m4a: { url in try GenericAudioDecoder(url: url) },
        .wav: { url in try WAVDecoder(url: url) },
        .aiff: { url in try AIFFDecoder(url: url) },
        .flac: { url in try GenericAudioDecoder(url: url) },
        .alac: { url in try GenericAudioDecoder(url: url) },
        .ogg: { url in try OGGDecoder(url: url) },
        .opus: { url in try OGGDecoder(url: url) }  // Opus uses OGG container
    ]
    
    /// Create a decoder for the given URL and format
    /// - Parameters:
    ///   - url: The URL of the audio file
    ///   - format: The detected audio format
    /// - Returns: An appropriate decoder for the format
    /// - Throws: AudioDecoderError if decoder creation fails
    public static func createDecoder(for url: URL, format: AudioFormat) throws -> AudioDecoder {
        guard let decoderCreator = decoderTypes[format] else {
            // Fall back to generic decoder for unsupported formats
            if format != .unknown {
                return try GenericAudioDecoder(url: url)
            }
            throw AudioDecoderError.unsupportedFormat(format)
        }
        
        do {
            return try decoderCreator(url)
        } catch {
            // If specific decoder fails, try generic decoder as fallback
            if !(error is AudioDecoderError) {
                return try GenericAudioDecoder(url: url)
            }
            throw error
        }
    }
    
    /// Create a decoder by auto-detecting the format
    /// - Parameter url: The URL of the audio file
    /// - Returns: An appropriate decoder for the detected format
    /// - Throws: AudioDecoderError if format detection or decoder creation fails
    public static func createDecoder(for url: URL) throws -> AudioDecoder {
        let detector = FormatDetector()
        let formatInfo = try detector.detectFormat(at: url)
        
        guard formatInfo.format != .unknown else {
            throw AudioDecoderError.unknownFormat
        }
        
        return try createDecoder(for: url, format: formatInfo.format)
    }
}

/// Errors specific to audio decoding
public enum AudioDecoderError: LocalizedError {
    case fileNotOpen
    case unsupportedFormat(AudioFormat)
    case unknownFormat
    case decoderCreationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "Audio file is not open"
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format.displayName)"
        case .unknownFormat:
            return "Unknown audio format"
        case .decoderCreationFailed(let error):
            return "Failed to create decoder: \(error.localizedDescription)"
        }
    }
}