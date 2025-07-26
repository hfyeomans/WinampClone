//
//  SkinnableButton.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Button that uses skin sprites
//

import SwiftUI
import AppKit

/// Skinnable button using sprites
public struct SkinnableButton: View {
    let normalSprite: SpriteType
    let pressedSprite: SpriteType
    let hoverSprite: SpriteType?
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    @StateObject private var skinManager = SkinManager.shared
    
    public init(
        normal: SpriteType,
        pressed: SpriteType,
        hover: SpriteType? = nil,
        action: @escaping () -> Void
    ) {
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
            .onHover { hovering in
                isHovered = hovering
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            isPressed = false
                        }
                    }
            )
    }
}

/// Toggle button with on/off states
public struct SkinnableToggleButton: View {
    @Binding var isOn: Bool
    let offNormal: SpriteType
    let offPressed: SpriteType
    let onNormal: SpriteType
    let onPressed: SpriteType
    
    @State private var isPressed = false
    @StateObject private var skinManager = SkinManager.shared
    
    public init(
        isOn: Binding<Bool>,
        offNormal: SpriteType,
        offPressed: SpriteType,
        onNormal: SpriteType,
        onPressed: SpriteType
    ) {
        self._isOn = isOn
        self.offNormal = offNormal
        self.offPressed = offPressed
        self.onNormal = onNormal
        self.onPressed = onPressed
    }
    
    private var currentSprite: SpriteType {
        if isOn {
            return isPressed ? onPressed : onNormal
        } else {
            return isPressed ? offPressed : offNormal
        }
    }
    
    public var body: some View {
        SpriteView(currentSprite)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .onTapGesture {
                isOn.toggle()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            isPressed = false
                        }
                    }
            )
    }
}

/// Transport control button
public struct TransportControlButton: View {
    let type: TransportButtonType
    let action: () -> Void
    
    @State private var buttonState: ButtonState = .normal
    @StateObject private var skinManager = SkinManager.shared
    
    public enum TransportButtonType {
        case previous
        case play
        case pause
        case stop
        case next
        case eject
    }
    
    public init(type: TransportButtonType, action: @escaping () -> Void) {
        self.type = type
        self.action = action
    }
    
    private var spriteType: SpriteType {
        switch type {
        case .previous:
            return .previousButton(buttonState)
        case .play:
            return .playButton(buttonState)
        case .pause:
            return .pauseButton(buttonState)
        case .stop:
            return .stopButton(buttonState)
        case .next:
            return .nextButton(buttonState)
        case .eject:
            return .ejectButton(buttonState)
        }
    }
    
    public var body: some View {
        SpriteView(spriteType)
            .onHover { hovering in
                if hovering && buttonState == .normal {
                    buttonState = .hover
                } else if !hovering && buttonState == .hover {
                    buttonState = .normal
                }
            }
            .scaleEffect(buttonState == .pressed ? 0.98 : 1.0)
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            buttonState = .pressed
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            buttonState = .normal
                        }
                    }
            )
    }
}