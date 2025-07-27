//
//  SkinGenerator.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Main skin generation orchestrator
//

import Foundation
import Combine
import AppKit

/// Main skin generator that orchestrates the procedural generation process
@MainActor
public class SkinGenerator: ObservableObject {
    
    /// Shared instance
    public static let shared = SkinGenerator()
    
    /// Generation state
    public enum GeneratorState {
        case idle
        case generating(progress: Double)
        case completed(GeneratedSkin)
        case failed(Error)
    }
    
    /// Published properties
    @Published public private(set) var state: GeneratorState = .idle
    @Published public private(set) var availableTemplates: [String: String] = [:]
    @Published public private(set) var generatedSkins: [GeneratedSkin] = []
    @Published public var currentConfig: SkinGenerationConfig?
    
    /// Generation queue
    private let generationQueue = DispatchQueue(label: "com.winamp.skingeneration", qos: .userInitiated)
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize generator
    private init() {
        loadTemplates()
    }
    
    // MARK: - Public Methods
    
    /// Generate a skin from configuration
    public func generateSkin(from config: SkinGenerationConfig) async throws -> GeneratedSkin {
        state = .generating(progress: 0.0)
        
        do {
            // Update progress
            updateProgress(0.1, message: "Generating color palette...")
            
            // Generate palette
            let palette = PaletteGenerator.generatePalette(from: config)
            
            updateProgress(0.3, message: "Creating textures...")
            
            // Package skin (includes sprite generation)
            updateProgress(0.5, message: "Rendering components...")
            
            let outputURL = getSkinOutputURL(for: config.metadata.name)
            
            let skin = try await SkinPackager.packageSkin(
                config: config,
                palette: palette,
                outputURL: outputURL
            )
            
            updateProgress(0.9, message: "Finalizing...")
            
            // Add to generated skins
            generatedSkins.append(skin)
            
            // Install in skin manager
            if let skinInfo = try? await SkinManager.shared.installSkin(from: outputURL) {
                updateProgress(1.0, message: "Skin installed successfully")
            }
            
            state = .completed(skin)
            return skin
            
        } catch {
            state = .failed(error)
            throw error
        }
    }
    
    /// Generate skin from TOML string
    public func generateSkin(from tomlString: String) async throws -> GeneratedSkin {
        let config = try ConfigurationParser.parse(from: tomlString)
        return try await generateSkin(from: config)
    }
    
    /// Generate skin from template
    public func generateSkin(fromTemplate templateName: String) async throws -> GeneratedSkin {
        guard let templateContent = availableTemplates[templateName] else {
            throw GeneratorError.templateNotFound(templateName)
        }
        
        return try await generateSkin(from: templateContent)
    }
    
    /// Generate batch of skins with variations
    public func generateBatch(
        baseConfig: SkinGenerationConfig,
        count: Int,
        variations: BatchVariations = .all
    ) async throws -> [GeneratedSkin] {
        var generatedSkins: [GeneratedSkin] = []
        
        for i in 0..<count {
            updateProgress(
                Double(i) / Double(count),
                message: "Generating skin \(i + 1) of \(count)..."
            )
            
            let variedConfig = applyVariations(
                to: baseConfig,
                seed: UInt32(i),
                variations: variations
            )
            
            let skin = try await generateSkin(from: variedConfig)
            generatedSkins.append(skin)
        }
        
        return generatedSkins
    }
    
    /// Generate random skin
    public func generateRandomSkin() async throws -> GeneratedSkin {
        let config = generateRandomConfig()
        return try await generateSkin(from: config)
    }
    
    /// Load configuration from file
    public func loadConfiguration(from url: URL) throws -> SkinGenerationConfig {
        return try ConfigurationParser.parse(from: url)
    }
    
