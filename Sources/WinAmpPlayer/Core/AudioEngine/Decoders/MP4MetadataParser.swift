import Foundation

/// Parser for MP4/M4A metadata atoms (iTunes metadata)
public class MP4MetadataParser {
    
    // MARK: - Atom Types
    
    private struct AtomType {
        static let ftyp = "ftyp"
        static let moov = "moov"
        static let udta = "udta"
        static let meta = "meta"
        static let ilst = "ilst"
        static let mdat = "mdat"
        
        // iTunes metadata atoms
        static let nam = "©nam"  // Title
        static let art = "©ART"  // Artist
        static let alb = "©alb"  // Album
        static let day = "©day"  // Year
        static let gen = "©gen"  // Genre
        static let wrt = "©wrt"  // Composer
        static let cmt = "©cmt"  // Comment
        static let too = "©too"  // Encoder
        static let cpy = "cprt"  // Copyright
        static let lyr = "©lyr"  // Lyrics
        static let grp = "©grp"  // Grouping
        static let aART = "aART" // Album Artist
        
        // Binary atoms
        static let trkn = "trkn" // Track number
        static let disk = "disk" // Disc number
        static let covr = "covr" // Cover art
        static let tmpo = "tmpo" // BPM
        static let cpil = "cpil" // Compilation
        static let pgap = "pgap" // Gapless playback
        static let pcst = "pcst" // Podcast
        static let rtng = "rtng" // Rating
        
        // Custom metadata
        static let free = "free" // Free form
        static let custom = "----" // Custom metadata
        
        // Data atom
        static let data = "data"
    }
    
    // MARK: - Data Types
    
    private enum DataType: UInt32 {
        case binary = 0
        case utf8 = 1
        case utf16 = 2
        case jpeg = 13
        case png = 14
        case signed32BitInteger = 21
        case signed16BitInteger = 65
        case unsigned32BitInteger = 22
        case unsigned16BitInteger = 23
        case unsigned8BitInteger = 24
    }
    
    // MARK: - Public Methods
    
    /// Parse MP4/M4A metadata from file URL
    public func parse(fileURL: URL) throws -> AACMetadata {
        let data = try Data(contentsOf: fileURL)
        return parse(data: data)
    }
    
    /// Parse MP4/M4A metadata from data
    public func parse(data: Data) -> AACMetadata {
        var metadata = AACMetadata()
        
        // Find and parse the moov atom
        if let moovRange = findAtom(type: AtomType.moov, in: data, startingAt: 0) {
            let moovData = data.subdata(in: moovRange)
            parseMovieAtom(moovData, into: &metadata)
        }
        
        return metadata
    }
    
    // MARK: - Private Methods
    
    private func parseMovieAtom(_ data: Data, into metadata: inout AACMetadata) {
        // Find udta atom within moov
        guard let udtaRange = findAtom(type: AtomType.udta, in: data, startingAt: 8) else { return }
        let udtaData = data.subdata(in: udtaRange)
        
        // Find meta atom within udta
        guard let metaRange = findAtom(type: AtomType.meta, in: udtaData, startingAt: 8) else { return }
        let metaData = udtaData.subdata(in: metaRange)
        
        // Skip 4 bytes (version and flags) and find ilst atom
        guard let ilstRange = findAtom(type: AtomType.ilst, in: metaData, startingAt: 12) else { return }
        let ilstData = metaData.subdata(in: ilstRange)
        
        // Parse all atoms in ilst
        parseIListAtom(ilstData, into: &metadata)
    }
    
    private func parseIListAtom(_ data: Data, into metadata: inout AACMetadata) {
        var offset = 8 // Skip atom header
        
        while offset < data.count {
            guard offset + 8 <= data.count else { break }
            
            let atomSize = data.readUInt32BE(at: offset)
            let atomType = data.readString(at: offset + 4, length: 4)
            
            guard atomSize >= 8 && offset + Int(atomSize) <= data.count else { break }
            
            let atomData = data.subdata(in: (offset + 8)..<(offset + Int(atomSize)))
            parseMetadataAtom(type: atomType, data: atomData, into: &metadata)
            
            offset += Int(atomSize)
        }
    }
    
