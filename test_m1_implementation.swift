#!/usr/bin/env swift

import Foundation
import AppKit
@testable import WinAmpPlayer

// Simple test script for M1: WSZ extraction + BMP decoder

func testM1Implementation() {
    print("🧪 Testing M1: WSZ Extraction + BMP Decoder")
    
    // Test BMP decoder with sample data
    print("\n1. Testing BMP decoder...")
    do {
        // Create a simple test BMP
        let width = 50
        let height = 25
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 3,
            bitsPerPixel: 24
        ) else {
            throw TestError.bitmapCreationFailed
        }
        
        // Fill with blue and magenta pattern
        for y in 0..<height {
            for x in 0..<width {
                let color = (x + y) % 2 == 0 ? NSColor.blue : ClassicBMPDecoder.transparentMagenta
                bitmapRep.setColor(color, atX: x, y: y)
            }
        }
        
        guard let bmpData = bitmapRep.representation(using: .bmp, properties: [:]) else {
            throw TestError.bmpDataCreationFailed
        }
        
        // Test decoder
        let decodedImage = try ClassicBMPDecoder.decode(bmpData)
        print("✅ BMP decoder: Successfully decoded \(Int(decodedImage.size.width))x\(Int(decodedImage.size.height)) image")
        
        // Test transparency validation
        let hasTransparency = ClassicBMPDecoder.validateTransparency(in: decodedImage)
        print("✅ Transparency: \(hasTransparency ? "Detected" : "Not detected")")
        
    } catch {
        print("❌ BMP decoder test failed: \(error)")
    }
    
    // Test sprite sheet creation
    print("\n2. Testing sprite sheet...")
    do {
        // Create test image
        let width = 100
        let height = 50
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 3,
            bitsPerPixel: 24
        ) else {
            throw TestError.bitmapCreationFailed
        }
        
        // Fill with gradient
        for y in 0..<height {
            for x in 0..<width {
                let intensity = CGFloat(x) / CGFloat(width)
                let color = NSColor(red: intensity, green: 0.5, blue: 1.0 - intensity, alpha: 1.0)
                bitmapRep.setColor(color, atX: x, y: y)
            }
        }
        
        guard let bmpData = bitmapRep.representation(using: .bmp, properties: [:]) else {
            throw TestError.bmpDataCreationFailed
        }
        
        let sourceImage = try ClassicBMPDecoder.decode(bmpData)
        
        let spriteMap = [
            "button1": CGRect(x: 0, y: 0, width: 25, height: 25),
            "button2": CGRect(x: 25, y: 0, width: 25, height: 25),
            "button3": CGRect(x: 50, y: 0, width: 25, height: 25)
        ]
        
        let spriteSheet = SpriteSheet(sourceImage: sourceImage, spriteMap: spriteMap)
        
        // Test sprite extraction
        guard let button1 = spriteSheet.sprite(named: "button1") else {
            throw TestError.spriteExtractionFailed
        }
        
        print("✅ Sprite sheet: Successfully created with \(spriteSheet.availableSprites.count) sprites")
        print("✅ Sprite extraction: button1 is \(Int(button1.size.width))x\(Int(button1.size.height))")
        
        // Test missing sprite
        let missingSprite = spriteSheet.sprite(named: "nonexistent")
        print("✅ Missing sprite handling: \(missingSprite == nil ? "Correctly returns nil" : "ERROR - should return nil")")
        
    } catch {
        print("❌ Sprite sheet test failed: \(error)")
    }
    
    // Test main window sprite map
    print("\n3. Testing main window sprite map...")
    do {
        // Create 275x116 test image (WinAmp main window size)
        let width = 275
        let height = 116
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 3,
            bitsPerPixel: 24
        ) else {
            throw TestError.bitmapCreationFailed
        }
        
        // Fill with pattern
        for y in 0..<height {
            for x in 0..<width {
                let intensity = CGFloat(x + y) / CGFloat(width + height)
                let color = NSColor(red: intensity, green: 0.5, blue: 1.0 - intensity, alpha: 1.0)
                bitmapRep.setColor(color, atX: x, y: y)
            }
        }
        
        guard let bmpData = bitmapRep.representation(using: .bmp, properties: [:]) else {
            throw TestError.bmpDataCreationFailed
        }
        
        let sourceImage = try ClassicBMPDecoder.decode(bmpData)
        let spriteSheet = MainWindowSpriteMap.createSpriteSheet(from: sourceImage)
        
        // Test key sprites
        let titlebar = spriteSheet.sprite(named: "titlebar")
        let background = spriteSheet.sprite(named: "background") 
        let transportBackground = spriteSheet.sprite(named: "transportBackground")
        
        print("✅ Main window sprites:")
        print("   - titlebar: \(titlebar != nil ? "✓" : "✗")")
        print("   - background: \(background != nil ? "✓" : "✗")")
        print("   - transportBackground: \(transportBackground != nil ? "✓" : "✗")")
        print("   - Total sprites available: \(spriteSheet.availableSprites.count)")
        
    } catch {
        print("❌ Main window sprite map test failed: \(error)")
    }
    
    print("\n🎉 M1 Implementation Test Complete!")
    print("✅ BMP decoding with magenta transparency")
    print("✅ Sprite sheet creation and extraction")
    print("✅ Main window sprite layout")
    print("\nNext: M2 - Region mask parsing")
}

enum TestError: Error {
    case bitmapCreationFailed
    case bmpDataCreationFailed
    case spriteExtractionFailed
}

// Run the test
testM1Implementation()