    /// Save configuration to file
    public func saveConfiguration(_ config: SkinGenerationConfig, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url)
    }
    
    // MARK: - Private Methods
    
    /// Load available templates
    private func loadTemplates() {
        availableTemplates = ConfigurationParser.defaultTemplates()
    }
    
    /// Update generation progress
    private func updateProgress(_ progress: Double, message: String) {
        Task { @MainActor in
            self.state = .generating(progress: progress)
        }
    }
    
    /// Get output URL for skin
    private func getSkinOutputURL(for name: String) -> URL {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        let skinsFolder = documentsPath.appendingPathComponent("GeneratedSkins")
        try? FileManager.default.createDirectory(
            at: skinsFolder,
            withIntermediateDirectories: true
        )
        
        let filename = "\(name.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).wsz"
        return skinsFolder.appendingPathComponent(filename)
    }
    
    /// Apply variations to configuration
    private func applyVariations(
        to config: SkinGenerationConfig,
        seed: UInt32,
        variations: BatchVariations
    ) -> SkinGenerationConfig {
        
        var rng = SeededRandom(seed: seed)
        var newConfig = config
        
        // Update metadata
        newConfig = SkinGenerationConfig(
            metadata: SkinGenerationConfig.Metadata(
                name: "\(config.metadata.name) Variant \(seed)",
                author: config.metadata.author,
                version: config.metadata.version,
                description: "Variant \(seed) of \(config.metadata.name)"
            ),
            theme: newConfig.theme,
            colors: newConfig.colors,
            textures: newConfig.textures,
            components: newConfig.components
        )
        
        // Apply color variations
        if variations.contains(.colors) {
            let hueShift = rng.random(in: -30...30)
            let chromaMultiplier = rng.random(in: 0.8...1.2)
            
            let primary = config.colors.primary
            newConfig = SkinGenerationConfig(
                metadata: newConfig.metadata,
                theme: newConfig.theme,
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(
                        hue: (primary.hue + hueShift).truncatingRemainder(dividingBy: 360),
                        chroma: min(1.0, primary.chroma * chromaMultiplier),
                        tone: primary.tone
                    ),
                    secondary: newConfig.colors.secondary,
                    tertiary: newConfig.colors.tertiary,
                    scheme: newConfig.colors.scheme
                ),
                textures: newConfig.textures,
                components: newConfig.components
            )
        }
        
        // Apply texture variations
        if variations.contains(.textures) {
            let textureTypes: [TextureType] = [.noise, .dots, .lines, .waves, .circuit]
            let randomTexture = textureTypes.randomElement(using: &rng) ?? .noise
            
            newConfig = SkinGenerationConfig(
                metadata: newConfig.metadata,
                theme: newConfig.theme,
                colors: newConfig.colors,
                textures: SkinGenerationConfig.Textures(
                    background: TextureConfig(
                        type: randomTexture,
                        scale: rng.random(in: 0.5...2.0),
                        opacity: rng.random(in: 0.1...0.3)
                    ),
                    overlay: newConfig.textures.overlay,
                    accent: newConfig.textures.accent
                ),
                components: newConfig.components
            )
        }
        
        // Apply component variations
        if variations.contains(.components) {
            let buttonStyles: [ButtonStyle] = [.flat, .rounded, .beveled, .glass, .pill]
            let sliderStyles: [SliderStyle] = [.classic, .modern, .minimal, .groove, .rail]
            
            newConfig = SkinGenerationConfig(
                metadata: newConfig.metadata,
                theme: newConfig.theme,
                colors: newConfig.colors,
                textures: newConfig.textures,
                components: SkinGenerationConfig.Components(
                    buttonStyle: buttonStyles.randomElement(using: &rng) ?? .rounded,
                    sliderStyle: sliderStyles.randomElement(using: &rng) ?? .modern,
                    cornerRadius: rng.random(in: 0...8),
                    borderWidth: rng.random(in: 0...2),
                    shadowSize: rng.random(in: 0...5)
                )
            )
        }
        
        return newConfig
    }
    
    /// Generate random configuration
    private func generateRandomConfig() -> SkinGenerationConfig {
        let themes: [ThemeMode] = [.dark, .light]
        let styles: [VisualStyle] = [.modern, .retro, .minimal, .glass, .cyberpunk, .vaporwave]
        let schemes: [ColorScheme] = [.monochromatic, .complementary, .analogous, .triadic]
        let buttonStyles: [ButtonStyle] = [.flat, .rounded, .beveled, .glass, .pill]
        let sliderStyles: [SliderStyle] = [.classic, .modern, .minimal, .groove, .rail]
        
        return SkinGenerationConfig(
            metadata: SkinGenerationConfig.Metadata(
                name: "Random Skin \(Int.random(in: 1000...9999))",
                author: "Random Generator",
                version: "1.0",
                description: "Randomly generated skin"
            ),
            theme: SkinGenerationConfig.Theme(
                mode: themes.randomElement()!,
                style: styles.randomElement()!
            ),
            colors: SkinGenerationConfig.Colors(
                primary: HCTColor(
                    hue: Double.random(in: 0...360),
                    chroma: Double.random(in: 0.3...1.0),
                    tone: Double.random(in: 0.3...0.7)
                ),
                scheme: schemes.randomElement()!
            ),
            textures: SkinGenerationConfig.Textures(
                background: Bool.random() ? TextureConfig(
                    type: [.noise, .gradient, .dots, .lines].randomElement()!,
                    scale: Double.random(in: 0.5...2.0),
                    opacity: Double.random(in: 0.1...0.3)
                ) : nil
            ),
            components: SkinGenerationConfig.Components(
                buttonStyle: buttonStyles.randomElement()!,
                sliderStyle: sliderStyles.randomElement()!,
                cornerRadius: Double.random(in: 0...8),
                borderWidth: Double.random(in: 0...2),
                shadowSize: Double.random(in: 0...5)
            )
        )
    }
}

