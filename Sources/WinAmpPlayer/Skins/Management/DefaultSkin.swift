//
//  DefaultSkin.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Default skin implementation when no skin file is available
//

import Foundation
import AppKit
import SwiftUI

/// Default skin provider
public class DefaultSkin {
    public static let shared = DefaultSkin()
    
    private var sprites: [SpriteType: NSImage] = [:]
    
    private init() {}
    
    /// Preload default skin sprites
    public func preload() {
        generateDefaultSprites()
    }
    
    /// Get default sprite
    public func getSprite(_ type: SpriteType) -> NSImage? {
        if sprites.isEmpty {
            generateDefaultSprites()
        }
        return sprites[type]
    }
    
    /// Generate default sprites programmatically
    private func generateDefaultSprites() {
        // Main window background
        sprites[.mainBackground] = createGradientImage(
            size: CGSize(width: 275, height: 116),
            startColor: WinAmpColors.background,
            endColor: WinAmpColors.backgroundDark
        )
        
        // Title bars
        sprites[.titleBarActive] = createGradientImage(
            size: CGSize(width: 275, height: 14),
            startColor: WinAmpColors.accent,
            endColor: WinAmpColors.accentDark
        )
        
        sprites[.titleBarInactive] = createGradientImage(
            size: CGSize(width: 275, height: 14),
            startColor: WinAmpColors.backgroundLight,
            endColor: WinAmpColors.background
        )
        
        // Transport buttons
        createTransportButtons()
        
        // Window buttons
        createWindowButtons()
        
        // Toggle buttons
        createToggleButtons()
        
        // Sliders
        createSliders()
        
        // Numbers
        createNumberSprites()
        
        // Indicators
        createIndicators()
    }
    
