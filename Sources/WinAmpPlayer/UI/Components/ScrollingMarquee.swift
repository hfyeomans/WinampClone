//
//  ScrollingMarquee.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Classic WinAmp-style scrolling text marquee
//

import SwiftUI
import AppKit

/// Scrolling text marquee matching classic WinAmp behavior
public struct ScrollingMarquee: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double // pixels per second
    
    @State private var textWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var animationTimer: Timer?
    @State private var pauseTimer: Timer?
    @State private var isPaused = true
    
    public init(
        text: String,
        font: Font = .system(size: 11, weight: .regular, design: .monospaced),
        color: Color = Color(red: 0.0, green: 1.0, blue: 0.0),
        speed: Double = 30
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.speed = speed
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Color(WinAmpColors.lcdBackground)
                
                // Scrolling text
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeometry.size.width
                                    startScrolling(containerWidth: geometry.size.width)
                                }
                        }
                    )
                    .offset(x: scrollOffset)
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width)
                    )
            }
            .clipped()
            .classicWindowStyle(raised: false)
            .onChange(of: text) { _ in
                resetScrolling(containerWidth: geometry.size.width)
            }
            .onDisappear {
                stopScrolling()
            }
        }
    }
    
    private func startScrolling(containerWidth: CGFloat) {
        guard textWidth > containerWidth else {
            // Text fits, no need to scroll
            scrollOffset = 0
            return
        }
        
        // Start with a pause
        isPaused = true
        scrollOffset = 0
        
        // Pause for 3 seconds before starting to scroll
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            isPaused = false
            startAnimation(containerWidth: containerWidth)
        }
    }
    
    private func startAnimation(containerWidth: CGFloat) {
        // Calculate animation duration based on speed
        let totalDistance = textWidth + containerWidth
        let duration = totalDistance / speed
        
        // Animate scrolling
        withAnimation(.linear(duration: duration)) {
            scrollOffset = -textWidth
        }
        
        // Reset after animation completes
        animationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            scrollOffset = containerWidth
            
            // Continue scrolling from right to left
            withAnimation(.linear(duration: duration)) {
                scrollOffset = -textWidth
            }
            
            // Loop the animation
            animationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { _ in
                scrollOffset = containerWidth
                withAnimation(.linear(duration: duration)) {
                    scrollOffset = -textWidth
                }
            }
        }
    }
    
    private func resetScrolling(containerWidth: CGFloat) {
        stopScrolling()
        startScrolling(containerWidth: containerWidth)
    }
    
    private func stopScrolling() {
        animationTimer?.invalidate()
        animationTimer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
}

/// Classic WinAmp song title display with scrolling
public struct SongTitleDisplay: View {
    let track: Track?
    let isPlaying: Bool
    
    public var body: some View {
        Group {
            if let track = track {
                let displayText = formatTrackDisplay(track)
                
                if isPlaying {
                    ScrollingMarquee(
                        text: displayText,
                        font: .system(size: 11, weight: .regular, design: .monospaced),
                        color: Color(WinAmpColors.lcdText),
                        speed: 40
                    )
                } else {
                    // Static display when not playing
                    Text(displayText)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(WinAmpColors.lcdText))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .background(Color(WinAmpColors.lcdBackground))
                        .classicWindowStyle(raised: false)
                }
            } else {
                // No track loaded
                Text("WINAMP")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(WinAmpColors.lcdTextDim))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(WinAmpColors.lcdBackground))
                    .classicWindowStyle(raised: false)
            }
        }
    }
    
    private func formatTrackDisplay(_ track: Track) -> String {
        var parts: [String] = []
        
        // Add track number if available
        if let trackNumber = track.trackNumber {
            parts.append("\(trackNumber).")
        }
        
        // Add artist if available
        if let artist = track.artist, !artist.isEmpty {
            parts.append(artist)
        }
        
        // Add title
        parts.append(track.displayTitle)
        
        // Join with " - "
        return parts.joined(separator: " - ")
    }
}

/// Playlist info display with scrolling
public struct PlaylistInfoDisplay: View {
    let playlist: Playlist
    let currentTrackIndex: Int?
    
    public var body: some View {
        let infoText = formatPlaylistInfo()
        
        ScrollingMarquee(
            text: infoText,
            font: .system(size: 9, weight: .regular, design: .monospaced),
            color: Color(WinAmpColors.text),
            speed: 25
        )
        .frame(height: 14)
    }
    
    private func formatPlaylistInfo() -> String {
        var parts: [String] = []
        
        // Playlist name
        parts.append(playlist.name)
        
        // Track count
        parts.append("\(playlist.tracks.count) tracks")
        
        // Total duration
        let totalDuration = playlist.tracks.compactMap { $0.duration }.reduce(0, +)
        parts.append(formatDuration(totalDuration))
        
        // Current position
        if let index = currentTrackIndex {
            parts.append("[\(index + 1)/\(playlist.tracks.count)]")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}