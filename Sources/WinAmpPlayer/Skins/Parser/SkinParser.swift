//
//  SkinParser.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Parser for WinAmp classic skin files (.wsz format)
//

import Foundation
import AppKit

/// Errors that can occur during skin parsing
enum SkinParsingError: Error {
    case invalidFormat
    case missingRequiredFile(String)
    case decompressError(Error)
    case invalidBitmapData
    case invalidConfiguration
    case unsupportedVersion
}

/// Main skin parser for WinAmp .wsz files
public class SkinParser {
    private let fileManager = FileManager.default
    private let tempDirectory: URL
    
    /// Required bitmap files for a valid skin
    private let requiredBitmaps = [
        "main.bmp",         // Main window sprites
        "cbuttons.bmp",     // Control buttons
        "titlebar.bmp",     // Title bar elements
        "shufrep.bmp",      // Shuffle/repeat buttons
        "volume.bmp",       // Volume slider
        "balance.bmp",      // Balance slider
        "posbar.bmp",       // Position/seek bar
        "numbers.bmp",      // Number sprites
        "monoster.bmp"      // Mono/stereo indicators
    ]
    
    /// Optional bitmap files
    private let optionalBitmaps = [
        "playpaus.bmp",     // Play/pause buttons
        "eqmain.bmp",       // Equalizer window
        "pledit.bmp",       // Playlist editor
        "mb.bmp",           // Mini-browser
        "avs.bmp"           // AVS window
    ]
    
    /// Configuration files
    private let configFiles = [
        "pledit.txt",       // Playlist colors
        "viscolor.txt",     // Visualization colors
        "region.txt"        // Button hit regions
    ]
    
    public init() throws {
        // Create temporary directory for skin extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WinAmpSkins")
            .appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        self.tempDirectory = tempDir
    }
    
    deinit {
        // Clean up temporary directory
        try? fileManager.removeItem(at: tempDirectory)
    }
    
    /// Parse a skin file from the given URL
    public func parseSkin(from url: URL) async throws -> ParsedSkin {
        // Validate file extension
        guard url.pathExtension.lowercased() == "wsz" || 
              url.pathExtension.lowercased() == "zip" else {
            throw SkinParsingError.invalidFormat
        }
        
        // Extract skin to temporary directory
        let extractedPath = try await extractSkin(from: url)
        
        // Parse bitmap files
        var bitmaps: [String: NSImage] = [:]
        for bitmapName in requiredBitmaps {
            let bitmapPath = extractedPath.appendingPathComponent(bitmapName)
            guard let bitmap = try? parseBitmap(at: bitmapPath) else {
                throw SkinParsingError.missingRequiredFile(bitmapName)
            }
            bitmaps[bitmapName] = bitmap
        }
        
        // Parse optional bitmaps
        for bitmapName in optionalBitmaps {
            let bitmapPath = extractedPath.appendingPathComponent(bitmapName)
            if let bitmap = try? parseBitmap(at: bitmapPath) {
                bitmaps[bitmapName] = bitmap
            }
        }
        
        // Parse configuration files
        var configs: [String: String] = [:]
        for configName in configFiles {
            let configPath = extractedPath.appendingPathComponent(configName)
            if let content = try? String(contentsOf: configPath, encoding: .windowsCP1252) {
                configs[configName] = content
            }
        }
        
        // Create parsed skin
        return ParsedSkin(
            name: url.deletingPathExtension().lastPathComponent,
            bitmaps: bitmaps,
            configurations: configs,
            sourceURL: url
        )
    }
    
    /// Extract skin archive to temporary directory
    private func extractSkin(from url: URL) async throws -> URL {
        let destinationPath = tempDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent)
        
        // Create extraction task
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-q", "-o", url.path, "-d", destinationPath.path]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw SkinParsingError.decompressError(NSError(domain: "SkinParser", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString]))
            }
        } catch {
            throw SkinParsingError.decompressError(error)
        }
        
        return destinationPath
    }
    
    /// Parse a bitmap file
    private func parseBitmap(at url: URL) throws -> NSImage {
        guard let image = NSImage(contentsOf: url) else {
            throw SkinParsingError.invalidBitmapData
        }
        
        // Apply transparency color key (magenta: RGB 255,0,255)
        return applyTransparency(to: image)
    }
    
    /// Apply transparency to bitmap using magenta color key
    private func applyTransparency(to image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        
        // Draw image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get pixel data
        guard let pixelData = context.data else { return image }
        let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Apply transparency to magenta pixels
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                
                // Check for magenta (255, 0, 255)
                if r == 255 && g == 0 && b == 255 {
                    data[offset + 3] = 0 // Set alpha to 0
                }
            }
        }
        
        // Create new image from modified context
        guard let newCGImage = context.makeImage() else { return image }
        let newImage = NSImage(cgImage: newCGImage, size: image.size)
        
        return newImage
    }
}

/// Parsed skin data structure
public struct ParsedSkin: ParsedSkinProtocol {
    public let name: String
    public let bitmaps: [String: NSImage]
    public let configurations: [String: String]
    public let sourceURL: URL
    
