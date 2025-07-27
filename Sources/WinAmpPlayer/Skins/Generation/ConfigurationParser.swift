//
//  ConfigurationParser.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  TOML configuration parser for skin generation
//

import Foundation

/// Parser for skin generation configuration files
public class ConfigurationParser {
    
    /// Parse errors
    public enum ParseError: LocalizedError {
        case fileNotFound(URL)
        case invalidFormat(String)
        case missingRequiredField(String)
        case invalidValue(field: String, value: String)
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let url):
                return "Configuration file not found: \(url.lastPathComponent)"
            case .invalidFormat(let message):
                return "Invalid configuration format: \(message)"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            case .invalidValue(let field, let value):
                return "Invalid value '\(value)' for field '\(field)'"
            }
        }
    }
    
    /// Parse configuration from TOML file
    public static func parse(from url: URL) throws -> SkinGenerationConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParseError.fileNotFound(url)
        }
        
        let data = try Data(contentsOf: url)
        return try parse(from: data)
    }
    
    /// Parse configuration from TOML string
    public static func parse(from string: String) throws -> SkinGenerationConfig {
        guard let data = string.data(using: .utf8) else {
            throw ParseError.invalidFormat("Invalid UTF-8 string")
        }
        return try parse(from: data)
    }
    
    /// Parse configuration from data
    public static func parse(from data: Data) throws -> SkinGenerationConfig {
        // For now, we'll use a simple manual parser
        // In production, use a proper TOML library
        guard let string = String(data: data, encoding: .utf8) else {
            throw ParseError.invalidFormat("Invalid UTF-8 data")
        }
        
        let lines = string.components(separatedBy: .newlines)
        var currentSection = ""
        var values: [String: [String: Any]] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                if values[currentSection] == nil {
                    values[currentSection] = [:]
                }
                continue
            }
            
            // Key-value pair
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = trimmed[..<equalIndex].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: equalIndex)...].trimmingCharacters(in: .whitespaces)
                
                if var section = values[currentSection] {
                    section[key] = parseValue(value)
                    values[currentSection] = section
                }
            }
        }
        
        // Build configuration from parsed values
        return try buildConfiguration(from: values)
    }
    
    /// Parse a TOML value
    private static func parseValue(_ value: String) -> Any {
        // Remove quotes if present
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        
        // Parse boolean
        if value == "true" { return true }
        if value == "false" { return false }
        
        // Parse number
        if let int = Int(value) { return int }
        if let double = Double(value) { return double }
        
        // Parse inline table
        if value.hasPrefix("{") && value.hasSuffix("}") {
            return parseInlineTable(String(value.dropFirst().dropLast()))
        }
        
        return value
    }
    
    /// Parse inline TOML table
    private static func parseInlineTable(_ content: String) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Simple parser for inline tables like { hue = 210, chroma = 0.8 }
        let pairs = content.split(separator: ",")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                result[key] = parseValue(value)
            }
        }
        
        return result
    }
    
    /// Build configuration from parsed values
    private static func buildConfiguration(from values: [String: [String: Any]]) throws -> SkinGenerationConfig {
        // Metadata
        let metadata = try parseMetadata(values["metadata"] ?? [:])
        
        // Theme
        let theme = parseTheme(values["theme"] ?? [:])
        
        // Colors
        let colors = try parseColors(values["colors"] ?? [:])
        
        // Textures
        let textures = parseTextures(values["textures"] ?? [:])
        
        // Components
        let components = parseComponents(values["components"] ?? [:])
        
        return SkinGenerationConfig(
            metadata: metadata,
            theme: theme,
            colors: colors,
            textures: textures,
            components: components
        )
    }
    
    /// Parse metadata section
    private static func parseMetadata(_ section: [String: Any]) throws -> SkinGenerationConfig.Metadata {
        guard let name = section["name"] as? String else {
            throw ParseError.missingRequiredField("metadata.name")
        }
        
        return SkinGenerationConfig.Metadata(
            name: name,
            author: section["author"] as? String ?? "WinAmp Generator",
            version: section["version"] as? String ?? "1.0",
            description: section["description"] as? String
        )
    }
    
    /// Parse theme section
    private static func parseTheme(_ section: [String: Any]) -> SkinGenerationConfig.Theme {
        let mode = ThemeMode(rawValue: section["mode"] as? String ?? "") ?? .dark
        let style = VisualStyle(rawValue: section["style"] as? String ?? "") ?? .modern
        
        return SkinGenerationConfig.Theme(mode: mode, style: style)
    }
    
    /// Parse colors section
    private static func parseColors(_ section: [String: Any]) throws -> SkinGenerationConfig.Colors {
        guard let primaryDict = section["primary"] as? [String: Any] else {
            throw ParseError.missingRequiredField("colors.primary")
        }
        
        let primary = try parseHCTColor(primaryDict)
        let secondary = (section["secondary"] as? [String: Any]).flatMap { try? parseHCTColor($0) }
        let tertiary = (section["tertiary"] as? [String: Any]).flatMap { try? parseHCTColor($0) }
        let scheme = ColorScheme(rawValue: section["scheme"] as? String ?? "") ?? .complementary
        
        return SkinGenerationConfig.Colors(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            scheme: scheme
        )
    }
    
    /// Parse HCT color
    private static func parseHCTColor(_ dict: [String: Any]) throws -> HCTColor {
        guard let hue = dict["hue"] as? Double else {
            throw ParseError.missingRequiredField("color.hue")
        }
        
        let chroma = dict["chroma"] as? Double ?? 0.5
        let tone = dict["tone"] as? Double ?? 0.5
        
        return HCTColor(hue: hue, chroma: chroma, tone: tone)
    }
    
    /// Parse textures section
    private static func parseTextures(_ section: [String: Any]) -> SkinGenerationConfig.Textures {
        let background = (section["background"] as? [String: Any]).flatMap { parseTextureConfig($0) }
        let overlay = (section["overlay"] as? [String: Any]).flatMap { parseTextureConfig($0) }
        let accent = (section["accent"] as? [String: Any]).flatMap { parseTextureConfig($0) }
        
        return SkinGenerationConfig.Textures(
            background: background,
            overlay: overlay,
            accent: accent
        )
    }
    
    /// Parse texture configuration
    private static func parseTextureConfig(_ dict: [String: Any]) -> TextureConfig? {
        guard let typeString = dict["type"] as? String,
              let type = TextureType(rawValue: typeString) else {
            return nil
        }
        
        return TextureConfig(
            type: type,
            scale: dict["scale"] as? Double ?? 1.0,
            octaves: dict["octaves"] as? Int,
            persistence: dict["persistence"] as? Double,
            opacity: dict["opacity"] as? Double ?? 1.0,
            blendMode: dict["blend_mode"] as? String
        )
    }
    
    /// Parse components section
    private static func parseComponents(_ section: [String: Any]) -> SkinGenerationConfig.Components {
        let buttonStyle = ButtonStyle(rawValue: section["button_style"] as? String ?? "") ?? .rounded
        let sliderStyle = SliderStyle(rawValue: section["slider_style"] as? String ?? "") ?? .modern
        
        return SkinGenerationConfig.Components(
            buttonStyle: buttonStyle,
            sliderStyle: sliderStyle,
            cornerRadius: section["corner_radius"] as? Double ?? 4.0,
            borderWidth: section["border_width"] as? Double ?? 1.0,
            shadowSize: section["shadow_size"] as? Double ?? 2.0
        )
    }
}

