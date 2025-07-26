//
//  BitmapFont.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Bitmap font rendering for skin numbers
//

import SwiftUI
import AppKit

/// Bitmap font text view using skin number sprites
public struct BitmapFontText: View {
    let text: String
    let spacing: CGFloat
    
    @StateObject private var skinManager = SkinManager.shared
    
    public init(_ text: String, spacing: CGFloat = 0) {
        self.text = text
        self.spacing = spacing
    }
    
    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                if let sprite = spriteForCharacter(character) {
                    SpriteView(sprite)
                }
            }
        }
    }
    
    private func spriteForCharacter(_ char: Character) -> SpriteType? {
        switch char {
        case "0": return .numberDigit(0)
        case "1": return .numberDigit(1)
        case "2": return .numberDigit(2)
        case "3": return .numberDigit(3)
        case "4": return .numberDigit(4)
        case "5": return .numberDigit(5)
        case "6": return .numberDigit(6)
        case "7": return .numberDigit(7)
        case "8": return .numberDigit(8)
        case "9": return .numberDigit(9)
        case ":": return .timeColon
        case "-": return .timeMinus
        default: return nil
        }
    }
}

/// Time display using bitmap font
public struct SkinnableTimeDisplay: View {
    let time: TimeInterval
    let showRemaining: Bool
    
    @StateObject private var skinManager = SkinManager.shared
    
    public init(time: TimeInterval, showRemaining: Bool = false) {
        self.time = time
        self.showRemaining = showRemaining
    }
    
    private var formattedTime: String {
        let minutes = Int(abs(time)) / 60
        let seconds = Int(abs(time)) % 60
        let prefix = showRemaining && time > 0 ? "-" : ""
        return String(format: "%@%d:%02d", prefix, minutes, seconds)
    }
    
    public var body: some View {
        BitmapFontText(formattedTime)
    }
}

/// Bitrate display
public struct SkinnableBitrateDisplay: View {
    let bitrate: Int? // in kbps
    
    @StateObject private var skinManager = SkinManager.shared
    
    public init(bitrate: Int?) {
        self.bitrate = bitrate
    }
    
    public var body: some View {
        if let bitrate = bitrate {
            BitmapFontText(String(bitrate))
        } else {
            BitmapFontText("---")
        }
    }
}

/// Sample rate display
public struct SkinnableSampleRateDisplay: View {
    let sampleRate: Int? // in Hz
    
    @StateObject private var skinManager = SkinManager.shared
    
    public init(sampleRate: Int?) {
        self.sampleRate = sampleRate
    }
    
    public var body: some View {
        if let sampleRate = sampleRate {
            let khz = sampleRate / 1000
            BitmapFontText(String(khz))
        } else {
            BitmapFontText("--")
        }
    }
}