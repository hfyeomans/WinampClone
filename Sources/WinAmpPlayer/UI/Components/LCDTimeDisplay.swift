//
//  LCDTimeDisplay.swift
//  WinAmpPlayer
//
//  LCD-style time display with bitmap font
//

import SwiftUI

struct LCDTimeDisplay: View {
    let currentTime: String
    let totalTime: String
    let kbps: String
    let khz: String
    let mode: String // "Stereo" or "Mono"
    @Binding var isRemainingTime: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            // Time display
            HStack(spacing: 0) {
                ForEach(Array(displayTime.enumerated()), id: \.offset) { index, char in
                    LCDDigit(character: char)
                }
            }
            
            Spacer()
            
            // Bitrate and sample rate
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(kbps) kbps")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(WinAmpColors.lcdText)
                Text("\(khz) kHz")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(WinAmpColors.lcdText)
            }
            
            // Mode indicator
            Text(mode)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(WinAmpColors.lcdText)
                .frame(width: 35)
        }
        .padding(.horizontal, 4)
        .frame(width: 154, height: 13)
        .background(WinAmpColors.lcdBackground)
        .overlay(BeveledBorder(raised: false))
        .onTapGesture {
            isRemainingTime.toggle()
        }
    }
    
    private var displayTime: String {
        if isRemainingTime {
            return "-\(totalTime)"
        } else {
            return " \(currentTime)"
        }
    }
}

struct LCDDigit: View {
    let character: Character
    
    var body: some View {
        Text(String(character))
            .font(.custom("Monaco", size: 11))
            .foregroundColor(WinAmpColors.lcdText)
            .frame(width: 6, height: 11)
            .shadow(color: WinAmpColors.lcdText.opacity(0.5), radius: 1)
    }
}

// MARK: - Song Title Display

struct LCDSongDisplay: View {
    let artist: String
    let title: String
    @State private var scrollOffset: CGFloat = 0
    @State private var shouldScroll = false
    
    private let scrollSpeed: Double = 30 // pixels per second
    
    var displayText: String {
        if !artist.isEmpty && !title.isEmpty {
            return "\(artist) - \(title)"
        } else if !title.isEmpty {
            return title
        } else {
            return "WinAmp"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Text(displayText)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(WinAmpColors.lcdText)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear {
                                shouldScroll = textGeometry.size.width > geometry.size.width
                            }
                    }
                )
                .offset(x: scrollOffset)
                .animation(shouldScroll ? .linear(duration: Double(displayText.count) / 10).repeatForever(autoreverses: true) : .none, value: scrollOffset)
                .onAppear {
                    if shouldScroll {
                        withAnimation {
                            scrollOffset = -(textGeometry.size.width - geometry.size.width)
                        }
                    }
                }
        }
        .frame(height: 11)
        .clipped()
        .background(WinAmpColors.lcdBackground)
    }
    
    private var textGeometry: some GeometryProxy {
        GeometryReader { geometry in
            Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
        }
        .frame(height: 0)
        .hidden()
        as! GeometryProxy
    }
}

// Size preference key for measuring text
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}