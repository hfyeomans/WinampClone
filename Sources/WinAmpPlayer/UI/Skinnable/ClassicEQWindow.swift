//
//  ClassicEQWindow.swift
//  WinAmpPlayer
//
//  Classic WinAmp equalizer window
//

import SwiftUI

struct ClassicEQWindow: View {
    @State private var isOn = true
    @State private var isAuto = false
    @State private var preamp: Float = 0
    @State private var bands: [Float] = Array(repeating: 0, count: 10)
    
    private let frequencies = ["60", "170", "310", "600", "1k", "3k", "6k", "12k", "14k", "16k"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 0) {
                Text("WINAMP EQUALIZER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                    .padding(.leading, 6)
                
                Spacer()
                
                // Close button
                Button(action: {}) {
                    Text("X")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 9, height: 9)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 3)
            }
            .frame(height: 14)
            .background(
                LinearGradient(
                    colors: [WinAmpColors.backgroundLight, WinAmpColors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Main EQ area
            HStack(spacing: 0) {
                // Left padding
                Rectangle()
                    .fill(WinAmpColors.background)
                    .frame(width: 14)
                
                // Controls section
                VStack(spacing: 4) {
                    // On/Auto buttons
                    HStack(spacing: 2) {
                        ClassicToggleButton(icon: "ON", isOn: $isOn, width: 26)
                        ClassicToggleButton(icon: "AUTO", isOn: $isAuto, width: 32)
                    }
                    .padding(.top, 4)
                    
                    Spacer()
                    
                    // Presets button
                    Button(action: {}) {
                        Text("PRESETS")
                            .font(Font.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(WinAmpColors.text)
                            .frame(width: 44, height: 12)
                            .background(WinAmpColors.buttonNormal)
                            .overlay(BeveledBorder(raised: true))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 4)
                }
                .frame(width: 60)
                
                // Preamp slider
                VStack(spacing: 2) {
                    Text("PREAMP")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(WinAmpColors.text)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 14, height: 40)
                    
                    ClassicEQSlider(value: $preamp)
                        .frame(width: 14)
                }
                .padding(.horizontal, 4)
                
                // Separator
                Rectangle()
                    .fill(WinAmpColors.darkBorder)
                    .frame(width: 1)
                    .padding(.vertical, 8)
                
                // Frequency sliders
                HStack(spacing: 3) {
                    ForEach(0..<10) { index in
                        ClassicEQSlider(
                            value: $bands[index]
                        )
                    }
                }
                .padding(.horizontal, 8)
                
                // Right padding
                Rectangle()
                    .fill(WinAmpColors.background)
                    .frame(width: 14)
            }
            .frame(height: 102)
        }
        .frame(width: 275, height: 116)
        .background(WinAmpColors.background)
        .overlay(BeveledBorder(raised: true))
    }
}

// EQ Preset Menu
struct EQPresetMenu: View {
    let presets = [
        "Flat",
        "Classical",
        "Club",
        "Dance",
        "Full Bass",
        "Full Bass & Treble",
        "Full Treble",
        "Laptop Speakers",
        "Large Hall",
        "Live",
        "Party",
        "Pop",
        "Reggae",
        "Rock",
        "Ska",
        "Soft",
        "Soft Rock",
        "Techno"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(presets, id: \.self) { preset in
                Button(action: {}) {
                    Text(preset)
                        .font(.system(size: 11))
                        .foregroundColor(WinAmpColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    // Handle hover state
                }
                
                if preset != presets.last {
                    Divider()
                        .background(WinAmpColors.darkBorder)
                }
            }
        }
        .background(WinAmpColors.background)
        .overlay(BeveledBorder(raised: true))
        .frame(width: 150)
    }
}