//
//  FormatValidator.swift
//  WinAmpPlayer
//
//  Created on 2025-06-28.
//  Validates that detected audio formats match actual file content.
//

import Foundation
import AVFoundation
import os.log

/// Validates audio format detection results
public class FormatValidator {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.winamp.player", category: "FormatValidator")
    private let queue = DispatchQueue(label: "com.winamp.formatvalidator", qos: .userInitiated)
    private let detector: FormatDetector
    
    // MARK: - Initialization
    
    public init(detector: FormatDetector? = nil) {
        self.detector = detector ?? FormatDetector()
    }
    
    // MARK: - Public Methods
    
    /// Validate that a file matches the expected format
    /// - Parameters:
    ///   - url: The file URL to validate
    ///   - expectedFormat: The expected audio format
    /// - Returns: Validation result with details
    public func validate(url: URL, expectedFormat: AudioFormat) async throws -> ValidationResult {
        // First, detect the actual format
        let detectedInfo = try await detector.detectFormat(from: url)
        
        // Basic format match
        let formatMatches = detectedInfo.format == expectedFormat ||
                           (detectedInfo.containerFormat == expectedFormat)
        
        // Perform deeper validation based on format type
        let deepValidation = try await performDeepValidation(
            url: url,
            detectedFormat: detectedInfo.format,
            expectedFormat: expectedFormat
        )
        
        // Check file integrity
        let integrityCheck = try await checkFileIntegrity(url: url, format: detectedInfo.format)
        
        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(
            formatMatches: formatMatches,
            detectionConfidence: detectedInfo.confidence,
            deepValidation: deepValidation,
            integrityCheck: integrityCheck
        )
        
        return ValidationResult(
            isValid: formatMatches && deepValidation.isValid && integrityCheck.isValid,
            confidence: overallConfidence,
            detectedFormat: detectedInfo,
            expectedFormat: expectedFormat,
            issues: collectIssues(
                formatMatches: formatMatches,
                deepValidation: deepValidation,
                integrityCheck: integrityCheck
            ),
            details: ValidationDetails(
                formatValidation: deepValidation,
                integrityCheck: integrityCheck
            )
        )
    }
    
    /// Validate audio data matches expected format
    /// - Parameters:
    ///   - data: The audio data to validate
    ///   - expectedFormat: The expected audio format
    /// - Returns: Validation result
    public func validate(data: Data, expectedFormat: AudioFormat) async throws -> ValidationResult {
        // Detect format from data
        let detectedInfo = try await detector.detectFormat(from: data)
        
        // Basic format match
        let formatMatches = detectedInfo.format == expectedFormat
        
        // Validate data structure
        let structureValidation = validateDataStructure(data: data, format: expectedFormat)
        
        // Calculate confidence
        let overallConfidence = min(detectedInfo.confidence, structureValidation.confidence)
        
        return ValidationResult(
            isValid: formatMatches && structureValidation.isValid,
            confidence: overallConfidence,
            detectedFormat: detectedInfo,
            expectedFormat: expectedFormat,
            issues: formatMatches ? [] : [.formatMismatch],
            details: ValidationDetails(
                formatValidation: structureValidation,
                integrityCheck: IntegrityCheckResult(
                    isValid: true,
                    confidence: 1.0,
                    errors: []
                )
            )
        )
    }
    
    /// Quick validation check without deep inspection
    /// - Parameters:
    ///   - url: The file URL to check
    ///   - expectedFormat: The expected format
    /// - Returns: Quick validation result
    public func quickValidate(url: URL, expectedFormat: AudioFormat) -> Bool {
        // Check file extension
        let ext = url.pathExtension.lowercased()
        if !expectedFormat.fileExtensions.contains(ext) {
            return false
        }
        
        // Check file exists and is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }
        
        // Quick magic bytes check
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: 64) else {
            return false
        }
        defer { try? handle.close() }
        
