import XCTest
import AppKit
@testable import WinAmpPlayer

class ClassicSkinParsingTests: XCTestCase {
    
    var testDataDirectory: URL!
    var sampleWSZURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test data directory
        testDataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WinAmpTestData")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: testDataDirectory, 
                                              withIntermediateDirectories: true)
        
        // Create sample WSZ for testing
        sampleWSZURL = try createSampleWSZ()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        try? FileManager.default.removeItem(at: testDataDirectory)
        try super.tearDownWithError()
    }
    
    // MARK: - WSZ Archive Tests
    
    func testWSZExtractionSuccess() throws {
        let archive = try ClassicWSZArchive(url: sampleWSZURL)
        
        // Verify required files are present
        XCTAssertTrue(archive.contains("main.bmp"))
        XCTAssertTrue(archive.contains("cbuttons.bmp"))
        XCTAssertTrue(archive.contains("region.txt"))
        
        // Test file access
        let mainBMPData = try archive.data(for: "main.bmp")
        XCTAssertFalse(mainBMPData.isEmpty)
    }
    
    func testWSZValidation() throws {
        let archive = try ClassicWSZArchive(url: sampleWSZURL)
        
        // Should not throw for valid skin structure
        XCTAssertNoThrow(try archive.validateSkinStructure())
    }
    
    func testWSZMissingFiles() throws {
        // Create WSZ without required files
        let incompleteWSZURL = try createIncompleteWSZ()
        let archive = try ClassicWSZArchive(url: incompleteWSZURL)
        
        // Should throw for invalid skin structure
        XCTAssertThrowsError(try archive.validateSkinStructure()) { error in
            guard case WSZArchiveError.invalidSkinStructure(let missing) = error else {
                XCTFail("Expected invalidSkinStructure error")
                return
            }
            XCTAssertTrue(missing.contains("main.bmp"))
        }
    }
    
    // MARK: - BMP Decoder Tests
    
    func testBMPDecodingSuccess() throws {
        let bmpData = try createSampleBMP()
        let image = try ClassicBMPDecoder.decode(bmpData)
        
        XCTAssertEqual(image.size.width, 100)
        XCTAssertEqual(image.size.height, 50)
    }
    
    func testMagentaTransparency() throws {
        let bmpData = try createBMPWithMagenta()
        let image = try ClassicBMPDecoder.decode(bmpData)
        
        // Verify transparency was applied
        XCTAssertTrue(ClassicBMPDecoder.validateTransparency(in: image))
    }
    
    func testSpriteExtraction() throws {
        let bmpData = try createSampleBMP()
        let sourceImage = try ClassicBMPDecoder.decode(bmpData)
        
        // Extract a small sprite
        let spriteRect = CGRect(x: 10, y: 10, width: 20, height: 20)
        let sprite = ClassicBMPDecoder.extractSprite(from: sourceImage, rect: spriteRect)
        
        XCTAssertNotNil(sprite)
        XCTAssertEqual(sprite?.size.width, 20)
        XCTAssertEqual(sprite?.size.height, 20)
    }
    
    // MARK: - Sprite Sheet Tests
    
    func testSpriteSheetCreation() throws {
        let bmpData = try createSampleBMP()
        let sourceImage = try ClassicBMPDecoder.decode(bmpData)
        
        let spriteMap = [
            "button1": CGRect(x: 0, y: 0, width: 25, height: 25),
            "button2": CGRect(x: 25, y: 0, width: 25, height: 25)
        ]
        
        let spriteSheet = SpriteSheet(sourceImage: sourceImage, spriteMap: spriteMap)
        
        XCTAssertEqual(spriteSheet.availableSprites.count, 2)
        XCTAssertTrue(spriteSheet.availableSprites.contains("button1"))
        XCTAssertTrue(spriteSheet.availableSprites.contains("button2"))
    }
    
    func testSpriteSheetLazyLoading() throws {
        let bmpData = try createSampleBMP()
        let sourceImage = try ClassicBMPDecoder.decode(bmpData)
        
        let spriteMap = ["testSprite": CGRect(x: 0, y: 0, width: 20, height: 20)]
        let spriteSheet = SpriteSheet(sourceImage: sourceImage, spriteMap: spriteMap)
        
        // First access should create and cache the sprite
        let sprite1 = spriteSheet.sprite(named: "testSprite")
        let sprite2 = spriteSheet.sprite(named: "testSprite")
        
        XCTAssertNotNil(sprite1)
        XCTAssertNotNil(sprite2)
        // Should be the same cached instance
        XCTAssertTrue(sprite1 === sprite2)
    }
    
    func testMainWindowSpriteMap() throws {
        let bmpData = try createMainBMP()
        let sourceImage = try ClassicBMPDecoder.decode(bmpData)
        
        let spriteSheet = MainWindowSpriteMap.createSpriteSheet(from: sourceImage)
        
        // Verify key sprites are available
        XCTAssertNotNil(spriteSheet.sprite(named: "titlebar"))
        XCTAssertNotNil(spriteSheet.sprite(named: "background"))
        XCTAssertNotNil(spriteSheet.sprite(named: "transportBackground"))
    }
    
    // MARK: - Test Data Creation Helpers
    
    private func createSampleWSZ() throws -> URL {
        let wszURL = testDataDirectory.appendingPathComponent("test_skin.wsz")
        
        // Create temporary directory with skin files
        let tempSkinDir = testDataDirectory.appendingPathComponent("temp_skin")
        try FileManager.default.createDirectory(at: tempSkinDir, withIntermediateDirectories: true)
        
        // Create minimal required files
        try createSampleBMP().write(to: tempSkinDir.appendingPathComponent("main.bmp"))
        try createSampleBMP().write(to: tempSkinDir.appendingPathComponent("cbuttons.bmp"))
        try createSampleBMP().write(to: tempSkinDir.appendingPathComponent("playpaus.bmp"))
        try "1".data(using: .utf8)!.write(to: tempSkinDir.appendingPathComponent("region.txt"))
        
        // Create ZIP archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", wszURL.path, "."]
        process.currentDirectoryURL = tempSkinDir
        
        try process.run()
        process.waitUntilExit()
        
        // Clean up temp directory
        try FileManager.default.removeItem(at: tempSkinDir)
        
        return wszURL
    }
    
    private func createIncompleteWSZ() throws -> URL {
        let wszURL = testDataDirectory.appendingPathComponent("incomplete_skin.wsz")
        
        let tempSkinDir = testDataDirectory.appendingPathComponent("temp_incomplete")
        try FileManager.default.createDirectory(at: tempSkinDir, withIntermediateDirectories: true)
        
        // Only create some files (missing main.bmp)
        try createSampleBMP().write(to: tempSkinDir.appendingPathComponent("cbuttons.bmp"))
        try "1".data(using: .utf8)!.write(to: tempSkinDir.appendingPathComponent("region.txt"))
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", wszURL.path, "."]
        process.currentDirectoryURL = tempSkinDir
        
        try process.run()
        process.waitUntilExit()
        
        try FileManager.default.removeItem(at: tempSkinDir)
        
        return wszURL
    }
    
    private func createSampleBMP() throws -> Data {
        // Create a simple 100x50 BMP in memory
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
        
        // Fill with blue color
        for y in 0..<height {
            for x in 0..<width {
                bitmapRep.setColor(.blue, atX: x, y: y)
            }
        }
        
        guard let bmpData = bitmapRep.representation(using: .bmp, properties: [:]) else {
            throw TestError.bmpDataCreationFailed
        }
        
        return bmpData
    }
    
    private func createBMPWithMagenta() throws -> Data {
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
        
        // Fill with alternating blue and magenta
        for y in 0..<height {
            for x in 0..<width {
                let color = (x + y) % 2 == 0 ? NSColor.blue : ClassicBMPDecoder.transparentMagenta
                bitmapRep.setColor(color, atX: x, y: y)
            }
        }
        
        guard let bmpData = bitmapRep.representation(using: .bmp, properties: [:]) else {
            throw TestError.bmpDataCreationFailed
        }
        
        return bmpData
    }
    
    private func createMainBMP() throws -> Data {
        // Create a 275x116 BMP matching WinAmp main window dimensions
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
        
        return bmpData
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case bitmapCreationFailed
    case bmpDataCreationFailed
}
