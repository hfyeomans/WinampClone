//
//  ClassicSkinGenerator.swift
//  WinAmpPlayer
//
//  Generates the classic WinAmp 2.x skin assets programmatically
//

import SwiftUI
import AppKit

public class ClassicSkinGenerator {
    
    // Classic WinAmp colors
    struct ClassicColors {
        static let background = NSColor(red: 58/255, green: 58/255, blue: 58/255, alpha: 1.0)
        static let darkBorder = NSColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        static let lightBorder = NSColor(red: 165/255, green: 165/255, blue: 165/255, alpha: 1.0)
        static let midTone = NSColor(red: 99/255, green: 99/255, blue: 99/255, alpha: 1.0)
        static let buttonFace = NSColor(red: 74/255, green: 74/255, blue: 74/255, alpha: 1.0)
        static let lcdBackground = NSColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        static let lcdText = NSColor(red: 0, green: 255, blue: 0, alpha: 1.0)
        static let lcdDim = NSColor(red: 0, green: 80/255, blue: 0, alpha: 1.0)
    }
    
    public static func generateClassicSkin() async throws {
        let outputDir = SkinManager.shared.skinsDirectory.appendingPathComponent("Classic")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Generate main window background
        try generateMainBackground(to: outputDir)
        
        // Generate buttons
        try generateControlButtons(to: outputDir)
        
        // Generate title bar
        try generateTitleBar(to: outputDir)
        
        // Generate LCD numbers
        try generateLCDNumbers(to: outputDir)
        
        // Generate sliders
        try generateSliders(to: outputDir)
        
        // Generate EQ window
        try generateEQWindow(to: outputDir)
        
        // Generate playlist window
        try generatePlaylistWindow(to: outputDir)
        
        // Create skin.xml
        try createSkinXML(at: outputDir)
    }
    
    // MARK: - Main Window Background
    
    private static func generateMainBackground(to directory: URL) throws {
        let size = CGSize(width: 275, height: 116)
        let image = NSImage(size: size, flipped: false) { rect in
            // Fill background
            ClassicColors.background.setFill()
            rect.fill()
            
            // Draw beveled border
            drawBeveledRect(rect.insetBy(dx: 0, dy: 0), raised: true)
            
            // Draw LCD area
            let lcdRect = CGRect(x: 24, y: 43, width: 76, height: 13)
            ClassicColors.lcdBackground.setFill()
            lcdRect.fill()
            drawBeveledRect(lcdRect, raised: false)
            
            // Draw visualizer area
            let visRect = CGRect(x: 24, y: 58, width: 76, height: 16)
            ClassicColors.lcdBackground.setFill()
            visRect.fill()
            drawBeveledRect(visRect, raised: false)
            
            return true
        }
        
        try image.pngData()?.write(to: directory.appendingPathComponent("main.png"))
    }
    
    // MARK: - Control Buttons
    
    private static func generateControlButtons(to directory: URL) throws {
        let buttonConfigs: [(name: String, symbol: String, size: CGSize)] = [
            ("play", "►", CGSize(width: 23, height: 18)),
            ("pause", "||", CGSize(width: 23, height: 18)),
            ("stop", "■", CGSize(width: 23, height: 18)),
            ("previous", "|◄", CGSize(width: 23, height: 18)),
            ("next", "►|", CGSize(width: 23, height: 18)),
            ("eject", "⏏", CGSize(width: 22, height: 16))
        ]
        
        for config in buttonConfigs {
            // Normal state
            let normalImage = createButton(size: config.size, symbol: config.symbol, pressed: false)
            try normalImage.pngData()?.write(to: directory.appendingPathComponent("\(config.name).png"))
            
            // Pressed state
            let pressedImage = createButton(size: config.size, symbol: config.symbol, pressed: true)
            try pressedImage.pngData()?.write(to: directory.appendingPathComponent("\(config.name)_pressed.png"))
        }
    }
    