    private func parseMetadataAtom(type: String, data: Data, into metadata: inout AACMetadata) {
        switch type {
        case AtomType.nam:
            metadata.title = parseStringAtom(data)
        case AtomType.art:
            metadata.artist = parseStringAtom(data)
        case AtomType.alb:
            metadata.album = parseStringAtom(data)
        case AtomType.day:
            metadata.year = parseStringAtom(data)
        case AtomType.gen:
            metadata.genre = parseStringAtom(data)
        case AtomType.wrt:
            metadata.composer = parseStringAtom(data)
        case AtomType.cmt:
            metadata.comment = parseStringAtom(data)
        case AtomType.too:
            metadata.encoder = parseStringAtom(data)
        case AtomType.cpy:
            metadata.copyright = parseStringAtom(data)
        case AtomType.lyr:
            metadata.lyrics = parseStringAtom(data)
        case AtomType.aART:
            metadata.albumArtist = parseStringAtom(data)
        case AtomType.trkn:
            let (track, total) = parseTrackAtom(data)
            metadata.track = track
            metadata.totalTracks = total
        case AtomType.disk:
            let (disc, total) = parseDiscAtom(data)
            metadata.disc = disc
            metadata.totalDiscs = total
        case AtomType.covr:
            let (artData, mimeType) = parseCoverArtAtom(data)
            metadata.albumArt = artData
            metadata.albumArtMimeType = mimeType
        case AtomType.tmpo:
            metadata.bpm = parseBPMAtom(data)
        case AtomType.cpil:
            metadata.compilation = parseBoolAtom(data)
        case AtomType.pgap:
            metadata.gapless = parseBoolAtom(data)
        case AtomType.pcst:
            metadata.podcast = parseBoolAtom(data)
        case AtomType.custom:
            parseCustomAtom(data, into: &metadata)
        default:
            break
        }
    }
    
    private func parseStringAtom(_ data: Data) -> String? {
        guard let dataAtomRange = findAtom(type: AtomType.data, in: data, startingAt: 0) else { return nil }
        let dataAtomData = data.subdata(in: dataAtomRange)
        
        guard dataAtomData.count >= 16 else { return nil }
        
        // Skip atom header (8 bytes) + version/flags (4 bytes) + reserved (4 bytes)
        let stringData = dataAtomData.subdata(in: 16..<dataAtomData.count)
        return String(data: stringData, encoding: .utf8)
    }
    
    private func parseTrackAtom(_ data: Data) -> (track: Int?, totalTracks: Int?) {
        guard let dataAtomRange = findAtom(type: AtomType.data, in: data, startingAt: 0) else { return (nil, nil) }
        let dataAtomData = data.subdata(in: dataAtomRange)
        
        guard dataAtomData.count >= 22 else { return (nil, nil) }
        
        // Track data starts at offset 18 (atom header + version/flags + reserved)
        let track = Int(dataAtomData.readUInt16BE(at: 18))
        let totalTracks = Int(dataAtomData.readUInt16BE(at: 20))
        
        return (track > 0 ? track : nil, totalTracks > 0 ? totalTracks : nil)
    }
    
    private func parseDiscAtom(_ data: Data) -> (disc: Int?, totalDiscs: Int?) {
        guard let dataAtomRange = findAtom(type: AtomType.data, in: data, startingAt: 0) else { return (nil, nil) }
        let dataAtomData = data.subdata(in: dataAtomRange)
        
        guard dataAtomData.count >= 22 else { return (nil, nil) }
        
        // Disc data starts at offset 18
        let disc = Int(dataAtomData.readUInt16BE(at: 18))
        let totalDiscs = Int(dataAtomData.readUInt16BE(at: 20))
        
        return (disc > 0 ? disc : nil, totalDiscs > 0 ? totalDiscs : nil)
    }
    
    private func parseCoverArtAtom(_ data: Data) -> (data: Data?, mimeType: String?) {
        guard let dataAtomRange = findAtom(type: AtomType.data, in: data, startingAt: 0) else { return (nil, nil) }
        let dataAtomData = data.subdata(in: dataAtomRange)
        
        guard dataAtomData.count >= 16 else { return (nil, nil) }
        
        // Read data type to determine image format
        let dataType = dataAtomData.readUInt32BE(at: 8)
        let imageData = dataAtomData.subdata(in: 16..<dataAtomData.count)
        
        var mimeType: String?
        switch DataType(rawValue: dataType) {
        case .jpeg:
            mimeType = "image/jpeg"
        case .png:
            mimeType = "image/png"
        default:
            // Try to detect from image data
            if imageData.count >= 4 {
                let header = imageData.prefix(4)
                if header.starts(with: [0xFF, 0xD8, 0xFF]) {
                    mimeType = "image/jpeg"
                } else if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                    mimeType = "image/png"
                }
            }
        }
        
