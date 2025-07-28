//
//  SpriteExtractor.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Extracts individual sprites from WinAmp skin sprite sheets
//

import Foundation
import AppKit

/// Sprite extractor for WinAmp skins
public class SpriteExtractor {
    
    /// Sprite sheet definitions mapping sprite types to their regions
    private static let spriteDefinitions: [String: [SpriteType: CGRect]] = [
        "main.bmp": [
            .mainBackground: CGRect(x: 0, y: 14, width: 275, height: 102), // Exclude title bar (14px)
            .titleBarActive: CGRect(x: 27, y: 0, width: 275, height: 14),
            .titleBarInactive: CGRect(x: 27, y: 15, width: 275, height: 14),
            .playingIndicator: CGRect(x: 24, y: 18, width: 3, height: 9),
            .pausedIndicator: CGRect(x: 27, y: 18, width: 3, height: 9),
            .stoppedIndicator: CGRect(x: 30, y: 18, width: 3, height: 9)
        ],
        
        "monoster.bmp": [
            .stereoIndicator: CGRect(x: 0, y: 0, width: 29, height: 12),
            .monoIndicator: CGRect(x: 0, y: 12, width: 29, height: 12)
        ],
        
        "cbuttons.bmp": [
            .previousButton(.normal): CGRect(x: 0, y: 0, width: 23, height: 18),
            .previousButton(.pressed): CGRect(x: 0, y: 18, width: 23, height: 18),
            .playButton(.normal): CGRect(x: 23, y: 0, width: 23, height: 18),
            .playButton(.pressed): CGRect(x: 23, y: 18, width: 23, height: 18),
            .pauseButton(.normal): CGRect(x: 46, y: 0, width: 23, height: 18),
            .pauseButton(.pressed): CGRect(x: 46, y: 18, width: 23, height: 18),
            .stopButton(.normal): CGRect(x: 69, y: 0, width: 23, height: 18),
            .stopButton(.pressed): CGRect(x: 69, y: 18, width: 23, height: 18),
            .nextButton(.normal): CGRect(x: 92, y: 0, width: 22, height: 18),
            .nextButton(.pressed): CGRect(x: 92, y: 18, width: 22, height: 18),
            .ejectButton(.normal): CGRect(x: 114, y: 0, width: 22, height: 16),
            .ejectButton(.pressed): CGRect(x: 114, y: 16, width: 22, height: 16)
        ],
        
        "titlebar.bmp": [
            .closeButton(.normal): CGRect(x: 18, y: 0, width: 9, height: 9),
            .closeButton(.pressed): CGRect(x: 18, y: 9, width: 9, height: 9),
            .minimizeButton(.normal): CGRect(x: 9, y: 0, width: 9, height: 9),
            .minimizeButton(.pressed): CGRect(x: 9, y: 9, width: 9, height: 9),
            .shadeButton(.normal): CGRect(x: 0, y: 0, width: 9, height: 9),
            .shadeButton(.pressed): CGRect(x: 0, y: 9, width: 9, height: 9),
            .menuButton(.normal): CGRect(x: 0, y: 18, width: 9, height: 9),
            .menuButton(.pressed): CGRect(x: 9, y: 18, width: 9, height: 9)
        ],
        
        "shufrep.bmp": [
            .shuffleButton(false, .normal): CGRect(x: 28, y: 0, width: 47, height: 15),
            .shuffleButton(false, .pressed): CGRect(x: 28, y: 15, width: 47, height: 15),
            .shuffleButton(true, .normal): CGRect(x: 28, y: 30, width: 47, height: 15),
            .shuffleButton(true, .pressed): CGRect(x: 28, y: 45, width: 47, height: 15),
            .repeatButton(false, .normal): CGRect(x: 0, y: 0, width: 28, height: 15),
            .repeatButton(false, .pressed): CGRect(x: 0, y: 15, width: 28, height: 15),
            .repeatButton(true, .normal): CGRect(x: 0, y: 30, width: 28, height: 15),
            .repeatButton(true, .pressed): CGRect(x: 0, y: 45, width: 28, height: 15),
            .equalizerButton(false, .normal): CGRect(x: 0, y: 61, width: 23, height: 12),
            .equalizerButton(false, .pressed): CGRect(x: 46, y: 61, width: 23, height: 12),
            .equalizerButton(true, .normal): CGRect(x: 0, y: 73, width: 23, height: 12),
            .equalizerButton(true, .pressed): CGRect(x: 46, y: 73, width: 23, height: 12),
            .playlistButton(false, .normal): CGRect(x: 23, y: 61, width: 23, height: 12),
            .playlistButton(false, .pressed): CGRect(x: 69, y: 61, width: 23, height: 12),
            .playlistButton(true, .normal): CGRect(x: 23, y: 73, width: 23, height: 12),
            .playlistButton(true, .pressed): CGRect(x: 69, y: 73, width: 23, height: 12)
        ],
        
        "volume.bmp": [
            // Volume bar contains 28 frames of animation (0-27 volume levels)
            // Each frame is 68x13 pixels
            .volumeSliderTrack: CGRect(x: 0, y: 0, width: 68, height: 13)
        ],
        
        "balance.bmp": [
            // Balance bar contains 28 frames of animation
            // Each frame is 38x13 pixels  
            .balanceSliderTrack: CGRect(x: 9, y: 0, width: 38, height: 13)
        ],
        
        "posbar.bmp": [
            .positionSliderTrack: CGRect(x: 0, y: 0, width: 248, height: 10),
            .positionSliderThumb(.normal): CGRect(x: 248, y: 0, width: 29, height: 10),
            .positionSliderThumb(.pressed): CGRect(x: 278, y: 0, width: 29, height: 10)
        ],
        
        "numbers.bmp": [
            .numberDigit(0): CGRect(x: 0, y: 0, width: 9, height: 13),
            .numberDigit(1): CGRect(x: 9, y: 0, width: 9, height: 13),
            .numberDigit(2): CGRect(x: 18, y: 0, width: 9, height: 13),
            .numberDigit(3): CGRect(x: 27, y: 0, width: 9, height: 13),
            .numberDigit(4): CGRect(x: 36, y: 0, width: 9, height: 13),
            .numberDigit(5): CGRect(x: 45, y: 0, width: 9, height: 13),
            .numberDigit(6): CGRect(x: 54, y: 0, width: 9, height: 13),
            .numberDigit(7): CGRect(x: 63, y: 0, width: 9, height: 13),
            .numberDigit(8): CGRect(x: 72, y: 0, width: 9, height: 13),
            .numberDigit(9): CGRect(x: 81, y: 0, width: 9, height: 13),
            .timeColon: CGRect(x: 90, y: 0, width: 5, height: 13),
            .timeMinus: CGRect(x: 99, y: 0, width: 9, height: 13)
        ],
        
        "text.bmp": [:], // Text bitmap handled by extractTextCharacter method
        
        "eqmain.bmp": [
            .eqBackground: CGRect(x: 0, y: 0, width: 275, height: 116),
            .eqOnOffButton(false, .normal): CGRect(x: 10, y: 119, width: 25, height: 12),
            .eqOnOffButton(false, .pressed): CGRect(x: 128, y: 119, width: 25, height: 12),
            .eqOnOffButton(true, .normal): CGRect(x: 69, y: 119, width: 25, height: 12),
            .eqOnOffButton(true, .pressed): CGRect(x: 187, y: 119, width: 25, height: 12),
            .eqAutoButton(false, .normal): CGRect(x: 35, y: 119, width: 33, height: 12),
            .eqAutoButton(false, .pressed): CGRect(x: 153, y: 119, width: 33, height: 12),
            .eqAutoButton(true, .normal): CGRect(x: 94, y: 119, width: 33, height: 12),
            .eqAutoButton(true, .pressed): CGRect(x: 212, y: 119, width: 33, height: 12),
            .eqPresetButton(.normal): CGRect(x: 224, y: 164, width: 44, height: 12),
            .eqPresetButton(.pressed): CGRect(x: 224, y: 176, width: 44, height: 12),
            // Close, minimize, shade buttons for EQ window
            .eqCloseButton: CGRect(x: 0, y: 116, width: 9, height: 9),
            .eqMinimizeButton: CGRect(x: 9, y: 116, width: 9, height: 9),
            .eqShadeButton: CGRect(x: 18, y: 116, width: 9, height: 9),
            // EQ title bar
            .eqTitleBarActive: CGRect(x: 0, y: 134, width: 275, height: 14),
            .eqTitleBarInactive: CGRect(x: 0, y: 149, width: 275, height: 14)
        ],
        
        "eq_ex.bmp": [
            // EQ sliders - contains slider backgrounds and thumb sprites
            // Each band slider is 14x63 pixels
            .eqSliderBackground: CGRect(x: 0, y: 0, width: 113, height: 63),
            .eqSliderThumb(.normal): CGRect(x: 0, y: 64, width: 11, height: 11),
            .eqSliderThumb(.pressed): CGRect(x: 0, y: 76, width: 11, height: 11),
            // Preamp slider
            .eqPreampBackground: CGRect(x: 113, y: 0, width: 14, height: 63),
            .eqPreampThumb(.normal): CGRect(x: 113, y: 64, width: 11, height: 11),
            .eqPreampThumb(.pressed): CGRect(x: 113, y: 76, width: 11, height: 11)
        ],
        
        "pledit.bmp": [
            .playlistBackground: CGRect(x: 0, y: 0, width: 275, height: 116),
            .playlistScrollbarTrack: CGRect(x: 36, y: 42, width: 8, height: 18),
            .playlistScrollbarThumb: CGRect(x: 52, y: 53, width: 8, height: 18),
            .playlistAddButton(.normal): CGRect(x: 11, y: 20, width: 25, height: 18),
            .playlistAddButton(.pressed): CGRect(x: 11, y: 40, width: 25, height: 18),
            .playlistRemoveButton(.normal): CGRect(x: 40, y: 20, width: 25, height: 18),
            .playlistRemoveButton(.pressed): CGRect(x: 40, y: 40, width: 25, height: 18),
            .playlistSelectButton(.normal): CGRect(x: 69, y: 20, width: 25, height: 18),
            .playlistSelectButton(.pressed): CGRect(x: 69, y: 40, width: 25, height: 18),
            .playlistMiscButton(.normal): CGRect(x: 98, y: 20, width: 25, height: 18),
            .playlistMiscButton(.pressed): CGRect(x: 98, y: 40, width: 25, height: 18),
            .playlistListButton(.normal): CGRect(x: 127, y: 20, width: 25, height: 18),
            .playlistListButton(.pressed): CGRect(x: 127, y: 40, width: 25, height: 18)
        ]
    ]
    