    /// Get playlist editor configuration
    public var playlistConfig: PlaylistConfig? {
        guard let configText = configurations["pledit.txt"] else { return nil }
        return PlaylistConfig.parse(from: configText)
    }
    
    /// Get visualization colors
    public var visualizationColors: VisualizationColors? {
        guard let configText = configurations["viscolor.txt"] else { return nil }
        return VisualizationColors.parse(from: configText)
    }
    
    /// Get button regions
    public var buttonRegions: [ButtonRegion]? {
        guard let configText = configurations["region.txt"] else { return nil }
        return ButtonRegion.parseRegions(from: configText)
    }
}

/// Playlist editor configuration
public struct PlaylistConfig {
    public let normalText: NSColor
    public let currentText: NSColor
    public let normalBackground: NSColor
    public let selectedBackground: NSColor
    public let font: String?
    
    static func parse(from text: String) -> PlaylistConfig? {
        var config = PlaylistConfig(
            normalText: .white,
            currentText: .green,
            normalBackground: .black,
            selectedBackground: .blue,
            font: nil
        )
        
        // Parse configuration lines
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            
            let key = parts[0].lowercased()
            let value = parts[1]
            
            switch key {
            case "normal":
                if let color = parseColor(from: value) {
                    config = PlaylistConfig(
                        normalText: color,
                        currentText: config.currentText,
                        normalBackground: config.normalBackground,
                        selectedBackground: config.selectedBackground,
                        font: config.font
                    )
                }
            case "current":
                if let color = parseColor(from: value) {
                    config = PlaylistConfig(
                        normalText: config.normalText,
                        currentText: color,
                        normalBackground: config.normalBackground,
                        selectedBackground: config.selectedBackground,
                        font: config.font
                    )
                }
            case "normalbg":
                if let color = parseColor(from: value) {
                    config = PlaylistConfig(
                        normalText: config.normalText,
                        currentText: config.currentText,
                        normalBackground: color,
                        selectedBackground: config.selectedBackground,
                        font: config.font
                    )
                }
            case "selectedbg":
                if let color = parseColor(from: value) {
                    config = PlaylistConfig(
                        normalText: config.normalText,
                        currentText: config.currentText,
                        normalBackground: config.normalBackground,
                        selectedBackground: color,
                        font: config.font
                    )
                }
            case "font":
                config = PlaylistConfig(
                    normalText: config.normalText,
                    currentText: config.currentText,
                    normalBackground: config.normalBackground,
                    selectedBackground: config.selectedBackground,
                    font: value
                )
            default:
                break
            }
        }
        
        return config
    }
    
    private static func parseColor(from string: String) -> NSColor? {
        // Parse hex color format #RRGGBB
        if string.hasPrefix("#") && string.count == 7 {
            let hex = String(string.dropFirst())
            var rgbValue: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgbValue)
            
            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0
            
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
        
        return nil
    }
}

/// Visualization color configuration
public struct VisualizationColors {
    public let colors: [NSColor]
    
    static func parse(from text: String) -> VisualizationColors? {
        var colors: [NSColor] = []
        
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let values = line.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if values.count >= 3 {
                let color = NSColor(
                    red: CGFloat(values[0]) / 255.0,
                    green: CGFloat(values[1]) / 255.0,
                    blue: CGFloat(values[2]) / 255.0,
                    alpha: 1.0
                )
                colors.append(color)
            }
        }
        
        return colors.isEmpty ? nil : VisualizationColors(colors: colors)
    }
}

/// Button hit region
public struct ButtonRegion {
    public let name: String
    public let points: [CGPoint]
    
    static func parseRegions(from text: String) -> [ButtonRegion]? {
        var regions: [ButtonRegion] = []
        var currentRegion: (name: String, points: [CGPoint])?
        
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                // Save previous region if exists
                if let region = currentRegion {
                    regions.append(ButtonRegion(name: region.name, points: region.points))
                }
                
                // Start new region
                let name = String(trimmed.dropFirst().dropLast())
                currentRegion = (name, [])
            } else if trimmed.contains("=") {
                // Parse point
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let coords = parts[1].split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    if coords.count >= 2 {
                        let point = CGPoint(x: coords[0], y: coords[1])
                        currentRegion?.points.append(point)
                    }
                }
            }
        }
        
        // Save last region
        if let region = currentRegion {
            regions.append(ButtonRegion(name: region.name, points: region.points))
        }
        
        return regions.isEmpty ? nil : regions
    }
    
    /// Check if a point is inside the region
    public func contains(point: CGPoint) -> Bool {
        guard points.count >= 3 else { return false }
        
        // Point-in-polygon test using ray casting
        var inside = false
        var p1 = points.last!
        
        for p2 in points {
            if (p2.y > point.y) != (p1.y > point.y) {
                let slope = (point.x - p1.x) * (p2.y - p1.y) - (p2.x - p1.x) * (point.y - p1.y)
                if (p2.y > p1.y) ? (slope < 0) : (slope > 0) {
                    inside = !inside
                }
            }
            p1 = p2
        }
        
        return inside
    }
}