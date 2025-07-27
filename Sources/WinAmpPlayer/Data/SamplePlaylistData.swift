//
//  SamplePlaylistData.swift
//  WinAmpPlayer
//
//  Sample playlist data for classic WinAmp experience
//

import Foundation

struct SamplePlaylistData {
    static func createSamplePlaylist() -> Playlist {
        let tracks = [
            Track(
                title: "Llama Whippin' Intro",
                artist: "DJ Mike Llama",
                album: "Winamp 5",
                duration: 5,
                fileURL: nil,
                metadata: TrackMetadata(
                    title: "Llama Whippin' Intro",
                    artist: "DJ Mike Llama",
                    album: "Winamp 5",
                    genre: "Electronic",
                    year: "2003",
                    track: 1,
                    bitrate: 128,
                    sampleRate: 44100,
                    channels: 2
                )
            ),
            Track(
                title: "Winamp 5 theme.cda",
                artist: "Nullsoft",
                album: "Winamp 5",
                duration: 219, // 3:39
                fileURL: nil,
                metadata: TrackMetadata(
                    title: "Winamp 5 theme.cda",
                    artist: "Nullsoft",
                    album: "Winamp 5",
                    genre: "Theme",
                    year: "2003",
                    track: 2,
                    bitrate: 128,
                    sampleRate: 44100,
                    channels: 2
                )
            ),
            Track(
                title: "We Are Going To Eclectunk Your Ass",
                artist: "Eclectak",
                album: "Demo Tracks",
                duration: 190, // 3:10
                fileURL: nil,
                metadata: TrackMetadata(
                    title: "We Are Going To Eclectunk Your Ass",
                    artist: "Eclectak",
                    album: "Demo Tracks",
                    genre: "Electronic",
                    year: "2003",
                    track: 3,
                    bitrate: 128,
                    sampleRate: 44100,
                    channels: 2
                )
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
         fileURL: URL?, metadata: TrackMetadata) {
        self.init(fileURL: fileURL)
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.metadata = metadata
    }
}