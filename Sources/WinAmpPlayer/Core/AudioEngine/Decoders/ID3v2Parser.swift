import Foundation

/// Parser for ID3v2 tags with support for v2.2, v2.3, and v2.4
public struct ID3v2Parser {
    
    /// ID3v2 tag identifier
    private static let tagIdentifier = "ID3"
    
    /// Text encoding types
    private enum TextEncoding: UInt8 {
        case isoLatin1 = 0x00
        case utf16 = 0x01
        case utf16BE = 0x02
        case utf8 = 0x03
        
        var encoding: String.Encoding? {
            switch self {
            case .isoLatin1:
                return .isoLatin1
            case .utf16:
                return .utf16
            case .utf16BE:
                return .utf16BigEndian
            case .utf8:
                return .utf8
            }
        }
    }
    
    /// ID3v2 header structure
    private struct Header {
        let version: UInt8
        let revision: UInt8
        let flags: UInt8
        let size: Int
        
        var isUnsynchronized: Bool { (flags & 0x80) != 0 }
        var hasExtendedHeader: Bool { (flags & 0x40) != 0 }
        var isExperimental: Bool { (flags & 0x20) != 0 }
        var hasFooter: Bool { version >= 4 && (flags & 0x10) != 0 }
    }
    
    /// Parse ID3v2 tags from MP3 data
    public static func parse(data: Data) -> MP3Metadata? {
        guard data.count >= 10 else { return nil }
        
        // Check for "ID3" identifier
        let identifier = String(data: data.prefix(3), encoding: .isoLatin1) ?? ""
        guard identifier == tagIdentifier else { return nil }
        
        // Parse header
        guard let header = parseHeader(data: data) else { return nil }
        
        // Get tag data
        let tagEndIndex = 10 + header.size
        guard data.count >= tagEndIndex else { return nil }
        
        let tagData = data[10..<tagEndIndex]
        
        // Skip extended header if present
        var frameStartOffset = 0
        if header.hasExtendedHeader {
            guard tagData.count >= 4 else { return nil }
            let extendedHeaderSize = parseSyncSafeInt(data: tagData, offset: 0)
            frameStartOffset = extendedHeaderSize
        }
        
        // Parse frames
        var metadata = MP3Metadata()
        parseFrames(data: tagData, offset: frameStartOffset, version: header.version, metadata: &metadata)
        
        return metadata
    }
    
    /// Parse ID3v2 header
    private static func parseHeader(data: Data) -> Header? {
        guard data.count >= 10 else { return nil }
        
        let version = data[3]
        let revision = data[4]
        let flags = data[5]
        
        // Parse sync-safe integer for tag size
        let size = parseSyncSafeInt(data: data, offset: 6)
        
        return Header(version: version, revision: revision, flags: flags, size: size)
    }
    
    /// Parse sync-safe integer (7 bits per byte)
    private static func parseSyncSafeInt(data: Data, offset: Int) -> Int {
        guard data.count >= offset + 4 else { return 0 }
        
        let b1 = Int(data[offset]) & 0x7F
        let b2 = Int(data[offset + 1]) & 0x7F
        let b3 = Int(data[offset + 2]) & 0x7F
        let b4 = Int(data[offset + 3]) & 0x7F
        
        return (b1 << 21) | (b2 << 14) | (b3 << 7) | b4
    }
    
    /// Parse regular 32-bit integer
    private static func parseInt32(data: Data, offset: Int) -> Int {
        guard data.count >= offset + 4 else { return 0 }
        
        let b1 = Int(data[offset]) << 24
        let b2 = Int(data[offset + 1]) << 16
        let b3 = Int(data[offset + 2]) << 8
        let b4 = Int(data[offset + 3])
        
        return b1 | b2 | b3 | b4
    }
    
    /// Parse frames from tag data
    private static func parseFrames(data: Data, offset: Int, version: UInt8, metadata: inout MP3Metadata) {
        var currentOffset = offset
        
        while currentOffset < data.count {
            // Check if we have enough data for a frame header
            let frameHeaderSize = version < 3 ? 6 : 10
            guard currentOffset + frameHeaderSize <= data.count else { break }
            
            // Parse frame header
            let frameID: String
            let frameSize: Int
            
            if version < 3 {
                // ID3v2.2 uses 3-character frame IDs
                frameID = String(data: data[currentOffset..<currentOffset + 3], encoding: .isoLatin1) ?? ""
                frameSize = parseInt24(data: data, offset: currentOffset + 3)
                currentOffset += 6
            } else {
                // ID3v2.3 and v2.4 use 4-character frame IDs
                frameID = String(data: data[currentOffset..<currentOffset + 4], encoding: .isoLatin1) ?? ""
                
                if version >= 4 {
                    // ID3v2.4 uses sync-safe integers for frame size
                    frameSize = parseSyncSafeInt(data: data, offset: currentOffset + 4)
                } else {
                    // ID3v2.3 uses regular integers
                    frameSize = parseInt32(data: data, offset: currentOffset + 4)
                }
                
                // Skip frame flags (2 bytes)
                currentOffset += 10
            }
            
            // Check for padding (null bytes)
            if frameID.isEmpty || frameID.starts(with: "\0") {
                break
            }
            
            // Check if we have enough data for the frame content
            guard currentOffset + frameSize <= data.count else { break }
            
            // Get frame data
            let frameData = data[currentOffset..<currentOffset + frameSize]
            
            // Parse frame based on ID
            parseFrame(frameID: frameID, data: frameData, version: version, metadata: &metadata)
            
            currentOffset += frameSize
        }
    }
    
