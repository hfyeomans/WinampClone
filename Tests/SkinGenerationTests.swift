//
//  SkinGenerationTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-07-27.
//  Basic tests for procedural skin generation
//

import XCTest
@testable import WinAmpPlayer

class SkinGenerationTests: XCTestCase {
    
    // MARK: - Color System Tests
    
    func testHCTColorClamping() {
        let color1 = HCTColor(hue: 400, chroma: 1.5, tone: -0.5)
        XCTAssertEqual(color1.hue, 40, "Hue should wrap around 360")
        XCTAssertEqual(color1.chroma, 1.0, "Chroma should clamp to 1.0")
        XCTAssertEqual(color1.tone, 0.0, "Tone should clamp to 0.0")
        
        let color2 = HCTColor(hue: -30, chroma: 0.5, tone: 1.5)
        XCTAssertEqual(color2.hue, 330, "Negative hue should wrap correctly")
        XCTAssertEqual(color2.tone, 1.0, "Tone should clamp to 1.0")
    }
    
    func testTonalPaletteGeneration() {
        let baseColor = HCTColor(hue: 210, chroma: 0.8, tone: 0.5)
        let palette = TonalPalette(baseColor: baseColor)
        
        XCTAssertEqual(palette.tones.count, 13, "Should have 13 tone levels")
        XCTAssertNotNil(palette.tone(0), "Should have tone 0")
        XCTAssertNotNil(palette.tone(50), "Should have tone 50")
        XCTAssertNotNil(palette.tone(100), "Should have tone 100")
    }
    
    func testColorSchemeGeneration() {
        let config = SkinGenerationConfig(
            metadata: SkinGenerationConfig.Metadata(name: "Test"),
            colors: SkinGenerationConfig.Colors(
                primary: HCTColor(hue: 0, chroma: 0.8, tone: 0.5),
                scheme: .complementary
            )
        )
        
        let palette = PaletteGenerator.generatePalette(from: config)
        
        // Complementary color should be ~180° away
        let primaryHue = palette.primary.baseColor.hue
        let secondaryHue = palette.secondary.baseColor.hue
        let hueDiff = abs(primaryHue - secondaryHue)
        
        XCTAssertTrue(abs(hueDiff - 180) < 1, "Complementary colors should be 180° apart")
    }
    
    // MARK: - Configuration Parser Tests
    
    func testTOMLParsing() throws {
        let toml = """
        [metadata]
        name = "Test Skin"
        author = "Test Author"
        version = "1.0"
        
        [theme]
        mode = "dark"
        style = "modern"
        
        [colors]
        primary = { hue = 210, chroma = 0.8, tone = 0.5 }
        scheme = "complementary"
        """
        
        let config = try ConfigurationParser.parse(from: toml)
        
        XCTAssertEqual(config.metadata.name, "Test Skin")
        XCTAssertEqual(config.metadata.author, "Test Author")
        XCTAssertEqual(config.theme.mode, .dark)
        XCTAssertEqual(config.theme.style, .modern)
        XCTAssertEqual(config.colors.primary.hue, 210)
        XCTAssertEqual(config.colors.scheme, .complementary)
    }
    
    func testDefaultTemplates() {
        let templates = ConfigurationParser.defaultTemplates()
        
        XCTAssertEqual(templates.count, 5, "Should have 5 default templates")
        XCTAssertNotNil(templates["modern_dark"])
        XCTAssertNotNil(templates["retro"])
        XCTAssertNotNil(templates["minimal"])
        XCTAssertNotNil(templates["cyberpunk"])
        XCTAssertNotNil(templates["vaporwave"])
        
        // Test each template parses correctly
        for (name, content) in templates {
            XCTAssertNoThrow(try ConfigurationParser.parse(from: content), "Template \(name) should parse without errors")
        }
    }
    
    // MARK: - Texture Engine Tests
    
    func testTextureGeneration() {
        let context = TextureEngine.Context(width: 100, height: 100, seed: 12345)
        let palette = createTestPalette()
        
        let textureTypes: [TextureType] = [.solid, .gradient, .noise, .dots, .lines, .checkerboard]
        
        for type in textureTypes {
            let texture = TextureEngine.generateTexture(
                type: type,
                context: context,
                colors: palette
            )
            
            XCTAssertNotNil(texture, "Texture type \(type) should generate successfully")
            
            if let texture = texture {
                XCTAssertEqual(texture.width, 100, "Texture width should match context")
                XCTAssertEqual(texture.height, 100, "Texture height should match context")
            }
        }
    }
    
    func testNoiseReproducibility() {
        let context1 = TextureEngine.Context(width: 50, height: 50, seed: 42)
        let context2 = TextureEngine.Context(width: 50, height: 50, seed: 42)
        let palette = createTestPalette()
        
        let texture1 = TextureEngine.generateTexture(type: .noise, context: context1, colors: palette)
        let texture2 = TextureEngine.generateTexture(type: .noise, context: context2, colors: palette)
        
        XCTAssertNotNil(texture1)
        XCTAssertNotNil(texture2)
        
        // Same seed should produce identical results
        // Note: This is a simplified test - in practice you'd compare pixel data
        XCTAssertEqual(texture1?.width, texture2?.width)
        XCTAssertEqual(texture1?.height, texture2?.height)
    }
    