// MARK: - Default Templates

extension ConfigurationParser {
    
    /// Get default template configurations
    public static func defaultTemplates() -> [String: String] {
        return [
            "modern_dark": modernDarkTemplate,
            "retro": retroTemplate,
            "minimal": minimalTemplate,
            "cyberpunk": cyberpunkTemplate,
            "vaporwave": vaporwaveTemplate
        ]
    }
    
    private static let modernDarkTemplate = """
    [metadata]
    name = "Modern Dark"
    author = "WinAmp Generator"
    version = "1.0"
    description = "A modern dark theme with subtle gradients"
    
    [theme]
    mode = "dark"
    style = "modern"
    
    [colors]
    primary = { hue = 210, chroma = 0.8, tone = 0.5 }
    secondary = { hue = 30, chroma = 0.6, tone = 0.6 }
    scheme = "complementary"
    
    [textures]
    background = { type = "gradient", scale = 1.0, opacity = 0.8 }
    overlay = { type = "noise", scale = 0.5, octaves = 3, opacity = 0.1 }
    
    [components]
    button_style = "rounded"
    slider_style = "modern"
    corner_radius = 4.0
    shadow_size = 3.0
    """
    
    private static let retroTemplate = """
    [metadata]
    name = "Retro Wave"
    author = "WinAmp Generator"
    version = "1.0"
    description = "Classic 90s style with beveled buttons"
    
    [theme]
    mode = "light"
    style = "retro"
    
    [colors]
    primary = { hue = 180, chroma = 0.3, tone = 0.6 }
    secondary = { hue = 0, chroma = 0, tone = 0.5 }
    scheme = "monochromatic"
    
    [textures]
    background = { type = "solid", opacity = 1.0 }
    
    [components]
    button_style = "beveled"
    slider_style = "classic"
    corner_radius = 0.0
    border_width = 2.0
    shadow_size = 0.0
    """
    
