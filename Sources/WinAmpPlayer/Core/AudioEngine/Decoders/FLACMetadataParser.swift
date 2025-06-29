import Foundation

/// Parser for FLAC metadata blocks
public struct FLACMetadataParser {
    
    /// FLAC file marker
    private static let flacMarker = "fLaC"
    
    /// Metadata block types
    private enum BlockType: UInt8 {
        case streamInfo = 0
        case padding = 1
        case application = 2
        case seekTable = 3
        case vorbisComment = 4
        case cueSheet = 5
        case picture = 6
        case invalid = 127
    }
    
    /// Parse FLAC metadata from file data
    public static func parse(data: Data) -> FLACMetadata? {
        guard data.count >= 4 else { return nil }
        
        // Check for "fLaC" marker
        let marker = String(data: data.prefix(4), encoding: .ascii) ?? ""
        guard marker == flacMarker else { return nil }
        
        var metadata = FLACMetadata()
        var offset = 4
        var isLastBlock = false
        
        // Parse metadata blocks
        while !isLastBlock && offset < data.count - 4 {
            // Read block header
            let header = data[offset]
            isLastBlock = (header & 0x80) != 0
            let blockType = BlockType(rawValue: header & 0x7F) ?? .invalid
            
            // Read block size (24-bit big-endian)
            let size = Int(data[offset + 1]) << 16 | 
                      Int(data[offset + 2]) << 8 | 
                      Int(data[offset + 3])
            
            offset += 4
            
            guard offset + size <= data.count else { break }
            
            let blockData = data.subdata(in: offset..<(offset + size))
            
            switch blockType {
            case .streamInfo:
                parseStreamInfo(blockData, into: &metadata)
            case .vorbisComment:
                parseVorbisComment(blockData, into: &metadata)
            case .picture:
                if let picture = parsePicture(blockData) {
                    metadata.pictures.append(picture)
                }
            default:
                break
            }
            
            offset += size
        }
        
        return metadata
    }
    
    // MARK: - Stream Info Parsing
    
    private static func parseStreamInfo(_ data: Data, into metadata: inout FLACMetadata) {
        guard data.count >= 34 else { return }
        
        var offset = 0
        
        // Min/max block size (16 bits each)
        metadata.minBlockSize = data.readUInt16BE(at: &offset)
        metadata.maxBlockSize = data.readUInt16BE(at: &offset)
        
        // Min/max frame size (24 bits each)
        metadata.minFrameSize = data.readUInt24BE(at: &offset)
        metadata.maxFrameSize = data.readUInt24BE(at: &offset)
        
        // Sample rate (20 bits), channels (3 bits), bits per sample (5 bits), total samples (36 bits)
        // This is packed into 8 bytes
        let packed = data.readUInt64BE(at: &offset)
        metadata.sampleRate = UInt32((packed >> 44) & 0xFFFFF)
        metadata.channels = UInt8(((packed >> 41) & 0x7) + 1)
        metadata.bitsPerSample = UInt8(((packed >> 36) & 0x1F) + 1)
        metadata.totalSamples = packed & 0xFFFFFFFFF
        
        // MD5 signature (16 bytes)
        if offset + 16 <= data.count {
            metadata.md5Signature = data.subdata(in: offset..<(offset + 16))
        }
    }
    
    // MARK: - Vorbis Comment Parsing
    
    private static func parseVorbisComment(_ data: Data, into metadata: inout FLACMetadata) {
        var offset = 0
        
        // Vendor string length (little-endian)
        guard offset + 4 <= data.count else { return }
        let vendorLength = Int(data.readUInt32LE(at: &offset))
        
        // Skip vendor string
        offset += vendorLength
        guard offset + 4 <= data.count else { return }
        
        // Number of comments
        let commentCount = Int(data.readUInt32LE(at: &offset))
        
        // Parse each comment
        for _ in 0..<commentCount {
            guard offset + 4 <= data.count else { break }
            
            let commentLength = Int(data.readUInt32LE(at: &offset))
            guard offset + commentLength <= data.count else { break }
            
            if let comment = String(data: data.subdata(in: offset..<(offset + commentLength)), encoding: .utf8) {
                parseVorbisField(comment, into: &metadata)
            }
            
            offset += commentLength
        }
    }
    
