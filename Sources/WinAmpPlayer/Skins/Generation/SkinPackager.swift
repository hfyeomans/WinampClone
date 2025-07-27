//
//  SkinPackager.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Packages generated skin assets into .wsz files
//

import Foundation
import CoreGraphics
import AppKit

/// Packages generated skins into .wsz files
public class SkinPackager {
    
    /// Package error types
    public enum PackageError: LocalizedError {
        case assetGenerationFailed(String)
        case imageConversionFailed(String)
        case archiveCreationFailed(String)
        case invalidConfiguration
        
        public var errorDescription: String? {
            switch self {
            case .assetGenerationFailed(let detail):
                return "Asset generation failed: \(detail)"
            case .imageConversionFailed(let detail):
                return "Image conversion failed: \(detail)"
            case .archiveCreationFailed(let detail):
                return "Archive creation failed: \(detail)"
            case .invalidConfiguration:
                return "Invalid skin configuration"
            }
        }
    }
    
    /// Package a generated skin
    public static func packageSkin(
        config: SkinGenerationConfig,
        palette: GeneratedPalette,
        outputURL: URL
    ) async throws -> GeneratedSkin {
        
        // Generate all required sprites
        let sprites = try await generateAllSprites(config: config, palette: palette)
        
        // Create metadata
        let metadata = generateMetadata(config: config)
        
        // Create generated skin object
        let generatedSkin = GeneratedSkin(
            config: config,
            palette: palette,
            sprites: sprites,
            metadata: metadata
        )
        
        // Package into .wsz file
        try await createSkinArchive(
            skin: generatedSkin,
            outputURL: outputURL
        )
        
        return generatedSkin
    }
    
    // MARK: - Sprite Generation
    
    /// Generate all required sprites
    private static func generateAllSprites(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) async throws -> [SpriteType: CGImage] {
        
        var sprites: [SpriteType: CGImage] = [:]
        
        // Main window components
        sprites[.main] = try generateMainWindow(config: config, palette: palette)
        sprites[.titleBar] = try generateTitleBar(config: config, palette: palette)
        
        // Control buttons
        sprites[.cButtons] = try generateControlButtons(config: config, palette: palette)
        
        // Sliders
        sprites[.volume] = try generateVolumeSlider(config: config, palette: palette)
        sprites[.balance] = try generateBalanceSlider(config: config, palette: palette)
        sprites[.posBar] = try generatePositionBar(config: config, palette: palette)
        
        // Display areas
        sprites[.numbers] = try generateNumbers(config: config, palette: palette)
        sprites[.text] = try generateText(config: config, palette: palette)
        sprites[.monoster] = try generateMonoster(config: config, palette: palette)
        
        // Playlist window
        sprites[.pledit] = try generatePlaylistEditor(config: config, palette: palette)
        sprites[.plEdit] = try generatePlaylistText(config: config, palette: palette)
        
        // Equalizer window
        sprites[.eqMain] = try generateEqualizer(config: config, palette: palette)
        sprites[.eq_ex] = try generateEqualizerExtended(config: config, palette: palette)
        
        // Visualization
        sprites[.visColor] = try generateVisualizationColors(config: config, palette: palette)
        
        // AVS placeholder
        sprites[.avs] = try generateAVSPlaceholder(config: config, palette: palette)
        
        return sprites
    }
    
    /// Generate main window sprite
    private static func generateMainWindow(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let size = CGSize(width: 275, height: 116)
        
        guard let image = ComponentRenderer.renderComponent(
            type: .mainWindow,
            size: size,
            style: .normal,
            palette: palette,
            config: config
        ) else {
            throw PackageError.assetGenerationFailed("main window")
        }
        
        return image
    }
    
