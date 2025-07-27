//
//  PaletteGenerator.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Color palette generation using HCT color space and color theory
//

import Foundation
import CoreGraphics

/// Generates color palettes for skin themes
public class PaletteGenerator {
    
    /// WCAG contrast levels
    public enum ContrastLevel: Double {
        case aa = 4.5      // Normal text
        case aaLarge = 3.0 // Large text
        case aaa = 7.0     // Enhanced contrast
    }
    
    /// Generate a complete palette from configuration
    public static func generatePalette(from config: SkinGenerationConfig) -> GeneratedPalette {
        let primaryColor = config.colors.primary
        
        // Generate color scheme based on configuration
        let scheme = generateColorScheme(
            primary: primaryColor,
            secondary: config.colors.secondary,
            tertiary: config.colors.tertiary,
            scheme: config.colors.scheme
        )
        
        // Adjust for theme mode
        let adjustedScheme = adjustForThemeMode(scheme, mode: config.theme.mode)
        
        // Generate tonal palettes
        let primary = TonalPalette(baseColor: adjustedScheme.primary)
        let secondary = TonalPalette(baseColor: adjustedScheme.secondary)
        let tertiary = TonalPalette(baseColor: adjustedScheme.tertiary)
        
        // Generate neutral palette based on primary hue
        let neutral = generateNeutralPalette(from: adjustedScheme.primary)
        
        // Error color (red-based)
        let error = TonalPalette(baseColor: HCTColor(hue: 0, chroma: 0.8, tone: 0.5))
        
        return GeneratedPalette(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            neutral: neutral,
            error: error
        )
    }
    
    /// Generate color scheme based on color theory
    private static func generateColorScheme(
        primary: HCTColor,
        secondary: HCTColor?,
        tertiary: HCTColor?,
        scheme: ColorScheme
    ) -> (primary: HCTColor, secondary: HCTColor, tertiary: HCTColor) {
        
        let primaryHue = primary.hue
        
        switch scheme {
        case .monochromatic:
            // Use different chroma/tone values of same hue
            return (
                primary: primary,
                secondary: HCTColor(hue: primaryHue, chroma: primary.chroma * 0.6, tone: primary.tone * 0.8),
                tertiary: HCTColor(hue: primaryHue, chroma: primary.chroma * 0.3, tone: primary.tone * 1.2)
            )
            
        case .complementary:
            // Opposite on color wheel
            let secondaryHue = (primaryHue + 180).truncatingRemainder(dividingBy: 360)
            return (
                primary: primary,
                secondary: secondary ?? HCTColor(hue: secondaryHue, chroma: primary.chroma * 0.8, tone: primary.tone),
                tertiary: tertiary ?? HCTColor(hue: primaryHue + 30, chroma: primary.chroma * 0.5, tone: primary.tone * 0.9)
            )
            
        case .analogous:
            // Adjacent colors (±30°)
            let secondaryHue = (primaryHue + 30).truncatingRemainder(dividingBy: 360)
            let tertiaryHue = (primaryHue - 30 + 360).truncatingRemainder(dividingBy: 360)
            return (
                primary: primary,
                secondary: secondary ?? HCTColor(hue: secondaryHue, chroma: primary.chroma, tone: primary.tone),
                tertiary: tertiary ?? HCTColor(hue: tertiaryHue, chroma: primary.chroma * 0.8, tone: primary.tone * 0.9)
            )
            
        case .triadic:
            // Three equidistant colors (120° apart)
            let secondaryHue = (primaryHue + 120).truncatingRemainder(dividingBy: 360)
            let tertiaryHue = (primaryHue + 240).truncatingRemainder(dividingBy: 360)
            return (
                primary: primary,
                secondary: secondary ?? HCTColor(hue: secondaryHue, chroma: primary.chroma * 0.9, tone: primary.tone),
                tertiary: tertiary ?? HCTColor(hue: tertiaryHue, chroma: primary.chroma * 0.8, tone: primary.tone)
            )
            
        case .splitComplementary:
            // Complement's adjacent colors
            let baseComplement = (primaryHue + 180).truncatingRemainder(dividingBy: 360)
            let secondaryHue = (baseComplement + 30).truncatingRemainder(dividingBy: 360)
            let tertiaryHue = (baseComplement - 30 + 360).truncatingRemainder(dividingBy: 360)
            return (
                primary: primary,
                secondary: secondary ?? HCTColor(hue: secondaryHue, chroma: primary.chroma * 0.8, tone: primary.tone),
                tertiary: tertiary ?? HCTColor(hue: tertiaryHue, chroma: primary.chroma * 0.7, tone: primary.tone * 0.9)
            )
            
        case .tetradic:
            // Four colors forming a rectangle
            let secondaryHue = (primaryHue + 90).truncatingRemainder(dividingBy: 360)
            let tertiaryHue = (primaryHue + 180).truncatingRemainder(dividingBy: 360)
            return (
                primary: primary,
                secondary: secondary ?? HCTColor(hue: secondaryHue, chroma: primary.chroma * 0.8, tone: primary.tone),
                tertiary: tertiary ?? HCTColor(hue: tertiaryHue, chroma: primary.chroma * 0.7, tone: primary.tone * 0.9)
            )
        }
    }
    
