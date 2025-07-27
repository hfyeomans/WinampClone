//
//  ClassicSliders.swift
//  WinAmpPlayer
//
//  Classic WinAmp-style sliders for EQ and volume
//

import SwiftUI

// MARK: - Vertical EQ Slider

struct LegacyClassicEQSlider: View {
    @Binding var value: Double // -12 to +12 dB
    let frequency: String
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 2) {
            Text("+12")
                .font(.system(size: 7))
                .foregroundColor(WinAmpColors.text)
            
            GeometryReader { geometry in
                ZStack {
                    // Groove
                    Rectangle()
                        .fill(WinAmpColors.darkBorder)
                        .frame(width: 2, height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .overlay(BeveledBorder(raised: false))
                    
                    // Thumb
                    RoundedRectangle(cornerRadius: 1)
                        .fill(WinAmpColors.buttonNormal)
                        .frame(width: 11, height: 6)
                        .overlay(BeveledBorder(raised: !isDragging))
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height * (1.0 - (value + 12) / 24.0)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { drag in
                                    isDragging = true
                                    let newValue = 1.0 - (drag.location.y / geometry.size.height)
                                    value = (newValue * 24.0) - 12.0
                                    value = max(-12, min(12, value))
                                    
                                    // Snap to center (0 dB)
                                    if abs(value) < 1 {
                                        value = 0
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            }
            .frame(width: 14, height: 50)
            
            Text("-12")
                .font(.system(size: 7))
                .foregroundColor(WinAmpColors.text)
            
            Text(frequency)
                .font(.system(size: 7))
                .foregroundColor(WinAmpColors.text)
        }
    }
}

// MARK: - Horizontal Volume/Balance Slider

struct LegacyClassicHorizontalSlider: View {
    @Binding var value: Double // 0.0 to 1.0
    let width: CGFloat = 68
    let height: CGFloat = 13
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 0)
                    .fill(WinAmpColors.background)
                    .overlay(BeveledBorder(raised: false))
                
                // Groove
                Rectangle()
                    .fill(WinAmpColors.darkBorder)
                    .frame(width: geometry.size.width - 10, height: 2)
                
                // Thumb
                RoundedRectangle(cornerRadius: 1)
                    .fill(WinAmpColors.buttonNormal)
                    .frame(width: 14, height: 11)
                    .overlay(BeveledBorder(raised: !isDragging))
                    .overlay(
                        // Center indicator
                        Rectangle()
                            .fill(WinAmpColors.darkBorder)
                            .frame(width: 1, height: 7)
                    )
                    .position(
                        x: 5 + (geometry.size.width - 10) * CGFloat(value),
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                isDragging = true
                                let newValue = (drag.location.x - 5) / (geometry.size.width - 10)
                                value = max(0, min(1, Double(newValue)))
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Position Slider (Seek Bar)

struct LegacyClassicPositionSlider: View {
    @Binding var value: Double // 0.0 to 1.0
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var temporaryValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 0)
                    .fill(WinAmpColors.background)
                    .overlay(BeveledBorder(raised: false))
                
                // Progress fill
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(WinAmpColors.accent)
                        .frame(width: geometry.size.width * CGFloat(isDragging ? temporaryValue : value))
                    Spacer()
                }
                
                // Thumb (only visible when dragging)
                if isDragging {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(WinAmpColors.buttonNormal)
                        .frame(width: 10, height: geometry.size.height - 2)
                        .overlay(BeveledBorder(raised: false))
                        .position(
                            x: max(5, min(geometry.size.width - 5, 
                                         geometry.size.width * CGFloat(temporaryValue))),
                            y: geometry.size.height / 2
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            temporaryValue = value
                        }
                        let newValue = drag.location.x / geometry.size.width
                        temporaryValue = max(0, min(1, Double(newValue)))
                    }
                    .onEnded { drag in
                        isDragging = false
                        let finalValue = drag.location.x / geometry.size.width
                        let clampedValue = max(0, min(1, Double(finalValue)))
                        value = clampedValue
                        onSeek(clampedValue)
                    }
            )
        }
        .frame(height: 10)
    }
}