// MARK: - Supporting Types

/// Batch variation options
public struct BatchVariations: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let colors = BatchVariations(rawValue: 1 << 0)
    public static let textures = BatchVariations(rawValue: 1 << 1)
    public static let components = BatchVariations(rawValue: 1 << 2)
    
    public static let all: BatchVariations = [.colors, .textures, .components]
}

/// Generator errors
public enum GeneratorError: LocalizedError {
    case templateNotFound(String)
    case generationFailed(String)
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let name):
            return "Template '\(name)' not found"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid configuration"
        }
    }
}

/// Seeded random number generator
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt32) {
        self.state = UInt64(seed)
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    mutating func random<T: BinaryFloatingPoint>(in range: ClosedRange<T>) -> T {
        let unit = T(next()) / T(UInt64.max)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Preview Support

extension SkinGenerator {
    
    /// Generate preview of configuration
    public func generatePreview(for config: SkinGenerationConfig) async -> NSImage? {
        // Generate just the main window for preview
        let palette = PaletteGenerator.generatePalette(from: config)
        
        guard let mainWindow = ComponentRenderer.renderComponent(
            type: .mainWindow,
            size: CGSize(width: 275, height: 116),
            style: .normal,
            palette: palette,
            config: config
        ) else { return nil }
        
        // Render some buttons on top
        let buttonTypes: [ComponentRenderer.ComponentType] = [
            .previousButton, .playButton, .pauseButton, .stopButton, .nextButton
        ]
        
        let image = NSImage(size: CGSize(width: 275, height: 116))
        image.lockFocus()
        
        // Draw main window
        NSGraphicsContext.current?.cgContext.draw(
            mainWindow,
            in: CGRect(x: 0, y: 0, width: 275, height: 116)
        )
        
        // Draw buttons
        var xOffset: CGFloat = 16
        let yOffset: CGFloat = 88
        
        for buttonType in buttonTypes {
            if let button = ComponentRenderer.renderComponent(
                type: buttonType,
                size: CGSize(width: 23, height: 18),
                style: .normal,
                palette: palette,
                config: config
            ) {
                NSGraphicsContext.current?.cgContext.draw(
                    button,
                    in: CGRect(x: xOffset, y: yOffset, width: 23, height: 18)
                )
                xOffset += 23
            }
        }
        
        image.unlockFocus()
        return image
    }
}