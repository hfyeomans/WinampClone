//
//  AmpWindow.swift
//  WinAmpPlayer
//
//  Custom NSWindow subclass for WinAmp-style chrome
//

import AppKit
import SwiftUI

/// Custom window class that provides WinAmp-style chrome and behavior
class AmpWindow: NSWindow {
    
    /// Current skin being used for chrome
    private var currentSkin: Skin?
    
    /// Observer for skin changes
    private var skinObserver: NSObjectProtocol?
    
    /// Custom chrome view
    private var chromeView: CustomWindowChrome?
    
    /// Whether the window supports region-based shapes
    var supportsRegionMask: Bool = true
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .miniaturizable, .closable], backing: backingStoreType, defer: flag)
        setupAmpWindow()
    }
    
    private func setupAmpWindow() {
        // Configure window properties
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Setup custom chrome
        setupCustomChrome()
        
        // Listen for skin changes
        setupSkinObserver()
        
        // Apply initial skin
        applySkinChrome()
    }
    
    private func setupCustomChrome() {
        // Create custom chrome view
        chromeView = CustomWindowChrome(window: self)
        
        // Set up the chrome as the title bar
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Add chrome view to window
        if let chromeView = chromeView {
            contentView?.addSubview(chromeView)
            chromeView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                chromeView.topAnchor.constraint(equalTo: contentView!.topAnchor),
                chromeView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
                chromeView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
                chromeView.heightAnchor.constraint(equalToConstant: 14) // WinAmp title bar height
            ])
        }
    }
    
    private func setupSkinObserver() {
        skinObserver = NotificationCenter.default.addObserver(
            forName: .skinDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let skin = notification.object as? Skin {
                self?.currentSkin = skin
                self?.applySkinChrome()
            }
        }
    }
    
    private func applySkinChrome() {
        guard let skin = currentSkin ?? SkinManager.shared.currentSkin as? Skin else { return }
        
        // Update chrome with new skin
        chromeView?.updateSkin(skin)
        
        // Apply window shape if skin supports it
        if supportsRegionMask {
            applyRegionMask()
        }
    }
    
    private func applyRegionMask() {
        // TODO: Implement region-based window masking
        // This requires extending CachedSkin to store RegionMask data
        // For now, skip region masking and use rectangular window
    }
    
    deinit {
        if let observer = skinObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Window Behavior Overrides
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // Enable dragging from any part of the window
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        
        // Check if click is in a control area
        if let hitView = contentView?.hitTest(location), hitView != contentView {
            super.mouseDown(with: event)
            return
        }
        
        // Start window dragging
        let initialLocation = event.locationInWindow
        let screenFrame = frame
        
        var keepGoing = true
        while keepGoing {
            guard let nextEvent = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            
            switch nextEvent.type {
            case .leftMouseDragged:
                let currentLocation = nextEvent.locationInWindow
                let deltaX = currentLocation.x - initialLocation.x
                let deltaY = currentLocation.y - initialLocation.y
                
                let newOrigin = CGPoint(
                    x: screenFrame.origin.x + deltaX,
                    y: screenFrame.origin.y + deltaY
                )
                
                setFrameOrigin(newOrigin)
                
            case .leftMouseUp:
                keepGoing = false
                
            default:
                break
            }
        }
    }
}

// MARK: - Custom Window Chrome View

class CustomWindowChrome: NSView {
    private weak var ampWindow: AmpWindow?
    private var currentSkin: Skin?
    
    // Window control buttons
    private var closeButton: SkinnableWindowButton?
    private var minimizeButton: SkinnableWindowButton?
    private var shadeButton: SkinnableWindowButton?
    
