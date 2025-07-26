//
//  SkinnableEqualizerWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Skinnable 10-band graphic equalizer window
//

import SwiftUI
import AppKit
import AVFoundation

/// Skinnable EQ slider
struct SkinnableEQSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChanged: (Float) -> Void
    
    @State private var isDragging = false
    @StateObject private var skinManager = SkinManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track background - use EQ background sprite region
                if let eqBackground = skinManager.getSprite(.eqBackground) {
                    // Extract just the slider track area from the background
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 14, height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                // Center line (0 dB)
                Rectangle()
                    .fill(Color(WinAmpColors.border))
                    .frame(width: 20, height: 1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Thumb
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let yPosition = geometry.size.height * (1 - CGFloat(normalizedValue))
                
                if let thumbSprite = skinManager.getSprite(.eqSliderThumb(isDragging ? .pressed : .normal)) {
                    Image(nsImage: thumbSprite)
                        .position(x: geometry.size.width / 2, y: yPosition)
                } else {
                    // Fallback thumb
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isDragging ? Color(WinAmpColors.accent) : Color(WinAmpColors.text))
                        .frame(width: 28, height: 11)
                        .position(x: geometry.size.width / 2, y: yPosition)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let normalizedY = 1 - (drag.location.y / geometry.size.height)
                        let clampedY = max(0, min(1, normalizedY))
                        let newValue = range.lowerBound + Float(clampedY) * (range.upperBound - range.lowerBound)
                        
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
                    }
            )
        }
    }
}

/// Skinnable equalizer window
struct SkinnableEqualizerWindow: View {
    @StateObject private var eqController: EqualizerController
    @StateObject private var skinManager = SkinManager.shared
    @State private var isEnabled = true
    @State private var selectedPreset: EQPreset? = EQPreset.flat
    @State private var showingPresetMenu = false
    
    private let windowSize = CGSize(width: 275, height: 116)
    
    init(audioEngine: AudioEngine) {
        _eqController = StateObject(wrappedValue: EqualizerController(audioEngine: audioEngine))
    }
    
    var body: some View {
        ZStack {
            // Background
            if let bgSprite = skinManager.getSprite(.eqBackground) {
                Image(nsImage: bgSprite)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: windowSize.width, height: windowSize.height)
            } else {
                // Fallback background
                WinAmpWindow(
                    configuration: WinAmpWindowConfiguration(
                        title: "Equalizer",
                        windowType: .equalizer,
                        showTitleBar: true,
                        resizable: false,
                        minSize: windowSize,
                        maxSize: windowSize
                    )
                ) {
                    fallbackContent
                }
            }
            
            // Content overlay
            VStack(spacing: 0) {
                // Title bar area (built into sprite)
                Color.clear
                    .frame(height: 14)
                
                VStack(spacing: 8) {
                    // Top controls
                    HStack(spacing: 12) {
                        // On/Off toggle
                        SkinnableToggleButton(
                            isOn: $isEnabled,
                            offNormal: .eqOnOffButton(false, .normal),
                            offPressed: .eqOnOffButton(false, .pressed),
                            onNormal: .eqOnOffButton(true, .normal),
                            onPressed: .eqOnOffButton(true, .pressed)
                        )
                        .onChange(of: isEnabled) { newValue in
                            eqController.isEnabled = newValue
                        }
                        .frame(width: 25, height: 12)
                        
                        // Auto toggle
                        SkinnableToggleButton(
                            isOn: .constant(false),
                            offNormal: .eqAutoButton(false, .normal),
                            offPressed: .eqAutoButton(false, .pressed),
                            onNormal: .eqAutoButton(true, .normal),
                            onPressed: .eqAutoButton(true, .pressed)
                        )
                        .frame(width: 33, height: 12)
                        
                        Spacer()
                        
                        // Preset button
                        SkinnableButton(
                            normal: .eqPresetButton(.normal),
                            pressed: .eqPresetButton(.pressed),
                            action: { showingPresetMenu.toggle() }
                        )
                        .frame(width: 44, height: 12)
                        .popover(isPresented: $showingPresetMenu) {
                            PresetMenu(
                                selectedPreset: $selectedPreset,
                                onSelect: applyPreset
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    
                    // EQ sliders
                    HStack(spacing: 0) {
                        // Preamp slider
                        VStack(spacing: 2) {
                            Text("Preamp")
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(WinAmpColors.textDim))
                                .rotationEffect(.degrees(-90))
                                .fixedSize()
                                .frame(width: 8, height: 40)
                            
                            SkinnableEQSlider(
                                value: $eqController.preampGain,
                                range: -12...12,
                                onChanged: { _ in selectedPreset = nil }
                            )
                            .frame(width: 28, height: 50)
                        }
                        .padding(.leading, 8)
                        
                        // Divider
                        Rectangle()
                            .fill(Color(WinAmpColors.border))
                            .frame(width: 1, height: 70)
                            .padding(.horizontal, 4)
                        
                        // Band sliders
                        HStack(spacing: 2) {
                            ForEach(Array(EQBandFrequency.allCases.enumerated()), id: \.offset) { index, frequency in
                                VStack(spacing: 2) {
                                    Text(frequency.displayText)
                                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color(WinAmpColors.textDim))
                                    
                                    SkinnableEQSlider(
                                        value: $eqController.bandGains[index],
                                        range: -12...12,
                                        onChanged: { _ in selectedPreset = nil }
                                    )
                                    .frame(width: 14, height: 50)
                                }
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .onAppear {
            WindowCommunicator.shared.registerWindow("equalizer")
            applyPreset(EQPreset.flat)
        }
    }
    
    private var fallbackContent: some View {
        VStack(spacing: 8) {
            // Top controls
            HStack(spacing: 12) {
                EQToggleButton(isOn: $isEnabled, title: "ON") {
                    eqController.isEnabled = isEnabled
                }
                
                EQToggleButton(isOn: .constant(false), title: "AUTO") {
                    // TODO: Implement auto-gain
                }
                
                Spacer()
                
                Button(action: { showingPresetMenu.toggle() }) {
                    Text(selectedPreset?.name ?? "Custom")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(WinAmpColors.text)
                        .frame(width: 80)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingPresetMenu) {
                    PresetMenu(
                        selectedPreset: $selectedPreset,
                        onSelect: applyPreset
                    )
                }
            }
            .padding(.horizontal, 8)
            
            // EQ sliders (fallback to original implementation)
            HStack(spacing: 4) {
                // Preamp slider
                VStack(spacing: 2) {
                    Text("Preamp")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(WinAmpColors.textDim)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 8, height: 40)
                    
                    EQSlider(
                        value: $eqController.preampGain,
                        range: -12...12,
                        onChanged: { _ in selectedPreset = nil }
                    )
                    .frame(width: 20, height: 60)
                }
                
                Divider()
                    .frame(width: 1, height: 80)
                    .background(WinAmpColors.border)
                
                // Band sliders
                ForEach(Array(EQBandFrequency.allCases.enumerated()), id: \.offset) { index, frequency in
                    VStack(spacing: 2) {
                        Text(frequency.displayText)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(WinAmpColors.textDim)
                        
                        EQSlider(
                            value: $eqController.bandGains[index],
                            range: -12...12,
                            onChanged: { _ in selectedPreset = nil }
                        )
                        .frame(width: 20, height: 60)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
    
    private func applyPreset(_ preset: EQPreset) {
        selectedPreset = preset
        eqController.applyPreset(preset)
    }
}