        let bytes = Array(data)
        for signature in expectedFormat.magicBytes {
            if matchesSignature(bytes: bytes, signature: signature) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    /// Perform deep validation specific to the format
    private func performDeepValidation(url: URL, detectedFormat: AudioFormat, expectedFormat: AudioFormat) async throws -> FormatValidationResult {
        switch detectedFormat {
        case .mp3:
            return try await validateMP3(url: url)
        case .aac, .m4a, .alac:
            return try await validateM4A(url: url)
        case .flac:
            return try await validateFLAC(url: url)
        case .wav:
            return try await validateWAV(url: url)
        case .aiff:
            return try await validateAIFF(url: url)
        case .ogg, .opus:
            return try await validateOgg(url: url)
        default:
            return FormatValidationResult(isValid: true, confidence: 0.5, errors: [])
        }
    }
    
    /// Validate MP3 file structure
    private func validateMP3(url: URL) async throws -> FormatValidationResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var errors: [ValidationError] = []
        var frameCount = 0
        var hasID3v2 = false
        var hasID3v1 = false
        
        // Check for ID3v2 header
        let headerData = try handle.read(upToCount: 10) ?? Data()
        if headerData.starts(with: [0x49, 0x44, 0x33]) {  // "ID3"
            hasID3v2 = true
            // Skip ID3v2 tag
            let size = calculateID3v2Size(from: Array(headerData))
            try handle.seek(toOffset: UInt64(size + 10))
        }
        
        // Scan for MP3 frames
        var position = handle.offsetInFile
        let fileSize = try handle.seekToEnd()
        
        while position < fileSize - 4 {
            try handle.seek(toOffset: position)
            guard let frameHeader = try handle.read(upToCount: 4) else { break }
            
            if isValidMP3FrameHeader(Array(frameHeader)) {
                frameCount += 1
                // Skip to next potential frame (simplified - real implementation would calculate frame size)
                position += 400  // Approximate frame size
            } else {
                position += 1
            }
            
            // Sample first 100 frames for performance
            if frameCount >= 100 { break }
        }
        
        // Check for ID3v1 tag at end
        if fileSize >= 128 {
            try handle.seek(toOffset: fileSize - 128)
            if let tagData = try handle.read(upToCount: 3),
               tagData.starts(with: "TAG".data(using: .ascii)!) {
                hasID3v1 = true
            }
        }
        
        let isValid = frameCount >= 10  // At least 10 valid frames
        let confidence = min(1.0, Double(frameCount) / 50.0)
        
        if frameCount < 10 {
            errors.append(.insufficientFrames(found: frameCount, expected: 10))
        }
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors,
            metadata: [
                "frameCount": frameCount,
                "hasID3v2": hasID3v2,
                "hasID3v1": hasID3v1
            ]
        )
    }
    
    /// Validate M4A/AAC file structure
    private func validateM4A(url: URL) async throws -> FormatValidationResult {
        let asset = AVAsset(url: url)
        var errors: [ValidationError] = []
        
        // Check if asset is playable
        let isPlayable = try await asset.load(.isPlayable)
        if !isPlayable {
            errors.append(.notPlayable)
            return FormatValidationResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        // Validate atoms/boxes structure
        let atomValidation = try await validateM4AAtoms(url: url)
        errors.append(contentsOf: atomValidation.errors)
        
        // Check for audio track
        let tracks = try await asset.load(.tracks)
        let audioTracks = tracks.filter { $0.mediaType == .audio }
        
        if audioTracks.isEmpty {
            errors.append(.noAudioTrack)
            return FormatValidationResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        // Validate audio track
        if let audioTrack = audioTracks.first {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if formatDescriptions.isEmpty {
                errors.append(.invalidFormat("No format description"))
            }
        }
        
        let isValid = errors.isEmpty
        let confidence = isValid ? 0.95 : 0.3
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors,
            metadata: ["audioTrackCount": audioTracks.count]
        )
    }
    
    /// Validate M4A atom structure
    private func validateM4AAtoms(url: URL) async throws -> FormatValidationResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var errors: [ValidationError] = []
        var foundFtyp = false
        var foundMdat = false
        var foundMoov = false
        
        // Read and validate atoms
        var position: UInt64 = 0
        let fileSize = try handle.seekToEnd()
        
        while position < fileSize {
            try handle.seek(toOffset: position)
            
            // Read atom size and type
            guard let sizeData = try handle.read(upToCount: 4),
                  let typeData = try handle.read(upToCount: 4) else {
                break
            }
            
            let size = sizeData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let type = String(data: typeData, encoding: .ascii) ?? ""
            
            // Validate atom
            switch type {
            case "ftyp":
                foundFtyp = true
            case "mdat":
                foundMdat = true
            case "moov":
                foundMoov = true
            default:
                break
            }
            
            // Move to next atom
            if size == 1 {
                // 64-bit size
                guard let extendedSizeData = try handle.read(upToCount: 8) else { break }
                let extendedSize = extendedSizeData.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                position += extendedSize
            } else if size == 0 {
                // Extends to end of file
                break
            } else {
                position += UInt64(size)
            }
            
            // Limit scanning to prevent infinite loops
            if position > fileSize { break }
        }
        
        if !foundFtyp {
            errors.append(.missingRequiredAtom("ftyp"))
        }
        if !foundMdat && !foundMoov {
            errors.append(.missingRequiredAtom("mdat or moov"))
        }
        
        let isValid = foundFtyp && (foundMdat || foundMoov)
        let confidence = isValid ? 0.9 : 0.2
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors,
            metadata: [
                "foundFtyp": foundFtyp,
                "foundMdat": foundMdat,
                "foundMoov": foundMoov
            ]
        )
    }
    
    /// Validate FLAC file structure
    private func validateFLAC(url: URL) async throws -> FormatValidationResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var errors: [ValidationError] = []
        
        // Check FLAC signature
        guard let signature = try handle.read(upToCount: 4),
              signature == "fLaC".data(using: .ascii) else {
            errors.append(.invalidSignature)
            return FormatValidationResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        // Validate metadata blocks
        var foundStreamInfo = false
        var position: UInt64 = 4
        
        while true {
            try handle.seek(toOffset: position)
            guard let blockHeader = try handle.read(upToCount: 4) else { break }
            
            let isLast = (blockHeader[0] & 0x80) != 0
            let blockType = blockHeader[0] & 0x7F
            let blockSize = UInt32(blockHeader[1]) << 16 | UInt32(blockHeader[2]) << 8 | UInt32(blockHeader[3])
            
            if blockType == 0 {  // STREAMINFO
                foundStreamInfo = true
            }
            
            position += 4 + UInt64(blockSize)
            
            if isLast { break }
        }
        
        if !foundStreamInfo {
            errors.append(.missingRequiredBlock("STREAMINFO"))
        }
        
        let isValid = errors.isEmpty
        let confidence = isValid ? 0.95 : 0.3
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors
        )
    }
    
    /// Validate WAV file structure
    private func validateWAV(url: URL) async throws -> FormatValidationResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var errors: [ValidationError] = []
        
        // Check RIFF header
        guard let riffHeader = try handle.read(upToCount: 12) else {
            errors.append(.invalidHeader)
            return FormatValidationResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        let riffTag = riffHeader.subdata(in: 0..<4)
        let waveTag = riffHeader.subdata(in: 8..<12)
        
        if riffTag != "RIFF".data(using: .ascii) {
            errors.append(.invalidSignature)
        }
        if waveTag != "WAVE".data(using: .ascii) {
            errors.append(.invalidFormat("Not a WAVE file"))
        }
        
        // Look for fmt and data chunks
        var foundFmt = false
        var foundData = false
        var position: UInt64 = 12
        let fileSize = try handle.seekToEnd()
        
        while position < fileSize - 8 {
            try handle.seek(toOffset: position)
            
            guard let chunkHeader = try handle.read(upToCount: 8) else { break }
            let chunkID = chunkHeader.subdata(in: 0..<4)
            let chunkSize = chunkHeader.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
            
            if chunkID == "fmt ".data(using: .ascii) {
                foundFmt = true
            } else if chunkID == "data".data(using: .ascii) {
                foundData = true
            }
            
            position += 8 + UInt64(chunkSize)
            if chunkSize % 2 == 1 { position += 1 }  // Padding byte
        }
        
        if !foundFmt {
            errors.append(.missingRequiredChunk("fmt"))
        }
        if !foundData {
            errors.append(.missingRequiredChunk("data"))
        }
        
        let isValid = errors.isEmpty
        let confidence = isValid ? 0.95 : 0.3
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors
        )
    }
    
    /// Validate AIFF file structure
    private func validateAIFF(url: URL) async throws -> FormatValidationResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var errors: [ValidationError] = []
        
        // Check FORM header
        guard let formHeader = try handle.read(upToCount: 12) else {
            errors.append(.invalidHeader)
            return FormatValidationResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        let formTag = formHeader.subdata(in: 0..<4)
        let aiffTag = formHeader.subdata(in: 8..<12)
        
        if formTag != "FORM".data(using: .ascii) {
            errors.append(.invalidSignature)
        }
        if aiffTag != "AIFF".data(using: .ascii) && aiffTag != "AIFC".data(using: .ascii) {
            errors.append(.invalidFormat("Not an AIFF file"))
        }
        
        let isValid = errors.isEmpty
        let confidence = isValid ? 0.95 : 0.3
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors
        )
    }
    
    /// Validate Ogg file structure
    private func validateOgg(url: URL) async throws -> FormatValidationResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var errors: [ValidationError] = []
        var pageCount = 0
        
        // Scan for Ogg pages
        var position: UInt64 = 0
        let fileSize = try handle.seekToEnd()
        
        while position < fileSize - 27 {  // Minimum Ogg page header size
            try handle.seek(toOffset: position)
            
            guard let pageHeader = try handle.read(upToCount: 27) else { break }
            
            // Check for OggS signature
            if pageHeader.starts(with: "OggS".data(using: .ascii)!) {
                pageCount += 1
                
                // Get segment count to calculate page size
                let segmentCount = pageHeader[26]
                guard let segmentTable = try handle.read(upToCount: Int(segmentCount)) else { break }
                
                let dataSize = segmentTable.reduce(0) { $0 + Int($1) }
                position += 27 + UInt64(segmentCount) + UInt64(dataSize)
            } else {
                position += 1
            }
            
            // Sample first 50 pages for performance
            if pageCount >= 50 { break }
        }
        
        if pageCount < 2 {
            errors.append(.insufficientPages(found: pageCount, expected: 2))
        }
        
        let isValid = pageCount >= 2
        let confidence = min(1.0, Double(pageCount) / 20.0)
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors,
            metadata: ["pageCount": pageCount]
        )
    }
    
    /// Check file integrity
    private func checkFileIntegrity(url: URL, format: AudioFormat) async throws -> IntegrityCheckResult {
        var errors: [ValidationError] = []
        
        // Check file readability
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            errors.append(.fileNotReadable)
            return IntegrityCheckResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            errors.append(.invalidFileSize)
            return IntegrityCheckResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        // Minimum file size check
        let minSize: Int64
        switch format {
        case .mp3, .aac, .ogg, .opus:
            minSize = 1024  // 1KB minimum for compressed formats
        case .wav, .aiff, .flac:
            minSize = 4096  // 4KB minimum for uncompressed/lossless
        default:
            minSize = 512
        }
        
        if fileSize < minSize {
            errors.append(.fileTooSmall(size: fileSize, minimum: minSize))
        }
        
        // Try to create AVAsset to verify playability
        let asset = AVAsset(url: url)
        let isPlayable = try await asset.load(.isPlayable)
        if !isPlayable {
            errors.append(.notPlayable)
        }
        
        let isValid = errors.isEmpty
        let confidence = isValid ? 0.9 : 0.3
        
        return IntegrityCheckResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors,
            metadata: ["fileSize": fileSize]
        )
    }
    
    /// Validate data structure
    private func validateDataStructure(data: Data, format: AudioFormat) -> FormatValidationResult {
        var errors: [ValidationError] = []
        let bytes = Array(data.prefix(64))
        
        // Check minimum data size
        if data.count < 64 {
            errors.append(.insufficientData)
            return FormatValidationResult(isValid: false, confidence: 0.0, errors: errors)
        }
        
        // Check magic bytes
        var foundValidSignature = false
        for signature in format.magicBytes {
            if matchesSignature(bytes: bytes, signature: signature) {
                foundValidSignature = true
                break
            }
        }
        
        if !foundValidSignature {
            errors.append(.invalidSignature)
        }
        
        let isValid = foundValidSignature
        let confidence = isValid ? 0.8 : 0.1
        
        return FormatValidationResult(
            isValid: isValid,
            confidence: confidence,
            errors: errors
        )
    }
    
    // MARK: - Helper Methods
    
    /// Check if bytes match signature
    private func matchesSignature(bytes: [UInt8], signature: [UInt8]) -> Bool {
        guard bytes.count >= signature.count else { return false }
        
        for i in 0..<signature.count {
            if bytes[i] != signature[i] {
                return false
            }
        }
        return true
    }
    
    /// Calculate ID3v2 tag size
    private func calculateID3v2Size(from header: [UInt8]) -> Int {
        guard header.count >= 10 else { return 0 }
        
        // Synchsafe integer decoding
        let size = (Int(header[6]) << 21) |
                   (Int(header[7]) << 14) |
                   (Int(header[8]) << 7) |
                   Int(header[9])
        return size
    }
    
    /// Check if data represents a valid MP3 frame header
    private func isValidMP3FrameHeader(_ header: [UInt8]) -> Bool {
        guard header.count >= 4 else { return false }
        
        // Check sync word (11 bits set)
        if header[0] != 0xFF || (header[1] & 0xE0) != 0xE0 {
            return false
        }
        
        // Check MPEG version (bits 19-20)
        let version = (header[1] & 0x18) >> 3
        if version == 0x01 { return false }  // Reserved
        
        // Check layer (bits 17-18)
        let layer = (header[1] & 0x06) >> 1
        if layer == 0x00 { return false }  // Reserved
        
        // Check bitrate (bits 12-15)
        let bitrate = (header[2] & 0xF0) >> 4
        if bitrate == 0x0F { return false }  // Bad
        
        // Check sample rate (bits 10-11)
        let sampleRate = (header[2] & 0x0C) >> 2
        if sampleRate == 0x03 { return false }  // Reserved
        
        return true
    }
    
    /// Calculate overall confidence
    private func calculateOverallConfidence(
        formatMatches: Bool,
        detectionConfidence: Double,
        deepValidation: FormatValidationResult,
        integrityCheck: IntegrityCheckResult
    ) -> Double {
        if !formatMatches { return 0.0 }
        
        // Weight the different confidence scores
        let weights: [Double] = [0.3, 0.4, 0.3]  // detection, validation, integrity
        let scores = [detectionConfidence, deepValidation.confidence, integrityCheck.confidence]
        
        let weightedSum = zip(weights, scores).reduce(0.0) { $0 + ($1.0 * $1.1) }
        return min(1.0, weightedSum)
    }
    
    /// Collect validation issues
    private func collectIssues(
        formatMatches: Bool,
        deepValidation: FormatValidationResult,
        integrityCheck: IntegrityCheckResult
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if !formatMatches {
            issues.append(.formatMismatch)
        }
        
        if !deepValidation.errors.isEmpty {
            issues.append(.structureErrors(deepValidation.errors))
        }
        
        if !integrityCheck.errors.isEmpty {
            issues.append(.integrityErrors(integrityCheck.errors))
        }
        
        return issues
    }
}

