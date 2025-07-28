import XCTest
import CoreGraphics
import AppKit
@testable import WinAmpPlayer

class RegionMaskTests: XCTestCase {
    
    // MARK: - Basic Parsing Tests
    
    func testSimpleRegionParsing() throws {
        let regionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: regionText)
        
        XCTAssertEqual(mask.gridWidth, 3)
        XCTAssertEqual(mask.gridHeight, 3)
        
        // Check specific pixels
        XCTAssertTrue(mask.regionData[0][0])   // Top-left
        XCTAssertTrue(mask.regionData[0][2])   // Top-right
        XCTAssertFalse(mask.regionData[1][1])  // Center (should be false)
        XCTAssertTrue(mask.regionData[2][1])   // Bottom-center
    }
    
    func testEmptyRegionData() {
        XCTAssertThrowsError(try RegionMask(regionText: "")) { error in
            guard case RegionMaskError.emptyRegionData = error else {
                XCTFail("Expected emptyRegionData error")
                return
            }
        }
    }
    
    func testInconsistentLineLength() {
        let regionText = """
        111
        11
        111
        """
        
        XCTAssertThrowsError(try RegionMask(regionText: regionText)) { error in
            guard case RegionMaskError.inconsistentLineLength(let line, let expected, let actual) = error else {
                XCTFail("Expected inconsistentLineLength error")
                return
            }
            XCTAssertEqual(line, 1) // Second line (0-indexed)
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(actual, 2)
        }
    }
    
    func testInvalidCharacter() {
        let regionText = """
        111
        1X1
        111
        """
        
        XCTAssertThrowsError(try RegionMask(regionText: regionText)) { error in
            guard case RegionMaskError.invalidCharacter(let char) = error else {
                XCTFail("Expected invalidCharacter error")
                return
            }
            XCTAssertEqual(char, "X")
        }
    }
    
    // MARK: - Path Creation Tests
    
    func testPathCreation() throws {
        let regionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: regionText)
        let path = mask.createPath(scale: 10.0)
        
        XCTAssertFalse(path.isEmpty)
        
        // Check that the path contains expected areas
        XCTAssertTrue(path.contains(CGPoint(x: 5, y: 25))) // Top row, center
        XCTAssertFalse(path.contains(CGPoint(x: 15, y: 15))) // Middle row, center (should be transparent)
        XCTAssertTrue(path.contains(CGPoint(x: 5, y: 5))) // Bottom row, left
    }
    
    func testShapeLayerCreation() throws {
        let regionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: regionText)
        let layer = mask.makeShapeLayer(scale: 2.0)
        
        XCTAssertNotNil(layer.path)
        XCTAssertEqual(layer.frame.width, 6.0) // 3 * 2.0
        XCTAssertEqual(layer.frame.height, 6.0) // 3 * 2.0
    }
    
    // MARK: - Point Containment Tests
    
    func testPointContainment() throws {
        let regionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: regionText)
        
        // Test points at scale 1.0
        XCTAssertTrue(mask.contains(point: CGPoint(x: 0, y: 3), scale: 1.0))  // Top-left
        XCTAssertTrue(mask.contains(point: CGPoint(x: 2, y: 3), scale: 1.0))  // Top-right
        XCTAssertFalse(mask.contains(point: CGPoint(x: 1, y: 2), scale: 1.0)) // Middle (transparent)
        XCTAssertTrue(mask.contains(point: CGPoint(x: 1, y: 1), scale: 1.0))  // Bottom-center
        
        // Test out of bounds
        XCTAssertFalse(mask.contains(point: CGPoint(x: -1, y: 0), scale: 1.0))
        XCTAssertFalse(mask.contains(point: CGPoint(x: 5, y: 0), scale: 1.0))
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() throws {
        let regionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: regionText)
        let stats = mask.statistics
        
        XCTAssertEqual(stats.totalPixels, 9)
        XCTAssertEqual(stats.visiblePixels, 8)
        XCTAssertEqual(stats.transparentPixels, 1)
        XCTAssertEqual(stats.coverage, 8.0 / 9.0, accuracy: 0.001)
    }
    
    // MARK: - Main Window Validation Tests
    
    func testMainWindowDimensionValidation() throws {
        // Create region with wrong dimensions
        let smallRegionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: smallRegionText)
        
        XCTAssertThrowsError(try mask.validateMainWindowRegion()) { error in
            guard case RegionMaskError.invalidDimensions(let width, let height) = error else {
                XCTFail("Expected invalidDimensions error")
                return
            }
            XCTAssertEqual(width, 3)
            XCTAssertEqual(height, 3)
        }
    }
    
    func testMainWindowCoverageValidation() throws {
        // Create region with invalid coverage (all transparent)
        let transparentRegion = String(repeating: String(repeating: "0", count: 275) + "\n", count: 116)
        let mask = try RegionMask(regionText: transparentRegion.trimmingCharacters(in: .newlines))
        
        XCTAssertThrowsError(try mask.validateMainWindowRegion()) { error in
            guard case RegionMaskError.invalidCoverage = error else {
                XCTFail("Expected invalidCoverage error")
                return
            }
        }
    }
    
    func testMainWindowTitlebarValidation() throws {
        // Create region with transparent titlebar
        var lines: [String] = []
        lines.append(String(repeating: "0", count: 275)) // Transparent titlebar
        for _ in 1..<116 {
            lines.append(String(repeating: "1", count: 275)) // Visible body
        }
        
        let mask = try RegionMask(regionText: lines.joined(separator: "\n"))
        
        XCTAssertThrowsError(try mask.validateMainWindowRegion()) { error in
            guard case RegionMaskError.missingTitlebar = error else {
                XCTFail("Expected missingTitlebar error")
                return
            }
        }
    }
    
    // MARK: - Convenience Factory Tests
    
    func testRectangularRegion() {
        let mask = RegionMask.createRectangular(width: 5, height: 3)
        
        XCTAssertEqual(mask.gridWidth, 5)
        XCTAssertEqual(mask.gridHeight, 3)
        
        let stats = mask.statistics
        XCTAssertEqual(stats.coverage, 1.0) // Should be 100% visible
    }
    
    func testStandardMainWindowRegion() {
        let mask = RegionMask.createStandardMainWindow()
        
        XCTAssertEqual(mask.gridWidth, 275)
        XCTAssertEqual(mask.gridHeight, 116)
        
        XCTAssertNoThrow(try mask.validateMainWindowRegion())
    }
    
    func testRoundedMainWindowRegion() {
        let mask = RegionMask.createRoundedMainWindow(cornerRadius: 3)
        
        XCTAssertEqual(mask.gridWidth, 275)
        XCTAssertEqual(mask.gridHeight, 116)
        
        // Check that corners are rounded (transparent)
        XCTAssertFalse(mask.regionData[0][0])     // Top-left corner
        XCTAssertFalse(mask.regionData[0][274])   // Top-right corner
        XCTAssertFalse(mask.regionData[115][0])   // Bottom-left corner
        XCTAssertFalse(mask.regionData[115][274]) // Bottom-right corner
        
        // Check that center areas are visible
        XCTAssertTrue(mask.regionData[10][10])    // Near top-left, but not corner
        XCTAssertTrue(mask.regionData[50][137])   // Center
    }
    
    // MARK: - Data Initialization Tests
    
    func testDataInitialization() throws {
        let regionText = "111\n101\n111"
        let data = regionText.data(using: .utf8)!
        
        let mask = try RegionMask(data: data)
        
        XCTAssertEqual(mask.gridWidth, 3)
        XCTAssertEqual(mask.gridHeight, 3)
    }
    
    func testInvalidDataEncoding() {
        // Create invalid UTF-8 data
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        
        XCTAssertThrowsError(try RegionMask(data: invalidData)) { error in
            guard case RegionMaskError.invalidTextEncoding = error else {
                XCTFail("Expected invalidTextEncoding error")
                return
            }
        }
    }
    
    // MARK: - Debug Image Tests
    
    func testDebugImageCreation() throws {
        let regionText = """
        111
        101
        111
        """
        
        let mask = try RegionMask(regionText: regionText)
        let debugImage = mask.createDebugImage(scale: 4.0)
        
        XCTAssertEqual(debugImage.size.width, 12.0) // 3 * 4.0
        XCTAssertEqual(debugImage.size.height, 12.0) // 3 * 4.0
    }
    
    // MARK: - Real-world Region Tests
    
    func testComplexRegionMask() throws {
        // Create a more complex region that resembles actual WinAmp skin
        var lines: [String] = []
        
        // Titlebar with rounded corners
        for y in 0..<116 {
            var line = ""
            for x in 0..<275 {
                if y < 2 && (x < 2 || x >= 273) {
                    line += "0" // Rounded titlebar corners
                } else if y >= 114 && (x < 3 || x >= 272) {
                    line += "0" // Rounded bottom corners
                } else {
                    line += "1" // Visible area
                }
            }
            lines.append(line)
        }
        
        let mask = try RegionMask(regionText: lines.joined(separator: "\n"))
        
        XCTAssertNoThrow(try mask.validateMainWindowRegion())
        
        let stats = mask.statistics
        XCTAssertGreaterThan(stats.coverage, 0.95) // Should be mostly visible
        XCTAssertLessThan(stats.coverage, 1.0)      // But not completely filled
    }
}
