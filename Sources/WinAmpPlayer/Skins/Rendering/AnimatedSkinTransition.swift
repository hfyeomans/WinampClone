//
//  AnimatedSkinTransition.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Animated transitions for skin changes
//

import SwiftUI
import Combine

/// View modifier that adds skin transition animations
struct SkinTransitionModifier: ViewModifier {
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var isTransitioning = false
    
    private let animationDuration: Double = 0.15
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .onReceive(NotificationCenter.default.publisher(for: .skinWillChange)) { _ in
                withAnimation(.easeOut(duration: animationDuration)) {
                    opacity = 0.0
                    scale = 0.95
                    isTransitioning = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .skinDidChange)) { _ in
                if isTransitioning {
                    // Reset to hidden state before fading in
                    opacity = 0.0
                    scale = 1.05
                    
                    withAnimation(.easeIn(duration: animationDuration)) {
                        opacity = 1.0
                        scale = 1.0
                        isTransitioning = false
                    }
                }
            }
    }
}

/// Extension to easily apply skin transitions
extension View {
    func skinTransition() -> some View {
        modifier(SkinTransitionModifier())
    }
}

/// Crossfade transition for sprite changes
struct CrossfadeSpriteView: View {
    let spriteType: SpriteType
    @StateObject private var skinManager = SkinManager.shared
    @State private var currentSprite: NSImage?
    @State private var previousSprite: NSImage?
    @State private var showPrevious = false
    
    var body: some View {
        ZStack {
            if showPrevious, let previous = previousSprite {
                Image(nsImage: previous)
                    .resizable()
                    .interpolation(.none)
                    .transition(.opacity)
            }
            
            if let current = currentSprite {
                Image(nsImage: current)
                    .resizable()
                    .interpolation(.none)
                    .transition(.opacity)
            }
        }
        .onAppear {
            currentSprite = skinManager.getSprite(spriteType)
        }
        .onReceive(NotificationCenter.default.publisher(for: .skinWillChange)) { _ in
            previousSprite = currentSprite
            showPrevious = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .skinDidChange)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSprite = skinManager.getSprite(spriteType)
                showPrevious = false
            }
        }
    }
}

/// Sliding transition for window content
struct SlidingSkinTransition: ViewModifier {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .onReceive(NotificationCenter.default.publisher(for: .skinWillChange)) { _ in
                withAnimation(.easeIn(duration: 0.15)) {
                    offset = -20
                    opacity = 0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .skinDidChange)) { _ in
                // Reset position
                offset = 20
                
                withAnimation(.easeOut(duration: 0.15)) {
                    offset = 0
                    opacity = 1
                }
            }
    }
}

/// Rotating cube transition effect
struct CubeSkinTransition: ViewModifier {
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.5
            )
            .opacity(opacity)
            .onReceive(NotificationCenter.default.publisher(for: .skinWillChange)) { _ in
                withAnimation(.easeIn(duration: 0.2)) {
                    rotation = -90
                    opacity = 0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .skinDidChange)) { _ in
                // Reset to other side
                rotation = 90
                
                withAnimation(.easeOut(duration: 0.2)) {
                    rotation = 0
                    opacity = 1
                }
            }
    }
}

/// Extension for different transition styles
extension View {
    func skinTransition(style: SkinTransitionStyle) -> some View {
        switch style {
        case .fade:
            return AnyView(self.skinTransition())
        case .slide:
            return AnyView(self.modifier(SlidingSkinTransition()))
        case .cube:
            return AnyView(self.modifier(CubeSkinTransition()))
        }
    }
}

enum SkinTransitionStyle {
    case fade
    case slide
    case cube
}