    /// Extract a specific sprite from the parsed skin
    public static func extractSprite(_ type: SpriteType, from skin: ParsedSkin) -> NSImage? {
        // Find which bitmap contains this sprite
        for (bitmapName, sprites) in spriteDefinitions {
            if let rect = sprites[type],
               let bitmap = skin.bitmaps[bitmapName] {
                return extractRegion(from: bitmap, rect: rect)
            }
        }
        return nil
    }
    
    /// Extract all sprites from a parsed skin
    public static func extractAllSprites(from skin: ParsedSkin) -> [SpriteType: NSImage] {
        var extractedSprites: [SpriteType: NSImage] = [:]
        
        // Default transparency color for WinAmp skins
        let transparencyColor = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0) // Magenta #FF00FF
        
        for (bitmapName, sprites) in spriteDefinitions {
            guard let bitmap = skin.bitmaps[bitmapName] else { continue }
            
            for (spriteType, rect) in sprites {
                if let sprite = extractRegion(from: bitmap, rect: rect, transparencyColor: transparencyColor) {
                    extractedSprites[spriteType] = sprite
                }
            }
        }
        
        return extractedSprites
    }
    
    /// Extract a region from an image with transparency masking
    private static func extractRegion(from image: NSImage, rect: CGRect, transparencyColor: NSColor? = nil) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Ensure rect is within image bounds
        let imageRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clippedRect = rect.intersection(imageRect)
        
        guard !clippedRect.isEmpty else { return nil }
        
        // Extract the region
        guard let croppedImage = cgImage.cropping(to: clippedRect) else { return nil }
        
        // Apply transparency mask if needed
        if let transparencyColor = transparencyColor {
            return applyTransparencyMask(to: croppedImage, transparencyColor: transparencyColor, size: clippedRect.size)
        }
        
        return NSImage(cgImage: croppedImage, size: clippedRect.size)
    }
    
    /// Apply transparency mask to an image based on a specific color
    private static func applyTransparencyMask(to cgImage: CGImage, transparencyColor: NSColor, size: CGSize) -> NSImage? {
        // Classic WinAmp uses magenta (#FF00FF) as the transparency color
        let magenta = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let colorToMask = transparencyColor == nil ? magenta : transparencyColor
        
        // Get color components
        guard let components = colorToMask.cgColor.components,
              components.count >= 3 else { return NSImage(cgImage: cgImage, size: size) }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Create color masking values (tolerance of ~2% for each component)
        let tolerance: CGFloat = 0.02
        let maskingColors: [CGFloat] = [
            max(0, r - tolerance) * 255, min(1, r + tolerance) * 255,
            max(0, g - tolerance) * 255, min(1, g + tolerance) * 255,
            max(0, b - tolerance) * 255, min(1, b + tolerance) * 255
        ]
        
        // Apply the color mask
        guard let maskedImage = cgImage.copy(maskingColorComponents: maskingColors) else {
            return NSImage(cgImage: cgImage, size: size)
        }
        
        return NSImage(cgImage: maskedImage, size: size)
    }
    
    /// Get expected sprite size for layout
    public static func getSpriteSize(for type: SpriteType) -> CGSize? {
        for (_, sprites) in spriteDefinitions {
            if let rect = sprites[type] {
                return rect.size
            }
        }
        return nil
    }
    
    /// Extract volume bar frame for a specific volume level
    public static func extractVolumeFrame(from skin: ParsedSkin, level: Int) -> NSImage? {
        guard let volumeBitmap = skin.bitmaps["volume.bmp"],
              level >= 0 && level <= 27 else { return nil }
        
        // Each frame is 68x13, stacked vertically
        let frameRect = CGRect(x: 0, y: level * 13, width: 68, height: 13)
        return extractRegion(from: volumeBitmap, rect: frameRect)
    }
    
    /// Extract balance bar frame for a specific balance level
    public static func extractBalanceFrame(from skin: ParsedSkin, level: Int) -> NSImage? {
        guard let balanceBitmap = skin.bitmaps["balance.bmp"],
              level >= 0 && level <= 27 else { return nil }
        
        // Each frame is 38x13, stacked vertically
        let frameRect = CGRect(x: 9, y: level * 13, width: 38, height: 13)
        return extractRegion(from: balanceBitmap, rect: frameRect)
    }
    
    /// Extract a character from the text bitmap font
    public static func extractTextCharacter(from skin: ParsedSkin, character: Character) -> NSImage? {
        guard let textBitmap = skin.bitmaps["text.bmp"] else { return nil }
        
        // WinAmp text.bmp layout:
        // - Characters are 5x6 pixels each
        // - Arranged in a grid, 31 characters per row
        // - ASCII characters from 32 (space) to 126 (~)
        
        let charWidth: CGFloat = 5
        let charHeight: CGFloat = 6
        let charsPerRow = 31
        
        let asciiValue = Int(character.asciiValue ?? 0)
        guard asciiValue >= 32 && asciiValue <= 126 else { return nil }
        
        let charIndex = asciiValue - 32
        let row = charIndex / charsPerRow
        let col = charIndex % charsPerRow
        
        let x = CGFloat(col) * charWidth
        let y = CGFloat(row) * charHeight
        
        let charRect = CGRect(x: x, y: y, width: charWidth, height: charHeight)
        let transparencyColor = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
        
        return extractRegion(from: textBitmap, rect: charRect, transparencyColor: transparencyColor)
    }
    
    /// Render text using the bitmap font
    public static func renderText(_ text: String, from skin: ParsedSkin, spacing: CGFloat = 0) -> NSImage? {
        let characters = Array(text)
        guard !characters.isEmpty else { return nil }
        
        let charWidth: CGFloat = 5
        let charHeight: CGFloat = 6
        let totalWidth = CGFloat(characters.count) * (charWidth + spacing) - spacing
        
        let image = NSImage(size: NSSize(width: totalWidth, height: charHeight))
        image.lockFocus()
        
        var xOffset: CGFloat = 0
        for char in characters {
            if let charImage = extractTextCharacter(from: skin, character: char) {
                charImage.draw(at: NSPoint(x: xOffset, y: 0),
                             from: NSRect.zero,
                             operation: .sourceOver,
                             fraction: 1.0)
            }
            xOffset += charWidth + spacing
        }
        
        image.unlockFocus()
        return image
    }
    
    /// Extract a single character from text.bmp using cached skin
    public static func extractTextCharacter(_ char: Character, from cachedSkin: CachedSkin) -> NSImage? {
        // Look for text sprite in cached skin
        guard let textSprite = cachedSkin.sprites[.text] else {
            return nil
        }
        
        // Calculate character position in text.bmp
        let charCode = Int(char.asciiValue ?? 0)
        if charCode < 32 || charCode > 126 { return nil } // ASCII printable range
        
        let charIndex = charCode - 32
        let charsPerRow = 31
        let charWidth: CGFloat = 5
        let charHeight: CGFloat = 6
        
        let row = charIndex / charsPerRow
        let col = charIndex % charsPerRow
        
        let x = CGFloat(col) * charWidth
        let y = CGFloat(row) * charHeight
        
        // Extract character region
        let charRect = CGRect(x: x, y: y, width: charWidth, height: charHeight)
        return extractRegion(from: textSprite, rect: charRect)
    }
    
    /// Combine multiple images horizontally with spacing
    public static func combineImages(_ images: [NSImage], spacing: CGFloat) -> NSImage? {
        guard !images.isEmpty else { return nil }
        
        let totalWidth = images.reduce(0) { $0 + $1.size.width } + (spacing * CGFloat(images.count - 1))
        let maxHeight = images.map { $0.size.height }.max() ?? 0
        
        let combinedImage = NSImage(size: NSSize(width: totalWidth, height: maxHeight))
        combinedImage.lockFocus()
        
        var xOffset: CGFloat = 0
        for image in images {
            image.draw(at: NSPoint(x: xOffset, y: 0), 
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .sourceOver,
                      fraction: 1.0)
            xOffset += image.size.width + spacing
        }
        
        combinedImage.unlockFocus()
        return combinedImage
    }
}