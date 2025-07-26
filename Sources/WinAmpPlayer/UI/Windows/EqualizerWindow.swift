//
//  EqualizerWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  10-band graphic equalizer window implementation
//

import SwiftUI
import AppKit
import AVFoundation

/// Equalizer band frequencies (in Hz)
enum EQBandFrequency: Int, CaseIterable {
    case hz60 = 60
    case hz170 = 170
    case hz310 = 310
    case hz600 = 600
    case hz1k = 1000
    case hz3k = 3000
    case hz6k = 6000
    case hz12k = 12000
    case hz14k = 14000
    case hz16k = 16000
    
    var displayText: String {
        switch self {
        case .hz60: return "60"
        case .hz170: return "170"
        case .hz310: return "310"
        case .hz600: return "600"
        case .hz1k: return "1K"
        case .hz3k: return "3K"
        case .hz6k: return "6K"
        case .hz12k: return "12K"
        case .hz14k: return "14K"
        case .hz16k: return "16K"
        }
    }
}

/// Equalizer preset
struct EQPreset: Identifiable, Codable {
    let id = UUID()
    let name: String
    let gains: [Float] // 10 values, -12 to +12 dB
    let preamp: Float // -12 to +12 dB
    
    static let flat = EQPreset(name: "Flat", gains: Array(repeating: 0, count: 10), preamp: 0)
    static let rock = EQPreset(name: "Rock", gains: [5, 4, 3, 0, -2, -3, 0, 2, 3, 4], preamp: 0)
    static let pop = EQPreset(name: "Pop", gains: [-2, -1, 0, 2, 4, 4, 2, 0, -1, -2], preamp: 0)
    static let jazz = EQPreset(name: "Jazz", gains: [0, 2, 3, 3, 2, 0, 0, 2, 3, 3], preamp: 0)
    static let classical = EQPreset(name: "Classical", gains: [0, 0, 0, 0, 0, 0, -4, -4, -4, -6], preamp: 0)
    static let dance = EQPreset(name: "Dance", gains: [6, 5, 2, 0, 0, -3, -4, -4, 0, 0], preamp: 2)
    static let bass = EQPreset(name: "Bass", gains: [8, 8, 8, 4, 2, 0, 0, 0, 0, 0], preamp: 2)
    static let treble = EQPreset(name: "Treble", gains: [-6, -6, -6, -2, 0, 2, 6, 8, 8, 8], preamp: 0)
    
    static let builtInPresets = [flat, rock, pop, jazz, classical, dance, bass, treble]
}

/// Classic WinAmp-style equalizer window
struct EqualizerWindow: View {
    @StateObject private var eqController: EqualizerController
    @State private var isEnabled = true
    @State private var selectedPreset: EQPreset? = EQPreset.flat
    @State private var showingPresetMenu = false
    
    private let configuration = WinAmpWindowConfiguration(
        title: "Equalizer",
        windowType: .equalizer,
        showTitleBar: true,
        resizable: false,
        minSize: CGSize(width: 275, height: 116),
        maxSize: CGSize(width: 275, height: 116)
    )
    
    init(audioEngine: AudioEngine) {
        _eqController = StateObject(wrappedValue: EqualizerController(audioEngine: audioEngine))
    }
    
    var body: some View {
        WinAmpWindow(
            configuration: configuration
        ) {
            VStack(spacing: 8) {
                // Top controls
                HStack(spacing: 12) {
                    // On/Off toggle
                    EQToggleButton(isOn: $isEnabled, title: "ON") {
                        eqController.isEnabled = isEnabled
                    }
                    
                    // Auto toggle
                    EQToggleButton(isOn: .constant(false), title: "AUTO") {
                        // TODO: Implement auto-gain
                    }
                    
                    Spacer()
                    
                    // Preset button
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
                
                // EQ sliders
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
            .background(WinAmpColors.background)
        }
        .onAppear {
            WindowCommunicator.shared.registerWindow("equalizer")
            applyPreset(EQPreset.flat)
        }
    }
    
    private func applyPreset(_ preset: EQPreset) {
        selectedPreset = preset
        eqController.applyPreset(preset)
    }
}

/// EQ toggle button (ON/AUTO)
struct EQToggleButton: View {
    @Binding var isOn: Bool
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            isOn.toggle()
            action()
        }) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isOn ? WinAmpColors.text : WinAmpColors.textDim)
                .frame(width: 30, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isOn ? WinAmpColors.backgroundLight : WinAmpColors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(WinAmpColors.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Vertical EQ slider
struct EQSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChanged: (Float) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(WinAmpColors.backgroundLight)
                    .frame(width: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(WinAmpColors.border, lineWidth: 1)
                    )
                
                // Center line (0 dB)
                Rectangle()
                    .fill(WinAmpColors.border)
                    .frame(width: 12, height: 1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Thumb
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let yPosition = geometry.size.height * (1 - CGFloat(normalizedValue))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDragging ? WinAmpColors.accent : WinAmpColors.text)
                    .frame(width: 16, height: 8)
                    .position(x: geometry.size.width / 2, y: yPosition)
                    .shadow(color: WinAmpColors.shadow, radius: 2, x: 0, y: 1)
            }
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

/// Preset selection menu
struct PresetMenu: View {
    @Binding var selectedPreset: EQPreset?
    let onSelect: (EQPreset) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(EQPreset.builtInPresets) { preset in
                PresetMenuItem(
                    preset: preset,
                    isSelected: selectedPreset?.name == preset.name,
                    action: {
                        onSelect(preset)
                        dismiss()
                    }
                )
            }
            
            Divider()
                .background(WinAmpColors.border)
                .padding(.vertical, 2)
            
            // TODO: Add custom preset support
            MenuButton(title: "Save Preset...", action: {
                // TODO: Implement save preset
                dismiss()
            })
            
            MenuButton(title: "Delete Preset...", action: {
                // TODO: Implement delete preset
                dismiss()
            })
        }
        .padding(8)
        .frame(width: 150)
        .background(WinAmpColors.background)
    }
}

/// Preset menu item
struct PresetMenuItem: View {
    let preset: EQPreset
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(preset.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isHovered ? .white : WinAmpColors.text)
                
                Spacer()
                
                if isSelected {
                    Text("✓")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(WinAmpColors.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(isHovered ? WinAmpColors.selection.opacity(0.5) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Equalizer controller managing the audio processing
class EqualizerController: ObservableObject {
    @Published var isEnabled = true {
        didSet { updateEQ() }
    }
    
    @Published var preampGain: Float = 0 {
        didSet { updateEQ() }
    }
    
    @Published var bandGains: [Float] = Array(repeating: 0, count: 10) {
        didSet { updateEQ() }
    }
    
    private let audioEngine: AudioEngine
    private var eqNode: AVAudioUnitEQ?
    
    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
        setupEQ()
    }
    
    private func setupEQ() {
        // Note: In a real implementation, we would:
        // 1. Create an AVAudioUnitEQ with 10 bands
        // 2. Insert it into the audio engine's processing chain
        // 3. Configure each band with the appropriate frequency and Q factor
        
        // For now, we'll just store the values
        // The actual audio processing integration would require
        // access to the audio engine's internal AVAudioEngine
    }
    
    func applyPreset(_ preset: EQPreset) {
        preampGain = preset.preamp
        for (index, gain) in preset.gains.enumerated() {
            if index < bandGains.count {
                bandGains[index] = gain
            }
        }
    }
    
    private func updateEQ() {
        // Update the actual EQ node with new values
        // This would apply the gain values to each band
        // and enable/disable the effect based on isEnabled
    }
}