// MARK: - Supporting Types

/// Result of format validation
public struct ValidationResult {
    let isValid: Bool
    let confidence: Double
    let detectedFormat: AudioFormatInfo
    let expectedFormat: AudioFormat
    let issues: [ValidationIssue]
    let details: ValidationDetails
}

/// Detailed validation information
public struct ValidationDetails {
    let formatValidation: FormatValidationResult
    let integrityCheck: IntegrityCheckResult
}

/// Result of format-specific validation
public struct FormatValidationResult {
    let isValid: Bool
    let confidence: Double
    let errors: [ValidationError]
    var metadata: [String: Any] = [:]
}

/// Result of integrity check
public struct IntegrityCheckResult {
    let isValid: Bool
    let confidence: Double
    let errors: [ValidationError]
    var metadata: [String: Any] = [:]
}

/// Validation issues
public enum ValidationIssue {
    case formatMismatch
    case structureErrors([ValidationError])
    case integrityErrors([ValidationError])
}

/// Specific validation errors
public enum ValidationError: LocalizedError {
    case invalidSignature
    case invalidHeader
    case invalidFormat(String)
    case missingRequiredAtom(String)
    case missingRequiredChunk(String)
    case missingRequiredBlock(String)
    case insufficientFrames(found: Int, expected: Int)
    case insufficientPages(found: Int, expected: Int)
    case noAudioTrack
    case notPlayable
    case fileNotReadable
    case invalidFileSize
    case fileTooSmall(size: Int64, minimum: Int64)
    case insufficientData
    case corruptedData(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSignature:
            return "Invalid file signature"
        case .invalidHeader:
            return "Invalid file header"
        case .invalidFormat(let details):
            return "Invalid format: \(details)"
        case .missingRequiredAtom(let atom):
            return "Missing required atom: \(atom)"
        case .missingRequiredChunk(let chunk):
            return "Missing required chunk: \(chunk)"
        case .missingRequiredBlock(let block):
            return "Missing required block: \(block)"
        case .insufficientFrames(let found, let expected):
            return "Insufficient frames: found \(found), expected at least \(expected)"
        case .insufficientPages(let found, let expected):
            return "Insufficient pages: found \(found), expected at least \(expected)"
        case .noAudioTrack:
            return "No audio track found"
        case .notPlayable:
            return "File is not playable"
        case .fileNotReadable:
            return "File is not readable"
        case .invalidFileSize:
            return "Invalid file size"
        case .fileTooSmall(let size, let minimum):
            return "File too small: \(size) bytes, minimum \(minimum)"
        case .insufficientData:
            return "Insufficient data for validation"
        case .corruptedData(let details):
            return "Corrupted data: \(details)"
        }
    }
}