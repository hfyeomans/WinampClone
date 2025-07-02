import Foundation

/// Example usage of playlist parsers and writers
class PlaylistExample {
    
    static func demonstrateUsage() {
        // Example 1: Parse M3U8 playlist from file
        do {
            let playlistURL = URL(fileURLWithPath: "/path/to/playlist.m3u8")
            let tracks = try PlaylistFactory.parse(url: playlistURL)
            
            for (index, track) in tracks.enumerated() {
                print("Track \(index + 1):")
                print("  URL: \(track.url)")
                if let title = track.title {
                    print("  Title: \(title)")
                }
                if let duration = track.duration {
                    print("  Duration: \(duration)s")
                }
            }
        } catch {
            print("Error parsing playlist: \(error)")
        }
        
        // Example 2: Create and write a playlist
        do {
            let tracks = [
                PlaylistTrack(
                    url: URL(string: "https://example.com/song1.mp3")!,
                    title: "Song One",
                    duration: 180
                ),
                PlaylistTrack(
                    url: URL(fileURLWithPath: "/Users/music/song2.mp3"),
                    title: "Song Two",
                    duration: 240,
                    metadata: ["artist": "Artist Name", "album": "Album Name"]
                )
            ]
            
            // Write as M3U8
            let m3u8Data = try PlaylistFactory.write(tracks: tracks, format: .m3u8)
            try m3u8Data.write(to: URL(fileURLWithPath: "/path/to/output.m3u8"))
            
            // Write as XSPF
            let xspfData = try PlaylistFactory.write(tracks: tracks, format: .xspf)
            try xspfData.write(to: URL(fileURLWithPath: "/path/to/output.xspf"))
            
        } catch {
            print("Error writing playlist: \(error)")
        }
        
        // Example 3: Parse playlist from string
        do {
            let m3uContent = """
                #EXTM3U
                #EXTINF:123,Sample artist - Sample title
                https://example.com/sample.mp3
                #EXTINF:-1,Another track
                /path/to/local/file.mp3
                """
            
            let parser = M3UParser()
            let tracks = try parser.parse(content: m3uContent)
            print("Parsed \(tracks.count) tracks from M3U content")
            
        } catch {
            print("Error parsing M3U content: \(error)")
        }
        
        // Example 4: Convert between formats
        do {
            let sourceURL = URL(fileURLWithPath: "/path/to/playlist.pls")
            let tracks = try PlaylistFactory.parse(url: sourceURL)
            
            // Convert to different formats
            let formats: [PlaylistFactory.Format] = [.m3u8, .xspf]
            for format in formats {
                let outputURL = sourceURL
                    .deletingPathExtension()
                    .appendingPathExtension(format.fileExtension)
                
                try PlaylistFactory.write(tracks: tracks, to: outputURL, format: format)
                print("Converted to \(format.displayName): \(outputURL.lastPathComponent)")
            }
            
        } catch {
            print("Error converting playlist: \(error)")
        }
    }
    
    /// Example of creating a custom playlist with metadata
    static func createRichPlaylist() throws {
        let tracks = [
            PlaylistTrack(
                url: URL(string: "https://streaming.example.com/track1.mp3")!,
                title: "Bohemian Rhapsody",
                duration: 354,
                metadata: [
                    "artist": "Queen",
                    "album": "A Night at the Opera",
                    "trackNumber": "11",
                    "comment": "Classic rock masterpiece",
                    "artwork": "https://example.com/artwork/queen.jpg"
                ]
            ),
            PlaylistTrack(
                url: URL(fileURLWithPath: "/Users/music/pink_floyd/wish_you_were_here.mp3"),
                title: "Wish You Were Here",
                duration: 334,
                metadata: [
                    "artist": "Pink Floyd",
                    "album": "Wish You Were Here",
                    "trackNumber": "4"
                ]
            )
        ]
        
        // Write as XSPF (supports rich metadata)
        let xspfWriter = XSPFWriter()
        let xspfData = try xspfWriter.write(tracks: tracks)
        let xspfString = try xspfWriter.writeString(tracks: tracks)
        print("XSPF playlist:\n\(xspfString)")
        
        // Write as extended M3U8
        let m3uWriter = M3UWriter(extended: true)
        let m3uString = try m3uWriter.writeString(tracks: tracks)
        print("\nM3U8 playlist:\n\(m3uString)")
    }
}