import Foundation

/// Parser for XSPF (XML Shareable Playlist Format)
public class XSPFParser: NSObject, PlaylistParser {
    public static let supportedExtensions = ["xspf"]
    
    private let baseURL: URL?
    private var tracks: [PlaylistTrack] = []
    private var currentTrack: TrackBuilder?
    private var currentElement: String?
    private var currentValue: String = ""
    
    /// Initialize parser with optional base URL for resolving relative paths
    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
        super.init()
    }
    
    public func parse(data: Data) throws -> [PlaylistTrack] {
        tracks = []
        currentTrack = nil
        currentElement = nil
        currentValue = ""
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            if let error = parser.parserError {
                throw error
            }
            throw PlaylistParseError.malformedData
        }
        
        guard !tracks.isEmpty else {
            throw PlaylistParseError.emptyPlaylist
        }
        
        return tracks
    }
    
    private func resolveURL(from location: String) -> URL? {
        // XSPF uses URI encoding
        guard let decoded = location.removingPercentEncoding else {
            return nil
        }
        
        // Check if it's already a valid URL
        if let url = URL(string: decoded) {
            if url.scheme != nil {
                return url
            }
        }
        
        // Try as file URL
        if decoded.hasPrefix("file://") {
            return URL(string: decoded)
        }
        
        // Handle as path
        let normalizedPath = decoded.replacingOccurrences(of: "\\", with: "/")
        
        // Try relative to base URL
        if let baseURL = baseURL {
            if let relativeURL = URL(string: normalizedPath, relativeTo: baseURL) {
                return relativeURL
            }
        }
        
        // Try as file URL
        return URL(fileURLWithPath: normalizedPath)
    }
    
    private class TrackBuilder {
        var location: String?
        var title: String?
        var creator: String?
        var album: String?
        var duration: TimeInterval?
        var trackNum: Int?
        var annotation: String?
        var info: String?
        var image: String?
        var metadata: [String: String] = [:]
        
        func build(baseURL: URL?) -> PlaylistTrack? {
            guard let location = location,
                  let url = resolveURL(from: location, baseURL: baseURL) else {
                return nil
            }
            
            // Add other fields to metadata
            if let creator = creator {
                metadata["artist"] = creator
            }
            if let album = album {
                metadata["album"] = album
            }
            if let trackNum = trackNum {
                metadata["trackNumber"] = String(trackNum)
            }
            if let annotation = annotation {
                metadata["comment"] = annotation
            }
            if let info = info {
                metadata["info"] = info
            }
            if let image = image {
                metadata["artwork"] = image
            }
            
            return PlaylistTrack(
                url: url,
                title: title,
                duration: duration,
                metadata: metadata
            )
        }
        
        private func resolveURL(from location: String, baseURL: URL?) -> URL? {
            // XSPF uses URI encoding
            guard let decoded = location.removingPercentEncoding else {
                return nil
            }
            
            // Check if it's already a valid URL
            if let url = URL(string: decoded) {
                if url.scheme != nil {
                    return url
                }
            }
            
            // Try as file URL
            if decoded.hasPrefix("file://") {
                return URL(string: decoded)
            }
            
            // Handle as path
            let normalizedPath = decoded.replacingOccurrences(of: "\\", with: "/")
            
            // Try relative to base URL
            if let baseURL = baseURL {
                if let relativeURL = URL(string: normalizedPath, relativeTo: baseURL) {
                    return relativeURL
                }
            }
            
            // Try as file URL
            return URL(fileURLWithPath: normalizedPath)
        }
    }
}

// MARK: - XMLParserDelegate
extension XSPFParser: XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        
        if elementName == "track" {
            currentTrack = TrackBuilder()
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if elementName == "track" {
            if let track = currentTrack?.build(baseURL: baseURL) {
                tracks.append(track)
            }
            currentTrack = nil
        } else if let currentTrack = currentTrack {
            switch elementName {
            case "location":
                currentTrack.location = value
            case "title":
                currentTrack.title = value
            case "creator":
                currentTrack.creator = value
            case "album":
                currentTrack.album = value
            case "duration":
                // Duration is in milliseconds in XSPF
                if let ms = Double(value) {
                    currentTrack.duration = ms / 1000.0
                }
            case "trackNum":
                currentTrack.trackNum = Int(value)
            case "annotation":
                currentTrack.annotation = value
            case "info":
                currentTrack.info = value
            case "image":
                currentTrack.image = value
            default:
                break
            }
        }
        
        currentElement = nil
        currentValue = ""
    }
}

/// Writer for XSPF playlists
public class XSPFWriter: PlaylistWriter {
    public static let fileExtension = "xspf"
    
    private let version: String
    
    /// Initialize writer
    /// - Parameter version: XSPF version (default "1")
    public init(version: String = "1") {
        self.version = version
    }
    
    public func write(tracks: [PlaylistTrack]) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<playlist version=\"\(version)\" xmlns=\"http://xspf.org/ns/0/\">\n"
        xml += "  <trackList>\n"
        
        for track in tracks {
            xml += "    <track>\n"
            
            // Location (required)
            let location = escapeXML(track.url.absoluteString)
            xml += "      <location>\(location)</location>\n"
            
            // Title
            if let title = track.title {
                xml += "      <title>\(escapeXML(title))</title>\n"
            }
            
            // Creator (artist)
            if let artist = track.metadata["artist"] {
                xml += "      <creator>\(escapeXML(artist))</creator>\n"
            }
            
            // Album
            if let album = track.metadata["album"] {
                xml += "      <album>\(escapeXML(album))</album>\n"
            }
            
            // Duration (in milliseconds)
            if let duration = track.duration {
                let ms = Int(duration * 1000)
                xml += "      <duration>\(ms)</duration>\n"
            }
            
            // Track number
            if let trackNum = track.metadata["trackNumber"] {
                xml += "      <trackNum>\(trackNum)</trackNum>\n"
            }
            
            // Annotation (comment)
            if let comment = track.metadata["comment"] {
                xml += "      <annotation>\(escapeXML(comment))</annotation>\n"
            }
            
            // Info URL
            if let info = track.metadata["info"] {
                xml += "      <info>\(escapeXML(info))</info>\n"
            }
            
            // Image URL
            if let image = track.metadata["artwork"] {
                xml += "      <image>\(escapeXML(image))</image>\n"
            }
            
            xml += "    </track>\n"
        }
        
        xml += "  </trackList>\n"
        xml += "</playlist>\n"
        
        guard let data = xml.data(using: .utf8) else {
            throw PlaylistParseError.invalidEncoding
        }
        
        return data
    }
    
    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}