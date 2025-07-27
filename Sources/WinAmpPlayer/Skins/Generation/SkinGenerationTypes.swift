//
//  SkinGenerationTypes.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Core types and structures for procedural skin generation
//

import Foundation
import CoreGraphics

// MARK: - Configuration Types

/// Theme mode for generated skins
public enum ThemeMode: String, Codable {
    case dark
    case light
    case auto
}

/// Visual style for generated skins
public enum VisualStyle: String, Codable {
    case modern
    case retro
    case minimal
    case glass
    case cyberpunk
    case vaporwave
}

/// Button rendering style
public enum ButtonStyle: String, Codable {
    case flat
    case rounded
    case beveled
    case glass
    case pill
    case square
}

/// Slider rendering style
public enum SliderStyle: String, Codable {
    case classic
    case modern
    case minimal
    case groove
    case rail
}

/// Color harmony scheme
public enum ColorScheme: String, Codable {
    case monochromatic
    case complementary
    case analogous
    case triadic
    case splitComplementary
    case tetradic
}

// MARK: - Color Types

/// HCT (Hue, Chroma, Tone) color representation
public struct HCTColor: Codable {
    public let hue: Double      // 0-360 degrees
    public let chroma: Double   // 0-1 (0 = gray, 1 = maximum chroma)
    public let tone: Double     // 0-1 (0 = black, 1 = white)
    
    public init(hue: Double, chroma: Double, tone: Double) {
        self.hue = hue.truncatingRemainder(dividingBy: 360)
        self.chroma = max(0, min(1, chroma))
        self.tone = max(0, min(1, tone))
    }
}

/// Tonal palette with multiple tone levels
public struct TonalPalette {
    public let baseColor: HCTColor
    public let tones: [Int: CGColor] // Tone levels: 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100
    
    public init(baseColor: HCTColor) {
        self.baseColor = baseColor
        
        // Generate tones
        var toneMap: [Int: CGColor] = [:]
        let toneLevels = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100]
        
        for level in toneLevels {
            let tone = Double(level) / 100.0
            let color = HCTColor(hue: baseColor.hue, chroma: baseColor.chroma, tone: tone)
            toneMap[level] = color.toCGColor()
        }
        
        self.tones = toneMap
    }
    
    /// Get color at specific tone level
    public func tone(_ level: Int) -> CGColor {
        return tones[level] ?? CGColor.black
    }
}

/// Generated color palette for a skin
public struct GeneratedPalette {
    public let primary: TonalPalette
    public let secondary: TonalPalette
    public let tertiary: TonalPalette
    public let neutral: TonalPalette
    public let error: TonalPalette
    
    // Semantic colors
    public var background: CGColor { neutral.tone(10) }
    public var onBackground: CGColor { neutral.tone(90) }
    public var surface: CGColor { neutral.tone(20) }
    public var onSurface: CGColor { neutral.tone(90) }
    public var primaryColor: CGColor { primary.tone(50) }
    public var onPrimary: CGColor { primary.tone(100) }
    public var secondaryColor: CGColor { secondary.tone(50) }
    public var onSecondary: CGColor { secondary.tone(100) }
}

// MARK: - Texture Types

/// Type of procedural texture
public enum TextureType: String, Codable {
    case solid
    case gradient
    case noise
    case circuit
    case dots
    case lines
    case waves
    case voronoi
    case checkerboard
}

/// Texture configuration
public struct TextureConfig: Codable {
    public let type: TextureType
    public let scale: Double
    public let octaves: Int?
    public let persistence: Double?
    public let opacity: Double
    public let blendMode: String?
    
    public init(
        type: TextureType,
        scale: Double = 1.0,
        octaves: Int? = nil,
        persistence: Double? = nil,
        opacity: Double = 1.0,
        blendMode: String? = nil
    ) {
        self.type = type
        self.scale = scale
        self.octaves = octaves
        self.persistence = persistence
        self.opacity = opacity
        self.blendMode = blendMode
    }
}

// MARK: - Generation Configuration

/// Complete configuration for skin generation
public struct SkinGenerationConfig: Codable {
    // Metadata
    public struct Metadata: Codable {
        public let name: String
        public let author: String
        public let version: String
        public let description: String?
        
