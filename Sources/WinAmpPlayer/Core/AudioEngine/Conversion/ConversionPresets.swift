//
//  ConversionPresets.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Defines common audio conversion presets for various use cases.
//

import Foundation

/// Common audio conversion presets
public struct ConversionPreset: Hashable {
    /// Preset name
    public let name: String
    
    /// Preset description
    public let description: String
    
    /// Conversion settings for this preset
    public let settings: AudioConverter.ConversionSettings
    
    /// Whether this preset is recommended for the source format
    public let recommendedFor: [AudioFormat]
    
    /// File size reduction estimate (0.0 to 1.0, where 1.0 means no reduction)
    public let estimatedSizeRatio: Double
    
    public init(
        name: String,
        description: String,
        settings: AudioConverter.ConversionSettings,
        recommendedFor: [AudioFormat] = [],
        estimatedSizeRatio: Double = 1.0
    ) {
        self.name = name
        self.description = description
        self.settings = settings
        self.recommendedFor = recommendedFor
        self.estimatedSizeRatio = estimatedSizeRatio
    }
}

// MARK: - Preset Categories

public extension ConversionPreset {
    
    /// High quality presets for archival and audiophile use
    struct HighQuality {
        
        /// FLAC - Free Lossless Audio Codec
        public static let flac = ConversionPreset(
            name: "FLAC Lossless",
            description: "Perfect quality preservation with ~50-60% file size reduction",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .flac,
                preserveMetadata: true,
                quality: 1.0
            ),
            recommendedFor: [.wav, .aiff, .alac],
            estimatedSizeRatio: 0.55
        )
        
        /// Apple Lossless (ALAC)
        public static let alac = ConversionPreset(
            name: "Apple Lossless",
            description: "Apple's lossless format, perfect for iTunes/Apple Music",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .alac,
                preserveMetadata: true,
                quality: 1.0
            ),
            recommendedFor: [.wav, .aiff, .flac],
            estimatedSizeRatio: 0.55
        )
        
        /// WAV - Uncompressed
        public static let wav = ConversionPreset(
            name: "WAV Uncompressed",
            description: "Uncompressed audio, maximum compatibility",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .wav,
                sampleRate: 44100,
                channelCount: 2,
                bitDepth: 16,
                preserveMetadata: true,
                quality: 1.0
            ),
            recommendedFor: [.flac, .alac, .aiff],
            estimatedSizeRatio: 1.0
        )
        
        /// High-Resolution WAV
        public static let wavHiRes = ConversionPreset(
            name: "WAV Hi-Res (24-bit/96kHz)",
            description: "Studio-quality uncompressed audio",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .wav,
                sampleRate: 96000,
                channelCount: 2,
                bitDepth: 24,
                preserveMetadata: true,
                quality: 1.0
            ),
            recommendedFor: [],
            estimatedSizeRatio: 2.2
        )
    }
    
    /// Standard quality presets for general listening
    struct StandardQuality {
        
        /// AAC 256kbps - iTunes Plus quality
        public static let aac256 = ConversionPreset(
            name: "AAC 256kbps",
            description: "iTunes Plus quality, excellent sound with small file size",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 256000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.9
            ),
            recommendedFor: [.mp3, .flac, .wav, .alac],
            estimatedSizeRatio: 0.18
        )
        
        /// AAC 192kbps
        public static let aac192 = ConversionPreset(
            name: "AAC 192kbps",
            description: "Very good quality with smaller file size",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 192000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.8
            ),
            recommendedFor: [.mp3],
            estimatedSizeRatio: 0.14
        )
        
        /// MP3 320kbps - Maximum MP3 quality
        public static let mp3_320 = ConversionPreset(
            name: "MP3 320kbps",
            description: "Maximum MP3 quality, widely compatible",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .mp3,
                bitrate: 320000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.95
            ),
            recommendedFor: [.aac, .flac, .wav],
            estimatedSizeRatio: 0.23
        )
        
        /// MP3 256kbps VBR
        public static let mp3_256vbr = ConversionPreset(
            name: "MP3 256kbps VBR",
            description: "Variable bitrate for optimal quality/size balance",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .mp3,
                bitrate: 256000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.85
            ),
            recommendedFor: [.aac, .flac, .wav],
            estimatedSizeRatio: 0.18
        )
    }
    
    /// Compressed presets for space-saving
    struct Compressed {
        
        /// AAC 128kbps
        public static let aac128 = ConversionPreset(
            name: "AAC 128kbps",
            description: "Good quality with small file size",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 128000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.7
            ),
            recommendedFor: [.mp3],
            estimatedSizeRatio: 0.09
        )
        
        /// MP3 128kbps
        public static let mp3_128 = ConversionPreset(
            name: "MP3 128kbps",
            description: "Acceptable quality, maximum compatibility",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .mp3,
                bitrate: 128000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.6
            ),
            recommendedFor: [],
            estimatedSizeRatio: 0.09
        )
        
        /// AAC 96kbps
        public static let aac96 = ConversionPreset(
            name: "AAC 96kbps",
            description: "Voice/podcast quality",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 96000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.5
            ),
            recommendedFor: [],
            estimatedSizeRatio: 0.07
        )
        
        /// Mono AAC for voice
        public static let aacVoice = ConversionPreset(
            name: "AAC Voice (Mono)",
            description: "Optimized for spoken content",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 64000,
                sampleRate: 22050,
                channelCount: 1,
                preserveMetadata: true,
                quality: 0.6
            ),
            recommendedFor: [],
            estimatedSizeRatio: 0.04
        )
    }
    
    /// Special purpose presets
    struct SpecialPurpose {
        
        /// Convert to stereo
        public static let convertToStereo = ConversionPreset(
            name: "Convert to Stereo",
            description: "Convert mono or multi-channel to stereo",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 256000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.9
            ),
            recommendedFor: [],
            estimatedSizeRatio: 0.18
        )
        
        /// Downsample for compatibility
        public static let downsample = ConversionPreset(
            name: "Downsample to 44.1kHz",
            description: "Convert high sample rate audio for compatibility",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .aac,
                bitrate: 256000,
                sampleRate: 44100,
                channelCount: 2,
                preserveMetadata: true,
                quality: 0.9
            ),
            recommendedFor: [],
            estimatedSizeRatio: 0.18
        )
        
        /// Audiobook optimized
        public static let audiobook = ConversionPreset(
            name: "Audiobook",
            description: "Optimized for spoken content with chapters preserved",
            settings: AudioConverter.ConversionSettings(
                outputFormat: .m4a,
                bitrate: 64000,
                sampleRate: 22050,
                channelCount: 1,
                preserveMetadata: true,
                quality: 0.7
            ),
            recommendedFor: [],
            estimatedSizeRatio: 0.04
        )
    }
}

