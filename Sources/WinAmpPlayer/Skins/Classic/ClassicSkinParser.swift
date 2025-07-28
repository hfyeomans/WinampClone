import Foundation
import AppKit
import CoreGraphics

/// Orchestrates the complete parsing of WinAmp .wsz skin files
/// Combines WSZ extraction, BMP decoding, sprite extraction, and region parsing
public class ClassicSkinParser {
    public let skinURL: URL
    private var archive: ClassicWSZArchive?
    
    /// Required files for a valid WinAmp skin
    private static let requiredFiles = [
        "main.bmp",
        "cbuttons.bmp", 
        "playpaus.bmp",
        "region.txt"
    ]
    
    /// Optional files that enhance the skin
    private static let optionalFiles = [
        "monoster.bmp",
        "nums_ex.bmp",
        "volume.bmp",
        "balance.bmp",
        "posbar.bmp",
        "shufrep.bmp",
        "text.bmp",
        "titlebar.bmp",
        "eq_main.bmp",
        "pledit.bmp"
    ]
    
    public init(skinURL: URL) {
        self.skinURL = skinURL
    }
    
    /// Parse the skin and return a complete ClassicParsedSkin object
    public func parse() async throws -> ClassicParsedSkin {
        // Step 1: Extract WSZ archive
        let archive = try ClassicWSZArchive(url: skinURL)
        self.archive = archive
        
        // Step 2: Validate required files
        try archive.validateSkinStructure()
        
        // Step 3: Parse region mask
        let regionMask = try parseRegionMask(from: archive)
        
        // Step 4: Parse all BMP files and create sprite sheets
        let spriteSheets = try await parseSpriteSheets(from: archive)
        
        // Step 5: Extract metadata
        let metadata = try parseMetadata(from: archive)
        
        // Step 6: Create ClassicParsedSkin object
        let parsedSkin = ClassicParsedSkin(
            url: skinURL,
            name: metadata.name,
            author: metadata.author,
            spriteSheets: spriteSheets,
            regionMask: regionMask,
            metadata: metadata
        )
        
        return parsedSkin
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseRegionMask(from archive: ClassicWSZArchive) throws -> RegionMask {
        guard let regionData = try? archive.data(for: "region.txt") else {
            // Create fallback rectangular region
            return RegionMask.createStandardMainWindow()
        }
        
        do {
            let regionMask = try RegionMask(data: regionData)
            try regionMask.validateMainWindowRegion()
            return regionMask
        } catch {
            print("[WinAmpPlayer] Invalid region.txt, using rectangular fallback: \(error)")
            return RegionMask.createStandardMainWindow()
        }
    }
    
    private func parseSpriteSheets(from archive: ClassicWSZArchive) async throws -> [String: SpriteSheet] {
        var spriteSheets: [String: SpriteSheet] = [:]
        
        // Parse main.bmp - the primary skin image
        if let mainData = try? archive.data(for: "main.bmp") {
            let mainImage = try ClassicBMPDecoder.decode(mainData)
            spriteSheets["main"] = MainWindowSpriteMap.createSpriteSheet(from: mainImage)
        } else {
            throw ClassicSkinParsingError.missingRequiredFile("main.bmp")
        }
        
        // Parse cbuttons.bmp - transport control buttons
        if let cbuttonsData = try? archive.data(for: "cbuttons.bmp") {
            let cbuttonsImage = try ClassicBMPDecoder.decode(cbuttonsData)
            spriteSheets["cbuttons"] = TransportButtonSpriteMap.createSpriteSheet(from: cbuttonsImage)
        } else {
            throw ClassicSkinParsingError.missingRequiredFile("cbuttons.bmp")
        }
        
        // Parse playpaus.bmp - play/pause indicator
        if let playPausData = try? archive.data(for: "playpaus.bmp") {
            let playPausImage = try ClassicBMPDecoder.decode(playPausData)
            spriteSheets["playpaus"] = PlayPauseSpriteMap.createSpriteSheet(from: playPausImage)
        } else {
            throw ClassicSkinParsingError.missingRequiredFile("playpaus.bmp")
        }
        
        // Parse optional files
        for optionalFile in Self.optionalFiles {
            if let data = try? archive.data(for: optionalFile),
               let image = try? ClassicBMPDecoder.decode(data) {
                
                // Create appropriate sprite sheet based on file type
                let spriteSheet = createSpriteSheetForFile(optionalFile, image: image)
                spriteSheets[optionalFile.replacingOccurrences(of: ".bmp", with: "")] = spriteSheet
            }
        }
        
        return spriteSheets
    }
    
    private func createSpriteSheetForFile(_ filename: String, image: NSImage) -> SpriteSheet {
        switch filename {
        case "monoster.bmp":
            return MonoStereoSpriteMap.createSpriteSheet(from: image)
        case "nums_ex.bmp":
            return NumbersSpriteMap.createSpriteSheet(from: image)
        case "volume.bmp", "balance.bmp":
            return SliderSpriteMap.createSpriteSheet(from: image)
        case "posbar.bmp":
            return SeekBarSpriteMap.createSpriteSheet(from: image)
        case "shufrep.bmp":
            return ShuffleRepeatSpriteMap.createSpriteSheet(from: image)
        case "text.bmp":
            return TextSpriteMap.createSpriteSheet(from: image)
        default:
            // Generic sprite sheet - treat as single sprite
            return SpriteSheet(sourceImage: image, spriteMap: [
                "full": CGRect(origin: .zero, size: image.size)
            ])
        }
    }
    
    private func parseMetadata(from archive: ClassicWSZArchive) throws -> SkinMetadata {
        // Try to read skin metadata from pledit.txt or other info files
        var name = skinURL.deletingPathExtension().lastPathComponent
        var author = "Unknown"
        var version = "1.0"
        var description = ""
        
        // Check for pledit.txt (playlist editor info)
        if let pleditData = try? archive.data(for: "pledit.txt"),
           let pleditText = String(data: pleditData, encoding: .utf8) {
            // Parse metadata from pledit.txt if available
            let lines = pleditText.components(separatedBy: .newlines)
            for line in lines {
                if line.lowercased().contains("name") {
                    name = extractMetadataValue(from: line) ?? name
                } else if line.lowercased().contains("author") {
                    author = extractMetadataValue(from: line) ?? author
                }
            }
        }
        
        // Check for readme.txt
        if let readmeData = try? archive.data(for: "readme.txt"),
           let readmeText = String(data: readmeData, encoding: .utf8) {
            description = readmeText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return SkinMetadata(
            name: name,
            author: author,
            version: version,
            description: description,
            creationDate: Date(),
            supportedVersion: "2.x"
        )
    }
    
    private func extractMetadataValue(from line: String) -> String? {
        // Extract value after '=' or ':'
        let separators = ["=", ":"]
        for separator in separators {
            if let range = line.range(of: separator) {
                return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

// MARK: - Additional Sprite Maps

/// Mono/Stereo indicator sprite map
public struct MonoStereoSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "stereo": CGRect(x: 0, y: 0, width: 29, height: 12),
        "mono": CGRect(x: 29, y: 0, width: 29, height: 12)
    ]
    
    public static func createSpriteSheet(from image: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: image, spriteMap: spriteMap)
    }
}

/// Numbers display sprite map (for time display)
public struct NumbersSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "0": CGRect(x: 0, y: 0, width: 9, height: 13),
        "1": CGRect(x: 9, y: 0, width: 9, height: 13),
        "2": CGRect(x: 18, y: 0, width: 9, height: 13),
        "3": CGRect(x: 27, y: 0, width: 9, height: 13),
        "4": CGRect(x: 36, y: 0, width: 9, height: 13),
        "5": CGRect(x: 45, y: 0, width: 9, height: 13),
        "6": CGRect(x: 54, y: 0, width: 9, height: 13),
        "7": CGRect(x: 63, y: 0, width: 9, height: 13),
        "8": CGRect(x: 72, y: 0, width: 9, height: 13),
        "9": CGRect(x: 81, y: 0, width: 9, height: 13),
        "colon": CGRect(x: 90, y: 0, width: 9, height: 13),
        "minus": CGRect(x: 99, y: 0, width: 9, height: 13)
    ]
    
    public static func createSpriteSheet(from image: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: image, spriteMap: spriteMap)
    }
}

