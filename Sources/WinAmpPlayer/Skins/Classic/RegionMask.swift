import Foundation
import CoreGraphics
import AppKit

/// Parses WinAmp region.txt files and creates window masks
/// Region files are 275x116 grids where '1' = visible, '0' = transparent
public class RegionMask {
    public let gridWidth: Int
    public let gridHeight: Int
    public let regionData: [[Bool]]
    
    /// Standard WinAmp main window dimensions
    public static let standardWidth = 275
    public static let standardHeight = 116
    
    public init(regionText: String) throws {
        let lines = regionText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw RegionMaskError.emptyRegionData
        }
        
        self.gridHeight = lines.count
        self.gridWidth = lines.first?.count ?? 0
        
        // Validate consistent line lengths
        for (index, line) in lines.enumerated() {
            if line.count != gridWidth {
                throw RegionMaskError.inconsistentLineLength(line: index, expected: gridWidth, actual: line.count)
            }
        }
        
        // Parse region data
        var parsedData: [[Bool]] = []
        for line in lines {
            var rowData: [Bool] = []
            for char in line {
                switch char {
                case "1":
                    rowData.append(true)  // Visible pixel
                case "0":
                    rowData.append(false) // Transparent pixel
                default:
                    throw RegionMaskError.invalidCharacter(char)
                }
            }
            parsedData.append(rowData)
        }
        