    /// Generate title bar sprite
    private static func generateTitleBar(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let size = CGSize(width: 275, height: 14)
        
        guard let image = ComponentRenderer.renderComponent(
            type: .titleBar,
            size: size,
            style: .normal,
            palette: palette,
            config: config
        ) else {
            throw PackageError.assetGenerationFailed("title bar")
        }
        
        return image
    }
    
    /// Generate control buttons sprite sheet
    private static func generateControlButtons(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // Button dimensions from classic WinAmp
        let buttonSizes: [(ComponentRenderer.ComponentType, CGSize)] = [
            (.previousButton, CGSize(width: 23, height: 18)),
            (.playButton, CGSize(width: 23, height: 18)),
            (.pauseButton, CGSize(width: 23, height: 18)),
            (.stopButton, CGSize(width: 23, height: 18)),
            (.nextButton, CGSize(width: 22, height: 18)),
            (.ejectButton, CGSize(width: 22, height: 16))
        ]
        
        // States: normal, pressed
        let states: [ComponentRenderer.RenderStyle] = [.normal, .pressed]
        
        // Calculate sprite sheet size
        let sheetWidth = 136 // Classic cbuttons.bmp width
        let sheetHeight = 36  // Two rows (normal, pressed)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: sheetWidth,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: sheetWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("control buttons context")
        }
        
