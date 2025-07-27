//
//  SamplePlaylistData.swift
//  WinAmpPlayer
//
//  Sample playlist data for classic WinAmp experience
//

import Foundation

// Import AudioMetadata from MetadataProtocol
import struct WinAmpPlayer.AudioMetadata

struct SamplePlaylistData {
    static func createSamplePlaylist() -> Playlist {
        let tracks = [
            Track(
                title: "Llama Whippin' Intro",
                artist: "DJ Mike Llama",
                album: "Winamp 5",
                duration: 5,
                fileURL: nil,
                metadata: {
                    var metadata = AudioMetadata()
                    metadata.title = "Llama Whippin' Intro"
                    metadata.artist = "DJ Mike Llama"
                    metadata.album = "Winamp 5"
                    metadata.genre = "Electronic"
                    metadata.year = 2003
                    metadata.trackNumber = 1
                    metadata.bitrate = 128
                    metadata.sampleRate = 44100
                    metadata.channels = 2
                    return metadata
                }()
            ),
            Track(
                title: "Winamp 5 theme.cda",
                artist: "Nullsoft",
                album: "Winamp 5",
                duration: 219, // 3:39
                fileURL: nil,
                metadata: {
                    var metadata = AudioMetadata()
                    metadata.title = "Winamp 5 theme.cda"
                    metadata.artist = "Nullsoft"
                    metadata.album = "Winamp 5"
                    metadata.genre = "Theme"
                    metadata.year = 2003
                    metadata.trackNumber = 2
                    metadata.bitrate = 128
                    metadata.sampleRate = 44100
                    metadata.channels = 2
                    return metadata
                }()
            ),
            Track(
                title: "We Are Going To Eclectunk Your Ass",
                artist: "Eclectak",
                album: "Demo Tracks",
                duration: 190, // 3:10
                fileURL: nil,
                metadata: {
                    var metadata = AudioMetadata()
                    metadata.title = "We Are Going To Eclectunk Your Ass"
                    metadata.artist = "Eclectak"
                    metadata.album = "Demo Tracks"
                    metadata.genre = "Electronic"
                    metadata.year = 2003
                    metadata.trackNumber = 3
                    metadata.bitrate = 128
                    metadata.sampleRate = 44100
                    metadata.channels = 2
                    return metadata
                }()
            )
        ]
        
        let playlist = Playlist(name: "Default Playlist")
        for track in tracks {
            playlist.addTrack(track)
        }
        
        return playlist
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Extension to make Track creation easier
extension Track {
    init(title: String, artist: String, album: String, duration: TimeInterval, 
         fileURL: URL?, metadata: AudioMetadata) {
        self.init(
            title: title,
            artist: artist,
            album: album,
            genre: metadata.genre,
            year: metadata.year,
            duration: duration,
            fileURL: fileURL,
            trackNumber: metadata.trackNumber
        )
    }
}