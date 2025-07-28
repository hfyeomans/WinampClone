import Foundation
import AppKit
import CoreGraphics

/// Decoder for classic WinAmp BMP files with magenta transparency
/// Handles 24-bit BMPs and converts magenta (#FF00FF) pixels to transparent
public class ClassicBMPDecoder {
    
    /// The magic magenta color used for transparency in WinAmp skins
    public static let transparentMagenta = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
    
    /// Decode BMP data and apply magenta transparency
    public static func decode(_ data: Data) throws -> NSImage {
        guard let bitmapRep = NSBitmapImageRep(data: data) else {
            throw BMPDecodingError.invalidBMPData
        }
        
        // Verify it's the expected format (24-bit RGB)
        guard bitmapRep.bitsPerPixel == 24 || bitmapRep.bitsPerPixel == 32 else {
            throw BMPDecodingError.unsupportedBitDepth(bitmapRep.bitsPerPixel)
        }
        
        // Create new bitmap with alpha channel
        guard let processedRep = applyMagentaTransparency(to: bitmapRep) else {
            throw BMPDecodingError.transparencyProcessingFailed
        }
        
        let image = NSImage(size: NSSize(width: processedRep.pixelsWide, 
                                       height: processedRep.pixelsHigh))
        image.addRepresentation(processedRep)
        
        return image
    }
    
    /// Convert BMP Data to CGImage with transparency
    public static func decodeToCGImage(_ data: Data) throws -> CGImage {
        let nsImage = try decode(data)
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw BMPDecodingError.cgImageConversionFailed
        }
        return cgImage
    }
    
    /// Apply magenta transparency to bitmap representation
    private static func applyMagentaTransparency(to bitmapRep: NSBitmapImageRep) -> NSBitmapImageRep? {
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        // Create new bitmap with alpha channel
        guard let newRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4, // RGBA
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }
        
        // Process each pixel
        for y in 0..<height {
            for x in 0..<width {
                guard let sourceColor = bitmapRep.colorAt(x: x, y: y) else { continue }
                
                // Convert to RGB values
                let red = Int(sourceColor.redComponent * 255)
                let green = Int(sourceColor.greenComponent * 255) 
                let blue = Int(sourceColor.blueComponent * 255)
                
                // Check if pixel is magenta (within tolerance)
                let isMagenta = red >= 250 && green <= 5 && blue >= 250
                
                // Set pixel with appropriate alpha
                let alpha: CGFloat = isMagenta ? 0.0 : 1.0
                let newColor = NSColor(red: sourceColor.redComponent,
                                     green: sourceColor.greenComponent,
                                     blue: sourceColor.blueComponent,
                                     alpha: alpha)
                
                newRep.setColor(newColor, atX: x, y: y)
            }
        }
        
        return newRep
    }
    
    /// Extract sprite from larger BMP using specified rectangle
    public static func extractSprite(from image: NSImage, rect: CGRect) -> NSImage? {
        let spriteSize = NSSize(width: rect.width, height: rect.height)
        let spriteImage = NSImage(size: spriteSize)
        
        spriteImage.lockFocus()
        
        // Draw portion of source image
        let sourceRect = NSRect(x: rect.origin.x, 
                               y: image.size.height - rect.origin.y - rect.height, // Flip Y coordinate
                               width: rect.width, 
                               height: rect.height)
        let destRect = NSRect(origin: .zero, size: spriteSize)
        
        image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
        
        spriteImage.unlockFocus()
        
        return spriteImage
    }
    
    /// Verify that an image contains the expected transparent magenta areas
    public static func validateTransparency(in image: NSImage) -> Bool {
        guard let bitmapRep = image.representations.first as? NSBitmapImageRep else {
            return false
        }
        
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        var transparentPixels = 0
        
        // Sample a few pixels to check for transparency
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                if let color = bitmapRep.colorAt(x: x, y: y), color.alphaComponent < 0.1 {
                    transparentPixels += 1
                }
            }
        }
        
        // Should have some transparent pixels in a typical WinAmp skin
        return transparentPixels > 0
    }
}

// MARK: - Error Types

public enum BMPDecodingError: LocalizedError {
    case invalidBMPData
    case unsupportedBitDepth(Int)
    case transparencyProcessingFailed
    case cgImageConversionFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidBMPData:
            return "Invalid BMP data format"
        case .unsupportedBitDepth(let depth):
            return "Unsupported bit depth: \(depth). Expected 24 or 32 bits per pixel"
        case .transparencyProcessingFailed:
            return "Failed to process magenta transparency"
        case .cgImageConversionFailed:
            return "Failed to convert NSImage to CGImage"
        }
    }
}