    init(window: AmpWindow) {
        self.ampWindow = window
        super.init(frame: .zero)
        setupChrome()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupChrome() {
        wantsLayer = true
        
        // Create window control buttons
        setupWindowControls()
    }
    
    private func setupWindowControls() {
        // Close button
        closeButton = SkinnableWindowButton(
            type: .close,
            normalSprite: .closeButton(.normal),
            pressedSprite: .closeButton(.pressed)
        ) { [weak self] in
            self?.ampWindow?.close()
        }
        
        // Minimize button  
        minimizeButton = SkinnableWindowButton(
            type: .minimize,
            normalSprite: .minimizeButton(.normal),
            pressedSprite: .minimizeButton(.pressed)
        ) { [weak self] in
            self?.ampWindow?.miniaturize(nil)
        }
        
        // Shade button (WinAmp specific)
        shadeButton = SkinnableWindowButton(
            type: .shade,
            normalSprite: .shadeButton(.normal),
            pressedSprite: .shadeButton(.pressed)
        ) { [weak self] in
            self?.toggleShadeMode()
        }
        
        // Add buttons to chrome
        if let closeButton = closeButton {
            addSubview(closeButton)
        }
        if let minimizeButton = minimizeButton {
            addSubview(minimizeButton)
        }
        if let shadeButton = shadeButton {
            addSubview(shadeButton)
        }
        
        layoutWindowControls()
    }
    
    private func layoutWindowControls() {
        guard let closeButton = closeButton,
              let minimizeButton = minimizeButton,
              let shadeButton = shadeButton else { return }
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        shadeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Position buttons in WinAmp style (right side of title bar)
        NSLayoutConstraint.activate([
            // Close button (rightmost)
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            closeButton.widthAnchor.constraint(equalToConstant: 9),
            closeButton.heightAnchor.constraint(equalToConstant: 9),
            
            // Minimize button (left of close)
            minimizeButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -1),
            minimizeButton.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            minimizeButton.widthAnchor.constraint(equalToConstant: 9),
            minimizeButton.heightAnchor.constraint(equalToConstant: 9),
            
            // Shade button (left of minimize)
            shadeButton.trailingAnchor.constraint(equalTo: minimizeButton.leadingAnchor, constant: -1),
            shadeButton.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            shadeButton.widthAnchor.constraint(equalToConstant: 9),
            shadeButton.heightAnchor.constraint(equalToConstant: 9)
        ])
    }
    
    func updateSkin(_ skin: Skin) {
        currentSkin = skin
        
        // Update button sprites
        closeButton?.updateSkin()
        minimizeButton?.updateSkin()
        shadeButton?.updateSkin()
        
        needsDisplay = true
    }
    
    private func toggleShadeMode() {
        // Toggle between normal and shaded mode (mini player)
        guard let window = ampWindow else { return }
        
        let currentHeight = window.frame.height
        let newHeight: CGFloat = currentHeight > 20 ? 14 : 116 // Shade to title bar only or restore
        
        var newFrame = window.frame
        newFrame.size.height = newHeight
        newFrame.origin.y += (currentHeight - newHeight) // Keep top position fixed
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw title bar background using skin sprite
        if let titleBarSprite = SkinManager.shared.getSprite(.titleBarActive) {
            titleBarSprite.draw(in: bounds)
        } else {
            // Fallback gradient
            let gradient = NSGradient(colors: [
                NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
                NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ])
            gradient?.draw(in: bounds, angle: 90)
        }
        
        // Draw WinAmp title text
        let titleRect = NSRect(x: 6, y: 3, width: 100, height: 11)
        let title = "WINAMP"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.green
        ]
        title.draw(in: titleRect, withAttributes: attributes)
    }
}

// MARK: - Skinnable Window Button

class SkinnableWindowButton: NSButton {
    enum ButtonType {
        case close, minimize, shade
    }
    
    private let buttonType: ButtonType
    private let normalSprite: SpriteType
    private let pressedSprite: SpriteType
    private let buttonAction: () -> Void
    
    init(type: ButtonType, normalSprite: SpriteType, pressedSprite: SpriteType, action: @escaping () -> Void) {
        self.buttonType = type
        self.normalSprite = normalSprite
        self.pressedSprite = pressedSprite
        self.buttonAction = action
        super.init(frame: .zero)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButton() {
        isBordered = false
        wantsLayer = true
        target = self
        self.action = #selector(buttonPressed)
        updateSkin()
    }
    
    @objc private func buttonPressed() {
        buttonAction()
    }
    
    func updateSkin() {
        // Update button appearance based on current skin
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let spriteType = isHighlighted ? pressedSprite : normalSprite
        
        if let sprite = SkinManager.shared.getSprite(spriteType) {
            sprite.draw(in: bounds)
        } else {
            // Fallback appearance
            let color = isHighlighted ? NSColor.darkGray : NSColor.lightGray
            color.setFill()
            bounds.fill()
            
            // Draw button symbol
            let symbolColor = NSColor.white
            symbolColor.setStroke()
            
            switch buttonType {
            case .close:
                // Draw X
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 2, y: 2))
                path.line(to: NSPoint(x: bounds.width - 2, y: bounds.height - 2))
                path.move(to: NSPoint(x: bounds.width - 2, y: 2))
                path.line(to: NSPoint(x: 2, y: bounds.height - 2))
                path.stroke()
                
            case .minimize:
                // Draw line
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 2, y: bounds.height / 2))
                path.line(to: NSPoint(x: bounds.width - 2, y: bounds.height / 2))
                path.stroke()
                
            case .shade:
                // Draw up arrow
                let path = NSBezierPath()
                path.move(to: NSPoint(x: bounds.width / 2, y: 2))
                path.line(to: NSPoint(x: 2, y: bounds.height - 2))
                path.line(to: NSPoint(x: bounds.width - 2, y: bounds.height - 2))
                path.close()
                path.stroke()
            }
        }
    }
}
