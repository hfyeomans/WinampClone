//
//  ComponentRenderer.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Component rendering for procedural skin generation
//

import Foundation
import CoreGraphics
import AppKit

/// Component renderer for skin generation
public class ComponentRenderer {
    
    /// Render component sprite
    public static func renderComponent(
        type: ComponentType,
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        
        switch type {
        case .playButton:
            return renderPlayButton(size: size, style: style, palette: palette, config: config)
            
        case .pauseButton:
            return renderPauseButton(size: size, style: style, palette: palette, config: config)
            
        case .stopButton:
            return renderStopButton(size: size, style: style, palette: palette, config: config)
            
        case .nextButton:
            return renderNextButton(size: size, style: style, palette: palette, config: config)
            
        case .previousButton:
            return renderPreviousButton(size: size, style: style, palette: palette, config: config)
            
        case .ejectButton:
            return renderEjectButton(size: size, style: style, palette: palette, config: config)
            
        case .volumeSlider:
            return renderVolumeSlider(size: size, style: style, palette: palette, config: config)
            
        case .balanceSlider:
            return renderBalanceSlider(size: size, style: style, palette: palette, config: config)
            
        case .positionSlider:
            return renderPositionSlider(size: size, style: style, palette: palette, config: config)
            
        case .titleBar:
            return renderTitleBar(size: size, style: style, palette: palette, config: config)
            
        case .mainWindow:
            return renderMainWindow(size: size, style: style, palette: palette, config: config)
            
        case .display:
            return renderDisplay(size: size, style: style, palette: palette, config: config)
            
        case .visualization:
            return renderVisualization(size: size, style: style, palette: palette, config: config)
        }
    }
    
    /// Component types
    public enum ComponentType {
        case playButton
        case pauseButton
        case stopButton
        case nextButton
        case previousButton
        case ejectButton
        case volumeSlider
        case balanceSlider
        case positionSlider
        case titleBar
        case mainWindow
        case display
        case visualization
    }
    
    /// Render style (normal, hover, pressed)
    public enum RenderStyle {
        case normal
        case hover
        case pressed
        case disabled
    }
    
    // MARK: - Button Renderers
    
