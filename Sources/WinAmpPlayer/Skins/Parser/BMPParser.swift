//
//  BMPParser.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Parser for BMP files and sprite extraction
//

import Foundation
import AppKit

/// BMP file header structure
struct BMPHeader {
    let fileSize: UInt32
    let pixelDataOffset: UInt32
    let headerSize: UInt32
    let width: Int32
    let height: Int32
    let bitsPerPixel: UInt16
    let compression: UInt32
    let imageSize: UInt32
}

/// Parser for BMP files with sprite extraction
public class BMPParser {
    
    /// Parse BMP file and extract image
    public static func parseBMP(from data: Data) throws -> NSImage? {
        guard data.count >= 54 else { // Minimum BMP header size
            throw SkinParsingError.invalidBitmapData
        }
        
        // Check BMP signature
        let signature = data.subdata(in: 0..<2)
        guard signature == Data([0x42, 0x4D]) else { // "BM"
            throw SkinParsingError.invalidBitmapData
        }
        
        // Parse header
        let header = try parseBMPHeader(from: data)
        
        // Extract pixel data
        let pixelData = data.subdata(in: Int(header.pixelDataOffset)..<data.count)
        
        // Create image from pixel data
        return createImage(from: pixelData, header: header)
    }
    
    /// Parse BMP header
    private static func parseBMPHeader(from data: Data) throws -> BMPHeader {
        var offset = 0
        
        // Skip signature (already checked)
        offset += 2
        
        // File size
        let fileSize = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        
        // Skip reserved bytes
        offset += 4
        
        // Pixel data offset
        let pixelDataOffset = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        
        // DIB header size
        let headerSize = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        
        // Image dimensions
        let width = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: Int32.self)
        }
        offset += 4
        
        let height = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: Int32.self)
        }
        offset += 4
        
        // Color planes (skip)
        offset += 2
        
        // Bits per pixel
        let bitsPerPixel = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt16.self)
        }
        offset += 2
        
        // Compression
        let compression = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        
        // Image size
        let imageSize = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
        
        return BMPHeader(
            fileSize: fileSize,
            pixelDataOffset: pixelDataOffset,
            headerSize: headerSize,
            width: width,
            height: height,
            bitsPerPixel: bitsPerPixel,
            compression: compression,
            imageSize: imageSize
        )
    }
    
    /// Create NSImage from pixel data
    private static func createImage(from pixelData: Data, header: BMPHeader) -> NSImage? {
        let width = Int(abs(header.width))
        let height = Int(abs(header.height))
        let isBottomUp = header.height > 0
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Get context data pointer
        guard let contextData = context.data else { return nil }
        let pixels = contextData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Convert pixel data based on bits per pixel
        switch header.bitsPerPixel {
        case 24:
            convertBGRToRGBA(from: pixelData, to: pixels, width: width, height: height, isBottomUp: isBottomUp)
        case 32:
            convertBGRAToRGBA(from: pixelData, to: pixels, width: width, height: height, isBottomUp: isBottomUp)
        default:
            return nil // Unsupported format
        }
        
        // Create image from context
        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
    
    /// Convert 24-bit BGR to RGBA
    private static func convertBGRToRGBA(from source: Data, to dest: UnsafeMutablePointer<UInt8>, width: Int, height: Int, isBottomUp: Bool) {
        let rowPadding = (4 - (width * 3) % 4) % 4
        let sourceRowSize = width * 3 + rowPadding
        
        source.withUnsafeBytes { sourceBytes in
            let sourcePixels = sourceBytes.bindMemory(to: UInt8.self)
            
            for y in 0..<height {
                let sourceY = isBottomUp ? (height - 1 - y) : y
                let sourceRowOffset = sourceY * sourceRowSize
                let destRowOffset = y * width * 4
                
                for x in 0..<width {
                    let sourceOffset = sourceRowOffset + x * 3
                    let destOffset = destRowOffset + x * 4
                    
                    // BGR to RGBA
                    dest[destOffset] = sourcePixels[sourceOffset + 2]     // R
                    dest[destOffset + 1] = sourcePixels[sourceOffset + 1] // G
                    dest[destOffset + 2] = sourcePixels[sourceOffset]     // B
                    
                    // Check for magenta transparency (255, 0, 255)
                    if dest[destOffset] == 255 && dest[destOffset + 1] == 0 && dest[destOffset + 2] == 255 {
                        dest[destOffset + 3] = 0 // Transparent
                    } else {
                        dest[destOffset + 3] = 255 // Opaque
                    }
                }
            }
        }
    }
    
    /// Convert 32-bit BGRA to RGBA
    private static func convertBGRAToRGBA(from source: Data, to dest: UnsafeMutablePointer<UInt8>, width: Int, height: Int, isBottomUp: Bool) {
        source.withUnsafeBytes { sourceBytes in
            let sourcePixels = sourceBytes.bindMemory(to: UInt8.self)
            
            for y in 0..<height {
                let sourceY = isBottomUp ? (height - 1 - y) : y
                let sourceRowOffset = sourceY * width * 4
                let destRowOffset = y * width * 4
                
                for x in 0..<width {
                    let sourceOffset = sourceRowOffset + x * 4
                    let destOffset = destRowOffset + x * 4
                    
                    // BGRA to RGBA
                    dest[destOffset] = sourcePixels[sourceOffset + 2]     // R
                    dest[destOffset + 1] = sourcePixels[sourceOffset + 1] // G
                    dest[destOffset + 2] = sourcePixels[sourceOffset]     // B
                    dest[destOffset + 3] = sourcePixels[sourceOffset + 3] // A
                    
                    // Check for magenta transparency if alpha is opaque
                    if dest[destOffset + 3] == 255 &&
                       dest[destOffset] == 255 && 
                       dest[destOffset + 1] == 0 && 
                       dest[destOffset + 2] == 255 {
                        dest[destOffset + 3] = 0 // Make transparent
                    }
                }
            }
        }
    }
}

/// Extension to load BMP directly from file
extension BMPParser {
    public static func loadBMP(from url: URL) throws -> NSImage? {
        let data = try Data(contentsOf: url)
        return try parseBMP(from: data)
    }
}