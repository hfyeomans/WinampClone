//
//  SkinnableSlider.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Slider that uses skin sprites
//

import SwiftUI
import AppKit

/// Skinnable slider using sprites
public struct SkinnableSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let trackSprite: SpriteType
    let thumbNormalSprite: SpriteType
    let thumbPressedSprite: SpriteType
    let onChanged: ((Double) -> Void)?
    
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @StateObject private var skinManager = SkinManager.shared
    
    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        track: SpriteType,
        thumbNormal: SpriteType,
        thumbPressed: SpriteType,
        onChanged: ((Double) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.trackSprite = track
        self.thumbNormalSprite = thumbNormal
        self.thumbPressedSprite = thumbPressed
        self.onChanged = onChanged
    }
    
    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                SpriteView(trackSprite)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Thumb
                let thumbSprite = isDragging ? thumbPressedSprite : thumbNormalSprite
                if let thumbSize = SpriteExtractor.getSpriteSize(for: thumbSprite) {
                    SpriteView(thumbSprite)
                        .frame(width: thumbSize.width, height: thumbSize.height)
                        .offset(x: thumbOffset(in: geometry.size.width, thumbWidth: thumbSize.width))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        updateValue(from: drag.location.x, in: geometry.size.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
    
    private func thumbOffset(in trackWidth: CGFloat, thumbWidth: CGFloat) -> CGFloat {
        let usableWidth = trackWidth - thumbWidth
        return CGFloat(normalizedValue) * usableWidth
    }
    
    private func updateValue(from x: CGFloat, in width: CGFloat) {
        let normalizedX = max(0, min(1, x / width))
        let newValue = range.lowerBound + Double(normalizedX) * (range.upperBound - range.lowerBound)
        value = newValue
        onChanged?(newValue)
    }
}

/// Volume slider with skin support
public struct SkinnableVolumeSlider: View {
    @Binding var volume: Float
    let onChanged: ((Float) -> Void)?
    
    public init(volume: Binding<Float>, onChanged: ((Float) -> Void)? = nil) {
        self._volume = volume
        self.onChanged = onChanged
    }
    
    public var body: some View {
        SkinnableSlider(
            value: Binding(
                get: { Double(volume) },
                set: { volume = Float($0) }
            ),
            in: 0...1,
            track: .volumeSliderTrack,
            thumbNormal: .volumeSliderThumb(.normal),
            thumbPressed: .volumeSliderThumb(.pressed),
            onChanged: { value in
                onChanged?(Float(value))
            }
        )
    }
}

/// Balance slider with skin support
public struct SkinnableBalanceSlider: View {
    @Binding var balance: Float
    let onChanged: ((Float) -> Void)?
    
    public init(balance: Binding<Float>, onChanged: ((Float) -> Void)? = nil) {
        self._balance = balance
        self.onChanged = onChanged
    }
    
    public var body: some View {
        SkinnableSlider(
            value: Binding(
                get: { Double(balance) },
                set: { balance = Float($0) }
            ),
            in: -1...1,
            track: .balanceSliderTrack,
            thumbNormal: .balanceSliderThumb(.normal),
            thumbPressed: .balanceSliderThumb(.pressed),
            onChanged: { value in
                // Snap to center
                if abs(value) < 0.05 {
                    balance = 0
                    onChanged?(0)
                } else {
                    onChanged?(Float(value))
                }
            }
        )
    }
}

/// Position/seek slider with skin support
public struct SkinnablePositionSlider: View {
    @Binding var position: Double
    let duration: Double
    let onSeek: ((Double) -> Void)?
    
    public init(
        position: Binding<Double>,
        duration: Double,
        onSeek: ((Double) -> Void)? = nil
    ) {
        self._position = position
        self.duration = duration
        self.onSeek = onSeek
    }
    
    public var body: some View {
        SkinnableSlider(
            value: Binding(
                get: { position / max(duration, 1) },
                set: { position = $0 * duration }
            ),
            in: 0...1,
            track: .positionSliderTrack,
            thumbNormal: .positionSliderThumb(.normal),
            thumbPressed: .positionSliderThumb(.pressed),
            onChanged: { normalizedValue in
                onSeek?(normalizedValue * duration)
            }
        )
    }
}