//
//  SkinConfiguration.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Configuration data for WinAmp skins
//

import Foundation
import AppKit

/// Complete skin configuration
public struct SkinConfiguration {
    public let playlistColors: PlaylistColors
    public let visualizationColors: [NSColor]
    public let buttonRegions: [String: ButtonRegion]
    public let fontName: String?
    
    /// Default configuration
    public static let defaultConfiguration = SkinConfiguration(
        playlistColors: PlaylistColors.default,
        visualizationColors: VisualizationColors.defaultColors,
        buttonRegions: [:],
        fontName: nil
    )
}

/// Playlist color configuration
public struct PlaylistColors {
    public let normalText: NSColor
    public let currentText: NSColor
    public let normalBackground: NSColor
    public let selectedBackground: NSColor
    public let focusRectangle: NSColor
    
    /// Default playlist colors
    public static let `default` = PlaylistColors(
        normalText: NSColor(WinAmpColors.text),
        currentText: NSColor(WinAmpColors.textHighlight),
        normalBackground: NSColor(WinAmpColors.background),
        selectedBackground: NSColor(WinAmpColors.selection),
        focusRectangle: NSColor(WinAmpColors.accent)
    )
}

/// Visualization color configuration
extension VisualizationColors {
    /// Default visualization colors
    public static let defaultColors: [NSColor] = [
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),    // Black
        NSColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0),    // Dark Blue
        NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0),    // Blue
        NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0),    // Light Blue
        NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0),    // Cyan
        NSColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0),    // Cyan-Green
        NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),    // Green
        NSColor(red: 0.5, green: 1.0, blue: 0.0, alpha: 1.0),    // Yellow-Green
        NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0),    // Yellow
        NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),    // Orange
        NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),    // Red
        NSColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0),    // Dark Red
        NSColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0),    // Purple
        NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0),    // Magenta
        NSColor(red: 1.0, green: 0.5, blue: 1.0, alpha: 1.0),    // Pink
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),    // White
    ]
}