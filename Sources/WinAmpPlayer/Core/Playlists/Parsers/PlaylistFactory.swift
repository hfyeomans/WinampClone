import Foundation

/// Factory for creating appropriate playlist parsers and writers
public class PlaylistFactory {
    
    /// Supported playlist formats
    public enum Format: String, CaseIterable {
        case m3u = "m3u"
        case m3u8 = "m3u8"
        case pls = "pls"
        case xspf = "xspf"
        
        public var displayName: String {
            switch self {
            case .m3u:
                return "M3U Playlist"
            case .m3u8:
                return "M3U8 Playlist (UTF-8)"
            case .pls:
                return "PLS Playlist"
            case .xspf:
                return "XSPF Playlist (XML)"
            }
        }
        
        public var fileExtension: String {
            return rawValue
        }
    }
    
    /// Create a parser for the given URL
    /// - Parameter url: The playlist file URL
    /// - Returns: Appropriate parser for the file type
    /// - Throws: Error if no parser supports the file type
    public static func createParser(for url: URL) throws -> PlaylistParser {
        let ext = url.pathExtension.lowercased()
        let baseURL = url.deletingLastPathComponent()
        
        switch ext {
        case "m3u", "m3u8":
            return M3UParser(baseURL: baseURL)
        case "pls":
            return PLSParser(baseURL: baseURL)
        case "xspf":
            return XSPFParser(baseURL: baseURL)
        default:
            throw PlaylistParseError.invalidFormat
        }
    }
    
    /// Create a parser for the given format
    /// - Parameters:
    ///   - format: The playlist format
    ///   - baseURL: Optional base URL for resolving relative paths
    /// - Returns: Parser for the specified format
    public static func createParser(for format: Format, baseURL: URL? = nil) -> PlaylistParser {
        switch format {
        case .m3u, .m3u8:
            return M3UParser(baseURL: baseURL)
        case .pls:
            return PLSParser(baseURL: baseURL)
        case .xspf:
            return XSPFParser(baseURL: baseURL)
        }
    }
    
    /// Create a writer for the given format
    /// - Parameter format: The playlist format
    /// - Returns: Writer for the specified format
    public static func createWriter(for format: Format) -> PlaylistWriter {
        switch format {
        case .m3u:
            return M3UWriter(extended: true, encoding: .isoLatin1)
        case .m3u8:
            return M3UWriter(extended: true, encoding: .utf8)
        case .pls:
            return PLSWriter()
        case .xspf:
            return XSPFWriter()
        }
    }
    
    /// Detect format from file extension
    /// - Parameter url: The file URL
    /// - Returns: The detected format, or nil if unknown
    public static func detectFormat(from url: URL) -> Format? {
        let ext = url.pathExtension.lowercased()
        return Format(rawValue: ext)
    }
    
    /// Parse playlist from URL with automatic format detection
    /// - Parameter url: The playlist file URL
    /// - Returns: Array of playlist tracks
    /// - Throws: Error if parsing fails
    public static func parse(url: URL) throws -> [PlaylistTrack] {
        let parser = try createParser(for: url)
        return try parser.parse(url: url)
    }
    
    /// Parse playlist from data with specified format
    /// - Parameters:
    ///   - data: The playlist data
    ///   - format: The playlist format
    ///   - baseURL: Optional base URL for resolving relative paths
    /// - Returns: Array of playlist tracks
    /// - Throws: Error if parsing fails
    public static func parse(data: Data, format: Format, baseURL: URL? = nil) throws -> [PlaylistTrack] {
        let parser = createParser(for: format, baseURL: baseURL)
        return try parser.parse(data: data)
    }
    
    /// Write playlist tracks to data
    /// - Parameters:
    ///   - tracks: The tracks to write
    ///   - format: The playlist format
    /// - Returns: The playlist data
    /// - Throws: Error if writing fails
    public static func write(tracks: [PlaylistTrack], format: Format) throws -> Data {
        let writer = createWriter(for: format)
        return try writer.write(tracks: tracks)
    }
    
    /// Write playlist tracks to file
    /// - Parameters:
    ///   - tracks: The tracks to write
    ///   - url: The destination URL
    ///   - format: The playlist format (auto-detected from extension if nil)
    /// - Throws: Error if writing fails
    public static func write(tracks: [PlaylistTrack], to url: URL, format: Format? = nil) throws {
        let actualFormat = format ?? detectFormat(from: url) ?? .m3u8
        let writer = createWriter(for: actualFormat)
        try writer.write(tracks: tracks, to: url)
    }
}