//
//  ID3TagParser.swift
//  WinAmpPlayer
//
//  Parser for ID3v1 and ID3v2 tags commonly found in MP3 files
//

import Foundation
import UIKit

/// Parser for ID3v1 and ID3v2 tags
public class ID3TagParser: MetadataExtractorProtocol {
    
    // MARK: - Constants
    
    private enum ID3v1 {
        static let tagSize = 128
        static let tagIdentifier = "TAG"
        static let titleRange = 3..<33
        static let artistRange = 33..<63
        static let albumRange = 63..<93
        static let yearRange = 93..<97
        static let commentRange = 97..<125
        static let trackIndicator = 125
        static let trackNumber = 126
        static let genre = 127
    }
    
    private enum ID3v2 {
        static let headerSize = 10
        static let tagIdentifier = "ID3"
        static let frameHeaderSize = 10 // ID3v2.3 and v2.4
        static let frameHeaderSizeV2_2 = 6 // ID3v2.2
    }
    
    // ID3v1 genre list
    private static let id3v1Genres = [
        "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop",
        "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B", "Rap", "Reggae", "Rock",
        "Techno", "Industrial", "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack",
        "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk", "Fusion", "Trance",
        "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
        "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop",
        "Instrumental Rock", "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic",
        "Pop-Folk", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40",
        "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave",
        "Psychadelic", "Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal", "Acid Punk",
        "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock"
    ]
    
    // MARK: - MetadataExtractorProtocol
    
    public var supportedFormats: [String] {
        ["mp3"]
    }
    
    public init() {}
    
    public func extractMetadata(from url: URL) async throws -> AudioMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let metadata = try self.parseID3Tags(from: url)
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func extractArtwork(from url: URL) async throws -> [AudioArtwork] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let artwork = try self.parseID3Artwork(from: url)
                    continuation.resume(returning: artwork)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func parseID3Tags(from url: URL) throws -> AudioMetadata {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw MetadataError.fileNotFound(url)
        }
        defer { fileHandle.closeFile() }
        
        var metadata = AudioMetadata()
        
        // Try ID3v2 first (at the beginning of the file)
        if let id3v2Metadata = try? parseID3v2(fileHandle: fileHandle) {
            metadata = id3v2Metadata
        }
        
        // Try ID3v1 (at the end of the file)
        if let id3v1Metadata = try? parseID3v1(fileHandle: fileHandle) {
            // Merge ID3v1 data, preferring ID3v2 when both exist
            if metadata.title == nil { metadata.title = id3v1Metadata.title }
            if metadata.artist == nil { metadata.artist = id3v1Metadata.artist }
            if metadata.album == nil { metadata.album = id3v1Metadata.album }
            if metadata.year == nil { metadata.year = id3v1Metadata.year }
            if metadata.genre == nil { metadata.genre = id3v1Metadata.genre }
            if metadata.trackNumber == nil { metadata.trackNumber = id3v1Metadata.trackNumber }
        }
        
        // If no metadata found, throw error
        if metadata.title == nil && metadata.artist == nil && metadata.album == nil {
            throw MetadataError.noMetadataFound
        }
        
        metadata.fileFormat = "MP3"
        