        // Clear background
        context.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1)) // Magenta for transparency
        context.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
        
        // Draw buttons
        var xOffset = 0
        
        for (buttonType, size) in buttonSizes {
            for (stateIndex, state) in states.enumerated() {
                if let buttonImage = ComponentRenderer.renderComponent(
                    type: buttonType,
                    size: size,
                    style: state,
                    palette: palette,
                    config: config
                ) {
                    let yOffset = stateIndex * 18
                    let rect = CGRect(x: xOffset, y: yOffset, width: Int(size.width), height: Int(size.height))
                    context.draw(buttonImage, in: rect)
                }
            }
            xOffset += Int(size.width)
        }
        
        guard let spriteSheet = context.makeImage() else {
            throw PackageError.assetGenerationFailed("control buttons sprite sheet")
        }
        
        return spriteSheet
    }
    
    /// Generate volume slider sprites
    private static func generateVolumeSlider(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let trackSize = CGSize(width: 68, height: 13)
        let thumbSize = CGSize(width: 14, height: 11)
        
        let sheetHeight = 422 // Classic volume.bmp height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: 68,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 68 * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("volume slider context")
        }
        
        // Background
        context.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 68, height: sheetHeight))
        
        // Track at top
        if let track = ComponentRenderer.renderComponent(
            type: .volumeSlider,
            size: trackSize,
            style: .normal,
            palette: palette,
            config: config
        ) {
            context.draw(track, in: CGRect(x: 0, y: 0, width: 68, height: 13))
        }
        
        // Thumb positions (28 positions)
        for i in 0..<28 {
            let thumbX = i * 2 // Thumb moves 2 pixels per step
            let thumbY = 15 + (i * 15) // Each thumb sprite is 15 pixels apart
            
            // Draw thumb at position
            if let thumbBg = generateSliderThumb(
                size: thumbSize,
                palette: palette,
                config: config,
                style: .normal
            ) {
                // Draw track background first
                if let track = ComponentRenderer.renderComponent(
                    type: .volumeSlider,
                    size: trackSize,
                    style: .normal,
                    palette: palette,
                    config: config
                ) {
                    context.draw(track, in: CGRect(x: 0, y: thumbY, width: 68, height: 13))
                }
                
                // Draw thumb on top
                context.draw(thumbBg, in: CGRect(x: thumbX, y: thumbY + 1, width: 14, height: 11))
            }
        }
        
        guard let spriteSheet = context.makeImage() else {
            throw PackageError.assetGenerationFailed("volume slider sprite sheet")
        }
        
        return spriteSheet
    }
    
    /// Generate balance slider sprites
    private static func generateBalanceSlider(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // Similar to volume but with center indicator
        let trackSize = CGSize(width: 38, height: 13)
        let thumbSize = CGSize(width: 14, height: 11)
        
        let sheetHeight = 422 // Classic balance.bmp height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: 38,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 38 * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("balance slider context")
        }
        
        // Background
        context.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 38, height: sheetHeight))
        
        // Track at top
        if let track = ComponentRenderer.renderComponent(
            type: .balanceSlider,
            size: trackSize,
            style: .normal,
            palette: palette,
            config: config
        ) {
            context.draw(track, in: CGRect(x: 0, y: 0, width: 38, height: 13))
        }
        
        // Thumb positions (28 positions)
        for i in 0..<28 {
            let thumbX = i // Balance thumb moves 1 pixel per step
            let thumbY = 15 + (i * 15)
            
            // Draw track with thumb
            if let track = ComponentRenderer.renderComponent(
                type: .balanceSlider,
                size: trackSize,
                style: .normal,
                palette: palette,
                config: config
            ) {
                context.draw(track, in: CGRect(x: 0, y: thumbY, width: 38, height: 13))
            }
            
            if let thumb = generateSliderThumb(
                size: thumbSize,
                palette: palette,
                config: config,
                style: .normal
            ) {
                context.draw(thumb, in: CGRect(x: thumbX, y: thumbY + 1, width: 14, height: 11))
            }
        }
        
        guard let spriteSheet = context.makeImage() else {
            throw PackageError.assetGenerationFailed("balance slider sprite sheet")
        }
        
        return spriteSheet
    }
    
    /// Generate position bar sprites
    private static func generatePositionBar(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let barSize = CGSize(width: 248, height: 10)
        
        guard let image = ComponentRenderer.renderComponent(
            type: .positionSlider,
            size: barSize,
            style: .normal,
            palette: palette,
            config: config
        ) else {
            throw PackageError.assetGenerationFailed("position bar")
        }
        
        return image
    }
    
    /// Generate slider thumb
    private static func generateSliderThumb(
        size: CGSize,
        palette: GeneratedPalette,
        config: SkinGenerationConfig,
        style: ComponentRenderer.RenderStyle
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
        
        // Thumb style based on slider style
        switch config.components.sliderStyle {
        case .classic:
            // Rectangular thumb with ridges
            context.setFillColor(palette.neutral.tone(60))
            context.fill(rect)
            
            // Ridges
            context.setStrokeColor(palette.neutral.tone(40))
            context.setLineWidth(1.0)
            for x in stride(from: 3, to: Int(size.width) - 3, by: 2) {
                context.move(to: CGPoint(x: CGFloat(x), y: 2))
                context.addLine(to: CGPoint(x: CGFloat(x), y: size.height - 2))
            }
            context.strokePath()
            
        case .modern:
            // Rounded rectangle
            let path = CGPath(
                roundedRect: rect.insetBy(dx: 1, dy: 1),
                cornerWidth: 2,
                cornerHeight: 2,
                transform: nil
            )
            context.addPath(path)
            context.setFillColor(palette.primary.tone(60))
            context.fillPath()
            
        case .minimal:
            // Simple rectangle
            context.setFillColor(palette.primary.tone(50))
            context.fill(rect)
            
        case .groove:
            // Thumb with center groove
            context.setFillColor(palette.neutral.tone(70))
            context.fill(rect)
            
            // Center groove
            let grooveRect = CGRect(
                x: rect.width / 2 - 1,
                y: 2,
                width: 2,
                height: rect.height - 4
            )
            context.setFillColor(palette.neutral.tone(40))
            context.fill(grooveRect)
            
        case .rail:
            // Metallic looking thumb
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [
                    palette.neutral.tone(80),
                    palette.neutral.tone(60),
                    palette.neutral.tone(70)
                ] as CFArray,
                locations: [0.0, 0.5, 1.0]
            )
            
            if let gradient = gradient {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
        }
        
        return context.makeImage()
    }
    
    /// Generate number sprites
    private static func generateNumbers(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // Numbers 0-9 in LCD style
        let numberWidth = 9
        let numberHeight = 13
        let sheetWidth = numberWidth * 11 // 0-9 plus ":"
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: sheetWidth,
            height: numberHeight,
            bitsPerComponent: 8,
            bytesPerRow: sheetWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("numbers context")
        }
        
        // Background
        context.setFillColor(CGColor.black)
        context.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: numberHeight))
        
        // Font attributes
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: palette.primary.tone(80))!
        ]
        
        // Draw numbers
        let numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":"]
        
        for (index, number) in numbers.enumerated() {
            let string = NSAttributedString(string: number, attributes: attributes)
            let size = string.size()
            let x = CGFloat(index * numberWidth) + (CGFloat(numberWidth) - size.width) / 2
            let y = (CGFloat(numberHeight) - size.height) / 2
            
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(numberHeight))
            context.scaleBy(x: 1, y: -1)
            string.draw(at: CGPoint(x: x, y: y))
            context.restoreGState()
        }
        
        guard let image = context.makeImage() else {
            throw PackageError.assetGenerationFailed("numbers sprite sheet")
        }
        
        return image
    }
    
    /// Generate text sprite (for scrolling text)
    private static func generateText(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // ASCII character set
        let charWidth = 5
        let charHeight = 6
        let charsPerRow = 31
        let rows = 3
        let sheetWidth = charWidth * charsPerRow
        let sheetHeight = charHeight * rows
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: sheetWidth,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: sheetWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("text context")
        }
        
        // Background
        context.setFillColor(CGColor.black)
        context.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
        
        // Font
        let font = NSFont.systemFont(ofSize: 5)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: palette.primary.tone(90))!
        ]
        
        // Draw ASCII characters
        let startChar: UInt8 = 32 // Space
        var charIndex = 0
        
        for row in 0..<rows {
            for col in 0..<charsPerRow {
                if charIndex < 95 { // Printable ASCII range
                    let char = String(Character(UnicodeScalar(startChar + UInt8(charIndex))))
                    let string = NSAttributedString(string: char, attributes: attributes)
                    
                    let x = CGFloat(col * charWidth)
                    let y = CGFloat(row * charHeight)
                    
                    context.saveGState()
                    context.translateBy(x: 0, y: CGFloat(sheetHeight))
                    context.scaleBy(x: 1, y: -1)
                    string.draw(at: CGPoint(x: x, y: CGFloat(sheetHeight) - y - CGFloat(charHeight)))
                    context.restoreGState()
                    
                    charIndex += 1
                }
            }
        }
        
        guard let image = context.makeImage() else {
            throw PackageError.assetGenerationFailed("text sprite sheet")
        }
        
        return image
    }
    
    /// Generate monoster sprites (mono/stereo indicator)
    private static func generateMonoster(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let indicatorWidth = 29
        let indicatorHeight = 12
        let sheetHeight = indicatorHeight * 2 // Mono and stereo
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: indicatorWidth,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: indicatorWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("monoster context")
        }
        
        // Background
        context.setFillColor(CGColor.black)
        context.fill(CGRect(x: 0, y: 0, width: indicatorWidth, height: sheetHeight))
        
        let font = NSFont.systemFont(ofSize: 8, weight: .medium)
        
        // Mono indicator
        let monoAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: palette.neutral.tone(50))!
        ]
        let monoString = NSAttributedString(string: "MONO", attributes: monoAttributes)
        
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(sheetHeight))
        context.scaleBy(x: 1, y: -1)
        monoString.draw(at: CGPoint(x: 2, y: sheetHeight - indicatorHeight + 2))
        context.restoreGState()
        
        // Stereo indicator
        let stereoAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: palette.primary.tone(80))!
        ]
        let stereoString = NSAttributedString(string: "STEREO", attributes: stereoAttributes)
        
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(sheetHeight))
        context.scaleBy(x: 1, y: -1)
        stereoString.draw(at: CGPoint(x: 2, y: 2))
        context.restoreGState()
        
        guard let image = context.makeImage() else {
            throw PackageError.assetGenerationFailed("monoster sprite sheet")
        }
        
        return image
    }
    
    /// Generate playlist editor sprite
    private static func generatePlaylistEditor(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let size = CGSize(width: 275, height: 232)
        
        guard let image = ComponentRenderer.renderComponent(
            type: .mainWindow,
            size: size,
            style: .normal,
            palette: palette,
            config: config
        ) else {
            throw PackageError.assetGenerationFailed("playlist editor")
        }
        
        return image
    }
    
    /// Generate playlist text colors
    private static func generatePlaylistText(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // Simple 1x1 pixel placeholder
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("playlist text context")
        }
        
        context.setFillColor(palette.primaryColor)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        
        guard let image = context.makeImage() else {
            throw PackageError.assetGenerationFailed("playlist text")
        }
        
        return image
    }
    
    /// Generate equalizer sprite
    private static func generateEqualizer(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let size = CGSize(width: 275, height: 116)
        
        guard let image = ComponentRenderer.renderComponent(
            type: .mainWindow,
            size: size,
            style: .normal,
            palette: palette,
            config: config
        ) else {
            throw PackageError.assetGenerationFailed("equalizer")
        }
        
        return image
    }
    
    /// Generate extended equalizer sprite
    private static func generateEqualizerExtended(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // Placeholder for extended EQ graphics
        return try generateEqualizer(config: config, palette: palette)
    }
    
    /// Generate visualization colors
    private static func generateVisualizationColors(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        // Generate color gradient for visualization
        let colors = PaletteGenerator.generateVisualizationColors(from: palette)
        let colorCount = colors.count
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: colorCount,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: colorCount * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw PackageError.assetGenerationFailed("vis colors context")
        }
        
        // Draw each color as a pixel
        for (index, color) in colors.enumerated() {
            context.setFillColor(color)
            context.fill(CGRect(x: index, y: 0, width: 1, height: 1))
        }
        
        guard let image = context.makeImage() else {
            throw PackageError.assetGenerationFailed("vis colors")
        }
        
        return image
    }
    
    /// Generate AVS placeholder
    private static func generateAVSPlaceholder(
        config: SkinGenerationConfig,
        palette: GeneratedPalette
    ) throws -> CGImage {
        let size = CGSize(width: 76, height: 16)
        
        guard let image = ComponentRenderer.renderComponent(
            type: .visualization,
            size: size,
            style: .normal,
            palette: palette,
            config: config
        ) else {
            throw PackageError.assetGenerationFailed("AVS")
        }
        
        return image
    }
    
    // MARK: - Archive Creation
    
    /// Create .wsz archive
    private static func createSkinArchive(
        skin: GeneratedSkin,
        outputURL: URL
    ) async throws {
        
        // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Save all sprites as BMP files
        for (spriteType, image) in skin.sprites {
            let filename = spriteTypeToFilename(spriteType) + ".bmp"
            let fileURL = tempDir.appendingPathComponent(filename)
            
            try saveBMP(image: image, to: fileURL)
        }
        
        // Create configuration files
        try createConfigFiles(skin: skin, in: tempDir)
        
        // Create ZIP archive
        try await createZipArchive(
            from: tempDir,
            to: outputURL
        )
    }
    
    /// Save image as BMP
    private static func saveBMP(image: CGImage, to url: URL) throws {
        guard let data = image.bmpData() else {
            throw PackageError.imageConversionFailed("Failed to convert to BMP")
        }
        
        try data.write(to: url)
    }
    
    /// Map SpriteType to filename
    private static func spriteTypeToFilename(_ spriteType: SpriteType) -> String {
        // Map sprite types to their standard WinAmp filenames
        switch spriteType {
        case .main: return "main"
        case .titleBar: return "titlebar"
        case .cButtons: return "cbuttons"
        case .volume: return "volume"
        case .balance: return "balance"
        case .posBar: return "posbar"
        case .numbers: return "numbers"
        case .text: return "text"
        case .monoster: return "monoster"
        case .pledit: return "pledit"
        case .plEdit: return "pledit"
        case .eqMain: return "eqmain"
        case .eq_ex: return "eq_ex"
        case .visColor: return "viscolor"
        case .avs: return "avs"
        default:
            // For complex enum cases with associated values, extract base filename
            return "unknown"
        }
    }
    
    /// Create configuration files
    private static func createConfigFiles(skin: GeneratedSkin, in directory: URL) throws {
        // viscolor.txt
        let visColors = generateVisColorConfig(palette: skin.palette)
        try visColors.write(
            to: directory.appendingPathComponent("viscolor.txt"),
            atomically: true,
            encoding: .windowsCP1252
        )
        
        // pledit.txt
        let plEdit = generatePlaylistConfig(palette: skin.palette, config: skin.config)
        try plEdit.write(
            to: directory.appendingPathComponent("pledit.txt"),
            atomically: true,
            encoding: .windowsCP1252
        )
        
        // region.txt (empty for rectangular windows)
        let region = ""
        try region.write(
            to: directory.appendingPathComponent("region.txt"),
            atomically: true,
            encoding: .windowsCP1252
        )
        
        // skin.xml (metadata)
        let metadata = generateSkinXML(skin: skin)
        try metadata.write(
            to: directory.appendingPathComponent("skin.xml"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    /// Generate viscolor.txt content
    private static func generateVisColorConfig(palette: GeneratedPalette) -> String {
        var lines: [String] = []
        
        // Generate 24 visualization colors
        let visColors = PaletteGenerator.generateVisualizationColors(from: palette)
        
        for (index, color) in visColors.prefix(24).enumerated() {
            if let components = color.components, components.count >= 3 {
                let r = Int(components[0] * 255)
                let g = Int(components[1] * 255)
                let b = Int(components[2] * 255)
                lines.append("\(r),\(g),\(b) // Color \(index)")
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Generate pledit.txt content
    private static func generatePlaylistConfig(palette: GeneratedPalette, config: SkinGenerationConfig) -> String {
        let isDark = config.theme.mode == .dark
        let colors = PaletteGenerator.generatePlaylistColors(from: palette, isDark: isDark)
        
        var lines: [String] = []
        
        // Helper to convert CGColor to hex
        func colorToHex(_ color: CGColor) -> String {
            guard let components = color.components, components.count >= 3 else {
                return "#000000"
            }
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        
        lines.append("[Text]")
        lines.append("Normal=\(colorToHex(colors.normalText))")
        lines.append("Current=\(colorToHex(colors.currentText))")
        lines.append("NormalBG=\(colorToHex(colors.normalTextBackground))")
        lines.append("SelectedBG=\(colorToHex(colors.selectedTextBackground))")
        lines.append("Font=Arial")
        
        return lines.joined(separator: "\n")
    }
    
    /// Generate skin.xml metadata
    private static func generateSkinXML(skin: GeneratedSkin) -> String {
        let config = skin.config
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <WinAMPSkin>
            <SkinInfo>
                <Name>\(config.metadata.name)</Name>
                <Author>\(config.metadata.author)</Author>
                <Version>\(config.metadata.version)</Version>
                <Description>\(config.metadata.description ?? "Generated skin")</Description>
                <Generator>WinAmpPlayer Procedural Skin Generator</Generator>
                <GeneratedDate>\(ISO8601DateFormatter().string(from: skin.timestamp))</GeneratedDate>
            </SkinInfo>
            <Theme>
                <Mode>\(config.theme.mode.rawValue)</Mode>
                <Style>\(config.theme.style.rawValue)</Style>
                <ColorScheme>\(config.colors.scheme.rawValue)</ColorScheme>
            </Theme>
        </WinAMPSkin>
        """
    }
    
    /// Create ZIP archive from directory
    private static func createZipArchive(from sourceDir: URL, to destinationURL: URL) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        task.currentDirectoryURL = sourceDir
        task.arguments = ["-r", "-q", destinationURL.path, "."]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PackageError.archiveCreationFailed("Failed to create archive: \(errorString)")
        }
    }
    
    // MARK: - Metadata Generation
    
    /// Generate metadata dictionary
    private static func generateMetadata(config: SkinGenerationConfig) -> [String: String] {
        var metadata: [String: String] = [:]
        
        metadata["name"] = config.metadata.name
        metadata["author"] = config.metadata.author
        metadata["version"] = config.metadata.version
        metadata["generator"] = "WinAmpPlayer Skin Generator"
        metadata["generatedDate"] = ISO8601DateFormatter().string(from: Date())
        metadata["theme"] = config.theme.style.rawValue
        metadata["colorScheme"] = config.colors.scheme.rawValue
        
        if let description = config.metadata.description {
            metadata["description"] = description
        }
        
        return metadata
    }
}

// MARK: - BMP Conversion Extension

extension CGImage {
    /// Convert CGImage to BMP data
    func bmpData() -> Data? {
        let width = self.width
        let height = self.height
        let bytesPerPixel = 3
        let bytesPerRow = ((width * bytesPerPixel + 3) / 4) * 4 // Align to 4 bytes
        let imageSize = bytesPerRow * height
        let headerSize = 54
        let fileSize = headerSize + imageSize
        
        var data = Data()
        
        // BMP Header
        data.append(contentsOf: [0x42, 0x4D]) // "BM"
        data.append(contentsOf: fileSize.littleEndianBytes(4))
        data.append(contentsOf: [0, 0, 0, 0]) // Reserved
        data.append(contentsOf: headerSize.littleEndianBytes(4))
        
        // DIB Header
        data.append(contentsOf: [40, 0, 0, 0]) // Header size
        data.append(contentsOf: width.littleEndianBytes(4))
        data.append(contentsOf: height.littleEndianBytes(4))
        data.append(contentsOf: [1, 0]) // Planes
        data.append(contentsOf: [24, 0]) // Bits per pixel
        data.append(contentsOf: [0, 0, 0, 0]) // Compression
        data.append(contentsOf: imageSize.littleEndianBytes(4))
        data.append(contentsOf: [0, 0, 0, 0]) // X pixels per meter
        data.append(contentsOf: [0, 0, 0, 0]) // Y pixels per meter
        data.append(contentsOf: [0, 0, 0, 0]) // Colors used
        data.append(contentsOf: [0, 0, 0, 0]) // Important colors
        
        // Get pixel data
        guard let pixelData = self.dataProvider?.data,
              let pixels = CFDataGetBytePtr(pixelData) else {
            return nil
        }
        
        // Convert RGBA to BGR and flip vertically
        for y in (0..<height).reversed() {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let b = pixels[pixelIndex + 2]
                let g = pixels[pixelIndex + 1]
                let r = pixels[pixelIndex]
                
                data.append(contentsOf: [b, g, r])
            }
            
            // Padding
            let padding = bytesPerRow - (width * bytesPerPixel)
            if padding > 0 {
                data.append(contentsOf: Array(repeating: 0, count: padding))
            }
        }
        
        return data
    }
}

extension Int {
    func littleEndianBytes(_ count: Int) -> [UInt8] {
        var value = self
        var bytes = [UInt8]()
        
        for _ in 0..<count {
            bytes.append(UInt8(value & 0xFF))
            value >>= 8
        }
        
        return bytes
    }
}