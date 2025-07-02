import Foundation

/// Parser for PLS (INI-style) playlist format
public class PLSParser: PlaylistParser {
    public static let supportedExtensions = ["pls"]
    
    private let baseURL: URL?
    
    /// Initialize parser with optional base URL for resolving relative paths
    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }
    
    public func parse(data: Data) throws -> [PlaylistTrack] {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw PlaylistParseError.invalidEncoding
        }
        
        return try parseContent(content)
    }
    
    private func parseContent(_ content: String) throws -> [PlaylistTrack] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw PlaylistParseError.emptyPlaylist
        }
        
        // Verify it's a PLS file
        guard lines.first?.lowercased() == "[playlist]" else {
            throw PlaylistParseError.invalidFormat
        }
        
        var entries: [Int: PlaylistEntry] = [:]
        var numberOfEntries: Int?
        var version: String?
        
        for line in lines.dropFirst() {
            // Skip comments
            if line.hasPrefix(";") || line.hasPrefix("#") {
                continue
            }
            
            // Parse key=value pairs
            guard let equalIndex = line.firstIndex(of: "=") else {
                continue
            }
            
            let key = line[..<equalIndex].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespaces)
            
            if key == "numberofentries" {
                numberOfEntries = Int(value)
            } else if key == "version" {
                version = value
            } else if key.hasPrefix("file") {
                // Extract entry number
                if let number = extractNumber(from: key, prefix: "file") {
                    if entries[number] == nil {
                        entries[number] = PlaylistEntry()
                    }
                    entries[number]?.file = value
                }
            } else if key.hasPrefix("title") {
                if let number = extractNumber(from: key, prefix: "title") {
                    if entries[number] == nil {
                        entries[number] = PlaylistEntry()
                    }
                    entries[number]?.title = value
                }
            } else if key.hasPrefix("length") {
                if let number = extractNumber(from: key, prefix: "length"),
                   let duration = TimeInterval(value) {
                    if entries[number] == nil {
                        entries[number] = PlaylistEntry()
                    }
                    entries[number]?.length = duration
                }
            }
        }
        
        // Convert entries to tracks
        let sortedEntries = entries.sorted { $0.key < $1.key }
        var tracks: [PlaylistTrack] = []
        
        for (_, entry) in sortedEntries {
            guard let file = entry.file,
                  let url = resolveURL(from: file) else {
                continue
            }
            
            let track = PlaylistTrack(
                url: url,
                title: entry.title,
                duration: entry.length
            )
            
            tracks.append(track)
        }
        
        guard !tracks.isEmpty else {
            throw PlaylistParseError.emptyPlaylist
        }
        
        // Validate number of entries if specified
        if let expectedCount = numberOfEntries, tracks.count != expectedCount {
            // Continue anyway, but we could log a warning
        }
        
        return tracks
    }
    
    private func extractNumber(from key: String, prefix: String) -> Int? {
        let suffix = key.dropFirst(prefix.count)
        return Int(suffix)
    }
    
    private func resolveURL(from path: String) -> URL? {
        // Check if it's already a valid URL
        if let url = URL(string: path) {
            if url.scheme != nil {
                return url
            }
        }
        
        // Handle Windows-style paths
        let normalizedPath = path.replacingOccurrences(of: "\\", with: "/")
        
        // Try as file URL
        let fileURL = URL(fileURLWithPath: normalizedPath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        // Try relative to base URL
        if let baseURL = baseURL {
            if let relativeURL = URL(string: normalizedPath, relativeTo: baseURL) {
                return relativeURL
            }
        }
        
        // Last resort: try as file URL even if it doesn't exist
        return URL(fileURLWithPath: normalizedPath)
    }
    
    private struct PlaylistEntry {
        var file: String?
        var title: String?
        var length: TimeInterval?
    }
}

/// Writer for PLS playlists
public class PLSWriter: PlaylistWriter {
    public static let fileExtension = "pls"
    
    public init() {}
    
    public func write(tracks: [PlaylistTrack]) throws -> Data {
        var lines: [String] = []
        
        // Header
        lines.append("[playlist]")
        lines.append("")
        
        // Write entries
        for (index, track) in tracks.enumerated() {
            let entryNum = index + 1
            
            // File path/URL
            lines.append("File\(entryNum)=\(track.url.absoluteString)")
            
            // Title
            if let title = track.title {
                lines.append("Title\(entryNum)=\(title)")
            }
            
            // Length (duration in seconds, -1 for unknown)
            let duration = Int(track.duration ?? -1)
            lines.append("Length\(entryNum)=\(duration)")
            
            lines.append("")
        }
        
        // Footer
        lines.append("NumberOfEntries=\(tracks.count)")
        lines.append("Version=2")
        
        let content = lines.joined(separator: "\n") + "\n"
        guard let data = content.data(using: .utf8) else {
            throw PlaylistParseError.invalidEncoding
        }
        
        return data
    }
}