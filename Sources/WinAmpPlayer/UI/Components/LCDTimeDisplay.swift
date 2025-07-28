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
    @EnvironmentObject var skinManager: SkinManager
    
    var body: some View {
        HStack(spacing: 2) {
            // Time display
            BitmapNumberText(text: displayTime)
            
            Spacer()
            
            // Bitrate and sample rate
            VStack(alignment: .trailing, spacing: 0) {
                BitmapFontText("\(kbps) KBPS", spacing: -1)
                    .scaleEffect(0.8)
                BitmapFontText("\(khz) KHZ", spacing: -1)
                    .scaleEffect(0.8)
            }
            
            // Mode indicator
            BitmapFontText(mode.uppercased(), spacing: -1)
                .scaleEffect(0.8)
                .frame(width: 35)
        }
        .padding(.horizontal, 4)
        .frame(width: 154, height: 13)
        .background(skinManager.colorManager.lcdBackgroundColor)
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
    @EnvironmentObject var skinManager: SkinManager
    
    var body: some View {
        Text(String(character))
            .font(.custom("Monaco", size: 11))
            .foregroundColor(skinManager.colorManager.timeDisplayColor)
            .frame(width: 6, height: 11)
            .shadow(color: skinManager.colorManager.timeDisplayColor.opacity(0.5), radius: 1)
    }
}

// MARK: - Song Title Display

struct LCDSongDisplay: View {
    let artist: String
    let title: String
    @EnvironmentObject var skinManager: SkinManager
    
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
        ScrollingBitmapText(text: displayText.uppercased(), width: 154)
            .frame(height: 11)
            .background(skinManager.colorManager.lcdBackgroundColor)
    }
}

// Size preference key for measuring text
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}