    private static func parseVorbisField(_ field: String, into metadata: inout FLACMetadata) {
        guard let equalIndex = field.firstIndex(of: "=") else { return }
        
        let key = field[..<equalIndex].uppercased()
        let value = String(field[field.index(after: equalIndex)...])
        
        switch key {
        case "TITLE":
            metadata.title = value
        case "ARTIST":
            metadata.artist = value
        case "ALBUM":
            metadata.album = value
        case "DATE":
            metadata.date = value
        case "COMMENT":
            metadata.comment = value
        case "GENRE":
            metadata.genre = value
        case "ALBUMARTIST":
            metadata.albumArtist = value
        case "COMPOSER":
            metadata.composer = value
        case "PERFORMER":
            metadata.performer = value
        case "COPYRIGHT":
            metadata.copyright = value
        case "LICENSE":
            metadata.license = value
        case "ORGANIZATION":
            metadata.organization = value
        case "DESCRIPTION":
            metadata.description = value
        case "LOCATION":
            metadata.location = value
        case "CONTACT":
            metadata.contact = value
        case "ISRC":
            metadata.isrc = value
        case "TRACKNUMBER":
            // Handle formats like "3/12"
            if let slashIndex = value.firstIndex(of: "/") {
                let trackStr = value[..<slashIndex]
                let totalStr = value[value.index(after: slashIndex)...]
                metadata.trackNumber = Int(trackStr)
                metadata.totalTracks = Int(totalStr)
            } else {
                metadata.trackNumber = Int(value)
            }
        case "TOTALTRACKS":
            metadata.totalTracks = Int(value)
        case "DISCNUMBER":
            // Handle formats like "1/2"
            if let slashIndex = value.firstIndex(of: "/") {
                let discStr = value[..<slashIndex]
                let totalStr = value[value.index(after: slashIndex)...]
                metadata.discNumber = Int(discStr)
                metadata.totalDiscs = Int(totalStr)
            } else {
                metadata.discNumber = Int(value)
            }
        case "TOTALDISCS":
            metadata.totalDiscs = Int(value)
        case "REPLAYGAIN_ALBUM_GAIN":
            metadata.replayGainAlbumGain = parseReplayGain(value)
        case "REPLAYGAIN_ALBUM_PEAK":
            metadata.replayGainAlbumPeak = Float(value)
        case "REPLAYGAIN_TRACK_GAIN":
            metadata.replayGainTrackGain = parseReplayGain(value)
        case "REPLAYGAIN_TRACK_PEAK":
            metadata.replayGainTrackPeak = Float(value)
        default:
            // Store in additional fields
            if metadata.additionalFields[key] != nil {
                metadata.additionalFields[key]?.append(value)
            } else {
                metadata.additionalFields[key] = [value]
            }
        }
    }
    
    private static func parseReplayGain(_ value: String) -> Float? {
        // ReplayGain values are typically in format "+1.23 dB" or "-1.23 dB"
        let trimmed = value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " dB", with: "")
            .replacingOccurrences(of: " db", with: "")
        return Float(trimmed)
    }
    
    // MARK: - Picture Parsing
    
    private static func parsePicture(_ data: Data) -> FLACPicture? {
        var offset = 0
        
        // Picture type
        guard offset + 4 <= data.count else { return nil }
        let typeValue = data.readUInt32BE(at: &offset)
        let type = FLACPicture.PictureType(rawValue: typeValue) ?? .other
        
        // MIME type length and string
        guard offset + 4 <= data.count else { return nil }
        let mimeLength = Int(data.readUInt32BE(at: &offset))
        guard offset + mimeLength <= data.count else { return nil }
        let mimeType = String(data: data.subdata(in: offset..<(offset + mimeLength)), encoding: .ascii) ?? ""
        offset += mimeLength
        
        // Description length and string
        guard offset + 4 <= data.count else { return nil }
        let descLength = Int(data.readUInt32BE(at: &offset))
        guard offset + descLength <= data.count else { return nil }
        let description = String(data: data.subdata(in: offset..<(offset + descLength)), encoding: .utf8) ?? ""
        offset += descLength
        
        // Picture dimensions and properties
        guard offset + 16 <= data.count else { return nil }
        let width = data.readUInt32BE(at: &offset)
        let height = data.readUInt32BE(at: &offset)
        let depth = data.readUInt32BE(at: &offset)
        let colorCount = data.readUInt32BE(at: &offset)
        
        // Picture data length and data
        guard offset + 4 <= data.count else { return nil }
        let dataLength = Int(data.readUInt32BE(at: &offset))
        guard offset + dataLength <= data.count else { return nil }
        let pictureData = data.subdata(in: offset..<(offset + dataLength))
        
        return FLACPicture(
            type: type,
            mimeType: mimeType,
            description: description,
            width: width,
            height: height,
            depth: depth,
            colorCount: colorCount,
            data: pictureData
        )
    }
}

// MARK: - Data Extensions

private extension Data {
    func readUInt16BE(at offset: inout Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        let value = UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
        offset += 2
        return value
    }
    
    func readUInt24BE(at offset: inout Int) -> UInt32 {
        guard offset + 3 <= count else { return 0 }
        let value = UInt32(self[offset]) << 16 | 
                    UInt32(self[offset + 1]) << 8 | 
                    UInt32(self[offset + 2])
        offset += 3
        return value
    }
    
    func readUInt32BE(at offset: inout Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let value = UInt32(self[offset]) << 24 | 
                    UInt32(self[offset + 1]) << 16 | 
                    UInt32(self[offset + 2]) << 8 | 
                    UInt32(self[offset + 3])
        offset += 4
        return value
    }
    
    func readUInt32LE(at offset: inout Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let value = UInt32(self[offset]) | 
                    UInt32(self[offset + 1]) << 8 | 
                    UInt32(self[offset + 2]) << 16 | 
                    UInt32(self[offset + 3]) << 24
        offset += 4
        return value
    }
    
    func readUInt64BE(at offset: inout Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var value: UInt64 = 0
        for i in 0..<8 {
            value = (value << 8) | UInt64(self[offset + i])
        }
        offset += 8
        return value
    }
}