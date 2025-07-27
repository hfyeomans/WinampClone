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
        await skinQueue.async {
            do {
                // Generate classic skin assets
                let assets = ClassicSkinGenerator.generateClassicSkin()
                
                // Create skin directory
                let classicSkinDir = self.skinsDirectory.appendingPathComponent("Classic")
                try? FileManager.default.createDirectory(at: classicSkinDir, withIntermediateDirectories: true)
                
                // Save assets to disk
                for (filename, image) in assets {
                    let fileURL = classicSkinDir.appendingPathComponent(filename)
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData) {
                        let data = bitmap.representation(using: .bmp, properties: [:])
                        try? data?.write(to: fileURL)
                    }
                }
                
                // Create skin info file
                let skinInfo = """
                [WinampSkin]
                Name=Classic
                Author=WinAmpPlayer
                Version=1.0
                Description=Classic WinAmp 2.x skin
                """
                
                let infoURL = classicSkinDir.appendingPathComponent("skin.txt")
                try? skinInfo.write(to: infoURL, atomically: true, encoding: .utf8)
                
                // Load the classic skin
                await self.loadSkin(named: "Classic")
                
            } catch {
                print("Failed to generate classic skin: \(error)")
            }
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
            let parser = SkinParser()
            let skin = try await parser.parseSkinDirectory(directory)
            
            // Cache the skin
            let cachedSkin = try await SkinAssetCache.shared.cacheSkin(skin)
            
            // Update current skin
            await MainActor.run {
                self.currentCachedSkin = cachedSkin
                self.currentSkin = skin
                
                // Notify observers
                NotificationCenter.default.post(name: .skinWillChange, object: self)
                NotificationCenter.default.post(name: .skinDidChange, object: self)
            }
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
        // TODO: Implement ZIP extraction and loading
        print("Loading from WSZ/ZIP not yet implemented: \(file)")
    }
}

/// Extension to load sprites from current skin
extension SkinManager {
    
    /// Get a sprite from the current skin
    public func getSprite(_ type: SpriteType) -> NSImage? {
        // First try cached skin
        if let cached = currentCachedSkin {
            return cached.getSprite(type)
        }
        
        // Fall back to default skin
        return DefaultSkin.shared.getSprite(type)
    }
    
    /// Get skin configuration
    public func getSkinConfiguration() -> SkinConfiguration {
        return currentSkin.configuration ?? SkinConfiguration()
    }
}