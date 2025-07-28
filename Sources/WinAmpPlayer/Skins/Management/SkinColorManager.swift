//
//  SkinColorManager.swift
//  WinAmpPlayer
//
//  Manages color extraction and application from loaded skins
//

import Foundation
import SwiftUI
import AppKit

/// Manages colors extracted from skins for consistent text rendering
public class SkinColorManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var mainTextColor: Color = WinAmpColors.text
    @Published public var lcdTextColor: Color = WinAmpColors.lcdText
    @Published public var lcdBackgroundColor: Color = WinAmpColors.lcdBackground
    @Published public var timeDisplayColor: Color = WinAmpColors.lcdText
    @Published public var songTitleColor: Color = WinAmpColors.text
    
    // Playlist colors
    @Published public var playlistTextColor: Color = WinAmpColors.playlistText
    @Published public var playlistPlayingColor: Color = WinAmpColors.playlistPlaying
    @Published public var playlistSelectedColor: Color = WinAmpColors.playlistSelected
    @Published public var playlistBackgroundColor: Color = WinAmpColors.playlistBackground
    
    // EQ colors
    @Published public var eqTextColor: Color = WinAmpColors.text
    @Published public var eqLabelColor: Color = WinAmpColors.textDim
    
    // MARK: - Private Properties
    
    private var currentSkin: CachedSkin?
    private var playlistConfig: PlaylistConfig?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Update colors based on loaded skin
    public func updateColors(from skin: CachedSkin) {
        currentSkin = skin
        
        // Extract playlist colors from config if available
        if let config = skin.playlistConfig {
            applyPlaylistConfig(config)
        }
        
        // Extract colors from bitmaps
        extractColorsFromBitmaps(skin)
        
        // Apply intelligent defaults based on skin brightness
        applyIntelligentDefaults(skin)
    }
    
    /// Reset to default WinAmp colors
    public func resetToDefaults() {
        mainTextColor = WinAmpColors.text
        lcdTextColor = WinAmpColors.lcdText
        lcdBackgroundColor = WinAmpColors.lcdBackground
        timeDisplayColor = WinAmpColors.lcdText
        songTitleColor = WinAmpColors.text
        
        playlistTextColor = WinAmpColors.playlistText
        playlistPlayingColor = WinAmpColors.playlistPlaying
        playlistSelectedColor = WinAmpColors.playlistSelected
        playlistBackgroundColor = WinAmpColors.playlistBackground
        
        eqTextColor = WinAmpColors.text
        eqLabelColor = WinAmpColors.textDim
    }
    
    // MARK: - Private Methods
    
    private func applyPlaylistConfig(_ config: PlaylistConfig) {
        // Convert NSColor to SwiftUI Color
        playlistTextColor = Color(config.normalText)
        playlistPlayingColor = Color(config.currentText)
        
        playlistSelectedColor = Color(config.selectedBackground)
        playlistBackgroundColor = Color(config.normalBackground)
    }
    
    private func extractColorsFromBitmaps(_ skin: CachedSkin) {
        // Extract LCD colors from main.bmp
        if let mainBitmap = skin.getSprite(.main) {
            // Sample LCD area for text color (around time display area)
            if let lcdColor = sampleColor(from: mainBitmap, at: CGPoint(x: 50, y: 26)) {
                lcdTextColor = Color(lcdColor)
                timeDisplayColor = Color(lcdColor)
            }
            
            // Sample song display area
            if let songColor = sampleColor(from: mainBitmap, at: CGPoint(x: 110, y: 23)) {
                songTitleColor = Color(songColor)
            }
        }
        
        // Extract text color from text.bmp
        if let textBitmap = skin.getSprite(.text) {
            // Sample a non-transparent pixel from the font
            if let textColor = sampleNonTransparentColor(from: textBitmap) {
                mainTextColor = Color(textColor)
            }
        }
        
        // Extract EQ text colors from eq_main.bmp
        if let eqBitmap = skin.getSprite(.eqMain) {
            // Sample frequency label area
            if let eqColor = sampleColor(from: eqBitmap, at: CGPoint(x: 50, y: 100)) {
                eqTextColor = Color(eqColor)
                eqLabelColor = Color(eqColor.withAlphaComponent(0.7))
            }
        }
    }
    
    private func applyIntelligentDefaults(_ skin: CachedSkin) {
        // Analyze overall skin brightness
        if let mainBitmap = skin.getSprite(.main) {
            let brightness = calculateAverageBrightness(of: mainBitmap)
            
            // If skin is dark, ensure text is light
            if brightness < 0.3 {
                ensureMinimumContrast(backgroundColor: brightness, isDark: true)
            }
            // If skin is light, ensure text is dark
            else if brightness > 0.7 {
                ensureMinimumContrast(backgroundColor: brightness, isDark: false)
            }
        }
    }
    
    private func sampleColor(from image: NSImage, at point: CGPoint) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else { return nil }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let x = Int(point.x)
        let y = Int(point.y)
        
        guard x >= 0 && x < cgImage.width && y >= 0 && y < cgImage.height else { return nil }
        
        let pixelData = CFDataGetBytePtr(data)
        let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
        
        let r = CGFloat(pixelData?[pixelIndex] ?? 0) / 255.0
        let g = CGFloat(pixelData?[pixelIndex + 1] ?? 0) / 255.0
        let b = CGFloat(pixelData?[pixelIndex + 2] ?? 0) / 255.0
        
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    private func sampleNonTransparentColor(from image: NSImage) -> NSColor? {
        // Sample multiple points to find a non-transparent pixel
        let samplePoints = [
            CGPoint(x: 10, y: 3),
            CGPoint(x: 20, y: 3),
            CGPoint(x: 30, y: 3),
            CGPoint(x: 15, y: 3)
        ]
        
        for point in samplePoints {
            if let color = sampleColor(from: image, at: point),
               !isTransparencyColor(color) {
                return color
            }
        }
        
        return nil
    }
    
    private func isTransparencyColor(_ color: NSColor) -> Bool {
        // Check if color is magenta (transparency color)
        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent
        
        return r > 0.9 && g < 0.1 && b > 0.9
    }
    
    private func calculateAverageBrightness(of image: NSImage) -> CGFloat {
        // Sample a grid of points to determine overall brightness
        var totalBrightness: CGFloat = 0
        var sampleCount = 0
        
        let sampleStep = 20
        for x in stride(from: 0, to: Int(image.size.width), by: sampleStep) {
            for y in stride(from: 0, to: Int(image.size.height), by: sampleStep) {
                if let color = sampleColor(from: image, at: CGPoint(x: x, y: y)) {
                    let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3.0
                    totalBrightness += brightness
                    sampleCount += 1
                }
            }
        }
        
        return sampleCount > 0 ? totalBrightness / CGFloat(sampleCount) : 0.5
    }
    
    private func ensureMinimumContrast(backgroundColor: CGFloat, isDark: Bool) {
        // Ensure text colors have sufficient contrast against background
        if isDark {
            // Ensure text colors are bright enough
            if lcdTextColor.brightness < 0.6 {
                lcdTextColor = Color(red: 0.0, green: 1.0, blue: 0.0) // Classic green
            }
            if mainTextColor.brightness < 0.6 {
                mainTextColor = Color(red: 0.8, green: 0.8, blue: 0.8)
            }
        } else {
            // Ensure text colors are dark enough
            if lcdTextColor.brightness > 0.4 {
                lcdTextColor = Color(red: 0.0, green: 0.3, blue: 0.0) // Dark green
            }
            if mainTextColor.brightness > 0.4 {
                mainTextColor = Color(red: 0.2, green: 0.2, blue: 0.2)
            }
        }
    }
    
    private func rgbToColor(_ rgb: (r: Int, g: Int, b: Int)) -> Color {
        Color(
            red: Double(rgb.r) / 255.0,
            green: Double(rgb.g) / 255.0,
            blue: Double(rgb.b) / 255.0
        )
    }
}

// MARK: - Color Extensions

extension Color {
    var brightness: CGFloat {
        let nsColor = NSColor(self)
        let r = nsColor.redComponent
        let g = nsColor.greenComponent
        let b = nsColor.blueComponent
        return (r + g + b) / 3.0
    }
}