/// Volume/Balance slider sprite map
public struct SliderSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "background": CGRect(x: 0, y: 0, width: 68, height: 13),
        "thumb": CGRect(x: 0, y: 14, width: 14, height: 11)
    ]
    
    public static func createSpriteSheet(from image: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: image, spriteMap: spriteMap)
    }
}

/// Seek bar sprite map
public struct SeekBarSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "background": CGRect(x: 0, y: 0, width: 248, height: 10),
        "thumb": CGRect(x: 248, y: 0, width: 29, height: 10)
    ]
    
    public static func createSpriteSheet(from image: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: image, spriteMap: spriteMap)
    }
}

/// Shuffle/Repeat button sprite map
public struct ShuffleRepeatSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "shuffle_off": CGRect(x: 0, y: 0, width: 28, height: 15),
        "shuffle_on": CGRect(x: 28, y: 0, width: 28, height: 15),
        "repeat_off": CGRect(x: 0, y: 15, width: 28, height: 15),
        "repeat_on": CGRect(x: 28, y: 15, width: 28, height: 15)
    ]
    
    public static func createSpriteSheet(from image: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: image, spriteMap: spriteMap)
    }
}

/// Text display sprite map
public struct TextSpriteMap {
    public static let spriteMap: [String: CGRect] = [
        "background": CGRect(x: 0, y: 0, width: 155, height: 6)
    ]
    