    private static let minimalTemplate = """
    [metadata]
    name = "Minimal"
    author = "WinAmp Generator"
    version = "1.0"
    
    [theme]
    mode = "light"
    style = "minimal"
    
    [colors]
    primary = { hue = 0, chroma = 0, tone = 0.2 }
    scheme = "monochromatic"
    
    [textures]
    background = { type = "solid" }
    
    [components]
    button_style = "flat"
    slider_style = "minimal"
    corner_radius = 0.0
    border_width = 0.0
    shadow_size = 0.0
    """
    
    private static let cyberpunkTemplate = """
    [metadata]
    name = "Cyberpunk 2077"
    author = "WinAmp Generator"
    version = "1.0"
    description = "Neon-soaked night city vibes"
    
    [theme]
    mode = "dark"
    style = "cyberpunk"
    
    [colors]
    primary = { hue = 300, chroma = 1.0, tone = 0.5 }
    secondary = { hue = 180, chroma = 1.0, tone = 0.4 }
    tertiary = { hue = 60, chroma = 0.8, tone = 0.6 }
    scheme = "triadic"
    
    [textures]
    background = { type = "circuit", scale = 2.0, opacity = 0.3 }
    overlay = { type = "lines", scale = 1.0, opacity = 0.2 }
    
    [components]
    button_style = "glass"
    slider_style = "modern"
    corner_radius = 2.0
    shadow_size = 5.0
    """
    
    private static let vaporwaveTemplate = """
    [metadata]
    name = "Vaporwave Aesthetic"
    author = "WinAmp Generator"
    version = "1.0"
    description = "A E S T H E T I C"
    
    [theme]
    mode = "dark"
    style = "vaporwave"
    
    [colors]
    primary = { hue = 280, chroma = 0.7, tone = 0.6 }
    secondary = { hue = 180, chroma = 0.5, tone = 0.7 }
    tertiary = { hue = 330, chroma = 0.6, tone = 0.8 }
    scheme = "analogous"
    
    [textures]
    background = { type = "gradient", scale = 1.0, opacity = 1.0 }
    overlay = { type = "checkerboard", scale = 0.1, opacity = 0.05 }
    accent = { type = "waves", scale = 3.0, opacity = 0.2 }
    
    [components]
    button_style = "pill"
    slider_style = "rail"
    corner_radius = 20.0
    border_width = 0.0
    shadow_size = 8.0
    """
}