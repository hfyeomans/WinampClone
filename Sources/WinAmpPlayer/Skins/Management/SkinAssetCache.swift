//
//  SkinAssetCache.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Cache system for loaded skin assets
//

import Foundation
import AppKit

/// Cache for managing loaded skin assets
public class SkinAssetCache {
    /// Shared instance
    public static let shared = SkinAssetCache()
    
    /// Cache storage
    private var loadedSkins: [URL: CachedSkin] = [:]
    private var extractedSprites: [String: [SpriteType: NSImage]] = [:] // Keyed by skin name
    
    /// Memory limit for cache (in bytes)
    private let memoryLimit: Int = 200 * 1024 * 1024 // 200MB
    private var currentMemoryUsage: Int = 0
    
    /// Queue for thread safety
    private let cacheQueue = DispatchQueue(label: "com.winamp.skinassetcache", attributes: .concurrent)
    
    private init() {}
    
    /// Load a skin with caching
    public func loadSkin(from url: URL) async throws -> CachedSkin {
        // Check cache first
        if let cached = getCachedSkin(for: url) {
            return cached
        }
        
        // Parse skin
        let parser = try SkinParser()
        let parsedSkin = try await parser.parseSkin(from: url)
        
        // Extract sprites
        let sprites = SpriteExtractor.extractAllSprites(from: parsedSkin)
        
        // Create cached skin
        let cachedSkin = CachedSkin(
            url: url,
            name: parsedSkin.name,
            sprites: sprites,
            configurations: parsedSkin.configurations,
            loadedAt: Date()
        )
        
        // Cache it
        try await cacheSkin(cachedSkin, for: url)
        
        return cachedSkin
    }
    
    /// Get cached skin
    private func getCachedSkin(for url: URL) -> CachedSkin? {
        cacheQueue.sync {
            return loadedSkins[url]
        }
    }
    
    /// Cache a skin
    private func cacheSkin(_ skin: CachedSkin, for url: URL) async throws {
        let estimatedSize = estimateSkinMemorySize(skin)
        
        // Check if we need to evict old skins
        await ensureMemoryLimit(additionalSize: estimatedSize)
        
        // Add to cache
        cacheQueue.async(flags: .barrier) {
            self.loadedSkins[url] = skin
            self.extractedSprites[skin.name] = skin.sprites
            self.currentMemoryUsage += estimatedSize
        }
    }
    
    /// Ensure memory limit is not exceeded
    private func ensureMemoryLimit(additionalSize: Int) async {
        await cacheQueue.sync {
            var bytesToFree = (currentMemoryUsage + additionalSize) - memoryLimit
            guard bytesToFree > 0 else { return }
            
            // Sort by last access time (LRU)
            let sortedSkins = loadedSkins.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }
            
            for skin in sortedSkins {
                guard bytesToFree > 0 else { break }
                
                let skinSize = estimateSkinMemorySize(skin)
                if let url = loadedSkins.first(where: { $0.value.name == skin.name })?.key {
                    loadedSkins.removeValue(forKey: url)
                    extractedSprites.removeValue(forKey: skin.name)
                    currentMemoryUsage -= skinSize
                    bytesToFree -= skinSize
                }
            }
        }
    }
    
    /// Estimate memory size of a skin
    private func estimateSkinMemorySize(_ skin: CachedSkin) -> Int {
        var totalSize = 0
        
        // Estimate sprite memory usage
        for (_, image) in skin.sprites {
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                totalSize += cgImage.width * cgImage.height * 4 // 4 bytes per pixel (RGBA)
            }
        }
        
        // Add configuration text size
        for (_, config) in skin.configurations {
            totalSize += config.utf8.count
        }
        
        return totalSize
    }
    
    /// Get sprite from cache
    public func getSprite(_ type: SpriteType, from skinName: String) -> NSImage? {
        cacheQueue.sync {
            // Update last accessed time
            if let skin = loadedSkins.values.first(where: { $0.name == skinName }) {
                skin.updateLastAccessed()
            }
            
            return extractedSprites[skinName]?[type]
        }
    }
    
    /// Clear cache
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.loadedSkins.removeAll()
            self.extractedSprites.removeAll()
            self.currentMemoryUsage = 0
        }
    }
    
    /// Preload default skin
    public func preloadDefaultSkin() async throws {
        // Load embedded default skin
        guard let defaultSkinURL = Bundle.main.url(forResource: "default", withExtension: "wsz") else {
            // If no default skin file, create one programmatically
            DefaultSkin.shared.preload()
            return
        }
        
        _ = try await loadSkin(from: defaultSkinURL)
    }
}

/// Cached skin data
public class CachedSkin {
    public let url: URL
    public let name: String
    public let sprites: [SpriteType: NSImage]
    public let configurations: [String: String]
    public let loadedAt: Date
    public private(set) var lastAccessedAt: Date
    
    init(url: URL, name: String, sprites: [SpriteType: NSImage], configurations: [String: String], loadedAt: Date) {
        self.url = url
        self.name = name
        self.sprites = sprites
        self.configurations = configurations
        self.loadedAt = loadedAt
        self.lastAccessedAt = loadedAt
    }
    
    func updateLastAccessed() {
        lastAccessedAt = Date()
    }
    
    /// Get playlist configuration
    public var playlistConfig: PlaylistConfig? {
        guard let configText = configurations["pledit.txt"] else { return nil }
        return PlaylistConfig.parse(from: configText)
    }
    
    /// Get visualization colors
    public var visualizationColors: VisualizationColors? {
        guard let configText = configurations["viscolor.txt"] else { return nil }
        return VisualizationColors.parse(from: configText)
    }
    
    /// Get button regions
    public var buttonRegions: [ButtonRegion]? {
        guard let configText = configurations["region.txt"] else { return nil }
        return ButtonRegion.parseRegions(from: configText)
    }
}