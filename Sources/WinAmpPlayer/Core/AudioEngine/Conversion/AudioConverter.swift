//
//  AudioConverter.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Handles audio format conversion between different audio formats.
//

import Foundation
import AVFoundation

/// Errors that can occur during audio conversion
public enum AudioConversionError: LocalizedError {
    case unsupportedFormat(AudioFormat)
    case fileNotFound(URL)
    case conversionFailed(String)
    case invalidSettings
    case metadataExtractionFailed
    case outputFileExists
    case insufficientDiskSpace
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format.displayName)"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .conversionFailed(let reason):
            return "Conversion failed: \(reason)"
        case .invalidSettings:
            return "Invalid conversion settings"
        case .metadataExtractionFailed:
            return "Failed to extract metadata from source file"
        case .outputFileExists:
            return "Output file already exists"
        case .insufficientDiskSpace:
            return "Insufficient disk space for conversion"
        case .cancelled:
            return "Conversion was cancelled"
        }
    }
}

/// Progress information for conversion operations
public struct ConversionProgress {
    /// Current progress (0.0 to 1.0)
    public let progress: Double
    
    /// Current file being processed (for batch operations)
    public let currentFile: URL?
    
    /// Total files to process
    public let totalFiles: Int
    
    /// Completed files count
    public let completedFiles: Int
    
    /// Estimated time remaining in seconds
    public let estimatedTimeRemaining: TimeInterval?
}

/// Audio converter for format conversion
public class AudioConverter {
    
    /// Conversion quality settings
    public struct ConversionSettings {
        /// Output format
        let outputFormat: AudioFormat
        
        /// Audio bitrate (for lossy formats)
        let bitrate: Int?
        
        /// Sample rate
        let sampleRate: Int?
        
        /// Number of channels (1 = mono, 2 = stereo)
        let channelCount: Int?
        
        /// Bit depth (for lossless formats)
        let bitDepth: Int?
        
        /// Whether to preserve metadata
        let preserveMetadata: Bool
        
        /// Whether to overwrite existing files
        let overwriteExisting: Bool
        
        /// Quality level (0.0 to 1.0)
        let quality: Double
        
        public init(
            outputFormat: AudioFormat,
            bitrate: Int? = nil,
            sampleRate: Int? = nil,
            channelCount: Int? = nil,
            bitDepth: Int? = nil,
            preserveMetadata: Bool = true,
            overwriteExisting: Bool = false,
            quality: Double = 0.8
        ) {
            self.outputFormat = outputFormat
            self.bitrate = bitrate
            self.sampleRate = sampleRate
            self.channelCount = channelCount
            self.bitDepth = bitDepth
            self.preserveMetadata = preserveMetadata
            self.overwriteExisting = overwriteExisting
            self.quality = max(0.0, min(1.0, quality))
        }
    }
    
    /// Progress callback type
    public typealias ProgressCallback = (ConversionProgress) -> Void
    
    /// Completion callback type
    public typealias CompletionCallback = (Result<URL, AudioConversionError>) -> Void
    
    private let fileManager = FileManager.default
    private var activeConversions = Set<UUID>()
    private let conversionQueue = DispatchQueue(label: "com.winampplayer.audioconverter", attributes: .concurrent)
    private let progressQueue = DispatchQueue(label: "com.winampplayer.audioconverter.progress")
    
    public init() {}
    