    /// Adjust colors for theme mode
    private static func adjustForThemeMode(
        _ colors: (primary: HCTColor, secondary: HCTColor, tertiary: HCTColor),
        mode: ThemeMode
    ) -> (primary: HCTColor, secondary: HCTColor, tertiary: HCTColor) {
        
        switch mode {
        case .dark:
            // Ensure sufficient contrast for dark themes
            return (
                primary: adjustForDarkTheme(colors.primary),
                secondary: adjustForDarkTheme(colors.secondary),
                tertiary: adjustForDarkTheme(colors.tertiary)
            )
            
        case .light:
            // Ensure sufficient contrast for light themes
            return (
                primary: adjustForLightTheme(colors.primary),
                secondary: adjustForLightTheme(colors.secondary),
                tertiary: adjustForLightTheme(colors.tertiary)
            )
            
        case .auto:
            // Return as-is, will be adjusted at runtime
            return colors
        }
    }
    
    /// Adjust color for dark theme
    private static func adjustForDarkTheme(_ color: HCTColor) -> HCTColor {
        // Increase chroma slightly and adjust tone for better visibility on dark backgrounds
        let adjustedChroma = min(1.0, color.chroma * 1.1)
        let adjustedTone = color.tone // Keep tone as-is for flexibility
        
        return HCTColor(hue: color.hue, chroma: adjustedChroma, tone: adjustedTone)
    }
    
    /// Adjust color for light theme
    private static func adjustForLightTheme(_ color: HCTColor) -> HCTColor {
        // Reduce chroma slightly and adjust tone for better visibility on light backgrounds
        let adjustedChroma = color.chroma * 0.9
        let adjustedTone = color.tone // Keep tone as-is for flexibility
        
        return HCTColor(hue: color.hue, chroma: adjustedChroma, tone: adjustedTone)
    }
    
    /// Generate neutral palette based on primary hue
    private static func generateNeutralPalette(from primary: HCTColor) -> TonalPalette {
        // Neutrals have very low chroma but can have a slight tint from primary
        let neutralHue = primary.hue
        let neutralChroma = 0.02 // Very low chroma for neutrals
        
        let neutral = HCTColor(hue: neutralHue, chroma: neutralChroma, tone: 0.5)
        return TonalPalette(baseColor: neutral)
    }
    
    /// Calculate contrast ratio between two colors
    public static func contrastRatio(between color1: CGColor, color2: CGColor) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Calculate relative luminance of a color
    private static func relativeLuminance(of color: CGColor) -> Double {
        guard let components = color.components,
              components.count >= 3 else { return 0 }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Convert to linear RGB
        let linearR = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let linearG = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let linearB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        // Calculate luminance
        return 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB
    }
    
    /// Check if two colors meet contrast requirements
    public static func meetsContrastRequirement(
        foreground: CGColor,
        background: CGColor,
        level: ContrastLevel
    ) -> Bool {
        let ratio = contrastRatio(between: foreground, color2: background)
        return ratio >= level.rawValue
    }
    
    /// Find best tone level for sufficient contrast
    public static func findContrastingTone(
        for palette: TonalPalette,
        against background: CGColor,
        minimumContrast: ContrastLevel
    ) -> Int? {
        let toneLevels = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100]
        
        for level in toneLevels {
            let color = palette.tone(level)
            if meetsContrastRequirement(
                foreground: color,
                background: background,
                level: minimumContrast
            ) {
                return level
            }
        }
        
        return nil
    }
}

// MARK: - Color Harmony Utilities

extension PaletteGenerator {
    
    /// Generate a set of harmonious colors for visualization
    public static func generateVisualizationColors(from palette: GeneratedPalette) -> [CGColor] {
        return [
            palette.primary.tone(60),
            palette.primary.tone(70),
            palette.primary.tone(80),
            palette.secondary.tone(60),
            palette.secondary.tone(70),
            palette.tertiary.tone(60),
            palette.tertiary.tone(70),
            palette.primary.tone(50),
            palette.secondary.tone(50),
            palette.tertiary.tone(50),
            palette.primary.tone(90),
            palette.secondary.tone(90),
            palette.tertiary.tone(90),
            palette.neutral.tone(60),
            palette.neutral.tone(80),
            palette.error.tone(60),
            palette.primary.tone(40),
            palette.secondary.tone(40)
        ]
    }
    
    /// Generate playlist editor colors
    public static func generatePlaylistColors(from palette: GeneratedPalette, isDark: Bool) -> GeneratedPlaylistColors {
        let background = isDark ? palette.neutral.tone(10) : palette.neutral.tone(95)
        let normalText = isDark ? palette.neutral.tone(90) : palette.neutral.tone(10)
        let selectedBg = palette.primary.tone(isDark ? 30 : 90)
        
        return GeneratedPlaylistColors(
            background: background,
            normalText: normalText,
            normalTextBackground: background,
            selectedText: palette.primary.tone(isDark ? 90 : 10),
            selectedTextBackground: selectedBg,
            currentText: normalText,
            currentTextBackground: palette.primary.tone(isDark ? 20 : 95)
        )
    }
}

/// Generated playlist color configuration
public struct GeneratedPlaylistColors {
    public let background: CGColor
    public let normalText: CGColor
    public let normalTextBackground: CGColor
    public let selectedText: CGColor
    public let selectedTextBackground: CGColor
    public let currentText: CGColor
    public let currentTextBackground: CGColor
}