//
//  RegionBasedButton.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Button that uses hit regions from skin configuration
//

import SwiftUI
import AppKit

/// Button that uses custom hit regions from skin
public struct RegionBasedButton: View {
    let regionName: String
    let normalSprite: SpriteType
    let pressedSprite: SpriteType
    let hoverSprite: SpriteType?
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    @StateObject private var skinManager = SkinManager.shared
    
    public init(
        region: String,
        normal: SpriteType,
        pressed: SpriteType,
        hover: SpriteType? = nil,
        action: @escaping () -> Void
    ) {
        self.regionName = region
        self.normalSprite = normal
        self.pressedSprite = pressed
        self.hoverSprite = hover
        self.action = action
    }
    
    private var currentSprite: SpriteType {
        if isPressed {
            return pressedSprite
        } else if isHovered, let hoverSprite = hoverSprite {
            return hoverSprite
        } else {
            return normalSprite
        }
    }
    
    public var body: some View {
        SpriteView(currentSprite)
            .background(
                RegionHitTestView(
                    regionName: regionName,
                    onPressed: { pressed in
                        isPressed = pressed
                        if !pressed {
                            action()
                        }
                    },
                    onHover: { hovering in
                        isHovered = hovering
                    }
                )
            )
    }
}

/// View that handles hit testing against a button region
struct RegionHitTestView: NSViewRepresentable {
    let regionName: String
    let onPressed: (Bool) -> Void
    let onHover: (Bool) -> Void
    
    func makeNSView(context: Context) -> RegionHitTestNSView {
        let view = RegionHitTestNSView()
        view.regionName = regionName
        view.onPressed = onPressed
        view.onHover = onHover
        return view
    }
    
    func updateNSView(_ nsView: RegionHitTestNSView, context: Context) {
        nsView.regionName = regionName
    }
}

/// NSView subclass that handles custom hit regions
class RegionHitTestNSView: NSView {
    var regionName: String = ""
    var onPressed: ((Bool) -> Void)?
    var onHover: ((Bool) -> Void)?
    
    private var isPressed = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeInKeyWindow
        ]
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        setupTracking()
    }
    
    override func mouseEntered(with event: NSEvent) {
        updateHoverState(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        if isHovered {
            isHovered = false
            onHover?(false)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        updateHoverState(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if isPointInRegion(location) {
            isPressed = true
            onPressed?(true)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isPressed {
            isPressed = false
            onPressed?(false)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let inRegion = isPointInRegion(location)
        
        if isPressed && !inRegion {
            isPressed = false
            onPressed?(false)
        } else if !isPressed && inRegion {
            isPressed = true
            onPressed?(true)
        }
    }
    
    private func updateHoverState(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let inRegion = isPointInRegion(location)
        
        if inRegion != isHovered {
            isHovered = inRegion
            onHover?(inRegion)
        }
    }
    
    private func isPointInRegion(_ point: NSPoint) -> Bool {
        // Get button region from skin manager
        guard let regions = SkinManager.shared.buttonRegions,
              let region = regions.first(where: { $0.name == regionName }) else {
            // Fallback to rectangular hit test
            return bounds.contains(point)
        }
        
        // Check if point is in the defined region
        return region.contains(point: CGPoint(x: point.x, y: point.y))
    }
}

/// Extension to make existing buttons region-aware
extension SkinnableButton {
    /// Create a button with custom hit region
    public init(
        region: String? = nil,
        normal: SpriteType,
        pressed: SpriteType,
        hover: SpriteType? = nil,
        action: @escaping () -> Void
    ) {
        if let region = region {
            // Use region-based button
            self = SkinnableButton(normal: normal, pressed: pressed, hover: hover, action: action)
            // Note: In a real implementation, we would modify SkinnableButton
            // to internally use RegionHitTestView when a region is specified
        } else {
            // Use standard rectangular hit test
            self.init(normal: normal, pressed: pressed, hover: hover, action: action)
        }
    }
}