        public init(name: String, author: String = "WinAmp Generator", version: String = "1.0", description: String? = nil) {
            self.name = name
            self.author = author
            self.version = version
            self.description = description
        }
    }
    
    // Theme settings
    public struct Theme: Codable {
        public let mode: ThemeMode
        public let style: VisualStyle
        
        public init(mode: ThemeMode = .dark, style: VisualStyle = .modern) {
            self.mode = mode
            self.style = style
        }
    }
    
    // Color settings
    public struct Colors: Codable {
        public let primary: HCTColor
        public let secondary: HCTColor?
        public let tertiary: HCTColor?
        public let scheme: ColorScheme
        
        public init(primary: HCTColor, secondary: HCTColor? = nil, tertiary: HCTColor? = nil, scheme: ColorScheme = .complementary) {
            self.primary = primary
            self.secondary = secondary
            self.tertiary = tertiary
            self.scheme = scheme
        }
    }
    
    // Texture settings
    public struct Textures: Codable {
        public let background: TextureConfig?
        public let overlay: TextureConfig?
        public let accent: TextureConfig?
        
        public init(background: TextureConfig? = nil, overlay: TextureConfig? = nil, accent: TextureConfig? = nil) {
            self.background = background
            self.overlay = overlay
            self.accent = accent
        }
    }
    
    // Component settings
    public struct Components: Codable {
        public let buttonStyle: ButtonStyle
        public let sliderStyle: SliderStyle
        public let cornerRadius: Double
        public let borderWidth: Double
        public let shadowSize: Double
        
        public init(
            buttonStyle: ButtonStyle = .rounded,
            sliderStyle: SliderStyle = .modern,
            cornerRadius: Double = 4.0,
            borderWidth: Double = 1.0,
            shadowSize: Double = 2.0
        ) {
            self.buttonStyle = buttonStyle
            self.sliderStyle = sliderStyle
            self.cornerRadius = cornerRadius
            self.borderWidth = borderWidth
            self.shadowSize = shadowSize
        }
    }
    
    public let metadata: Metadata
    public let theme: Theme
    public let colors: Colors
    public let textures: Textures
    public let components: Components
    
    public init(
        metadata: Metadata,
        theme: Theme = Theme(),
        colors: Colors,
        textures: Textures = Textures(),
        components: Components = Components()
    ) {
        self.metadata = metadata
        self.theme = theme
        self.colors = colors
        self.textures = textures
        self.components = components
    }
}

// MARK: - Generation Results

/// Result of skin generation process
public struct GeneratedSkin {
    public let config: SkinGenerationConfig
    public let palette: GeneratedPalette
    public let sprites: [SpriteType: CGImage]
    public let metadata: [String: String]
    public let timestamp: Date
    
    public init(
        config: SkinGenerationConfig,
        palette: GeneratedPalette,
        sprites: [SpriteType: CGImage],
        metadata: [String: String] = [:]
    ) {
        self.config = config
        self.palette = palette
        self.sprites = sprites
        self.metadata = metadata
        self.timestamp = Date()
    }
}

// MARK: - Extensions

extension HCTColor {
    /// Convert HCT to CGColor
    public func toCGColor() -> CGColor {
        // This is a simplified conversion - in real implementation, use proper CAM16/HCT conversion
        let rgb = hctToRGB()
        return CGColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1.0)
    }
    
    /// Simplified HCT to RGB conversion (placeholder - implement proper algorithm)
    private func hctToRGB() -> (r: Double, g: Double, b: Double) {
        // This is a simplified HSL-like conversion for now
        // TODO: Implement proper HCT/CAM16 conversion
        let c = chroma * tone
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = tone - c
        
        var r: Double, g: Double, b: Double
        
        switch hue {
        case 0..<60:
            (r, g, b) = (c, x, 0)
        case 60..<120:
            (r, g, b) = (x, c, 0)
        case 120..<180:
            (r, g, b) = (0, c, x)
        case 180..<240:
            (r, g, b) = (0, x, c)
        case 240..<300:
            (r, g, b) = (x, 0, c)
        default:
            (r, g, b) = (c, 0, x)
        }
        
        return (r + m, g + m, b + m)
    }
}