    /// Convert a single audio file
    /// - Parameters:
    ///   - sourceURL: Source audio file URL
    ///   - outputURL: Destination file URL
    ///   - settings: Conversion settings
    ///   - progress: Optional progress callback
    ///   - completion: Completion callback with result
    public func convertAudioFile(
        from sourceURL: URL,
        to outputURL: URL,
        settings: ConversionSettings,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        conversionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Validate source file exists
            guard self.fileManager.fileExists(atPath: sourceURL.path) else {
                completion(.failure(.fileNotFound(sourceURL)))
                return
            }
            
            // Check if output file exists
            if !settings.overwriteExisting && self.fileManager.fileExists(atPath: outputURL.path) {
                completion(.failure(.outputFileExists))
                return
            }
            
            // Create output directory if needed
            let outputDir = outputURL.deletingLastPathComponent()
            if !self.fileManager.fileExists(atPath: outputDir.path) {
                do {
                    try self.fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
                } catch {
                    completion(.failure(.conversionFailed("Failed to create output directory: \(error.localizedDescription)")))
                    return
                }
            }
            
            // Generate conversion ID
            let conversionID = UUID()
            self.progressQueue.sync {
                self.activeConversions.insert(conversionID)
            }
            
            // Perform conversion
            do {
                let convertedURL = try self.performConversion(
                    from: sourceURL,
                    to: outputURL,
                    settings: settings,
                    conversionID: conversionID,
                    progress: progress
                )
                
                // Preserve metadata if requested
                if settings.preserveMetadata {
                    try self.copyMetadata(from: sourceURL, to: convertedURL)
                }
                
                completion(.success(convertedURL))
            } catch {
                if let conversionError = error as? AudioConversionError {
                    completion(.failure(conversionError))
                } else {
                    completion(.failure(.conversionFailed(error.localizedDescription)))
                }
            }
            
            // Clean up
            self.progressQueue.sync {
                self.activeConversions.remove(conversionID)
            }
        }
    }
    
    /// Convert multiple audio files
    /// - Parameters:
    ///   - sourceURLs: Array of source audio file URLs
    ///   - outputDirectory: Directory to save converted files
    ///   - settings: Conversion settings
    ///   - progress: Optional progress callback
    ///   - completion: Completion callback with results
    public func convertAudioFiles(
        from sourceURLs: [URL],
        to outputDirectory: URL,
        settings: ConversionSettings,
        progress: ProgressCallback? = nil,
        completion: @escaping (Result<[URL], AudioConversionError>) -> Void
    ) {
        conversionQueue.async { [weak self] in
            guard let self = self else { return }
            
            var convertedFiles: [URL] = []
            var lastError: AudioConversionError?
            
            // Create output directory if needed
            if !self.fileManager.fileExists(atPath: outputDirectory.path) {
                do {
                    try self.fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                } catch {
                    completion(.failure(.conversionFailed("Failed to create output directory: \(error.localizedDescription)")))
                    return
                }
            }
            
            let totalFiles = sourceURLs.count
            
            for (index, sourceURL) in sourceURLs.enumerated() {
                // Generate output filename
                let outputFilename = sourceURL.deletingPathExtension().lastPathComponent + "." + settings.outputFormat.fileExtensions.first!
                let outputURL = outputDirectory.appendingPathComponent(outputFilename)
                
                // Update progress
                if let progress = progress {
                    let conversionProgress = ConversionProgress(
                        progress: Double(index) / Double(totalFiles),
                        currentFile: sourceURL,
                        totalFiles: totalFiles,
                        completedFiles: index,
                        estimatedTimeRemaining: nil
                    )
                    DispatchQueue.main.async {
                        progress(conversionProgress)
                    }
                }
                
                // Convert file
                let semaphore = DispatchSemaphore(value: 0)
                
                self.convertAudioFile(from: sourceURL, to: outputURL, settings: settings) { result in
                    switch result {
                    case .success(let url):
                        convertedFiles.append(url)
                    case .failure(let error):
                        lastError = error
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
                
                // Check if cancelled
                if lastError == .cancelled {
                    break
                }
            }
            
            // Final progress update
            if let progress = progress {
                let finalProgress = ConversionProgress(
                    progress: 1.0,
                    currentFile: nil,
                    totalFiles: totalFiles,
                    completedFiles: convertedFiles.count,
                    estimatedTimeRemaining: 0
                )
                DispatchQueue.main.async {
                    progress(finalProgress)
                }
            }
            
            if let error = lastError, convertedFiles.isEmpty {
                completion(.failure(error))
            } else {
                completion(.success(convertedFiles))
            }
        }
    }
    
    /// Cancel all active conversions
    public func cancelAllConversions() {
        progressQueue.sync {
            activeConversions.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func performConversion(
        from sourceURL: URL,
        to outputURL: URL,
        settings: ConversionSettings,
        conversionID: UUID,
        progress: ProgressCallback?
    ) throws -> URL {
        // Create asset from source file
        let asset = AVURLAsset(url: sourceURL)
        
        // Check if asset is readable
        guard asset.isReadable else {
            throw AudioConversionError.conversionFailed("Cannot read source file")
        }
        
        // Get audio track
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw AudioConversionError.conversionFailed("No audio track found in source file")
        }
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: getExportPreset(for: settings)) else {
            throw AudioConversionError.conversionFailed("Failed to create export session")
        }
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = getOutputFileType(for: settings.outputFormat)
        exportSession.audioMix = createAudioMix(for: audioTrack, settings: settings)
        
        // Apply audio settings if available
        if let audioSettings = createAudioSettings(for: settings) {
            exportSession.audioSettings = audioSettings
        }
        
        // Start export
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        
        exportSession.exportAsynchronously {
            if exportSession.status == .failed {
                exportError = exportSession.error
            }
            semaphore.signal()
        }
        
        // Monitor progress
        if progress != nil {
            monitorExportProgress(exportSession: exportSession, conversionID: conversionID, progress: progress)
        }
        
        semaphore.wait()
        
        // Check if cancelled
        if !progressQueue.sync(execute: { activeConversions.contains(conversionID) }) {
            throw AudioConversionError.cancelled
        }
        
        // Check export status
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw AudioConversionError.conversionFailed(exportError?.localizedDescription ?? "Unknown error")
        case .cancelled:
            throw AudioConversionError.cancelled
        default:
            throw AudioConversionError.conversionFailed("Export failed with status: \(exportSession.status.rawValue)")
        }
    }
    
    private func getExportPreset(for settings: ConversionSettings) -> String {
        switch settings.outputFormat {
        case .aac, .m4a:
            if let bitrate = settings.bitrate {
                if bitrate >= 256000 {
                    return AVAssetExportPresetAppleM4A
                }
            }
            return AVAssetExportPresetAppleM4A
        case .alac:
            return AVAssetExportPresetAppleM4A
        default:
            return AVAssetExportPresetPassthrough
        }
    }
    
    private func getOutputFileType(for format: AudioFormat) -> AVFileType {
        switch format {
        case .aac, .m4a, .alac:
            return .m4a
        case .mp3:
            return .mp3
        case .wav:
            return .wav
        case .aiff:
            return .aiff
        default:
            return .m4a  // Default to M4A
        }
    }
    
    private func createAudioSettings(for settings: ConversionSettings) -> [String: Any]? {
        var audioSettings: [String: Any] = [:]
        
        // Set audio format
        switch settings.outputFormat {
        case .aac, .m4a:
            audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        case .alac:
            audioSettings[AVFormatIDKey] = kAudioFormatAppleLossless
        case .mp3:
            audioSettings[AVFormatIDKey] = kAudioFormatMPEGLayer3
        case .wav:
            audioSettings[AVFormatIDKey] = kAudioFormatLinearPCM
        case .aiff:
            audioSettings[AVFormatIDKey] = kAudioFormatLinearPCM
        default:
            return nil
        }
        
        // Set sample rate
        if let sampleRate = settings.sampleRate {
            audioSettings[AVSampleRateKey] = sampleRate
        }
        
        // Set channel count
        if let channelCount = settings.channelCount {
            audioSettings[AVNumberOfChannelsKey] = channelCount
        }
        
        // Set bitrate for lossy formats
        if settings.outputFormat.isLossy, let bitrate = settings.bitrate {
            audioSettings[AVEncoderBitRateKey] = bitrate
        }
        
        // Set bit depth for lossless formats
        if !settings.outputFormat.isLossy, let bitDepth = settings.bitDepth {
            audioSettings[AVLinearPCMBitDepthKey] = bitDepth
            audioSettings[AVLinearPCMIsBigEndianKey] = false
            audioSettings[AVLinearPCMIsFloatKey] = false
            audioSettings[AVLinearPCMIsNonInterleaved] = false
        }
        
        // Set quality
        audioSettings[AVEncoderAudioQualityKey] = getAudioQuality(from: settings.quality)
        
        return audioSettings
    }
    
    private func getAudioQuality(from quality: Double) -> AVAudioQuality {
        switch quality {
        case 0..<0.25:
            return .low
        case 0.25..<0.5:
            return .medium
        case 0.5..<0.75:
            return .high
        default:
            return .max
        }
    }
    
    private func createAudioMix(for audioTrack: AVAssetTrack, settings: ConversionSettings) -> AVAudioMix? {
        let audioMixInputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
        
        // Apply any audio processing here if needed
        // For now, we'll just pass through
        
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [audioMixInputParameters]
        
        return audioMix
    }
    
    private func monitorExportProgress(
        exportSession: AVAssetExportSession,
        conversionID: UUID,
        progress: ProgressCallback?
    ) {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if cancelled
            if !self.progressQueue.sync(execute: { self.activeConversions.contains(conversionID) }) {
                exportSession.cancelExport()
                return
            }
            
            // Update progress
            if let progress = progress {
                let conversionProgress = ConversionProgress(
                    progress: Double(exportSession.progress),
                    currentFile: exportSession.outputURL,
                    totalFiles: 1,
                    completedFiles: 0,
                    estimatedTimeRemaining: nil
                )
                DispatchQueue.main.async {
                    progress(conversionProgress)
                }
            }
        }
        
        RunLoop.current.add(timer, forMode: .common)
        
        // Clean up timer when export completes
        conversionQueue.async {
            while exportSession.status == .waiting || exportSession.status == .exporting {
                Thread.sleep(forTimeInterval: 0.1)
            }
            timer.invalidate()
        }
    }
    
    private func copyMetadata(from sourceURL: URL, to destinationURL: URL) throws {
        // This is a placeholder for metadata copying
        // In a real implementation, you would use AVAssetWriter to preserve metadata
        // For now, we'll just return without error
    }
}

// MARK: - Convenience Methods

extension AudioConverter {
    
    /// Convert audio file with a preset
    public func convertAudioFile(
        from sourceURL: URL,
        to outputURL: URL,
        preset: ConversionPreset,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        convertAudioFile(
            from: sourceURL,
            to: outputURL,
            settings: preset.settings,
            progress: progress,
            completion: completion
        )
    }
    
    /// Check if a format conversion is supported
    public static func isConversionSupported(from sourceFormat: AudioFormat, to targetFormat: AudioFormat) -> Bool {
        // For now, we support conversions between most common formats
        // Some conversions might not be supported by AVFoundation
        switch (sourceFormat, targetFormat) {
        case (.unknown, _), (_, .unknown):
            return false
        case (.opus, _), (_, .opus):
            // Opus support is limited in AVFoundation
            return false
        default:
            return true
        }
    }
}