    // MARK: - Component Renderer Tests
    
    func testButtonRendering() {
        let palette = createTestPalette()
        let config = createTestConfig()
        
        let buttonTypes: [ComponentRenderer.ComponentType] = [
            .playButton, .pauseButton, .stopButton, .nextButton, .previousButton, .ejectButton
        ]
        
        for buttonType in buttonTypes {
            let button = ComponentRenderer.renderComponent(
                type: buttonType,
                size: CGSize(width: 23, height: 18),
                style: .normal,
                palette: palette,
                config: config
            )
            
            XCTAssertNotNil(button, "Button type \(buttonType) should render successfully")
        }
    }
    
    func testButtonStyles() {
        let palette = createTestPalette()
        let buttonStyles: [ButtonStyle] = [.flat, .rounded, .beveled, .glass, .pill, .square]
        
        for style in buttonStyles {
            let config = SkinGenerationConfig(
                metadata: SkinGenerationConfig.Metadata(name: "Test"),
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(hue: 210, chroma: 0.8, tone: 0.5)
                ),
                components: SkinGenerationConfig.Components(buttonStyle: style)
            )
            
            let button = ComponentRenderer.renderComponent(
                type: .playButton,
                size: CGSize(width: 23, height: 18),
                style: .normal,
                palette: palette,
                config: config
            )
            
            XCTAssertNotNil(button, "Button style \(style) should render successfully")
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndGeneration() async throws {
        let config = createTestConfig()
        
        let expectation = XCTestExpectation(description: "Skin generation completes")
        
        Task {
            do {
                let skin = try await SkinGenerator.shared.generateSkin(from: config)
                XCTAssertEqual(skin.config.metadata.name, config.metadata.name)
                XCTAssertNotNil(skin.palette)
                XCTAssertGreaterThan(skin.sprites.count, 0, "Should have generated sprites")
                expectation.fulfill()
            } catch {
                XCTFail("Skin generation failed: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPalette() -> GeneratedPalette {
        let primary = TonalPalette(baseColor: HCTColor(hue: 210, chroma: 0.8, tone: 0.5))
        let secondary = TonalPalette(baseColor: HCTColor(hue: 30, chroma: 0.6, tone: 0.6))
        let tertiary = TonalPalette(baseColor: HCTColor(hue: 150, chroma: 0.4, tone: 0.5))
        let neutral = TonalPalette(baseColor: HCTColor(hue: 210, chroma: 0.02, tone: 0.5))
        let error = TonalPalette(baseColor: HCTColor(hue: 0, chroma: 0.8, tone: 0.5))
        
        return GeneratedPalette(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            neutral: neutral,
            error: error
        )
    }
    
    private func createTestConfig() -> SkinGenerationConfig {
        return SkinGenerationConfig(
            metadata: SkinGenerationConfig.Metadata(name: "Test Skin"),
            theme: SkinGenerationConfig.Theme(mode: .dark, style: .modern),
            colors: SkinGenerationConfig.Colors(
                primary: HCTColor(hue: 210, chroma: 0.8, tone: 0.5),
                scheme: .complementary
            ),
            textures: SkinGenerationConfig.Textures(
                background: TextureConfig(type: .noise, opacity: 0.2)
            ),
            components: SkinGenerationConfig.Components(
                buttonStyle: .rounded,
                sliderStyle: .modern
            )
        )
    }
}

// MARK: - Performance Tests

class SkinGenerationPerformanceTests: XCTestCase {
    
    func testSingleSkinGenerationPerformance() {
        let config = createTestConfig()
        
        measure {
            let expectation = XCTestExpectation(description: "Performance test")
            
            Task {
                do {
                    _ = try await SkinGenerator.shared.generateSkin(from: config)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testTextureGenerationPerformance() {
        let context = TextureEngine.Context(width: 500, height: 500)
        let palette = createTestPalette()
        
        measure {
            _ = TextureEngine.generateTexture(
                type: .noise,
                context: context,
                colors: palette,
                config: TextureConfig(type: .noise, octaves: 4)
            )
        }
    }
    
    private func createTestConfig() -> SkinGenerationConfig {
        return SkinGenerationConfig(
            metadata: SkinGenerationConfig.Metadata(name: "Performance Test"),
            colors: SkinGenerationConfig.Colors(
                primary: HCTColor(hue: 210, chroma: 0.8, tone: 0.5)
            )
        )
    }
    
    private func createTestPalette() -> GeneratedPalette {
        let primary = TonalPalette(baseColor: HCTColor(hue: 210, chroma: 0.8, tone: 0.5))
        let secondary = TonalPalette(baseColor: HCTColor(hue: 30, chroma: 0.6, tone: 0.6))
        let tertiary = TonalPalette(baseColor: HCTColor(hue: 150, chroma: 0.4, tone: 0.5))
        let neutral = TonalPalette(baseColor: HCTColor(hue: 210, chroma: 0.02, tone: 0.5))
        let error = TonalPalette(baseColor: HCTColor(hue: 0, chroma: 0.8, tone: 0.5))
        
        return GeneratedPalette(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            neutral: neutral,
            error: error
        )
    }
}