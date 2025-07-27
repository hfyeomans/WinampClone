//
//  SkinManager.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Manager for loading and applying skins
//

import Foundation
import AppKit
import SwiftUI
import Combine

/// Notification names for skin changes
extension Notification.Name {
    static let skinWillChange = Notification.Name("skinWillChange")
    static let skinDidChange = Notification.Name("skinDidChange")
    static let skinLoadingFailed = Notification.Name("skinLoadingFailed")
}

/// Manager for WinAmp skins
public class SkinManager: ObservableObject {
    /// Shared instance
    public static let shared = SkinManager()
    
    /// Currently active skin
    @Published public private(set) var currentSkin: Skin = .defaultSkin
    
    /// Available skins
    @Published public private(set) var availableSkins: [Skin] = []
    
    /// Current cached skin data
    private var currentCachedSkin: CachedSkin?
    
    /// Main skins directory
    public var skinsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WinAmpPlayer/Skins")
    }
    
    /// Skin directories
    private let skinDirectories: [URL]
    
    /// Queue for skin operations
    private let skinQueue = DispatchQueue(label: "com.winamp.skinmanager")
    
    private init() {
        // Setup skin directories
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let winampDir = appSupport.appendingPathComponent("WinAmpPlayer")
        let skinsDir = winampDir.appendingPathComponent("Skins")
        
        // Create skins directory if needed
        try? FileManager.default.createDirectory(at: skinsDir, withIntermediateDirectories: true)
        
        // Built-in skins directory (in app bundle)
        let builtInSkinsDir = Bundle.main.url(forResource: "Skins", withExtension: nil) ?? Bundle.main.bundleURL
        
        self.skinDirectories = [skinsDir, builtInSkinsDir]
        
        // Load available skins
        loadAvailableSkins()
        
        // Load default skin
        Task {
            await loadDefaultSkin()
        }
    }
    
    /// Load default skin
    private func loadDefaultSkin() async {
        do {
            try await SkinAssetCache.shared.preloadDefaultSkin()
            await MainActor.run {
                self.currentSkin = .defaultSkin
            }
        } catch {
            print("Failed to load default skin: \(error)")
        }
    }
    
    /// Load available skins from disk
    public func loadAvailableSkins() {
        skinQueue.async { [weak self] in
            guard let self = self else { return }
            
            var skins: [Skin] = [.defaultSkin]
            
            for directory in self.skinDirectories {
                guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
                    continue
                }
                
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "wsz" || fileURL.pathExtension.lowercased() == "zip" {
                        // Parse skin info
                        let skinName = fileURL.deletingPathExtension().lastPathComponent
                        let skin = Skin(
                            name: skinName,
                            url: fileURL,
                            isDefault: false
                        )
                        skins.append(skin)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.availableSkins = skins
            }
        }
    }
    
    /// Apply a skin
    public func applySkin(_ skin: Skin) async throws {
        // Post pre-change notification for animation
        await MainActor.run {
            NotificationCenter.default.post(name: .skinWillChange, object: skin)
        }
        
        // Small delay for fade-out animation
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
        
        if skin.isDefault {
            // Use default skin
            currentCachedSkin = nil
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentSkin = skin
                }
            }
            NotificationCenter.default.post(name: .skinDidChange, object: skin)
        } else if let url = skin.url {
            // Load and apply skin
            do {
                let cachedSkin = try await SkinAssetCache.shared.loadSkin(from: url)
                currentCachedSkin = cachedSkin
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentSkin = skin
                    }
                }
                
                NotificationCenter.default.post(name: .skinDidChange, object: skin)
            } catch {
                NotificationCenter.default.post(
                    name: .skinLoadingFailed,
                    object: nil,
                    userInfo: ["error": error, "skin": skin]
                )
                throw error
            }
        }
    }
    
    /// Get sprite for current skin
    public func getSprite(_ type: SpriteType) -> NSImage? {
        if let cachedSkin = currentCachedSkin {
            return SkinAssetCache.shared.getSprite(type, from: cachedSkin.name)
        } else {
            // Use default skin
            return DefaultSkin.shared.getSprite(type)
        }
    }
    
    /// Get playlist configuration
    public var playlistConfig: PlaylistConfig? {
        return currentCachedSkin?.playlistConfig
    }
    
    /// Get visualization colors
    public var visualizationColors: VisualizationColors? {
        return currentCachedSkin?.visualizationColors
    }
    
    /// Get button regions
    public var buttonRegions: [ButtonRegion]? {
        return currentCachedSkin?.buttonRegions
    }
    
    /// Install skin from file
    public func installSkin(from url: URL) async throws -> Skin {
        // Check if it's a skin pack (contains multiple .wsz files)
        if let skins = try? await installSkinPack(from: url), !skins.isEmpty {
            // Return the first skin from the pack
            return skins.first!
        }
        
        // Single skin installation
        let fileName = url.lastPathComponent
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let skinsDir = appSupport.appendingPathComponent("WinAmpPlayer/Skins")
        let destinationURL = skinsDir.appendingPathComponent(fileName)
        
        // Copy file
        try FileManager.default.copyItem(at: url, to: destinationURL)
        
        // Create skin object
        let skinName = destinationURL.deletingPathExtension().lastPathComponent
        let skin = Skin(
            name: skinName,
            url: destinationURL,
            isDefault: false
        )
        
        // Reload available skins
        loadAvailableSkins()
        
        return skin
    }
    
    /// Install multiple skins from a pack
    public func installSkinPack(from packURL: URL) async throws -> [Skin] {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Extract pack
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-q", "-o", packURL.path, "-d", tempDir.path]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            // Not a valid zip, treat as single skin
            return []
        }
        
        // Find all .wsz files in the extracted content
        var installedSkins: [Skin] = []
        let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "wsz" || ext == "zip" {
                // Check if it's a valid skin file by trying to parse it
                do {
                    let parser = try SkinParser()
                    _ = try await parser.parseSkin(from: fileURL)
                    
                    // Valid skin, install it
                    let fileName = fileURL.lastPathComponent
                    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let skinsDir = appSupport.appendingPathComponent("WinAmpPlayer/Skins")
                    let destinationURL = skinsDir.appendingPathComponent(fileName)
                    
                    // Copy file (skip if already exists)
                    if !FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                        
                        let skinName = destinationURL.deletingPathExtension().lastPathComponent
                        let skin = Skin(
                            name: skinName,
                            url: destinationURL,
                            isDefault: false
                        )
                        installedSkins.append(skin)
                    }
                } catch {
                    // Not a valid skin file, skip it
                    continue
                }
            }
        }
        
        if !installedSkins.isEmpty {
            // Reload available skins
            loadAvailableSkins()
        }
        
        return installedSkins
    }
    
    /// Delete skin
    public func deleteSkin(_ skin: Skin) throws {
        guard !skin.isDefault, let url = skin.url else {
            throw NSError(domain: "SkinManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot delete default skin"])
        }
        
        try FileManager.default.removeItem(at: url)
        loadAvailableSkins()
        
        // If this was the current skin, switch to default
        if currentSkin.id == skin.id {
            Task {
                try? await applySkin(.defaultSkin)
            }
        }
    }
    
    /// Export skin to a location
    public func exportSkin(_ skin: Skin, to destinationURL: URL) throws {
        guard !skin.isDefault, let sourceURL = skin.url else {
            throw NSError(domain: "SkinManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot export default skin"])
        }
        
        // Check if source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "SkinManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Skin file not found"])
        }
        
        // Copy skin file to destination
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    /// Export multiple skins as a pack
    public func exportSkinPack(_ skins: [Skin], to destinationURL: URL) async throws {
        // Create temporary directory for pack contents
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Copy all skin files to temp directory
        var exportedCount = 0
        for skin in skins {
            guard !skin.isDefault, let sourceURL = skin.url else { continue }
            
            let fileName = sourceURL.lastPathComponent
            let destPath = tempDir.appendingPathComponent(fileName)
            
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destPath)
                exportedCount += 1
            } catch {
                print("Failed to export skin \(skin.name): \(error)")
            }
        }
        
        guard exportedCount > 0 else {
            throw NSError(domain: "SkinManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "No skins could be exported"])
        }
        
        // Create ZIP archive
        try await createZipArchive(from: tempDir, to: destinationURL)
    }
    
    /// Create ZIP archive from directory
    private func createZipArchive(from sourceDir: URL, to destinationURL: URL) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        task.currentDirectoryURL = sourceDir
        task.arguments = ["-r", "-q", destinationURL.path, "."]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SkinManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create archive: \(errorString)"])
        }
    }
    
    /// Create skin thumbnail
    public func createThumbnail(for skin: Skin) async -> NSImage? {
        guard let url = skin.url else { return nil }
        
        do {
            let cachedSkin = try await SkinAssetCache.shared.loadSkin(from: url)
            
            // Get main background sprite
            if let mainBackground = SkinAssetCache.shared.getSprite(.mainBackground, from: cachedSkin.name) {
                // Scale down to thumbnail size
                let thumbnailSize = NSSize(width: 137.5, height: 58) // Half size
                let thumbnail = NSImage(size: thumbnailSize)
                
                thumbnail.lockFocus()
                mainBackground.draw(in: NSRect(origin: .zero, size: thumbnailSize))
                thumbnail.unlockFocus()
                
                return thumbnail
            }
        } catch {
            print("Failed to create thumbnail for skin \(skin.name): \(error)")
        }
        
        return nil
    }
}