    private static func createButton(size: CGSize, symbol: String, pressed: Bool) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            // Button background
            ClassicColors.buttonFace.setFill()
            rect.fill()
            
            // Beveled edges
            drawBeveledRect(rect, raised: !pressed)
            
            // Draw symbol
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            
            let symbolSize = symbol.size(withAttributes: attributes)
            let symbolRect = CGRect(
                x: (rect.width - symbolSize.width) / 2 + (pressed ? 1 : 0),
                y: (rect.height - symbolSize.height) / 2 + (pressed ? -1 : 0),
                width: symbolSize.width,
                height: symbolSize.height
            )
            
            symbol.draw(in: symbolRect, withAttributes: attributes)
            
            return true
        }
    }
    
    // MARK: - LCD Numbers
    
    private static func generateLCDNumbers(to directory: URL) throws {
        let digits = "0123456789:-"
        let digitWidth: CGFloat = 5
        let digitHeight: CGFloat = 7
        
        for (index, char) in digits.enumerated() {
            let image = NSImage(size: CGSize(width: digitWidth, height: digitHeight), flipped: false) { rect in
                ClassicColors.lcdBackground.setFill()
                rect.fill()
                
                // Draw LCD-style digit
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: ClassicColors.lcdText
                ]
                
                String(char).draw(in: rect, withAttributes: attributes)
                
                return true
            }
            
            let filename = index < 10 ? "num_\(index).png" : (char == ":" ? "num_colon.png" : "num_dash.png")
            try image.pngData()?.write(to: directory.appendingPathComponent(filename))
        }
    }
    
    // MARK: - Helper Methods
    
    private static func drawBeveledRect(_ rect: CGRect, raised: Bool) {
        let topLeftColor = raised ? ClassicColors.lightBorder : ClassicColors.darkBorder
        let bottomRightColor = raised ? ClassicColors.darkBorder : ClassicColors.lightBorder
        
        // Top and left edges
        topLeftColor.setStroke()
        let topLeftPath = NSBezierPath()
        topLeftPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        topLeftPath.line(to: CGPoint(x: rect.minX, y: rect.minY))
        topLeftPath.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        topLeftPath.lineWidth = 1.0
        topLeftPath.stroke()
        
        // Bottom and right edges
        bottomRightColor.setStroke()
        let bottomRightPath = NSBezierPath()
        bottomRightPath.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        bottomRightPath.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        bottomRightPath.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        bottomRightPath.lineWidth = 1.0
        bottomRightPath.stroke()
    }
    
    // MARK: - Title Bar
    
    private static func generateTitleBar(to directory: URL) throws {
        let size = CGSize(width: 275, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            // Gradient background
            let gradient = NSGradient(colors: [
                ClassicColors.midTone,
                ClassicColors.buttonFace
            ])!
            gradient.draw(in: rect, angle: -90)
            
            // Beveled edge
            drawBeveledRect(rect, raised: true)
            
            return true
        }
        
        try image.pngData()?.write(to: directory.appendingPathComponent("titlebar.png"))
    }
    
    // MARK: - Sliders
    
    private static func generateSliders(to directory: URL) throws {
        // Volume slider background
        let volumeSize = CGSize(width: 68, height: 13)
        let volumeBg = NSImage(size: volumeSize, flipped: false) { rect in
            ClassicColors.background.setFill()
            rect.fill()
            
            // Groove
            let grooveRect = CGRect(x: 0, y: 6, width: rect.width, height: 2)
            drawBeveledRect(grooveRect, raised: false)
            
            return true
        }
        try volumeBg.pngData()?.write(to: directory.appendingPathComponent("volume_bg.png"))
        
        // Slider thumb
        let thumbSize = CGSize(width: 14, height: 11)
        let thumb = NSImage(size: thumbSize, flipped: false) { rect in
            ClassicColors.buttonFace.setFill()
            rect.fill()
            drawBeveledRect(rect, raised: true)
            
            // Center line
            ClassicColors.darkBorder.setStroke()
            let centerPath = NSBezierPath()
            centerPath.move(to: CGPoint(x: rect.midX, y: rect.minY + 2))
            centerPath.line(to: CGPoint(x: rect.midX, y: rect.maxY - 2))
            centerPath.lineWidth = 1.0
            centerPath.stroke()
            
            return true
        }
        try thumb.pngData()?.write(to: directory.appendingPathComponent("slider_thumb.png"))
    }
    
    // MARK: - EQ Window
    
    private static func generateEQWindow(to directory: URL) throws {
        let size = CGSize(width: 275, height: 116)
        let image = NSImage(size: size, flipped: false) { rect in
            ClassicColors.background.setFill()
            rect.fill()
            drawBeveledRect(rect, raised: true)
            
            // Draw EQ slider backgrounds
            let sliderWidth: CGFloat = 14
            let sliderHeight: CGFloat = 50
            let sliderSpacing: CGFloat = 18
            let startX: CGFloat = 78
            let startY: CGFloat = 38
            
            for i in 0..<10 {
                let x = startX + CGFloat(i) * sliderSpacing
                let sliderRect = CGRect(x: x, y: startY, width: sliderWidth, height: sliderHeight)
                
                // Groove
                let grooveRect = CGRect(x: sliderRect.midX - 1, y: sliderRect.minY, 
                                      width: 2, height: sliderRect.height)
                drawBeveledRect(grooveRect, raised: false)
            }
            
            return true
        }
        
        try image.pngData()?.write(to: directory.appendingPathComponent("eq_main.png"))
    }
    
    // MARK: - Playlist Window
    
    private static func generatePlaylistWindow(to directory: URL) throws {
        let size = CGSize(width: 275, height: 232)
        let image = NSImage(size: size, flipped: false) { rect in
            ClassicColors.background.setFill()
            rect.fill()
            drawBeveledRect(rect, raised: true)
            
            // List area
            let listRect = CGRect(x: 8, y: 20, width: 259, height: 174)
            NSColor.black.setFill()
            listRect.fill()
            drawBeveledRect(listRect, raised: false)
            
            return true
        }
        
        try image.pngData()?.write(to: directory.appendingPathComponent("playlist_main.png"))
    }
    
    // MARK: - Skin XML
    
    private static func createSkinXML(at directory: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <WinAmpSkin version="1.0">
            <info>
                <name>Classic</name>
                <author>WinAmpPlayer</author>
                <version>1.0</version>
                <description>Classic WinAmp 2.x skin</description>
            </info>
            <components>
                <main>
                    <background src="main.png"/>
                    <buttons>
                        <play normal="play.png" pressed="play_pressed.png" x="26" y="88"/>
                        <pause normal="pause.png" pressed="pause_pressed.png" x="49" y="88"/>
                        <stop normal="stop.png" pressed="stop_pressed.png" x="72" y="88"/>
                        <previous normal="previous.png" pressed="previous_pressed.png" x="16" y="88"/>
                        <next normal="next.png" pressed="next_pressed.png" x="108" y="88"/>
                        <eject normal="eject.png" pressed="eject_pressed.png" x="136" y="89"/>
                    </buttons>
                    <sliders>
                        <volume background="volume_bg.png" thumb="slider_thumb.png" x="107" y="57"/>
                        <balance background="balance_bg.png" thumb="slider_thumb.png" x="177" y="57"/>
                        <position background="position_bg.png" thumb="slider_thumb.png" x="16" y="72"/>
                    </sliders>
                    <display x="24" y="43" width="76" height="13"/>
                    <visualization x="24" y="58" width="76" height="16"/>
                </main>
                <equalizer>
                    <background src="eq_main.png"/>
                </equalizer>
                <playlist>
                    <background src="playlist_main.png"/>
                </playlist>
            </components>
        </WinAmpSkin>
        """
        
        try xml.write(to: directory.appendingPathComponent("skin.xml"), 
                     atomically: true, encoding: .utf8)
    }
}

// Extension to convert NSImage to PNG data
extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}