    /// Render play button
    private static func renderPlayButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderButton(
            size: size,
            style: style,
            palette: palette,
            config: config,
            icon: { context, rect in
                // Draw play triangle
                let inset = rect.width * 0.3
                let path = CGMutablePath()
                path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
                path.closeSubpath()
                
                context.addPath(path)
                context.fillPath()
            }
        )
    }
    
    /// Render pause button
    private static func renderPauseButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderButton(
            size: size,
            style: style,
            palette: palette,
            config: config,
            icon: { context, rect in
                // Draw pause bars
                let barWidth = rect.width * 0.15
                let spacing = rect.width * 0.2
                let inset = rect.height * 0.25
                
                let bar1Rect = CGRect(
                    x: rect.midX - spacing/2 - barWidth,
                    y: rect.minY + inset,
                    width: barWidth,
                    height: rect.height - inset * 2
                )
                
                let bar2Rect = CGRect(
                    x: rect.midX + spacing/2,
                    y: rect.minY + inset,
                    width: barWidth,
                    height: rect.height - inset * 2
                )
                
                context.fill(bar1Rect)
                context.fill(bar2Rect)
            }
        )
    }
    
    /// Render stop button
    private static func renderStopButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderButton(
            size: size,
            style: style,
            palette: palette,
            config: config,
            icon: { context, rect in
                // Draw stop square
                let inset = rect.width * 0.25
                let squareRect = rect.insetBy(dx: inset, dy: inset)
                context.fill(squareRect)
            }
        )
    }
    
    /// Render next button
    private static func renderNextButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderButton(
            size: size,
            style: style,
            palette: palette,
            config: config,
            icon: { context, rect in
                // Draw next triangles
                let inset = rect.width * 0.3
                let triangleWidth = rect.width * 0.3
                
                // First triangle
                let path1 = CGMutablePath()
                path1.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
                path1.addLine(to: CGPoint(x: rect.minX + inset + triangleWidth, y: rect.midY))
                path1.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
                path1.closeSubpath()
                
                // Second triangle
                let path2 = CGMutablePath()
                path2.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
                path2.addLine(to: CGPoint(x: rect.midX + triangleWidth, y: rect.midY))
                path2.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - inset))
                path2.closeSubpath()
                
                context.addPath(path1)
                context.addPath(path2)
                context.fillPath()
                
                // Bar at end
                let barRect = CGRect(
                    x: rect.maxX - inset - rect.width * 0.1,
                    y: rect.minY + inset,
                    width: rect.width * 0.1,
                    height: rect.height - inset * 2
                )
                context.fill(barRect)
            }
        )
    }
    
    /// Render previous button
    private static func renderPreviousButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderButton(
            size: size,
            style: style,
            palette: palette,
            config: config,
            icon: { context, rect in
                // Draw previous triangles (mirrored next)
                let inset = rect.width * 0.3
                let triangleWidth = rect.width * 0.3
                
                // Bar at start
                let barRect = CGRect(
                    x: rect.minX + inset,
                    y: rect.minY + inset,
                    width: rect.width * 0.1,
                    height: rect.height - inset * 2
                )
                context.fill(barRect)
                
                // First triangle
                let path1 = CGMutablePath()
                path1.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
                path1.addLine(to: CGPoint(x: rect.midX - triangleWidth, y: rect.midY))
                path1.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - inset))
                path1.closeSubpath()
                
                // Second triangle
                let path2 = CGMutablePath()
                path2.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
                path2.addLine(to: CGPoint(x: rect.maxX - inset - triangleWidth, y: rect.midY))
                path2.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
                path2.closeSubpath()
                
                context.addPath(path1)
                context.addPath(path2)
                context.fillPath()
            }
        )
    }
    
    /// Render eject button
    private static func renderEjectButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderButton(
            size: size,
            style: style,
            palette: palette,
            config: config,
            icon: { context, rect in
                // Draw eject triangle with line below
                let inset = rect.width * 0.25
                
                // Triangle
                let trianglePath = CGMutablePath()
                trianglePath.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
                trianglePath.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
                trianglePath.addLine(to: CGPoint(x: rect.minX + inset, y: rect.midY))
                trianglePath.closeSubpath()
                
                context.addPath(trianglePath)
                context.fillPath()
                
                // Line below
                let lineRect = CGRect(
                    x: rect.minX + inset,
                    y: rect.midY + rect.height * 0.1,
                    width: rect.width - inset * 2,
                    height: rect.height * 0.1
                )
                context.fill(lineRect)
            }
        )
    }
    
    /// Generic button renderer
    private static func renderButton(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig,
        icon: (CGContext, CGRect) -> Void
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(origin: .zero, size: size)
        
        // Determine colors based on style
        let (bgColor, fgColor, borderColor) = getButtonColors(style: style, palette: palette)
        
        // Draw button background
        switch config.components.buttonStyle {
        case .flat:
            drawFlatButton(context: context, rect: rect, bgColor: bgColor, borderColor: borderColor, config: config)
            
        case .rounded:
            drawRoundedButton(context: context, rect: rect, bgColor: bgColor, borderColor: borderColor, config: config)
            
        case .beveled:
            drawBeveledButton(context: context, rect: rect, bgColor: bgColor, style: style, config: config)
            
        case .glass:
            drawGlassButton(context: context, rect: rect, bgColor: bgColor, borderColor: borderColor, config: config)
            
        case .pill:
            drawPillButton(context: context, rect: rect, bgColor: bgColor, borderColor: borderColor, config: config)
            
        case .square:
            drawSquareButton(context: context, rect: rect, bgColor: bgColor, borderColor: borderColor, config: config)
        }
        
        // Draw icon
        context.setFillColor(fgColor)
        icon(context, rect)
        
        return context.makeImage()
    }
    
    /// Get button colors for style
    private static func getButtonColors(
        style: RenderStyle,
        palette: GeneratedPalette
    ) -> (bg: CGColor, fg: CGColor, border: CGColor) {
        switch style {
        case .normal:
            return (
                bg: palette.surface,
                fg: palette.onSurface,
                border: palette.neutral.tone(40)
            )
            
        case .hover:
            return (
                bg: palette.primary.tone(90),
                fg: palette.primary.tone(10),
                border: palette.primary.tone(70)
            )
            
        case .pressed:
            return (
                bg: palette.primary.tone(70),
                fg: palette.primary.tone(10),
                border: palette.primary.tone(50)
            )
            
        case .disabled:
            return (
                bg: palette.neutral.tone(20),
                fg: palette.neutral.tone(50),
                border: palette.neutral.tone(30)
            )
        }
    }
    
    // MARK: - Button Style Renderers
    
    private static func drawFlatButton(
        context: CGContext,
        rect: CGRect,
        bgColor: CGColor,
        borderColor: CGColor,
        config: SkinGenerationConfig
    ) {
        context.setFillColor(bgColor)
        context.fill(rect)
        
        if config.components.borderWidth > 0 {
            context.setStrokeColor(borderColor)
            context.setLineWidth(CGFloat(config.components.borderWidth))
            context.stroke(rect.insetBy(dx: CGFloat(config.components.borderWidth/2), dy: CGFloat(config.components.borderWidth/2)))
        }
    }
    
    private static func drawRoundedButton(
        context: CGContext,
        rect: CGRect,
        bgColor: CGColor,
        borderColor: CGColor,
        config: SkinGenerationConfig
    ) {
        let path = CGPath(
            roundedRect: rect.insetBy(dx: 1, dy: 1),
            cornerWidth: CGFloat(config.components.cornerRadius),
            cornerHeight: CGFloat(config.components.cornerRadius),
            transform: nil
        )
        
        context.addPath(path)
        context.setFillColor(bgColor)
        context.fillPath()
        
        if config.components.borderWidth > 0 {
            context.addPath(path)
            context.setStrokeColor(borderColor)
            context.setLineWidth(CGFloat(config.components.borderWidth))
            context.strokePath()
        }
    }
    
    private static func drawBeveledButton(
        context: CGContext,
        rect: CGRect,
        bgColor: CGColor,
        style: RenderStyle,
        config: SkinGenerationConfig
    ) {
        // Main button fill
        context.setFillColor(bgColor)
        context.fill(rect)
        
        let bevelSize = 2.0
        
        // Top/left highlight (lighter for normal/hover, darker for pressed)
        let highlightColor = style == .pressed ? 
            CGColor(gray: 0.2, alpha: 1.0) : CGColor(gray: 0.8, alpha: 1.0)
        
        context.setFillColor(highlightColor)
        
        // Top edge
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bevelSize))
        
        // Left edge
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: bevelSize, height: rect.height))
        
        // Bottom/right shadow
        let shadowColor = style == .pressed ? 
            CGColor(gray: 0.8, alpha: 1.0) : CGColor(gray: 0.2, alpha: 1.0)
        
        context.setFillColor(shadowColor)
        
        // Bottom edge
        context.fill(CGRect(x: rect.minX, y: rect.maxY - bevelSize, width: rect.width, height: bevelSize))
        
        // Right edge
        context.fill(CGRect(x: rect.maxX - bevelSize, y: rect.minY, width: bevelSize, height: rect.height))
    }
    
    private static func drawGlassButton(
        context: CGContext,
        rect: CGRect,
        bgColor: CGColor,
        borderColor: CGColor,
        config: SkinGenerationConfig
    ) {
        let path = CGPath(
            roundedRect: rect.insetBy(dx: 1, dy: 1),
            cornerWidth: CGFloat(config.components.cornerRadius),
            cornerHeight: CGFloat(config.components.cornerRadius),
            transform: nil
        )
        
        // Background
        context.addPath(path)
        context.setFillColor(bgColor)
        context.fillPath()
        
        // Glass effect - top highlight
        let highlightRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height * 0.5
        )
        
        let highlightPath = CGPath(
            roundedRect: highlightRect,
            cornerWidth: CGFloat(config.components.cornerRadius),
            cornerHeight: CGFloat(config.components.cornerRadius),
            transform: nil
        )
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Gradient for glass effect
        let locations: [CGFloat] = [0.0, 1.0]
        let colors = [
            CGColor(gray: 1.0, alpha: 0.3),
            CGColor(gray: 1.0, alpha: 0.0)
        ] as CFArray
        
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceGray(),
            colors: colors,
            locations: locations
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.midY),
                options: []
            )
        }
        
        context.restoreGState()
        
        // Border
        if config.components.borderWidth > 0 {
            context.addPath(path)
            context.setStrokeColor(borderColor)
            context.setLineWidth(CGFloat(config.components.borderWidth))
            context.strokePath()
        }
    }
    
    private static func drawPillButton(
        context: CGContext,
        rect: CGRect,
        bgColor: CGColor,
        borderColor: CGColor,
        config: SkinGenerationConfig
    ) {
        let cornerRadius = rect.height / 2
        let path = CGPath(
            roundedRect: rect.insetBy(dx: 1, dy: 1),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        context.addPath(path)
        context.setFillColor(bgColor)
        context.fillPath()
        
        if config.components.borderWidth > 0 {
            context.addPath(path)
            context.setStrokeColor(borderColor)
            context.setLineWidth(CGFloat(config.components.borderWidth))
            context.strokePath()
        }
    }
    
    private static func drawSquareButton(
        context: CGContext,
        rect: CGRect,
        bgColor: CGColor,
        borderColor: CGColor,
        config: SkinGenerationConfig
    ) {
        context.setFillColor(bgColor)
        context.fill(rect)
        
        if config.components.borderWidth > 0 {
            context.setStrokeColor(borderColor)
            context.setLineWidth(CGFloat(config.components.borderWidth))
            context.stroke(rect.insetBy(dx: CGFloat(config.components.borderWidth/2), dy: CGFloat(config.components.borderWidth/2)))
        }
    }
    
    // MARK: - Slider Renderers
    
    /// Render volume slider
    private static func renderVolumeSlider(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderSlider(
            size: size,
            style: style,
            palette: palette,
            config: config,
            orientation: .horizontal
        )
    }
    
    /// Render balance slider
    private static func renderBalanceSlider(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderSlider(
            size: size,
            style: style,
            palette: palette,
            config: config,
            orientation: .horizontal,
            hasCenter: true
        )
    }
    
    /// Render position slider
    private static func renderPositionSlider(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        return renderSlider(
            size: size,
            style: style,
            palette: palette,
            config: config,
            orientation: .horizontal
        )
    }
    
    /// Generic slider renderer
    private static func renderSlider(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig,
        orientation: Orientation = .horizontal,
        hasCenter: Bool = false
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(origin: .zero, size: size)
        
        // Draw track
        let trackRect: CGRect
        if orientation == .horizontal {
            let trackHeight = size.height * 0.3
            trackRect = CGRect(
                x: 0,
                y: (size.height - trackHeight) / 2,
                width: size.width,
                height: trackHeight
            )
        } else {
            let trackWidth = size.width * 0.3
            trackRect = CGRect(
                x: (size.width - trackWidth) / 2,
                y: 0,
                width: trackWidth,
                height: size.height
            )
        }
        
        // Track style
        switch config.components.sliderStyle {
        case .classic:
            drawClassicTrack(context: context, rect: trackRect, palette: palette, config: config)
            
        case .modern:
            drawModernTrack(context: context, rect: trackRect, palette: palette, config: config)
            
        case .minimal:
            drawMinimalTrack(context: context, rect: trackRect, palette: palette, config: config)
            
        case .groove:
            drawGrooveTrack(context: context, rect: trackRect, palette: palette, config: config)
            
        case .rail:
            drawRailTrack(context: context, rect: trackRect, palette: palette, config: config)
        }
        
        // Center indicator for balance
        if hasCenter {
            let centerX = rect.midX
            context.setStrokeColor(palette.neutral.tone(60))
            context.setLineWidth(1.0)
            context.move(to: CGPoint(x: centerX, y: rect.minY))
            context.addLine(to: CGPoint(x: centerX, y: rect.maxY))
            context.strokePath()
        }
        
        return context.makeImage()
    }
    
    enum Orientation {
        case horizontal
        case vertical
    }
    
    // Track style renderers
    private static func drawClassicTrack(
        context: CGContext,
        rect: CGRect,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) {
        // Groove with beveled edges
        context.setFillColor(palette.neutral.tone(20))
        context.fill(rect)
        
        // Bevel effect
        context.setStrokeColor(palette.neutral.tone(10))
        context.setLineWidth(1.0)
        context.stroke(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1))
        context.stroke(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height))
        
        context.setStrokeColor(palette.neutral.tone(40))
        context.stroke(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1))
        context.stroke(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height))
    }
    
    private static func drawModernTrack(
        context: CGContext,
        rect: CGRect,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) {
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: rect.height / 2,
            cornerHeight: rect.height / 2,
            transform: nil
        )
        
        context.addPath(path)
        context.setFillColor(palette.neutral.tone(30))
        context.fillPath()
    }
    
    private static func drawMinimalTrack(
        context: CGContext,
        rect: CGRect,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) {
        context.setFillColor(palette.neutral.tone(40))
        context.fill(rect)
    }
    
    private static func drawGrooveTrack(
        context: CGContext,
        rect: CGRect,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) {
        // Center groove
        let grooveRect = rect.insetBy(dx: 0, dy: rect.height * 0.3)
        context.setFillColor(palette.neutral.tone(15))
        context.fill(grooveRect)
        
        // Edges
        context.setFillColor(palette.neutral.tone(35))
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: grooveRect.minY - rect.minY))
        context.fill(CGRect(x: rect.minX, y: grooveRect.maxY, width: rect.width, height: rect.maxY - grooveRect.maxY))
    }
    
    private static func drawRailTrack(
        context: CGContext,
        rect: CGRect,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) {
        // Rails on edges
        let railWidth = rect.height * 0.2
        
        context.setFillColor(palette.neutral.tone(50))
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: railWidth))
        context.fill(CGRect(x: rect.minX, y: rect.maxY - railWidth, width: rect.width, height: railWidth))
        
        // Center track
        let centerRect = rect.insetBy(dx: 0, dy: railWidth)
        context.setFillColor(palette.neutral.tone(25))
        context.fill(centerRect)
    }
    
    // MARK: - Window Component Renderers
    
    /// Render title bar
    private static func renderTitleBar(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(origin: .zero, size: size)
        
        // Gradient background
        let locations: [CGFloat] = [0.0, 1.0]
        let colors = [
            palette.primary.tone(40),
            palette.primary.tone(30)
        ] as CFArray
        
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: locations
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        
        // Add texture if configured
        if let textureConfig = config.textures.overlay {
            if let texture = TextureEngine.generateTexture(
                type: textureConfig.type,
                context: TextureEngine.Context(
                    width: Int(size.width),
                    height: Int(size.height)
                ),
                colors: palette,
                config: textureConfig
            ) {
                context.saveGState()
                context.setAlpha(CGFloat(textureConfig.opacity))
                context.draw(texture, in: rect)
                context.restoreGState()
            }
        }
        
        return context.makeImage()
    }
    
    /// Render main window background
    private static func renderMainWindow(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(origin: .zero, size: size)
        
        // Background color
        context.setFillColor(palette.background)
        context.fill(rect)
        
        // Background texture
        if let textureConfig = config.textures.background {
            if let texture = TextureEngine.generateTexture(
                type: textureConfig.type,
                context: TextureEngine.Context(
                    width: Int(size.width),
                    height: Int(size.height)
                ),
                colors: palette,
                config: textureConfig
            ) {
                context.saveGState()
                context.setAlpha(CGFloat(textureConfig.opacity))
                context.draw(texture, in: rect)
                context.restoreGState()
            }
        }
        
        // Border
        if config.components.borderWidth > 0 {
            context.setStrokeColor(palette.neutral.tone(40))
            context.setLineWidth(CGFloat(config.components.borderWidth))
            context.stroke(rect.insetBy(dx: CGFloat(config.components.borderWidth/2), dy: CGFloat(config.components.borderWidth/2)))
        }
        
        return context.makeImage()
    }
    
    /// Render display area
    private static func renderDisplay(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(origin: .zero, size: size)
        
        // LCD-style background
        context.setFillColor(palette.neutral.tone(5))
        context.fill(rect)
        
        // Scanline effect for retro styles
        if config.theme.style == .retro || config.theme.style == .cyberpunk {
            context.setStrokeColor(palette.neutral.tone(10).copy(alpha: 0.3)!)
            context.setLineWidth(1.0)
            
            for y in stride(from: 0, to: Int(size.height), by: 2) {
                context.move(to: CGPoint(x: 0, y: CGFloat(y)))
                context.addLine(to: CGPoint(x: size.width, y: CGFloat(y)))
            }
            context.strokePath()
        }
        
        // Bevel inset
        context.setStrokeColor(palette.neutral.tone(0))
        context.setLineWidth(1.0)
        context.stroke(rect)
        
        let insetRect = rect.insetBy(dx: 1, dy: 1)
        context.setStrokeColor(palette.neutral.tone(20))
        context.stroke(insetRect)
        
        return context.makeImage()
    }
    
    /// Render visualization area
    private static func renderVisualization(
        size: CGSize,
        style: RenderStyle,
        palette: GeneratedPalette,
        config: SkinGenerationConfig
    ) -> CGImage? {
        // Similar to display but with darker background
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(origin: .zero, size: size)
        
        // Black background for visualization
        context.setFillColor(CGColor.black)
        context.fill(rect)
        
        // Grid overlay for some styles
        if config.theme.style == .cyberpunk || config.theme.style == .vaporwave {
            context.setStrokeColor(palette.primary.tone(30).copy(alpha: 0.2)!)
            context.setLineWidth(0.5)
            
            let gridSize = 16
            
            // Vertical lines
            for x in stride(from: 0, to: Int(size.width), by: gridSize) {
                context.move(to: CGPoint(x: CGFloat(x), y: 0))
                context.addLine(to: CGPoint(x: CGFloat(x), y: size.height))
            }
            
            // Horizontal lines
            for y in stride(from: 0, to: Int(size.height), by: gridSize) {
                context.move(to: CGPoint(x: 0, y: CGFloat(y)))
                context.addLine(to: CGPoint(x: size.width, y: CGFloat(y)))
            }
            
            context.strokePath()
        }
        
        return context.makeImage()
    }
}