    /// Parse 24-bit integer (for ID3v2.2)
    private static func parseInt24(data: Data, offset: Int) -> Int {
        guard data.count >= offset + 3 else { return 0 }
        
        let b1 = Int(data[offset]) << 16
        let b2 = Int(data[offset + 1]) << 8
        let b3 = Int(data[offset + 2])
        
        return b1 | b2 | b3
    }
    
    /// Parse individual frame
    private static func parseFrame(frameID: String, data: Data, version: UInt8, metadata: inout MP3Metadata) {
        // Map v2.2 frame IDs to v2.3/v2.4 equivalents
        let normalizedID = normalizeFrameID(frameID, version: version)
        
        switch normalizedID {
        // Text frames
        case "TIT2": // Title
            metadata.title = parseTextFrame(data: data)
        case "TPE1": // Artist
            metadata.artist = parseTextFrame(data: data)
        case "TALB": // Album
            metadata.album = parseTextFrame(data: data)
        case "TYER", "TDRC": // Year (TYER for v2.3, TDRC for v2.4)
            metadata.year = parseTextFrame(data: data)
        case "TRCK": // Track number
            if let trackString = parseTextFrame(data: data) {
                parseTrackNumber(trackString, metadata: &metadata)
            }
        case "TPOS": // Disc number
            if let discString = parseTextFrame(data: data) {
                parseDiscNumber(discString, metadata: &metadata)
            }
        case "TPE2": // Album artist
            metadata.albumArtist = parseTextFrame(data: data)
        case "TCOM": // Composer
            metadata.composer = parseTextFrame(data: data)
        case "TCON": // Genre
            metadata.genre = parseGenre(data: data)
        case "TSSE": // Encoder
            metadata.encoder = parseTextFrame(data: data)
        case "TBPM": // BPM
            if let bpmString = parseTextFrame(data: data), let bpm = Int(bpmString) {
                metadata.bpm = bpm
            }
        case "COMM": // Comment
            metadata.comment = parseCommentFrame(data: data)
        case "APIC": // Album art
            metadata.albumArt = parsePictureFrame(data: data)
        case "USLT": // Lyrics
            metadata.lyrics = parseLyricsFrame(data: data)
        default:
            // Store unrecognized frames in additional fields
            if let value = parseTextFrame(data: data) {
                metadata.additionalFields[frameID] = value
            }
        }
    }
    
    /// Normalize frame IDs from v2.2 to v2.3/v2.4
    private static func normalizeFrameID(_ frameID: String, version: UInt8) -> String {
        guard version < 3 else { return frameID }
        
        // Map v2.2 3-character IDs to v2.3/v2.4 4-character IDs
        let v22Mappings: [String: String] = [
            "TT2": "TIT2", // Title
            "TP1": "TPE1", // Artist
            "TAL": "TALB", // Album
            "TYE": "TYER", // Year
            "TRK": "TRCK", // Track
            "TPA": "TPOS", // Disc
            "TP2": "TPE2", // Album artist
            "TCM": "TCOM", // Composer
            "TCO": "TCON", // Genre
            "TSS": "TSSE", // Encoder
            "TBP": "TBPM", // BPM
            "COM": "COMM", // Comment
            "PIC": "APIC", // Picture
            "ULT": "USLT"  // Lyrics
        ]
        
        return v22Mappings[frameID] ?? frameID
    }
    
    /// Parse text frame
    private static func parseTextFrame(data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        
        let encodingByte = data[0]
        guard let textEncoding = TextEncoding(rawValue: encodingByte),
              let encoding = textEncoding.encoding else { return nil }
        
        let textData = data.dropFirst()
        
        // Handle null terminators
        var text = String(data: textData, encoding: encoding) ?? ""
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text.isEmpty ? nil : text
    }
    
