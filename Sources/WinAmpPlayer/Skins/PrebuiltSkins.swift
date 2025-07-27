//
//  PrebuiltSkins.swift
//  WinAmpPlayer
//
//  Pre-built skin configurations
//

import Foundation

extension SkinManager {
    /// Generate pre-built skins on first launch
    public func generatePrebuiltSkins() async {
        let prebuiltConfigs: [(name: String, config: SkinGenerationConfig)] = [
            ("Retro Green", SkinGenerationConfig(
                metadata: SkinGenerationConfig.Metadata(
                    name: "Retro Green",
                    author: "WinAmp Player",
                    version: "1.0",
                    description: "Classic green terminal style"
                ),
                theme: SkinGenerationConfig.Theme(
                    mode: .dark,
                    style: .retro
                ),
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(hue: 120, chroma: 80, tone: 50),
                    scheme: .monochromatic
                ),
                textures: SkinGenerationConfig.Textures(
                    background: TextureConfig(type: .lines, opacity: 0.15)
                ),
                components: SkinGenerationConfig.Components(
                    buttonStyle: .flat,
                    sliderStyle: .classic
                )
            )),
            
            ("Ocean Blue", SkinGenerationConfig(
                metadata: SkinGenerationConfig.Metadata(
                    name: "Ocean Blue",
                    author: "WinAmp Player",
                    version: "1.0",
                    description: "Deep ocean blues"
                ),
                theme: SkinGenerationConfig.Theme(
                    mode: .dark,
                    style: .modern
                ),
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(hue: 210, chroma: 90, tone: 40),
                    scheme: .analogous
                ),
                textures: SkinGenerationConfig.Textures(
                    background: TextureConfig(type: .gradient, opacity: 0.3)
                ),
                components: SkinGenerationConfig.Components(
                    buttonStyle: .rounded,
                    sliderStyle: .modern
                )
            )),
            
            ("Sunset Orange", SkinGenerationConfig(
                metadata: SkinGenerationConfig.Metadata(
                    name: "Sunset Orange",
                    author: "WinAmp Player",
                    version: "1.0",
                    description: "Warm sunset colors"
                ),
                theme: SkinGenerationConfig.Theme(
                    mode: .light,
                    style: .modern
                ),
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(hue: 30, chroma: 100, tone: 60),
                    scheme: .complementary
                ),
                textures: SkinGenerationConfig.Textures(
                    background: TextureConfig(type: .noise, opacity: 0.1)
                ),
                components: SkinGenerationConfig.Components(
                    buttonStyle: .rounded,
                    sliderStyle: .modern,
                    cornerRadius: 12
                )
            )),
            
            ("Cyber Purple", SkinGenerationConfig(
                metadata: SkinGenerationConfig.Metadata(
                    name: "Cyber Purple",
                    author: "WinAmp Player",
                    version: "1.0",
                    description: "Futuristic purple theme"
                ),
                theme: SkinGenerationConfig.Theme(
                    mode: .dark,
                    style: .cyberpunk
                ),
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(hue: 280, chroma: 95, tone: 45),
                    scheme: .triadic
                ),
                textures: SkinGenerationConfig.Textures(
                    background: TextureConfig(type: .circuit, opacity: 0.2)
                ),
                components: SkinGenerationConfig.Components(
                    buttonStyle: .glass,
                    sliderStyle: .minimal,
                    cornerRadius: 0
                )
            )),
            
            ("Minimal Gray", SkinGenerationConfig(
                metadata: SkinGenerationConfig.Metadata(
                    name: "Minimal Gray",
                    author: "WinAmp Player",
                    version: "1.0",
                    description: "Clean minimalist design"
                ),
                theme: SkinGenerationConfig.Theme(
                    mode: .auto,
                    style: .minimal
                ),
                colors: SkinGenerationConfig.Colors(
                    primary: HCTColor(hue: 0, chroma: 0, tone: 50),
                    scheme: .monochromatic
                ),
                textures: SkinGenerationConfig.Textures(),
                components: SkinGenerationConfig.Components(
                    buttonStyle: .flat,
                    sliderStyle: .minimal,
                    cornerRadius: 4
                )
            ))
        ]
        
        // Check if prebuilt skins already exist
        let prebuiltMarker = skinsDirectory.appendingPathComponent(".prebuilt_generated")
        if FileManager.default.fileExists(atPath: prebuiltMarker.path) {
            return
        }
        
        // Generate skins
        for (_, skinConfig) in prebuiltConfigs {
            do {
                _ = try await SkinGenerator.shared.generateSkin(from: skinConfig)
            } catch {
                print("Failed to generate prebuilt skin \(skinConfig.metadata.name): \(error)")
            }
        }
        
        // Mark as generated
        try? "".write(to: prebuiltMarker, atomically: true, encoding: .utf8)
        
        // Reload available skins
        loadAvailableSkins()
    }
}