        return metadata
    }
    
    private func parseID3v1(fileHandle: FileHandle) throws -> AudioMetadata {
        // Seek to 128 bytes from end
        let fileSize = fileHandle.seekToEndOfFile()
        guard fileSize >= ID3v1.tagSize else {
            throw MetadataError.noMetadataFound
        }
        
        fileHandle.seek(toFileOffset: fileSize - UInt64(ID3v1.tagSize))
        let tagData = fileHandle.readData(ofLength: ID3v1.tagSize)
        
        guard tagData.count == ID3v1.tagSize else {
            throw MetadataError.corruptedMetadata
        }
        
        // Check for "TAG" identifier
        let identifier = String(data: tagData[0..<3], encoding: .isoLatin1)
        guard identifier == ID3v1.tagIdentifier else {
            throw MetadataError.noMetadataFound
        }
        
        var metadata = AudioMetadata()
        
        // Extract fields
        metadata.title = extractString(from: tagData, range: ID3v1.titleRange)
        metadata.artist = extractString(from: tagData, range: ID3v1.artistRange)
        metadata.album = extractString(from: tagData, range: ID3v1.albumRange)
        
        if let yearString = extractString(from: tagData, range: ID3v1.yearRange),
           let year = Int(yearString) {
            metadata.year = year
        }
        
        // Check for track number (ID3v1.1)
        if tagData[ID3v1.trackIndicator] == 0 && tagData[ID3v1.trackNumber] != 0 {
            metadata.trackNumber = Int(tagData[ID3v1.trackNumber])
        }
        
        // Genre
        let genreIndex = Int(tagData[ID3v1.genre])
        if genreIndex < Self.id3v1Genres.count {
            metadata.genre = Self.id3v1Genres[genreIndex]
        }
        
        return metadata
    }
    
    private func parseID3v2(fileHandle: FileHandle) throws -> AudioMetadata {
        fileHandle.seek(toFileOffset: 0)
        let headerData = fileHandle.readData(ofLength: ID3v2.headerSize)
        
        guard headerData.count == ID3v2.headerSize else {
            throw MetadataError.noMetadataFound
        }
        
        // Check for "ID3" identifier
        let identifier = String(data: headerData[0..<3], encoding: .isoLatin1)
        guard identifier == ID3v2.tagIdentifier else {
            throw MetadataError.noMetadataFound
        }
        
        // Get version
        let majorVersion = headerData[3]
        let flags = headerData[5]
        
        // Calculate tag size (synchsafe integer)
        let size = synchsafeToInt(headerData[6..<10])
        
        // Read the entire tag
        let tagData = fileHandle.readData(ofLength: size)
        guard tagData.count == size else {
            throw MetadataError.corruptedMetadata
        }
        
        var metadata = AudioMetadata()
        var offset = 0
        
        // Parse frames based on version
        if majorVersion == 2 {
            metadata = parseID3v2_2Frames(data: tagData, size: size)
        } else if majorVersion == 3 || majorVersion == 4 {
            metadata = parseID3v2_3Frames(data: tagData, size: size, version: majorVersion)
        }
        
        return metadata
    }
    
    private func parseID3v2_2Frames(data: Data, size: Int) -> AudioMetadata {
        var metadata = AudioMetadata()
        var offset = 0
        
        while offset + ID3v2.frameHeaderSizeV2_2 < size {
            let frameID = String(data: data[offset..<offset+3], encoding: .isoLatin1) ?? ""
            let frameSize = (Int(data[offset+3]) << 16) | (Int(data[offset+4]) << 8) | Int(data[offset+5])
            
            if frameSize == 0 || frameID == "\0\0\0" {
                break
            }
            
            offset += ID3v2.frameHeaderSizeV2_2
            
            if offset + frameSize > size {
                break
            }
            
            let frameData = data[offset..<offset+frameSize]
            
            switch frameID {
            case "TT2": metadata.title = parseTextFrame(data: frameData)
            case "TP1": metadata.artist = parseTextFrame(data: frameData)
            case "TAL": metadata.album = parseTextFrame(data: frameData)
            case "TYE": 
                if let yearString = parseTextFrame(data: frameData),
                   let year = Int(yearString.prefix(4)) {
                    metadata.year = year
                }
            case "TCO": metadata.genre = parseTextFrame(data: frameData)
            case "TRK": 
                if let trackString = parseTextFrame(data: frameData) {
                    metadata.trackNumber = parseTrackNumber(trackString)
                }
            case "TP2": metadata.albumArtist = parseTextFrame(data: frameData)
            case "TCM": metadata.composer = parseTextFrame(data: frameData)
            case "COM": metadata.comment = parseTextFrame(data: frameData)
            case "PIC": metadata.hasArtwork = true
            default: break
            }
            
            offset += frameSize
        }
        
        return metadata
    }
    
    private func parseID3v2_3Frames(data: Data, size: Int, version: UInt8) -> AudioMetadata {
        var metadata = AudioMetadata()
        var offset = 0
        
        while offset + ID3v2.frameHeaderSize < size {
            let frameID = String(data: data[offset..<offset+4], encoding: .isoLatin1) ?? ""
            
            let frameSize: Int
            if version == 4 {
                // ID3v2.4 uses synchsafe integers
                frameSize = synchsafeToInt(data[offset+4..<offset+8])
            } else {
                // ID3v2.3 uses regular integers
                frameSize = (Int(data[offset+4]) << 24) | (Int(data[offset+5]) << 16) | 
                           (Int(data[offset+6]) << 8) | Int(data[offset+7])
            }
            
            if frameSize == 0 || frameID == "\0\0\0\0" {
                break
            }
            
            offset += ID3v2.frameHeaderSize
            
            if offset + frameSize > size {
                break
            }
            
            let frameData = data[offset..<offset+frameSize]
            
            switch frameID {
            case "TIT2": metadata.title = parseTextFrame(data: frameData)
            case "TPE1": metadata.artist = parseTextFrame(data: frameData)
            case "TALB": metadata.album = parseTextFrame(data: frameData)
            case "TYER", "TDRC": 
                if let yearString = parseTextFrame(data: frameData),
                   let year = Int(yearString.prefix(4)) {
                    metadata.year = year
                }
            case "TCON": metadata.genre = parseGenre(parseTextFrame(data: frameData))
            case "TRCK": 
                if let trackString = parseTextFrame(data: frameData) {
                    let parts = parseTrackInfo(trackString)
                    metadata.trackNumber = parts.track
                    metadata.totalTracks = parts.total
                }
            case "TPOS":
                if let discString = parseTextFrame(data: frameData) {
                    let parts = parseTrackInfo(discString)
                    metadata.discNumber = parts.track
                    metadata.totalDiscs = parts.total
                }
            case "TPE2": metadata.albumArtist = parseTextFrame(data: frameData)
            case "TCOM": metadata.composer = parseTextFrame(data: frameData)
            case "COMM": metadata.comment = parseCommentFrame(data: frameData)
            case "TBPM": 
                if let bpmString = parseTextFrame(data: frameData),
                   let bpm = Int(bpmString) {
                    metadata.bpm = bpm
                }
            case "TCOP": metadata.copyright = parseTextFrame(data: frameData)
            case "TPUB": metadata.publisher = parseTextFrame(data: frameData)
            case "TENC": metadata.encodedBy = parseTextFrame(data: frameData)
            case "USLT": metadata.lyrics = parseLyricsFrame(data: frameData)
            case "APIC": metadata.hasArtwork = true
            default: break
            }
            
            offset += frameSize
        }
        
        return metadata
    }
    
    private func parseID3Artwork(from url: URL) throws -> [AudioArtwork] {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw MetadataError.fileNotFound(url)
        }
        defer { fileHandle.closeFile() }
        
        fileHandle.seek(toFileOffset: 0)
        let headerData = fileHandle.readData(ofLength: ID3v2.headerSize)
        
        guard headerData.count == ID3v2.headerSize else {
            return []
        }
        
        // Check for "ID3" identifier
        let identifier = String(data: headerData[0..<3], encoding: .isoLatin1)
        guard identifier == ID3v2.tagIdentifier else {
            return []
        }
        
        // Get version
        let majorVersion = headerData[3]
        let size = synchsafeToInt(headerData[6..<10])
        
        // Read the entire tag
        let tagData = fileHandle.readData(ofLength: size)
        guard tagData.count == size else {
            return []
        }
        
        var artworks: [AudioArtwork] = []
        
        if majorVersion == 2 {
            artworks = parseID3v2_2Artwork(data: tagData, size: size)
        } else if majorVersion == 3 || majorVersion == 4 {
            artworks = parseID3v2_3Artwork(data: tagData, size: size, version: majorVersion)
        }
        
        return artworks
    }
    
    private func parseID3v2_2Artwork(data: Data, size: Int) -> [AudioArtwork] {
        var artworks: [AudioArtwork] = []
        var offset = 0
        
        while offset + ID3v2.frameHeaderSizeV2_2 < size {
            let frameID = String(data: data[offset..<offset+3], encoding: .isoLatin1) ?? ""
            let frameSize = (Int(data[offset+3]) << 16) | (Int(data[offset+4]) << 8) | Int(data[offset+5])
            
            if frameSize == 0 || frameID == "\0\0\0" {
                break
            }
            
            offset += ID3v2.frameHeaderSizeV2_2
            
            if offset + frameSize > size {
                break
            }
            
            if frameID == "PIC" {
                if let artwork = parsePICFrame(data: data[offset..<offset+frameSize]) {
                    artworks.append(artwork)
                }
            }
            
            offset += frameSize
        }
        
        return artworks
    }
    
    private func parseID3v2_3Artwork(data: Data, size: Int, version: UInt8) -> [AudioArtwork] {
        var artworks: [AudioArtwork] = []
        var offset = 0
        
        while offset + ID3v2.frameHeaderSize < size {
            let frameID = String(data: data[offset..<offset+4], encoding: .isoLatin1) ?? ""
            
            let frameSize: Int
            if version == 4 {
                frameSize = synchsafeToInt(data[offset+4..<offset+8])
            } else {
                frameSize = (Int(data[offset+4]) << 24) | (Int(data[offset+5]) << 16) | 
                           (Int(data[offset+6]) << 8) | Int(data[offset+7])
            }
            
            if frameSize == 0 || frameID == "\0\0\0\0" {
                break
            }
            
            offset += ID3v2.frameHeaderSize
            
            if offset + frameSize > size {
                break
            }
            
            if frameID == "APIC" {
                if let artwork = parseAPICFrame(data: data[offset..<offset+frameSize]) {
                    artworks.append(artwork)
                }
            }
            
            offset += frameSize
        }
        
        return artworks
    }
    
    // MARK: - Helper Methods
    
    private func extractString(from data: Data, range: Range<Int>) -> String? {
        let stringData = data[range]
        var string = String(data: stringData, encoding: .isoLatin1) ?? ""
        string = string.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        return string.isEmpty ? nil : string
    }
    
    private func synchsafeToInt(_ data: Data) -> Int {
        var result = 0
        for byte in data {
            result = (result << 7) | Int(byte & 0x7F)
        }
        return result
    }
    
    private func parseTextFrame(data: Data) -> String? {
        guard data.count > 1 else { return nil }
        
        let encoding = data[0]
        let textData = data[1...]
        
        switch encoding {
        case 0: // ISO-8859-1
            return String(data: textData, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case 1: // UTF-16 with BOM
            return String(data: textData, encoding: .utf16)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case 2: // UTF-16BE without BOM
            return String(data: textData, encoding: .utf16BigEndian)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case 3: // UTF-8
            return String(data: textData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return String(data: textData, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func parseCommentFrame(data: Data) -> String? {
        guard data.count > 4 else { return nil }
        
        let encoding = data[0]
        // Skip language (3 bytes) and short description
        var offset = 4
        
        // Find null terminator for short description
        while offset < data.count && data[offset] != 0 {
            offset += 1
        }
        offset += 1 // Skip null terminator
        
        guard offset < data.count else { return nil }
        
        let commentData = data[offset...]
        
        switch encoding {
        case 0: return String(data: commentData, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case 1: return String(data: commentData, encoding: .utf16)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case 2: return String(data: commentData, encoding: .utf16BigEndian)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case 3: return String(data: commentData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        default: return nil
        }
    }
    
    private func parseLyricsFrame(data: Data) -> String? {
        // Similar to comment frame structure
        return parseCommentFrame(data: data)
    }
    
    private func parseGenre(_ genreString: String?) -> String? {
        guard let genre = genreString else { return nil }
        
        // Check for ID3v1 style genre (e.g., "(31)")
        if genre.hasPrefix("(") && genre.hasSuffix(")") {
            let numberString = genre.dropFirst().dropLast()
            if let genreIndex = Int(numberString),
               genreIndex >= 0 && genreIndex < Self.id3v1Genres.count {
                return Self.id3v1Genres[genreIndex]
            }
        }
        
        return genre
    }
    
    private func parseTrackNumber(_ trackString: String) -> Int? {
        // Handle "track/total" format
        if let slashIndex = trackString.firstIndex(of: "/") {
            let trackPart = trackString[..<slashIndex]
            return Int(trackPart)
        }
        return Int(trackString)
    }
    
    private func parseTrackInfo(_ trackString: String) -> (track: Int?, total: Int?) {
        let parts = trackString.split(separator: "/", maxSplits: 1)
        let track = parts.count > 0 ? Int(parts[0]) : nil
        let total = parts.count > 1 ? Int(parts[1]) : nil
        return (track, total)
    }
    
    private func parsePICFrame(data: Data) -> AudioArtwork? {
        guard data.count > 5 else { return nil }
        
        let encoding = data[0]
        var offset = 1
        
        // Image format (3 characters for v2.2)
        let formatData = data[offset..<offset+3]
        let format = String(data: formatData, encoding: .isoLatin1) ?? ""
        offset += 3
        
        // Picture type
        let pictureType = data[offset]
        offset += 1
        
        // Description (null-terminated)
        while offset < data.count && data[offset] != 0 {
            offset += 1
        }
        offset += 1 // Skip null terminator
        
        // Image data
        guard offset < data.count else { return nil }
        let imageData = data[offset...]
        
        let mimeType = format == "JPG" ? "image/jpeg" : 
                      format == "PNG" ? "image/png" : nil
        
        let artworkType: AudioArtwork.ArtworkType
        switch pictureType {
        case 3: artworkType = .frontCover
        case 4: artworkType = .backCover
        case 8: artworkType = .artist
        default: artworkType = .other
        }
        
        return AudioArtwork(data: Data(imageData), mimeType: mimeType, type: artworkType)
    }
    
    private func parseAPICFrame(data: Data) -> AudioArtwork? {
        guard data.count > 4 else { return nil }
        
        let encoding = data[0]
        var offset = 1
        
        // MIME type (null-terminated)
        var mimeEndIndex = offset
        while mimeEndIndex < data.count && data[mimeEndIndex] != 0 {
            mimeEndIndex += 1
        }
        
        let mimeType = String(data: data[offset..<mimeEndIndex], encoding: .isoLatin1)
        offset = mimeEndIndex + 1
        
        guard offset < data.count else { return nil }
        
        // Picture type
        let pictureType = data[offset]
        offset += 1
        
        // Description (null-terminated, encoding dependent)
        let nullBytes = encoding == 0 || encoding == 3 ? 1 : 2
        while offset < data.count - nullBytes {
            var isNull = true
            for i in 0..<nullBytes {
                if data[offset + i] != 0 {
                    isNull = false
                    break
                }
            }
            if isNull {
                offset += nullBytes
                break
            }
            offset += 1
        }
        
        // Image data
        guard offset < data.count else { return nil }
        let imageData = data[offset...]
        
        let artworkType: AudioArtwork.ArtworkType
        switch pictureType {
        case 3: artworkType = .frontCover
        case 4: artworkType = .backCover
        case 8: artworkType = .artist
        default: artworkType = .other
        }
        
        return AudioArtwork(data: Data(imageData), mimeType: mimeType, type: artworkType)
    }
}