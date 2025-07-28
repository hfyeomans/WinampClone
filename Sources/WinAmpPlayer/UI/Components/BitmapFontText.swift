//
//  BitmapFontText.swift
//  WinAmpPlayer
//
//  Renders text using WinAmp bitmap fonts from skin files
//

import SwiftUI
import AppKit

/// View that renders text using bitmap fonts from WinAmp skins
struct BitmapFontText: View {
    let text: String
    let spacing: CGFloat
    @EnvironmentObject var skinManager: SkinManager
    
    init(_ text: String, spacing: CGFloat = 0) {
        self.text = text
        self.spacing = spacing
    }
    
    var body: some View {
        if let renderedImage = renderText() {
            Image(nsImage: renderedImage)
                .interpolation(.none) // Preserve pixel art
        } else {
            // Fallback to system font
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(skinManager.colorManager.mainTextColor)
        }
    }
    
    func lineLimit(_ number: Int?) -> some View {
        self // Bitmap fonts don't support line limits, but we accept the modifier for API compatibility
    }
    
    private func renderText() -> NSImage? {
        guard let cachedSkin = skinManager.currentCachedSkin else {
            return nil
        }
        
        // Extract text characters from the cached skin
        var characterImages: [NSImage] = []
        for char in text.uppercased() {
            if let charImage = SpriteExtractor.extractTextCharacter(char, from: cachedSkin) {
                characterImages.append(charImage)
            }
        }
        
        return SpriteExtractor.combineImages(characterImages, spacing: spacing)
    }
}

/// View for rendering scrolling bitmap text (like song titles)
struct ScrollingBitmapText: View {
    let text: String
    let width: CGFloat
    @State private var scrollOffset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var shouldScroll = false
    @EnvironmentObject var skinManager: SkinManager
    
    private let scrollSpeed: Double = 30 // pixels per second
    
    var body: some View {
        GeometryReader { geometry in
            BitmapFontText(text)
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear {
                                textWidth = textGeometry.size.width
                                shouldScroll = textGeometry.size.width > geometry.size.width
                                if shouldScroll {
                                    startScrolling()
                                }
                            }
                    }
                )
                .offset(x: scrollOffset)
                .frame(width: geometry.size.width, alignment: .leading)
                .clipped()
        }
        .frame(width: width, height: 6) // WinAmp text height
    }
    
    private func startScrolling() {
        // Reset to start position
        scrollOffset = 0
        
        // Animate scrolling
        withAnimation(.linear(duration: Double(textWidth + width) / scrollSpeed)) {
            scrollOffset = -(textWidth + 20) // Extra space before looping
        }
        
        // Loop animation
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(textWidth + width) / scrollSpeed) {
            if shouldScroll {
                startScrolling()
            }
        }
    }
}

/// View for rendering bitmap numbers (time display)
struct BitmapNumberText: View {
    let text: String
    @EnvironmentObject var skinManager: SkinManager
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                BitmapDigit(character: char)
            }
        }
    }
}

/// Single bitmap digit renderer
struct BitmapDigit: View {
    let character: Character
    @EnvironmentObject var skinManager: SkinManager
    
    var body: some View {
        if let digitImage = getDigitImage() {
            Image(nsImage: digitImage)
                .interpolation(.none)
        } else {
            // Fallback
            Text(String(character))
                .font(.custom("Monaco", size: 11))
                .foregroundColor(skinManager.colorManager.timeDisplayColor)
                .frame(width: character == ":" ? 5 : 9, height: 13)
        }
    }
    
    private func getDigitImage() -> NSImage? {
        guard let cachedSkin = skinManager.currentCachedSkin else {
            // Use default skin digits
            return getDefaultDigitImage()
        }
        
        // Map character to sprite type
        let spriteType: SpriteType?
        switch character {
        case "0"..."9":
            if let digit = Int(String(character)) {
                spriteType = .numberDigit(digit)
            } else {
                spriteType = nil
            }
        case ":":
            spriteType = .timeColon
        case "-":
            spriteType = .timeMinus
        default:
            spriteType = nil
        }
        
        guard let type = spriteType else { return nil }
        return skinManager.getSprite(type)
    }
    
    private func getDefaultDigitImage() -> NSImage? {
        let spriteType: SpriteType?
        switch character {
        case "0"..."9":
            if let digit = Int(String(character)) {
                spriteType = .numberDigit(digit)
            } else {
                spriteType = nil
            }
        case ":":
            spriteType = .timeColon
        case "-":
            spriteType = .timeMinus
        default:
            spriteType = nil
        }
        
        guard let type = spriteType else { return nil }
        return DefaultSkin.shared.getSprite(type)
    }
}

/// Preview provider
struct BitmapFontText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BitmapFontText("WINAMP CLASSIC")
                .environmentObject(SkinManager.shared)
            
            ScrollingBitmapText(text: "Now Playing: Artist - Song Title (Extended Mix)", width: 200)
                .environmentObject(SkinManager.shared)
            
            BitmapNumberText(text: "12:34")
                .environmentObject(SkinManager.shared)
        }
        .padding()
        .background(Color.black)
    }
}