import Foundation
import AppKit

/// WSZ (WinAmp Skin ZIP) archive handler
/// Extracts .wsz/.zip files to temporary directory and provides file access
public class ClassicWSZArchive {
    public let sourceURL: URL
    public let extractedDirectory: URL
    private let fileManager = FileManager.default
    
    /// Extracted file URLs mapped by filename
    private var extractedFiles: [String: URL] = [:]
    
    public init(url: URL) throws {
        self.sourceURL = url
        
        // Create temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("WinAmpSkins")
            .appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        self.extractedDirectory = tempDir
        
        // Extract the archive
        try extractArchive()
    }
    
    deinit {
        // Clean up temporary directory
        try? fileManager.removeItem(at: extractedDirectory)
    }
    
    /// Extract WSZ/ZIP archive using system unzip
    private func extractArchive() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = [
            "-q",  // quiet
            "-o",  // overwrite
            sourceURL.path,
            "-d", extractedDirectory.path
        ]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WSZArchiveError.extractionFailed(errorMessage)
        }
        
        // Build file index
        try buildFileIndex()
    }
    
    /// Build index of extracted files for quick lookup
    private func buildFileIndex() throws {
        let enumerator = fileManager.enumerator(at: extractedDirectory, 
                                              includingPropertiesForKeys: [.isRegularFileKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                let filename = fileURL.lastPathComponent.lowercased()
                extractedFiles[filename] = fileURL
            }
        }
    }
    
    /// Get URL for a specific file in the archive
    public func url(for filename: String) -> URL? {
        return extractedFiles[filename.lowercased()]
    }
    
    /// Check if a file exists in the archive
    public func contains(_ filename: String) -> Bool {
        return extractedFiles[filename.lowercased()] != nil
    }
    
    /// Get Data for a specific file
    public func data(for filename: String) throws -> Data {
        guard let fileURL = url(for: filename) else {
            throw WSZArchiveError.fileNotFound(filename)
        }
        return try Data(contentsOf: fileURL)
    }
    
    /// List all available files in the archive
    public var availableFiles: [String] {
        return Array(extractedFiles.keys).sorted()
    }
    
    /// Validate that this appears to be a valid WinAmp skin
    public func validateSkinStructure() throws {
        let requiredFiles = [
            "main.bmp",
            "cbuttons.bmp", 
            "playpaus.bmp",
            "region.txt"
        ]
        
        let missingFiles = requiredFiles.filter { !contains($0) }
        if !missingFiles.isEmpty {
            throw WSZArchiveError.invalidSkinStructure(missingFiles)
        }
    }
}

// MARK: - Error Types

public enum WSZArchiveError: LocalizedError {
    case extractionFailed(String)
    case fileNotFound(String)
    case invalidSkinStructure([String])
    
    public var errorDescription: String? {
        switch self {
        case .extractionFailed(let message):
            return "Failed to extract WSZ archive: \(message)"
        case .fileNotFound(let filename):
            return "File not found in archive: \(filename)"
        case .invalidSkinStructure(let missing):
            return "Invalid skin structure. Missing files: \(missing.joined(separator: ", "))"
        }
    }
}
