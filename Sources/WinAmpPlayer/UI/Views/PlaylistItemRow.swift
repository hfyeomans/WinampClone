//
//  PlaylistItemRow.swift
//  WinAmpPlayer
//
//  Individual playlist row component with classic WinAmp styling
//

import SwiftUI

struct PlaylistItemRow: View {
    let track: Track
    let trackNumber: Int
    let isSelected: Bool
    let isCurrentTrack: Bool
    
    @State private var isHovering = false
    
    // Classic WinAmp colors
    private let textColor = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let selectedColor = Color(red: 0.0, green: 0.5, blue: 0.0)
    private let playingColor = Color(red: 1.0, green: 1.0, blue: 0.0)
    private let hoverColor = Color(red: 0.0, green: 0.8, blue: 0.0).opacity(0.2)
    private let backgroundColor = Color.black
    
    var body: some View {
        HStack(spacing: 0) {
            // Track number or playing indicator
            HStack {
                if isCurrentTrack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundColor(playingColor)
                        .frame(width: 30)
                } else {
                    Text("\(trackNumber).")
                        .font(.custom("Monaco", size: 10))
                        .foregroundColor(rowTextColor)
                        .frame(width: 30, alignment: .trailing)
                }
            }
            
            // Title
            Text(track.displayTitle)
                .font(.custom("Monaco", size: 10))
                .foregroundColor(rowTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            
            // Artist
            Text(track.displayArtist)
                .font(.custom("Monaco", size: 10))
                .foregroundColor(rowTextColor.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 150, alignment: .leading)
            
            // Duration
            Text(track.formattedDuration)
                .font(.custom("Monaco", size: 10))
                .foregroundColor(rowTextColor)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .frame(height: 16)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var rowTextColor: Color {
        if isCurrentTrack {
            return playingColor
        } else if isSelected {
            return .white
        } else {
            return textColor
        }
    }
    
    private var rowBackground: some View {
        ZStack {
            if isSelected {
                Rectangle()
                    .fill(selectedColor)
            } else if isHovering {
                Rectangle()
                    .fill(hoverColor)
            } else {
                Rectangle()
                    .fill(backgroundColor)
            }
            
            // Subtle gradient for depth
            if isCurrentTrack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.yellow.opacity(0.1),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }
}

// MARK: - Playing Indicator Animation

struct PlayingIndicator: View {
    @State private var animating = false
    private let barCount = 3
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 1.0, green: 1.0, blue: 0.0))
                    .frame(width: 2, height: animating ? 8 : 4)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Track Info Tooltip

struct TrackInfoTooltip: View {
    let track: Track
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !track.title.isEmpty {
                Label("Title", systemImage: "music.note")
                    .font(.caption2)
                Text(track.title)
                    .font(.caption)
            }
            
            if let artist = track.artist {
                Label("Artist", systemImage: "person")
                    .font(.caption2)
                Text(artist)
                    .font(.caption)
            }
            
            if let album = track.album {
                Label("Album", systemImage: "square.stack")
                    .font(.caption2)
                Text(album)
                    .font(.caption)
            }
            
            if let format = track.audioFormat {
                Label("Format", systemImage: "waveform")
                    .font(.caption2)
                Text(format.displayName)
                    .font(.caption)
            }
        }
        .padding(8)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .border(Color(red: 0.3, green: 0.3, blue: 0.3), width: 1)
    }
}

// MARK: - Preview

struct PlaylistItemRow_Previews: PreviewProvider {
    static let sampleTrack = Track(
        title: "Sample Track Title That Is Very Long",
        artist: "Sample Artist Name",
        album: "Sample Album",
        duration: 245.5
    )
    
    static var previews: some View {
        VStack(spacing: 0) {
            PlaylistItemRow(
                track: sampleTrack,
                trackNumber: 1,
                isSelected: false,
                isCurrentTrack: false
            )
            
            PlaylistItemRow(
                track: sampleTrack,
                trackNumber: 2,
                isSelected: true,
                isCurrentTrack: false
            )
            
            PlaylistItemRow(
                track: sampleTrack,
                trackNumber: 3,
                isSelected: false,
                isCurrentTrack: true
            )
        }
        .frame(width: 550)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}