    /// Create transport control buttons
    private func createTransportButtons() {
        let buttonSize = CGSize(width: 23, height: 18)
        
        // Previous button
        sprites[.previousButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "◀◀",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.previousButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "◀◀",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Play button
        sprites[.playButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "▶",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.playButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "▶",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Pause button
        sprites[.pauseButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "❚❚",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.pauseButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "❚❚",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Stop button
        sprites[.stopButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "■",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.stopButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "■",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Next button
        sprites[.nextButton(.normal)] = createButtonImage(
            size: CGSize(width: 22, height: 18),
            symbol: "▶▶",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.nextButton(.pressed)] = createButtonImage(
            size: CGSize(width: 22, height: 18),
            symbol: "▶▶",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Eject button
        sprites[.ejectButton(.normal)] = createButtonImage(
            size: CGSize(width: 22, height: 16),
            symbol: "⏏",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.ejectButton(.pressed)] = createButtonImage(
            size: CGSize(width: 22, height: 16),
            symbol: "⏏",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
    }
    
    /// Create window control buttons
    private func createWindowButtons() {
        let buttonSize = CGSize(width: 9, height: 9)
        
        // Close button
        sprites[.closeButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "×",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.closeButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "×",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Minimize button
        sprites[.minimizeButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "_",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.minimizeButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "_",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
        
        // Shade button
        sprites[.shadeButton(.normal)] = createButtonImage(
            size: buttonSize,
            symbol: "▬",
            backgroundColor: WinAmpColors.buttonNormal,
            foregroundColor: WinAmpColors.text
        )
        sprites[.shadeButton(.pressed)] = createButtonImage(
            size: buttonSize,
            symbol: "▬",
            backgroundColor: WinAmpColors.buttonPressed,
            foregroundColor: WinAmpColors.textHighlight
        )
    }
    
    /// Create toggle buttons
    private func createToggleButtons() {
        let shuffleSize = CGSize(width: 47, height: 15)
        let repeatSize = CGSize(width: 28, height: 15)
        let windowButtonSize = CGSize(width: 23, height: 12)
        
        // Shuffle buttons
        sprites[.shuffleButton(false, .normal)] = createToggleButton(
            size: shuffleSize,
            text: "SHUFFLE",
            isOn: false,
            isPressed: false
        )
        sprites[.shuffleButton(false, .pressed)] = createToggleButton(
            size: shuffleSize,
            text: "SHUFFLE",
            isOn: false,
            isPressed: true
        )
        sprites[.shuffleButton(true, .normal)] = createToggleButton(
            size: shuffleSize,
            text: "SHUFFLE",
            isOn: true,
            isPressed: false
        )
        sprites[.shuffleButton(true, .pressed)] = createToggleButton(
            size: shuffleSize,
            text: "SHUFFLE",
            isOn: true,
            isPressed: true
        )
        
        // Repeat buttons
        sprites[.repeatButton(false, .normal)] = createToggleButton(
            size: repeatSize,
            text: "REPEAT",
            isOn: false,
            isPressed: false
        )
        sprites[.repeatButton(false, .pressed)] = createToggleButton(
            size: repeatSize,
            text: "REPEAT",
            isOn: false,
            isPressed: true
        )
        sprites[.repeatButton(true, .normal)] = createToggleButton(
            size: repeatSize,
            text: "REPEAT",
            isOn: true,
            isPressed: false
        )
        sprites[.repeatButton(true, .pressed)] = createToggleButton(
            size: repeatSize,
            text: "REPEAT",
            isOn: true,
            isPressed: true
        )
        
        // EQ button
        sprites[.equalizerButton(false, .normal)] = createToggleButton(
            size: windowButtonSize,
            text: "EQ",
            isOn: false,
            isPressed: false
        )
        sprites[.equalizerButton(true, .normal)] = createToggleButton(
            size: windowButtonSize,
            text: "EQ",
            isOn: true,
            isPressed: false
        )
        
        // PL button
        sprites[.playlistButton(false, .normal)] = createToggleButton(
            size: windowButtonSize,
            text: "PL",
            isOn: false,
            isPressed: false
        )
        sprites[.playlistButton(true, .normal)] = createToggleButton(
            size: windowButtonSize,
            text: "PL",
            isOn: true,
            isPressed: false
        )
    }
    
    /// Create slider sprites
    private func createSliders() {
        // Volume slider
        sprites[.volumeSliderTrack] = createSliderTrack(size: CGSize(width: 68, height: 13))
        sprites[.volumeSliderThumb(.normal)] = createSliderThumb(size: CGSize(width: 14, height: 11), isPressed: false)
        sprites[.volumeSliderThumb(.pressed)] = createSliderThumb(size: CGSize(width: 14, height: 11), isPressed: true)
        
        // Balance slider
        sprites[.balanceSliderTrack] = createSliderTrack(size: CGSize(width: 38, height: 13))
        sprites[.balanceSliderThumb(.normal)] = createSliderThumb(size: CGSize(width: 14, height: 11), isPressed: false)
        sprites[.balanceSliderThumb(.pressed)] = createSliderThumb(size: CGSize(width: 14, height: 11), isPressed: true)
        
        // Position slider
        sprites[.positionSliderTrack] = createSliderTrack(size: CGSize(width: 248, height: 10))
        sprites[.positionSliderThumb(.normal)] = createSliderThumb(size: CGSize(width: 29, height: 10), isPressed: false)
        sprites[.positionSliderThumb(.pressed)] = createSliderThumb(size: CGSize(width: 29, height: 10), isPressed: true)
    }
    
    /// Create number sprites
    private func createNumberSprites() {
        let digitSize = CGSize(width: 9, height: 13)
        
        for digit in 0...9 {
            sprites[.numberDigit(digit)] = createDigitImage(
                size: digitSize,
                digit: String(digit)
            )
        }
        
        sprites[.timeColon] = createDigitImage(
            size: CGSize(width: 5, height: 13),
            digit: ":"
        )
        
        sprites[.timeMinus] = createDigitImage(
            size: digitSize,
            digit: "-"
        )
    }
    
    /// Create indicator sprites
    private func createIndicators() {
        sprites[.stereoIndicator] = createTextImage(
            size: CGSize(width: 29, height: 12),
            text: "STEREO",
            color: WinAmpColors.text
        )
        
        sprites[.monoIndicator] = createTextImage(
            size: CGSize(width: 29, height: 12),
            text: "MONO",
            color: WinAmpColors.text
        )
        
        sprites[.playingIndicator] = createIndicatorDot(
            size: CGSize(width: 3, height: 9),
            color: WinAmpColors.playingIndicator
        )
        
        sprites[.pausedIndicator] = createIndicatorDot(
            size: CGSize(width: 3, height: 9),
            color: WinAmpColors.pausedIndicator
        )
        
        sprites[.stoppedIndicator] = createIndicatorDot(
            size: CGSize(width: 3, height: 9),
            color: WinAmpColors.stoppedIndicator
        )
    }
    
    // MARK: - Helper Methods
    
    private func createGradientImage(size: CGSize, startColor: Color, endColor: Color) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        let gradient = NSGradient(starting: NSColor(startColor), ending: NSColor(endColor))
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -90)
        
        image.unlockFocus()
        return image
    }
    
    private func createButtonImage(size: CGSize, symbol: String, backgroundColor: Color, foregroundColor: Color) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor(backgroundColor).setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Border
        NSColor(WinAmpColors.border).setStroke()
        let borderPath = NSBezierPath(rect: NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1
        borderPath.stroke()
        
        // Symbol
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.height * 0.6),
            .foregroundColor: NSColor(foregroundColor)
        ]
        
        let textSize = symbol.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        symbol.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
    
    private func createToggleButton(size: CGSize, text: String, isOn: Bool, isPressed: Bool) -> NSImage {
        let backgroundColor = isPressed ? WinAmpColors.buttonPressed : (isOn ? WinAmpColors.buttonActive : WinAmpColors.buttonNormal)
        let textColor = isOn ? WinAmpColors.textHighlight : WinAmpColors.text
        
        return createButtonImage(size: size, symbol: text, backgroundColor: backgroundColor, foregroundColor: textColor)
    }
    
    private func createSliderTrack(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Groove
        let grooveRect = NSRect(x: 0, y: size.height/2 - 2, width: size.width, height: 4)
        NSColor(WinAmpColors.backgroundDark).setFill()
        grooveRect.fill()
        
        // Border
        NSColor(WinAmpColors.border).setStroke()
        let borderPath = NSBezierPath(rect: grooveRect.insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1
        borderPath.stroke()
        
        image.unlockFocus()
        return image
    }
    
    private func createSliderThumb(size: CGSize, isPressed: Bool) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        let color = isPressed ? WinAmpColors.accent : WinAmpColors.text
        
        // Background
        NSColor(color).setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Highlight
        NSColor.white.withAlphaComponent(0.3).setFill()
        NSRect(x: 0, y: 0, width: size.width, height: 2).fill()
        
        // Shadow
        NSColor.black.withAlphaComponent(0.3).setFill()
        NSRect(x: 0, y: size.height - 2, width: size.width, height: 2).fill()
        
        image.unlockFocus()
        return image
    }
    
    private func createDigitImage(size: CGSize, digit: String) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Digit
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Courier", size: size.height) ?? NSFont.monospacedDigitSystemFont(ofSize: size.height, weight: .bold),
            .foregroundColor: NSColor(WinAmpColors.text)
        ]
        
        let textSize = digit.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        digit.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
    
    private func createTextImage(size: CGSize, text: String, color: Color) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: NSColor(color)
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
    
    private func createIndicatorDot(size: CGSize, color: Color) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Dot
        NSColor(color).setFill()
        let dotRect = NSRect(x: 0, y: (size.height - size.width) / 2, width: size.width, height: size.width)
        NSBezierPath(ovalIn: dotRect).fill()
        
        image.unlockFocus()
        return image
    }
}

// MARK: - WinAmp Color Extensions

extension WinAmpColors {
    static let buttonNormal = backgroundLight
    static let playingIndicator = Color.green
    static let pausedIndicator = Color.yellow
    static let stoppedIndicator = Color.red
    static let accentDark = Color(red: 0.0, green: 0.4, blue: 0.8)
}