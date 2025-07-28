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
            .mainBackground: CGRect(x: 0, y: 0, width: 275, height: 116),
            .titleBarActive: CGRect(x: 27, y: 0, width: 275, height: 14),
            .titleBarInactive: CGRect(x: 27, y: 15, width: 275, height: 14),
            .stereoIndicator: CGRect(x: 0, y: 12, width: 29, height: 12),
            .monoIndicator: CGRect(x: 29, y: 12, width: 29, height: 12),
            .playingIndicator: CGRect(x: 24, y: 18, width: 3, height: 9),
            .pausedIndicator: CGRect(x: 27, y: 18, width: 3, height: 9),
            .stoppedIndicator: CGRect(x: 30, y: 18, width: 3, height: 9)
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
            .volumeSliderTrack: CGRect(x: 0, y: 0, width: 68, height: 13),
            .volumeSliderThumb(.normal): CGRect(x: 15, y: 422, width: 14, height: 11),
            .volumeSliderThumb(.pressed): CGRect(x: 0, y: 422, width: 14, height: 11)
        ],
        
        "balance.bmp": [
            .balanceSliderTrack: CGRect(x: 9, y: 0, width: 38, height: 13),
            .balanceSliderThumb(.normal): CGRect(x: 15, y: 422, width: 14, height: 11),
            .balanceSliderThumb(.pressed): CGRect(x: 0, y: 422, width: 14, height: 11)
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
            .eqPresetButton(.pressed): CGRect(x: 224, y: 176, width: 44, height: 12)
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
        
        for (bitmapName, sprites) in spriteDefinitions {
            guard let bitmap = skin.bitmaps[bitmapName] else { continue }
            
            for (spriteType, rect) in sprites {
                if let sprite = extractRegion(from: bitmap, rect: rect) {
                    extractedSprites[spriteType] = sprite
                }
            }
        }
        
        return extractedSprites
    }
    
    /// Extract a region from an image
    private static func extractRegion(from image: NSImage, rect: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Ensure rect is within image bounds
        let imageRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clippedRect = rect.intersection(imageRect)
        
        guard !clippedRect.isEmpty else { return nil }
        
        // Extract the region
        guard let croppedImage = cgImage.cropping(to: clippedRect) else { return nil }
        
        return NSImage(cgImage: croppedImage, size: clippedRect.size)
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
}