// MARK: - Preset Collections

public extension ConversionPreset {
    
    /// All available presets
    static var allPresets: [ConversionPreset] {
        return losslessPresets + lossyPresets + specialPresets
    }
    
    /// Lossless presets
    static var losslessPresets: [ConversionPreset] {
        return [
            HighQuality.flac,
            HighQuality.alac,
            HighQuality.wav,
            HighQuality.wavHiRes
        ]
    }
    
    /// Lossy presets
    static var lossyPresets: [ConversionPreset] {
        return [
            StandardQuality.aac256,
            StandardQuality.aac192,
            StandardQuality.mp3_320,
            StandardQuality.mp3_256vbr,
            Compressed.aac128,
            Compressed.mp3_128,
            Compressed.aac96,
            Compressed.aacVoice
        ]
    }
    
    /// Special purpose presets
    static var specialPresets: [ConversionPreset] {
        return [
            SpecialPurpose.convertToStereo,
            SpecialPurpose.downsample,
            SpecialPurpose.audiobook
        ]
    }
    
    /// Get recommended presets for a source format
    static func recommendedPresets(for sourceFormat: AudioFormat) -> [ConversionPreset] {
        return allPresets.filter { preset in
            preset.recommendedFor.contains(sourceFormat)
        }
    }
    
    /// Get presets by output format
    static func presets(outputFormat: AudioFormat) -> [ConversionPreset] {
        return allPresets.filter { preset in
            preset.settings.outputFormat == outputFormat
        }
    }
}

// MARK: - Custom Preset Builder

/// Builder for creating custom conversion presets
public class ConversionPresetBuilder {
    private var name: String = "Custom Preset"
    private var description: String = "Custom conversion settings"
    private var outputFormat: AudioFormat = .aac
    private var bitrate: Int?
    private var sampleRate: Int?
    private var channelCount: Int?
    private var bitDepth: Int?
    private var preserveMetadata: Bool = true
    private var overwriteExisting: Bool = false
    private var quality: Double = 0.8
    
    public init() {}
    
    public func withName(_ name: String) -> ConversionPresetBuilder {
        self.name = name
        return self
    }
    
    public func withDescription(_ description: String) -> ConversionPresetBuilder {
        self.description = description
        return self
    }
    
    public func withOutputFormat(_ format: AudioFormat) -> ConversionPresetBuilder {
        self.outputFormat = format
        return self
    }
    
    public func withBitrate(_ bitrate: Int) -> ConversionPresetBuilder {
        self.bitrate = bitrate
        return self
    }
    
    public func withSampleRate(_ sampleRate: Int) -> ConversionPresetBuilder {
        self.sampleRate = sampleRate
        return self
    }
    
    public func withChannelCount(_ channelCount: Int) -> ConversionPresetBuilder {
        self.channelCount = channelCount
        return self
    }
    
    public func withBitDepth(_ bitDepth: Int) -> ConversionPresetBuilder {
        self.bitDepth = bitDepth
        return self
    }
    
    public func withMetadataPreservation(_ preserve: Bool) -> ConversionPresetBuilder {
        self.preserveMetadata = preserve
        return self
    }
    
    public func withOverwriteExisting(_ overwrite: Bool) -> ConversionPresetBuilder {
        self.overwriteExisting = overwrite
        return self
    }
    
    public func withQuality(_ quality: Double) -> ConversionPresetBuilder {
        self.quality = quality
        return self
    }
    
    public func build() -> ConversionPreset {
        let settings = AudioConverter.ConversionSettings(
            outputFormat: outputFormat,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitDepth: bitDepth,
            preserveMetadata: preserveMetadata,
            overwriteExisting: overwriteExisting,
            quality: quality
        )
        
        return ConversionPreset(
            name: name,
            description: description,
            settings: settings,
            recommendedFor: [],
            estimatedSizeRatio: estimateSizeRatio()
        )
    }
    
    private func estimateSizeRatio() -> Double {
        // Estimate file size ratio based on format and bitrate
        if !outputFormat.isLossy {
            return outputFormat == .flac || outputFormat == .alac ? 0.55 : 1.0
        }
        
        guard let bitrate = bitrate else { return 0.5 }
        
        // Rough estimation based on bitrate (assuming source is uncompressed)
        let uncompressedBitrate = 44100.0 * 16.0 * 2.0  // 44.1kHz, 16-bit, stereo
        return Double(bitrate) / uncompressedBitrate
    }
}