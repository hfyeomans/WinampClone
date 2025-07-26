//
//  SpriteRenderer.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  SwiftUI view for rendering skin sprites
//

import SwiftUI
import AppKit

/// View that renders a sprite from the current skin
public struct SpriteView: View {
    let spriteType: SpriteType
    @StateObject private var skinManager = SkinManager.shared
    
    public init(_ spriteType: SpriteType) {
        self.spriteType = spriteType
    }
    
    public var body: some View {
        if let sprite = skinManager.getSprite(spriteType) {
            Image(nsImage: sprite)
                .resizable()
                .interpolation(.none) // Preserve pixel art
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback rectangle
            Rectangle()
                .fill(Color.gray.opacity(0.3))
        }
    }
}

/// NSView-based sprite renderer for better performance
public class SpriteRendererView: NSView {
    private var spriteType: SpriteType
    private var sprite: NSImage?
    private var skinObserver: NSObjectProtocol?
    
    public init(spriteType: SpriteType) {
        self.spriteType = spriteType
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .nearest // Preserve pixel art
        
        // Load initial sprite
        updateSprite()
        
        // Listen for skin changes
        skinObserver = NotificationCenter.default.addObserver(
            forName: .skinDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSprite()
        }
    }
    
    deinit {
        if let observer = skinObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateSprite() {
        sprite = SkinManager.shared.getSprite(spriteType)
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let sprite = sprite else {
            // Draw placeholder
            NSColor.gray.withAlphaComponent(0.3).setFill()
            dirtyRect.fill()
            return
        }
        
        // Draw sprite
        sprite.draw(in: bounds)
    }
    
    public func setSpriteType(_ type: SpriteType) {
        self.spriteType = type
        updateSprite()
    }
}

/// SwiftUI wrapper for SpriteRendererView
public struct SpriteRenderer: NSViewRepresentable {
    let spriteType: SpriteType
    
    public init(_ spriteType: SpriteType) {
        self.spriteType = spriteType
    }
    
    public func makeNSView(context: Context) -> SpriteRendererView {
        SpriteRendererView(spriteType: spriteType)
    }
    
    public func updateNSView(_ nsView: SpriteRendererView, context: Context) {
        nsView.setSpriteType(spriteType)
    }
}