        self.regionData = parsedData
    }
    
    /// Create region mask from Data (assumes UTF-8 encoding)
    public convenience init(data: Data) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw RegionMaskError.invalidTextEncoding
        }
        try self.init(regionText: text)
    }
    
    /// Create a CGPath representing the visible region
    public func createPath(scale: CGFloat = 1.0) -> CGPath {
        let path = CGMutablePath()
        
        // Process row by row to create rectangles for visible areas
        for y in 0..<gridHeight {
            var x = 0
            while x < gridWidth {
                // Find start of visible region
                while x < gridWidth && !regionData[y][x] {
                    x += 1
                }
                
                if x >= gridWidth { break }
                
                let startX = x
                
                // Find end of visible region
                while x < gridWidth && regionData[y][x] {
                    x += 1
                }
                
                let width = x - startX
                let rect = CGRect(
                    x: CGFloat(startX) * scale,
                    y: CGFloat(gridHeight - y - 1) * scale, // Flip Y coordinate
                    width: CGFloat(width) * scale,
                    height: scale
                )
                path.addRect(rect)
            }
        }
        
        return path
    }
    
    /// Create a CAShapeLayer for use as a window mask
    public func makeShapeLayer(scale: CGFloat = 1.0) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = createPath(scale: scale)
        layer.fillColor = NSColor.black.cgColor // Black = visible
        layer.frame = CGRect(
            x: 0, 
            y: 0, 
            width: CGFloat(gridWidth) * scale,
            height: CGFloat(gridHeight) * scale
        )
        return layer
    }
    
    /// Check if a point is within the visible region
    public func contains(point: CGPoint, scale: CGFloat = 1.0) -> Bool {
        let x = Int(point.x / scale)
        let y = Int((CGFloat(gridHeight) * scale - point.y) / scale) // Flip Y
        
        guard x >= 0 && x < gridWidth && y >= 0 && y < gridHeight else {
            return false
        }
        
        return regionData[y][x]
    }
    
    /// Get statistics about the region
    public var statistics: RegionStatistics {
        var visiblePixels = 0
        var totalPixels = gridWidth * gridHeight
        
        for row in regionData {
            for isVisible in row {
                if isVisible {
                    visiblePixels += 1
                }
            }
        }
        
        return RegionStatistics(
            totalPixels: totalPixels,
            visiblePixels: visiblePixels,
            transparentPixels: totalPixels - visiblePixels,
            coverage: Double(visiblePixels) / Double(totalPixels)
        )
    }
    
    /// Validate that this appears to be a valid WinAmp main window region
    public func validateMainWindowRegion() throws {
        // Check dimensions
        guard gridWidth == RegionMask.standardWidth && gridHeight == RegionMask.standardHeight else {
            throw RegionMaskError.invalidDimensions(width: gridWidth, height: gridHeight)
        }
        
        // Check that there's reasonable coverage (not empty, not completely filled)
        let stats = statistics
        guard stats.coverage > 0.1 && stats.coverage < 0.99 else {
            throw RegionMaskError.invalidCoverage(stats.coverage)
        }
        
        // Check that top row (titlebar) has some visible pixels
        let titlebarVisible = regionData[0].contains(true)
        guard titlebarVisible else {
            throw RegionMaskError.missingTitlebar
        }
    }
    
    /// Create a debug image showing the region mask
    public func createDebugImage(scale: CGFloat = 2.0) -> NSImage {
        let imageSize = NSSize(
            width: CGFloat(gridWidth) * scale,
            height: CGFloat(gridHeight) * scale
        )
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        // Draw background
        NSColor.red.setFill() // Red = transparent areas
        NSRect(origin: .zero, size: imageSize).fill()
        
        // Draw visible areas
        NSColor.green.setFill() // Green = visible areas
        for y in 0..<gridHeight {
            for x in 0..<gridWidth {
                if regionData[y][x] {
                    let rect = NSRect(
                        x: CGFloat(x) * scale,
                        y: CGFloat(gridHeight - y - 1) * scale, // Flip Y
                        width: scale,
                        height: scale
                    )
                    rect.fill()
                }
            }
        }
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Supporting Types

public struct RegionStatistics {
    public let totalPixels: Int
    public let visiblePixels: Int
    public let transparentPixels: Int
    public let coverage: Double
    
    public var coveragePercentage: String {
        return String(format: "%.1f%%", coverage * 100)
    }
}

// MARK: - Error Types

public enum RegionMaskError: LocalizedError {
    case emptyRegionData
    case inconsistentLineLength(line: Int, expected: Int, actual: Int)
    case invalidCharacter(Character)
    case invalidTextEncoding
    case invalidDimensions(width: Int, height: Int)
    case invalidCoverage(Double)
    case missingTitlebar
    
    public var errorDescription: String? {
        switch self {
        case .emptyRegionData:
            return "Region data is empty"
        case .inconsistentLineLength(let line, let expected, let actual):
            return "Line \(line) has \(actual) characters, expected \(expected)"
        case .invalidCharacter(let char):
            return "Invalid character '\(char)' in region data. Expected '0' or '1'"
        case .invalidTextEncoding:
            return "Unable to decode region data as UTF-8 text"
        case .invalidDimensions(let width, let height):
            return "Invalid dimensions \(width)x\(height). Expected \(RegionMask.standardWidth)x\(RegionMask.standardHeight)"
        case .invalidCoverage(let coverage):
            return "Invalid coverage \(String(format: "%.1f%%", coverage * 100)). Expected between 10% and 99%"
        case .missingTitlebar:
            return "Titlebar (top row) appears to be completely transparent"
        }
    }
}

// MARK: - Convenience Extensions

extension RegionMask {
    /// Create a rectangular region (for testing or fallback)
    public static func createRectangular(width: Int, height: Int) -> RegionMask {
        let regionText = (0..<height).map { _ in
            String(repeating: "1", count: width)
        }.joined(separator: "\n")
        
        return try! RegionMask(regionText: regionText)
    }
    
    /// Create standard WinAmp main window rectangular region
    public static func createStandardMainWindow() -> RegionMask {
        return createRectangular(width: standardWidth, height: standardHeight)
    }
    
    /// Create region with rounded corners (for testing)
    public static func createRoundedMainWindow(cornerRadius: Int = 3) -> RegionMask {
        var lines: [String] = []
        
        for y in 0..<standardHeight {
            var line = ""
            for x in 0..<standardWidth {
                // Calculate distance to corners
                let distToTopLeft = max(cornerRadius - x, cornerRadius - y)
                let distToTopRight = max(x - (standardWidth - cornerRadius - 1), cornerRadius - y)
                let distToBottomLeft = max(cornerRadius - x, y - (standardHeight - cornerRadius - 1))
                let distToBottomRight = max(x - (standardWidth - cornerRadius - 1), y - (standardHeight - cornerRadius - 1))
                
                let isCorner = distToTopLeft > 0 || distToTopRight > 0 || distToBottomLeft > 0 || distToBottomRight > 0
                line += isCorner ? "0" : "1"
            }
            lines.append(line)
        }
        
        return try! RegionMask(regionText: lines.joined(separator: "\n"))
    }
}
