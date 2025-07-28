import Foundation
import AppKit
import CoreGraphics

/// Manages sprite extraction from WinAmp skin bitmap files
/// Provides lazy loading and caching of individual sprites from larger images
public class SpriteSheet {
    public let sourceImage: NSImage
    public let spriteMap: [String: CGRect]
    private var cachedSprites: [String: NSImage] = [:]
    
    public init(sourceImage: NSImage, spriteMap: [String: CGRect]) {
        self.sourceImage = sourceImage
        self.spriteMap = spriteMap
    }
    
    /// Get a sprite by name, with lazy loading and caching
    public func sprite(named name: String) -> NSImage? {
        // Return cached sprite if available
        if let cached = cachedSprites[name] {
            return cached
        }
        
        // Extract sprite if mapping exists
        guard let rect = spriteMap[name] else {
            return nil
        }
        
        guard let sprite = ClassicBMPDecoder.extractSprite(from: sourceImage, rect: rect) else {
            return nil
        }
        
        // Cache and return
        cachedSprites[name] = sprite
        return sprite
    }
    
    /// Get all available sprite names
    public var availableSprites: [String] {
        return Array(spriteMap.keys)
    }
    
    /// Clear cached sprites to free memory
    public func clearCache() {
        cachedSprites.removeAll()
    }
    
    /// Pre-load specific sprites into cache
    public func preloadSprites(_ names: [String]) {
        for name in names {
            _ = sprite(named: name)
        }
    }
}

// MARK: - WinAmp Main Window Sprite Layout

/// Standard sprite coordinates for WinAmp main.bmp (275x116 pixels)
public struct MainWindowSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        // Background areas
        "titlebar": CGRect(x: 0, y: 0, width: 275, height: 14),
        "background": CGRect(x: 0, y: 0, width: 275, height: 116),
        "mainBackground": CGRect(x: 0, y: 14, width: 275, height: 102),
        
        // Transport controls background areas
        "transportBackground": CGRect(x: 16, y: 88, width: 108, height: 28),
        
        // Volume/Balance slider backgrounds
        "volumeBackground": CGRect(x: 107, y: 57, width: 68, height: 13),
        "balanceBackground": CGRect(x: 177, y: 57, width: 38, height: 13),
        
        // Display areas
        "textDisplay": CGRect(x: 111, y: 27, width: 153, height: 6),
        "timeDisplay": CGRect(x: 36, y: 26, width: 63, height: 13),
        "visualization": CGRect(x: 24, y: 43, width: 76, height: 16),
        
        // Seek bar background
        "seekbarBackground": CGRect(x: 16, y: 72, width: 248, height: 10),
        
        // Small components
        "monoStereoDisplay": CGRect(x: 212, y: 41, width: 57, height: 12),
        "kbpsDisplay": CGRect(x: 111, y: 43, width: 56, height: 8),
        "khzDisplay": CGRect(x: 156, y: 43, width: 10, height: 8)
    ]
    
    /// Get sprite sheet for main.bmp
    public static func createSpriteSheet(from mainBMP: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: mainBMP, spriteMap: spriteMap)
    }
}

/// Standard sprite coordinates for WinAmp cbuttons.bmp (transport controls)
public struct TransportButtonSpriteMap {
    public static let buttonWidth: CGFloat = 23
    public static let buttonHeight: CGFloat = 18
    
    public static let spriteMap: [String: CGRect] = [
        // Previous button states (x: 0-22)
        "prevNormal": CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight),
        "prevPressed": CGRect(x: 0, y: 18, width: buttonWidth, height: buttonHeight),
        
        // Play button states (x: 23-45)
        "playNormal": CGRect(x: 23, y: 0, width: buttonWidth, height: buttonHeight),
        "playPressed": CGRect(x: 23, y: 18, width: buttonWidth, height: buttonHeight),
        
        // Pause button states (x: 46-68)  
        "pauseNormal": CGRect(x: 46, y: 0, width: buttonWidth, height: buttonHeight),
        "pausePressed": CGRect(x: 46, y: 18, width: buttonWidth, height: buttonHeight),
        
        // Stop button states (x: 69-91)
        "stopNormal": CGRect(x: 69, y: 0, width: buttonWidth, height: buttonHeight),
        "stopPressed": CGRect(x: 69, y: 18, width: buttonWidth, height: buttonHeight),
        
        // Next button states (x: 92-114)
        "nextNormal": CGRect(x: 92, y: 0, width: buttonWidth, height: buttonHeight),
        "nextPressed": CGRect(x: 92, y: 18, width: buttonWidth, height: buttonHeight),
        
        // Eject button states (x: 114-136)
        "ejectNormal": CGRect(x: 114, y: 0, width: buttonWidth, height: buttonHeight),
        "ejectPressed": CGRect(x: 114, y: 18, width: buttonWidth, height: buttonHeight)
    ]
    
    /// Get sprite sheet for cbuttons.bmp
    public static func createSpriteSheet(from cButtonsBMP: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: cButtonsBMP, spriteMap: spriteMap)
    }
}

/// Standard sprite coordinates for WinAmp playpaus.bmp (play/pause toggle)
public struct PlayPauseSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "play": CGRect(x: 0, y: 0, width: 9, height: 9),
        "pause": CGRect(x: 9, y: 0, width: 9, height: 9)
    ]
    
    public static func createSpriteSheet(from playPausBMP: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: playPausBMP, spriteMap: spriteMap)
    }
}

// MARK: - Sprite Loading Utilities

extension SpriteSheet {
    /// Create sprite sheet from BMP data
    public static func loadFromBMP(_ data: Data, layout: [String: CGRect]) throws -> SpriteSheet {
        let image = try ClassicBMPDecoder.decode(data)
        return SpriteSheet(sourceImage: image, spriteMap: layout)
    }
    
    /// Validate that all expected sprites can be extracted
    public func validateSprites() -> [String] {
        var missingSprites: [String] = []
        
        for spriteName in spriteMap.keys {
            if sprite(named: spriteName) == nil {
                missingSprites.append(spriteName)
            }
        }
        
        return missingSprites
    }
}
