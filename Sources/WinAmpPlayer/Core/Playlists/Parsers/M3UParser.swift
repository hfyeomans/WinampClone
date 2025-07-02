import Foundation

/// Parser for M3U and M3U8 (extended) playlist formats
public class M3UParser: PlaylistParser {
    public static let supportedExtensions = ["m3u", "m3u8"]
    
    private let baseURL: URL?
    
    /// Initialize parser with optional base URL for resolving relative paths
    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }
    
    public func parse(data: Data) throws -> [PlaylistTrack] {
        // Try UTF-8 first (required for M3U8), fallback to Latin-1 for M3U
        let content: String
        if let utf8String = String(data: data, encoding: .utf8) {
            content = utf8String
        } else if let latinString = String(data: data, encoding: .isoLatin1) {
            content = latinString
        } else {
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
        
        var tracks: [PlaylistTrack] = []
        var isExtended = false
        var currentTitle: String?
        var currentDuration: TimeInterval?
        var currentMetadata: [String: String] = [:]
        
        for line in lines {
            if line.hasPrefix("#EXTM3U") {
                isExtended = true
                continue
            }
            
            if line.hasPrefix("#EXTINF:") {
                // Parse extended info: #EXTINF:duration,title
                let info = line.dropFirst("#EXTINF:".count)
                let parts = info.split(separator: ",", maxSplits: 1)
                
                if let durationStr = parts.first {
                    currentDuration = TimeInterval(String(durationStr)) ?? -1
                    if currentDuration! < 0 {
                        currentDuration = nil
                    }
                }
                
                if parts.count > 1 {
                    currentTitle = String(parts[1]).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            
            if line.hasPrefix("#EXT-X-") {
                // HLS-specific tags
                let tag = line.dropFirst("#EXT-X-".count)
                if let colonIndex = tag.firstIndex(of: ":") {
                    let key = String(tag[..<colonIndex])
                    let value = String(tag[tag.index(after: colonIndex)...])
                    currentMetadata[key] = value
                }
                continue
            }
            
            if line.hasPrefix("#") {
                // Skip other comments
                continue
            }
            
            // This is a track URL/path
            guard let trackURL = resolveURL(from: line) else {
                continue
            }
            
            let track = PlaylistTrack(
                url: trackURL,
                title: currentTitle,
                duration: currentDuration,
                metadata: currentMetadata
            )
            
            tracks.append(track)
            
            // Reset for next track
            currentTitle = nil
            currentDuration = nil
            currentMetadata = [:]
        }
        
        guard !tracks.isEmpty else {
            throw PlaylistParseError.emptyPlaylist
        }
        
        return tracks
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
}

/// Writer for M3U/M3U8 playlists
public class M3UWriter: PlaylistWriter {
    public static let fileExtension = "m3u8"
    
    private let extended: Bool
    private let encoding: String.Encoding
    
    /// Initialize writer
    /// - Parameters:
    ///   - extended: Whether to write extended M3U format with metadata
    ///   - encoding: Text encoding to use (UTF-8 for M3U8, Latin-1 for M3U)
    public init(extended: Bool = true, encoding: String.Encoding = .utf8) {
        self.extended = extended
        self.encoding = encoding
    }
    
    public func write(tracks: [PlaylistTrack]) throws -> Data {
        var lines: [String] = []
        
        if extended {
            lines.append("#EXTM3U")
        }
        
        for track in tracks {
            if extended {
                var extInf = "#EXTINF:"
                extInf += String(Int(track.duration ?? -1))
                
                if let title = track.title {
                    extInf += ",\(title)"
                }
                
                lines.append(extInf)
            }
            
            // Write metadata as comments
            for (key, value) in track.metadata {
                lines.append("#EXT-X-\(key):\(value)")
            }
            
            // Write the URL/path
            lines.append(track.url.absoluteString)
        }
        
        let content = lines.joined(separator: "\n") + "\n"
        guard let data = content.data(using: encoding) else {
            throw PlaylistParseError.invalidEncoding
        }
        
        return data
    }
}