    public static func createSpriteSheet(from image: NSImage) -> SpriteSheet {
        return SpriteSheet(sourceImage: image, spriteMap: spriteMap)
    }
}

// MARK: - Supporting Types

/// Parsed skin data from ClassicSkinParser
public class ClassicParsedSkin: ParsedSkinProtocol {
    public let url: URL
    public let name: String
    public let author: String
    public let spriteSheets: [String: SpriteSheet]
    public let regionMask: RegionMask
    public let metadata: SkinMetadata
    
    /// Extracted sprites mapped by name for quick access
    private var _sprites: [String: NSImage] = [:]
    
    public init(url: URL, name: String, author: String, spriteSheets: [String: SpriteSheet], regionMask: RegionMask, metadata: SkinMetadata) {
        self.url = url
        self.name = name
        self.author = author
        self.spriteSheets = spriteSheets
        self.regionMask = regionMask
        self.metadata = metadata
    }
    
    /// Get sprite by name (lazy loading)
    public func sprite(named name: String) -> NSImage? {
        if let cached = _sprites[name] {
            return cached
        }
        
        // Search through all sprite sheets
        for (_, spriteSheet) in spriteSheets {
            if let sprite = spriteSheet.sprite(named: name) {
                _sprites[name] = sprite
                return sprite
            }
        }
        
        return nil
    }
    
    /// Get all available sprite names
    public var availableSprites: [String] {
        var names: [String] = []
        for (_, spriteSheet) in spriteSheets {
            names.append(contentsOf: spriteSheet.availableSprites)
        }
        return names
    }
    
    /// Compatibility with existing skin system
    public var sprites: [String: NSImage] {
        var allSprites: [String: NSImage] = [:]
        for spriteName in availableSprites {
            if let sprite = self.sprite(named: spriteName) {
                allSprites[spriteName] = sprite
            }
        }
        return allSprites
    }
    
    // MARK: - ParsedSkinProtocol Conformance
    
    /// Bitmaps for protocol compatibility (synthesized from sprite sheets)
    public var bitmaps: [String: NSImage] {
        var allBitmaps: [String: NSImage] = [:]
        for (sheetName, spriteSheet) in spriteSheets {
            allBitmaps[sheetName] = spriteSheet.sourceImage
        }
        return allBitmaps
    }
    
    /// Configurations for protocol compatibility
    public var configurations: [String: String] {
        return [
            "name": name,
            "author": author,
            "version": metadata.version,
            "description": metadata.description
        ]
    }
}

/// Skin metadata information
public struct SkinMetadata {
    public let name: String
    public let author: String
    public let version: String
    public let description: String
    public let creationDate: Date
    public let supportedVersion: String
    
    public init(name: String, author: String, version: String, description: String, creationDate: Date, supportedVersion: String) {
        self.name = name
        self.author = author
        self.version = version
        self.description = description
        self.creationDate = creationDate
        self.supportedVersion = supportedVersion
    }
}

// MARK: - Error Types

public enum ClassicSkinParsingError: LocalizedError {
    case missingRequiredFile(String)
    case invalidSkinStructure
    case bmpDecodingFailed(String, Error)
    case regionParsingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredFile(let filename):
            return "Missing required file: \(filename)"
        case .invalidSkinStructure:
            return "Invalid skin structure"
        case .bmpDecodingFailed(let filename, let error):
            return "Failed to decode \(filename): \(error.localizedDescription)"
        case .regionParsingFailed(let error):
            return "Failed to parse region mask: \(error.localizedDescription)"
        }
    }
}
