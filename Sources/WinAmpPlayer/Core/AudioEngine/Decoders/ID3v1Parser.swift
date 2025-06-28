import Foundation

/// Parser for ID3v1 tags (last 128 bytes of MP3 files)
public struct ID3v1Parser {
    
    /// ID3v1 tag size (always 128 bytes)
    private static let tagSize = 128
    
    /// ID3v1 tag identifier
    private static let tagIdentifier = "TAG"
    
    /// Genre list for ID3v1
    private static let genres = [
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
    
    /// Parse ID3v1 tags from MP3 data
    public static func parse(data: Data) -> MP3Metadata? {
        guard data.count >= tagSize else { return nil }
        
        // Get the last 128 bytes
        let tagData = data.suffix(tagSize)
        
        // Check for "TAG" identifier
        let identifier = String(data: tagData.prefix(3), encoding: .isoLatin1) ?? ""
        guard identifier == tagIdentifier else { return nil }
        
        var metadata = MP3Metadata()
        
        // Parse fields (all are fixed-length and ISO-8859-1 encoded)
        // Title: bytes 3-32 (30 bytes)
        metadata.title = parseString(from: tagData, offset: 3, length: 30)
        
        // Artist: bytes 33-62 (30 bytes)
        metadata.artist = parseString(from: tagData, offset: 33, length: 30)
        
        // Album: bytes 63-92 (30 bytes)
        metadata.album = parseString(from: tagData, offset: 63, length: 30)
        
        // Year: bytes 93-96 (4 bytes)
        metadata.year = parseString(from: tagData, offset: 93, length: 4)
        
        // Comment: bytes 97-126 (30 bytes)
        // Check for ID3v1.1 track number (if byte 125 is 0 and byte 126 is non-zero)
        if tagData[125] == 0 && tagData[126] != 0 {
            // ID3v1.1 - comment is only 28 bytes, track number is in byte 126
            metadata.comment = parseString(from: tagData, offset: 97, length: 28)
            metadata.track = Int(tagData[126])
        } else {
            // ID3v1.0 - comment is full 30 bytes
            metadata.comment = parseString(from: tagData, offset: 97, length: 30)
        }
        
        // Genre: byte 127
        let genreIndex = Int(tagData[127])
        if genreIndex < genres.count {
            metadata.genre = genres[genreIndex]
        }
        
        return metadata
    }
    
    /// Parse a string from the data at the given offset and length
    private static func parseString(from data: Data, offset: Int, length: Int) -> String? {
        let startIndex = data.startIndex.advanced(by: offset)
        let endIndex = startIndex.advanced(by: length)
        let stringData = data[startIndex..<endIndex]
        
        // Find the first null terminator
        if let nullIndex = stringData.firstIndex(of: 0) {
            let trimmedData = stringData[stringData.startIndex..<nullIndex]
            return String(data: trimmedData, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespaces)
        } else {
            return String(data: stringData, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespaces)
        }
    }
}