        return (imageData, mimeType)
    }
    
    private func parseBPMAtom(_ data: Data) -> Int? {
        guard let dataAtomRange = findAtom(type: AtomType.data, in: data, startingAt: 0) else { return nil }
        let dataAtomData = data.subdata(in: dataAtomRange)
        
        guard dataAtomData.count >= 18 else { return nil }
        
        // BPM is stored as 16-bit integer at offset 16
        return Int(dataAtomData.readUInt16BE(at: 16))
    }
    
    private func parseBoolAtom(_ data: Data) -> Bool {
        guard let dataAtomRange = findAtom(type: AtomType.data, in: data, startingAt: 0) else { return false }
        let dataAtomData = data.subdata(in: dataAtomRange)
        
        guard dataAtomData.count >= 17 else { return false }
        
        // Boolean value is at offset 16
        return dataAtomData[16] != 0
    }
    
    private func parseCustomAtom(_ data: Data, into metadata: inout AACMetadata) {
        // Custom atoms have a special structure:
        // mean atom (namespace) + name atom (field name) + data atom (value)
        
        var meanString: String?
        var nameString: String?
        var valueString: String?
        
        var offset = 0
        while offset < data.count {
            guard offset + 8 <= data.count else { break }
            
            let atomSize = data.readUInt32BE(at: offset)
            let atomType = data.readString(at: offset + 4, length: 4)
            
            guard atomSize >= 8 && offset + Int(atomSize) <= data.count else { break }
            
            let atomData = data.subdata(in: (offset + 8)..<(offset + Int(atomSize)))
            
            switch atomType {
            case "mean":
                // Skip 4 bytes of version/flags
                if atomData.count > 4 {
                    meanString = String(data: atomData.subdata(in: 4..<atomData.count), encoding: .utf8)
                }
            case "name":
                // Skip 4 bytes of version/flags
                if atomData.count > 4 {
                    nameString = String(data: atomData.subdata(in: 4..<atomData.count), encoding: .utf8)
                }
            case AtomType.data:
                valueString = parseStringAtom(data.subdata(in: offset..<(offset + Int(atomSize))))
            default:
                break
            }
            
            offset += Int(atomSize)
        }
        
        // Store custom metadata if we have a name and value
        if let name = nameString, let value = valueString {
            metadata.customMetadata[name] = value
        }
    }
    
    private func findAtom(type: String, in data: Data, startingAt start: Int) -> Range<Int>? {
        var offset = start
        
        while offset + 8 <= data.count {
            let atomSize = data.readUInt32BE(at: offset)
            let atomType = data.readString(at: offset + 4, length: 4)
            
            if atomType == type {
                return offset..<(offset + Int(atomSize))
            }
            
            offset += Int(atomSize)
            
            // Handle large atoms
            if atomSize == 1 && offset + 8 <= data.count {
                // 64-bit atom size
                let largeSize = data.readUInt64BE(at: offset)
                offset = start + Int(largeSize)
            } else if atomSize == 0 {
                // Atom extends to end of file
                break
            }
        }
        
        return nil
    }
}

// MARK: - Data Extensions

private extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        
        return self.subdata(in: offset..<offset+4).withUnsafeBytes { bytes in
            return bytes.load(as: UInt32.self).bigEndian
        }
    }
    
    func readUInt64BE(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        
        return self.subdata(in: offset..<offset+8).withUnsafeBytes { bytes in
            return bytes.load(as: UInt64.self).bigEndian
        }
    }
    
    func readUInt16BE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        
        return self.subdata(in: offset..<offset+2).withUnsafeBytes { bytes in
            return bytes.load(as: UInt16.self).bigEndian
        }
    }
    
    func readString(at offset: Int, length: Int) -> String {
        guard offset + length <= count else { return "" }
        
        let stringData = self.subdata(in: offset..<offset+length)
        return String(data: stringData, encoding: .ascii) ?? ""
    }
}