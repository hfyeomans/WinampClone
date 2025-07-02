import Foundation

/// Represents a track entry in a playlist
public struct PlaylistTrack {
    /// The URL or file path of the track
    public let url: URL
    
    /// Optional title of the track
    public let title: String?
    
    /// Optional duration in seconds
    public let duration: TimeInterval?
    
    /// Additional metadata
    public let metadata: [String: String]
    
    public init(url: URL, title: String? = nil, duration: TimeInterval? = nil, metadata: [String: String] = [:]) {
        self.url = url
        self.title = title
        self.duration = duration
        self.metadata = metadata
    }
}

/// Error types for playlist parsing
public enum PlaylistParseError: Error {
    case invalidFormat
    case emptyPlaylist
    case invalidEncoding
    case malformedData
    case unsupportedVersion
    case fileNotFound
}

/// Protocol for playlist parsers
public protocol PlaylistParser {
    /// The file extensions this parser supports
    static var supportedExtensions: [String] { get }
    
    /// Parse playlist data and return tracks
    /// - Parameter data: The raw playlist data
    /// - Returns: Array of playlist tracks
    /// - Throws: PlaylistParseError if parsing fails
    func parse(data: Data) throws -> [PlaylistTrack]
    
    /// Parse playlist from file URL
    /// - Parameter url: The URL of the playlist file
    /// - Returns: Array of playlist tracks
    /// - Throws: PlaylistParseError if parsing fails
    func parse(url: URL) throws -> [PlaylistTrack]
    
    /// Parse playlist from string content
    /// - Parameter content: The playlist content as string
    /// - Returns: Array of playlist tracks
    /// - Throws: PlaylistParseError if parsing fails
    func parse(content: String) throws -> [PlaylistTrack]
}

/// Default implementation for file-based parsing
extension PlaylistParser {
    public func parse(url: URL) throws -> [PlaylistTrack] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlaylistParseError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }
    
    public func parse(content: String) throws -> [PlaylistTrack] {
        guard let data = content.data(using: .utf8) else {
            throw PlaylistParseError.invalidEncoding
        }
        return try parse(data: data)
    }
}

/// Protocol for playlist writers
public protocol PlaylistWriter {
    /// The file extension this writer produces
    static var fileExtension: String { get }
    
    /// Write playlist tracks to data
    /// - Parameter tracks: The tracks to write
    /// - Returns: The playlist data
    /// - Throws: Error if writing fails
    func write(tracks: [PlaylistTrack]) throws -> Data
    
    /// Write playlist tracks to file
    /// - Parameters:
    ///   - tracks: The tracks to write
    ///   - url: The destination URL
    /// - Throws: Error if writing fails
    func write(tracks: [PlaylistTrack], to url: URL) throws
    
    /// Write playlist tracks to string
    /// - Parameter tracks: The tracks to write
    /// - Returns: The playlist as string
    /// - Throws: Error if writing fails
    func writeString(tracks: [PlaylistTrack]) throws -> String
}

/// Default implementation for file-based writing
extension PlaylistWriter {
    public func write(tracks: [PlaylistTrack], to url: URL) throws {
        let data = try write(tracks: tracks)
        try data.write(to: url)
    }
    
    public func writeString(tracks: [PlaylistTrack]) throws -> String {
        let data = try write(tracks: tracks)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PlaylistParseError.invalidEncoding
        }
        return string
    }
}