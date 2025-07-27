//
//  ClassicPlaylistWindow.swift
//  WinAmpPlayer
//
//  Classic WinAmp playlist window
//

import SwiftUI

struct ClassicPlaylistWindow: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var volumeController: VolumeBalanceController
    @EnvironmentObject var skinManager: SkinManager
    @State private var selectedIndex: Int? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var currentTracks: [Track] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 0) {
                Text("WINAMP PLAYLIST")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                    .padding(.leading, 6)
                
                Spacer()
                
                // Window controls
                HStack(spacing: 0) {
                    // Shade mode
                    Button(action: {}) {
                        Text("◢")
                            .font(.system(size: 9))
                            .foregroundColor(WinAmpColors.text)
                            .frame(width: 9, height: 9)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Close
                    Button(action: {}) {
                        Text("X")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(WinAmpColors.text)
                            .frame(width: 9, height: 9)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.trailing, 3)
            }
            .frame(height: 14)
            .background(
                LinearGradient(
                    colors: [WinAmpColors.backgroundLight, WinAmpColors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Playlist content
            HStack(spacing: 0) {
                // Track list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(currentTracks.enumerated()), id: \.offset) { index, track in
                            PlaylistRow(
                                track: track,
                                index: index + 1,
                                isSelected: selectedIndex == index,
                                isPlaying: audioEngine.currentTrack?.id == track.id && audioEngine.isPlaying
                            )
                            .onTapGesture {
                                selectedIndex = index
                            }
                            .onTapGesture(count: 2) {
                                selectedIndex = index
                                Task {
                                    try? await audioEngine.loadURL(track.fileURL ?? URL(fileURLWithPath: "/"))
                                    try? audioEngine.play()
                                }
                            }
                        }
                    }
                }
                .background(WinAmpColors.playlistBackground)
                .overlay(BeveledBorder(raised: false))
                
                // Scrollbar
                ClassicScrollbar(
                    contentHeight: CGFloat(currentTracks.count * 13),
                    viewHeight: 200,
                    offset: $scrollOffset
                )
                .frame(width: 8)
            }
            .frame(height: 200)
            
            // Bottom controls
            HStack(spacing: 2) {
                // Add button
                Button(action: {}) {
                    Text("ADD")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 22, height: 18)
                        .background(WinAmpColors.buttonNormal)
                        .overlay(BeveledBorder(raised: true))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Remove button
                Button(action: {
                    if let index = selectedIndex {
                        // Remove track from playlist
                        selectedIndex = nil
                    }
                }) {
                    Text("REM")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 22, height: 18)
                        .background(WinAmpColors.buttonNormal)
                        .overlay(BeveledBorder(raised: true))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Select button
                Button(action: {}) {
                    Text("SEL")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 22, height: 18)
                        .background(WinAmpColors.buttonNormal)
                        .overlay(BeveledBorder(raised: true))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Misc button
                Button(action: {}) {
                    Text("MISC")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 28, height: 18)
                        .background(WinAmpColors.buttonNormal)
                        .overlay(BeveledBorder(raised: true))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // List button
                Button(action: {}) {
                    Text("LIST")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 28, height: 18)
                        .background(WinAmpColors.buttonNormal)
                        .overlay(BeveledBorder(raised: true))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(height: 24)
            
            // Status bar
            HStack(spacing: 0) {
                Text("\(currentTracks.count) items")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                    .padding(.leading, 4)
                
                Spacer()
                
                Text(formatTotalTime())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                    .padding(.trailing, 4)
            }
            .frame(height: 14)
            .background(WinAmpColors.backgroundLight)
            .overlay(
                Rectangle()
                    .stroke(WinAmpColors.darkBorder, lineWidth: 1)
                    .padding(.bottom, 1)
            )
        }
        .frame(width: 275, height: 232)
        .background(WinAmpColors.background)
        .overlay(BeveledBorder(raised: true))
        .onAppear {
            if currentTracks.isEmpty {
                let samplePlaylist = SamplePlaylistData.createSamplePlaylist()
                currentTracks = samplePlaylist.tracks
            }
        }
    }
    
    private func formatTotalTime() -> String {
        let totalSeconds = currentTracks.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct PlaylistRow: View {
    let track: Track
    let index: Int
    let isSelected: Bool
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Track number
            Text(String(format: "%3d.", index))
                .font(.custom("Monaco", size: 11))
                .foregroundColor(textColor)
                .frame(width: 30, alignment: .trailing)
            
            // Track info
            Text(trackDisplay)
                .font(.custom("Monaco", size: 11))
                .foregroundColor(textColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            // Duration
            Text(SamplePlaylistData.formatDuration(track.duration))
                .font(.custom("Monaco", size: 11))
                .foregroundColor(textColor)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 4)
        }
        .frame(height: 13)
        .background(backgroundColor)
        .contentShape(Rectangle())
    }
    
    private var trackDisplay: String {
        if !track.artist.isEmpty && !track.title.isEmpty {
            return "\(track.artist) - \(track.title)"
        } else if !track.title.isEmpty {
            return track.title
        } else {
            return track.fileURL?.lastPathComponent ?? "Unknown"
        }
    }
    
    private var textColor: Color {
        if isPlaying {
            return WinAmpColors.playlistPlaying
        } else if isSelected {
            return WinAmpColors.playlistText
        } else {
            return WinAmpColors.playlistText
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return WinAmpColors.playlistSelected
        } else {
            return WinAmpColors.playlistBackground
        }
    }
}

struct ClassicScrollbar: View {
    let contentHeight: CGFloat
    let viewHeight: CGFloat
    @Binding var offset: CGFloat
    
    @State private var isDragging = false
    
    var thumbHeight: CGFloat {
        max(20, (viewHeight / contentHeight) * viewHeight)
    }
    
    var thumbPosition: CGFloat {
        let maxOffset = contentHeight - viewHeight
        let maxThumbPosition = viewHeight - thumbHeight
        return maxOffset > 0 ? (offset / maxOffset) * maxThumbPosition : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track
                Rectangle()
                    .fill(WinAmpColors.darkBorder)
                
                // Thumb
                RoundedRectangle(cornerRadius: 0)
                    .fill(WinAmpColors.buttonNormal)
                    .frame(height: thumbHeight)
                    .offset(y: thumbPosition)
                    .overlay(BeveledBorder(raised: !isDragging))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newPosition = thumbPosition + value.translation.height
                                let maxThumbPosition = geometry.size.height - thumbHeight
                                let clampedPosition = max(0, min(maxThumbPosition, newPosition))
                                
                                let maxOffset = contentHeight - viewHeight
                                offset = maxOffset > 0 ? (clampedPosition / maxThumbPosition) * maxOffset : 0
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .overlay(BeveledBorder(raised: false))
    }
}