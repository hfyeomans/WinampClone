//
//  ClassicSkinLoader.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Loads and manages the classic WinAmp skin
//

import Foundation
import AppKit

/// Extension to SkinManager for classic skin loading
extension SkinManager {
    
    /// Generate and install the classic WinAmp skin
    public func generateClassicSkin() async {
        do {
            // Generate classic skin assets (writes to disk directly)
            try await ClassicSkinGenerator.generateClassicSkin()
            
            // Load the classic skin
            await self.loadSkin(named: "Classic")
            
        } catch {
            print("Failed to generate classic skin: \(error)")
        }
    }
    
    /// Load a skin by name
    public func loadSkin(named name: String) async {
        // Check if it's the default skin
        if name == "Default" {
            await loadDefaultSkin()
            return
        }
        
        // Look for the skin in available directories
        for directory in skinDirectories {
            let skinPath = directory.appendingPathComponent(name)
            let skinFile = directory.appendingPathComponent("\(name).wsz")
            let zipFile = directory.appendingPathComponent("\(name).zip")
            
            if FileManager.default.fileExists(atPath: skinPath.path) {
                // Load directory-based skin
                await loadSkinFromDirectory(skinPath)
                return
            } else if FileManager.default.fileExists(atPath: skinFile.path) {
                // Load WSZ file
                await loadSkinFromFile(skinFile)
                return
            } else if FileManager.default.fileExists(atPath: zipFile.path) {
                // Load ZIP file
                await loadSkinFromFile(zipFile)
                return
            }
        }
        
        print("Skin not found: \(name)")
    }
    
    /// Load skin from directory
    private func loadSkinFromDirectory(_ directory: URL) async {
        do {
            // Parse skin
            let parser = try SkinParser()
            let parsedSkin = try await parser.parseSkin(from: directory)
            
            // Create Skin object from ParsedSkin
            let skin = Skin(
                name: parsedSkin.name,
                url: directory,
                isDefault: false
            )
            
            // Cache the parsed skin data
            let cachedSkin = try await SkinAssetCache.shared.loadSkin(from: directory)
            
            // Update current skin through applySkin method
            currentCachedSkin = cachedSkin
            try await applySkin(skin)
        } catch {
            print("Failed to load skin from directory: \(error)")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .skinLoadingFailed,
                    object: self,
                    userInfo: ["error": error]
                )
            }
        }
    }
    
    /// Load skin from WSZ/ZIP file
    private func loadSkinFromFile(_ file: URL) async {
        do {
            // Use our new ClassicSkinParser
            let parser = ClassicSkinParser(skinURL: file)
            let parsedSkin = try await parser.parse()
            
            // Create Skin object from parsed data
            let skin = Skin(
                name: parsedSkin.name,
                url: file,
                isDefault: false,
                author: parsedSkin.author,
                version: parsedSkin.version
            )
            
            // Store parsed data for use by other components
            await SkinAssetCache.shared.cacheSkin(parsedSkin, for: file)
            
            // Apply the skin using the proper method
            try await applySkin(skin)
            
            print("✅ Successfully loaded WSZ skin: \(parsedSkin.name) by \(parsedSkin.author)")
            
        } catch {
            print("❌ Failed to load WSZ skin: \(error)")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .skinLoadingFailed,
                    object: self,
                    userInfo: ["error": error, "file": file]
                )
            }
        }
    }
}

/// Extension to load skin configuration
extension SkinManager {
    
    /// Get skin configuration
    public func getSkinConfiguration() -> SkinConfiguration {
        guard let cachedSkin = currentCachedSkin else {
            return SkinConfiguration.defaultConfiguration
        }
        
        // Convert cached skin data to configuration format
        let playlistColors = PlaylistColors.default
        let visualizationColors = VisualizationColors.defaultColors
        let buttonRegions: [String: ButtonRegion] = 
            Dictionary(uniqueKeysWithValues: (cachedSkin.buttonRegions ?? []).map { ($0.name, $0) })
        
        return SkinConfiguration(
            playlistColors: playlistColors,
            visualizationColors: visualizationColors,
            buttonRegions: buttonRegions,
            fontName: cachedSkin.configurations["font"]
        )
    }
}