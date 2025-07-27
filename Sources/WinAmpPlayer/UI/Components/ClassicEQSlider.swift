//
//  ClassicEQSlider.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Classic WinAmp-style equalizer slider
//

import SwiftUI
import AppKit

/// Classic WinAmp-style vertical EQ slider
public struct ClassicEQSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChanged: (Float) -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    public init(
        value: Binding<Float>,
        range: ClosedRange<Float> = -12...12,
        onChanged: @escaping (Float) -> Void = { _ in }
    ) {
        self._value = value
        self.range = range
        self.onChanged = onChanged
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track background
                ClassicSliderTrack(
                    width: 14,
                    height: geometry.size.height,
                    orientation: .vertical
                )
                
                // Center line (0 dB)
                Rectangle()
                    .fill(Color(WinAmpColors.borderHighlight))
                    .frame(width: 20, height: 1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Tick marks
                VStack(spacing: 0) {
                    ForEach([-12, -6, 0, 6, 12], id: \.self) { tickValue in
                        if tickValue != 0 {
                            Spacer()
                        }
                        
                        Rectangle()
                            .fill(Color(WinAmpColors.border))
                            .frame(width: 8, height: 1)
                        
                        if tickValue != 12 {
                            Spacer()
                        }
                    }
                }
                .frame(height: geometry.size.height)
                
                // Thumb
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let yPosition = geometry.size.height * (1 - CGFloat(normalizedValue))
                
                ClassicEQThumb(isPressed: isDragging)
                    .position(x: geometry.size.width / 2, y: yPosition)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !isDragging {
                                    isDragging = true
                                    dragOffset = drag.location.y - yPosition
                                }
                                
                                let newY = drag.location.y - dragOffset
                                let clampedY = max(0, min(geometry.size.height, newY))
                                let normalizedY = 1 - (clampedY / geometry.size.height)
                                let newValue = range.lowerBound + Float(normalizedY) * (range.upperBound - range.lowerBound)
                                
                                // Snap to center (0 dB)
                                if abs(newValue) < 0.5 {
                                    value = 0
                                } else {
                                    value = newValue
                                }
                                
                                onChanged(value)
                            }
                            .onEnded { _ in
                                isDragging = false
                                dragOffset = 0
                            }
                    )
            }
        }
    }
}

/// Classic EQ slider thumb
struct ClassicEQThumb: View {
    let isPressed: Bool
    
    var body: some View {
        ZStack {
            // Main thumb body
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(isPressed ? WinAmpColors.buttonPressed : WinAmpColors.buttonFace))
                .frame(width: 28, height: 11)
                .classicWindowStyle(raised: !isPressed)
            
            // Grip indicator
            Rectangle()
                .fill(Color(isPressed ? WinAmpColors.lcdText : WinAmpColors.borderShadow))
                .frame(width: 20, height: 1)
        }
    }
}

/// Classic horizontal balance/volume slider
public struct ClassicHorizontalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChanged: (Float) -> Void
    let showCenterMark: Bool
    
    @State private var isDragging = false
    
    public init(
        value: Binding<Float>,
        range: ClosedRange<Float> = 0...1,
        showCenterMark: Bool = false,
        onChanged: @escaping (Float) -> Void = { _ in }
    ) {
        self._value = value
        self.range = range
        self.showCenterMark = showCenterMark
        self.onChanged = onChanged
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track
                ClassicSliderTrack(
                    width: geometry.size.width,
                    height: 8,
                    orientation: .horizontal
                )
                
                // Center mark (for balance)
                if showCenterMark {
                    Rectangle()
                        .fill(Color(WinAmpColors.borderHighlight))
                        .frame(width: 1, height: 12)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                // Thumb
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let xPosition = CGFloat(normalizedValue) * geometry.size.width
                
                ClassicSliderThumb(
                    size: CGSize(width: 14, height: 11),
                    isPressed: isDragging,
                    showGrips: true
                )
                .position(x: xPosition, y: geometry.size.height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            
                            let normalizedX = drag.location.x / geometry.size.width
                            let clampedX = max(0, min(1, normalizedX))
                            let newValue = range.lowerBound + Float(clampedX) * (range.upperBound - range.lowerBound)
                            
                            // Snap to center for balance slider
                            if showCenterMark && abs(newValue) < 0.05 {
                                value = 0
                            } else {
                                value = newValue
                            }
                            
                            onChanged(value)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
        }
    }
}

/// Position slider for seek bar
public struct SkinnablePositionSlider: View {
    @Binding var position: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging = false
    @State private var dragPosition: TimeInterval = 0
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track
                Rectangle()
                    .fill(Color(WinAmpColors.backgroundDark))
                    .frame(height: 10)
                    .classicWindowStyle(raised: false)
                
                // Progress fill
                if duration > 0 {
                    let progress = position / duration
                    Rectangle()
                        .fill(Color(WinAmpColors.accent).opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        .position(x: geometry.size.width * CGFloat(progress) / 2, y: geometry.size.height / 2)
                }
                
                // Thumb
                if duration > 0 {
                    let progress = isDragging ? dragPosition / duration : position / duration
                    let xPosition = geometry.size.width * CGFloat(progress)
                    
                    PositionThumb(isPressed: isDragging)
                        .position(x: xPosition, y: geometry.size.height / 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard duration > 0 else { return }
                        
                        isDragging = true
                        let progress = max(0, min(1, drag.location.x / geometry.size.width))
                        dragPosition = duration * Double(progress)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onSeek(dragPosition)
                    }
            )
        }
    }
}

/// Position slider thumb
struct PositionThumb: View {
    let isPressed: Bool
    
    var body: some View {
        Rectangle()
            .fill(Color(isPressed ? WinAmpColors.buttonPressed : WinAmpColors.buttonFace))
            .frame(width: 29, height: 10)
            .classicWindowStyle(raised: !isPressed)
    }
}

/// Volume slider component
public struct SkinnableVolumeSlider: View {
    @Binding var volume: Float
    let onChanged: (Float) -> Void
    
    public var body: some View {
        ClassicHorizontalSlider(
            value: $volume,
            range: 0...1,
            showCenterMark: false,
            onChanged: onChanged
        )
    }
}

/// Balance slider component
public struct SkinnableBalanceSlider: View {
    @Binding var balance: Float
    let onChanged: (Float) -> Void
    
    public var body: some View {
        ClassicHorizontalSlider(
            value: $balance,
            range: -1...1,
            showCenterMark: true,
            onChanged: onChanged
        )
    }
}