    /// Parse genre (may include references to ID3v1 genres)
    private static func parseGenre(data: Data) -> String? {
        guard let genreText = parseTextFrame(data: data) else { return nil }
        
        // Check for ID3v1 genre references like "(123)"
        if genreText.hasPrefix("(") && genreText.hasSuffix(")") {
            let indexString = String(genreText.dropFirst().dropLast())
            if let index = Int(indexString), index < ID3v1Parser.genres.count {
                return ID3v1Parser.genres[index]
            }
        }
        
        return genreText
    }
    
    /// Parse track number (may include total tracks)
    private static func parseTrackNumber(_ trackString: String, metadata: inout MP3Metadata) {
        let components = trackString.split(separator: "/")
        if let track = Int(components[0]) {
            metadata.track = track
        }
        if components.count > 1, let total = Int(components[1]) {
            metadata.totalTracks = total
        }
    }
    
    /// Parse disc number (may include total discs)
    private static func parseDiscNumber(_ discString: String, metadata: inout MP3Metadata) {
        let components = discString.split(separator: "/")
        if let disc = Int(components[0]) {
            metadata.discNumber = disc
        }
        if components.count > 1, let total = Int(components[1]) {
            metadata.totalDiscs = total
        }
    }
    
    /// Parse comment frame (COMM)
    private static func parseCommentFrame(data: Data) -> String? {
        guard data.count >= 5 else { return nil }
        
        let encodingByte = data[0]
        guard let textEncoding = TextEncoding(rawValue: encodingByte),
              let encoding = textEncoding.encoding else { return nil }
        
        // Skip encoding byte and language (3 bytes)
        var offset = 4
        
        // Skip short description (null-terminated)
        while offset < data.count {
            if encoding == .utf16 || encoding == .utf16BigEndian {
                // UTF-16 uses 2-byte null terminators
                if offset + 1 < data.count && data[offset] == 0 && data[offset + 1] == 0 {
                    offset += 2
                    break
                }
                offset += 2
            } else {
                if data[offset] == 0 {
                    offset += 1
                    break
                }
                offset += 1
            }
        }
        
        guard offset < data.count else { return nil }
        
        // Get actual comment text
        let commentData = data[offset...]
        var text = String(data: commentData, encoding: encoding) ?? ""
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text.isEmpty ? nil : text
    }
    
    /// Parse picture frame (APIC)
    private static func parsePictureFrame(data: Data) -> Data? {
        guard data.count > 1 else { return nil }
        
        let encodingByte = data[0]
        guard let textEncoding = TextEncoding(rawValue: encodingByte),
              let encoding = textEncoding.encoding else { return nil }
        
        var offset = 1
        
        // Parse MIME type (null-terminated)
        var mimeEndOffset = offset
        while mimeEndOffset < data.count && data[mimeEndOffset] != 0 {
            mimeEndOffset += 1
        }
        
        guard mimeEndOffset < data.count else { return nil }
        offset = mimeEndOffset + 1
        
        // Skip picture type byte
        guard offset < data.count else { return nil }
        offset += 1
        
        // Skip description (null-terminated)
        while offset < data.count {
            if encoding == .utf16 || encoding == .utf16BigEndian {
                if offset + 1 < data.count && data[offset] == 0 && data[offset + 1] == 0 {
                    offset += 2
                    break
                }
                offset += 2
            } else {
                if data[offset] == 0 {
                    offset += 1
                    break
                }
                offset += 1
            }
        }
        
        guard offset < data.count else { return nil }
        
        // Return picture data
        return data[offset...]
    }
    
    /// Parse lyrics frame (USLT)
    private static func parseLyricsFrame(data: Data) -> String? {
        // Similar structure to comment frame
        return parseCommentFrame(data: data)
    }
}

// Make ID3v1Parser genres accessible
extension ID3v1Parser {
    static let genres = [
        "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop",
        "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B", "Rap",
        "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska", "Death Metal", "Pranks",
        "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk", "Fusion", "Trance",
        "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
        "Alternative Rock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock",
        "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream",
        "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40", "Christian Rap", "Pop/Funk", "Jungle",
        "Native US", "Cabaret", "New Wave", "Psychedelic", "Rave", "Showtunes", "Trailer", "Lo-Fi",
        "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock",
        "Folk", "Folk-Rock", "National Folk", "Swing", "Fast Fusion", "Bebop", "Latin", "Revival",
        "Celtic", "Bluegrass", "Avantgarde", "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock",
        "Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson", "Opera",
        "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove", "Satire", "Slow Jam",
        "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
        "Duet", "Punk Rock", "Drum Solo", "A capella", "Euro-House", "Dance Hall", "Goa", "Drum & Bass",
        "Club-House", "Hardcore", "Terror", "Indie", "BritPop", "Negerpunk", "Polsk Punk", "Beat",
        "Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover", "Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
        "Thrash Metal", "Anime", "Jpop", "Synthpop"
    ]
}