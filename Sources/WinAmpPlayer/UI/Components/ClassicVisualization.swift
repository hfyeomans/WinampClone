//
//  ClassicVisualization.swift
//  WinAmpPlayer
//
//  Classic WinAmp spectrum analyzer and oscilloscope
//

import SwiftUI
import Combine

struct ClassicVisualization: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 19)
    @State private var peakHeights: [CGFloat] = Array(repeating: 0, count: 19)
    @State private var peakTimers: [Date] = Array(repeating: Date(), count: 19)
    @State private var mode: VisualizationMode = .spectrum
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    enum VisualizationMode {
        case spectrum
        case oscilloscope
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                WinAmpColors.lcdBackground
                
                if mode == .spectrum {
                    // Spectrum analyzer
                    HStack(spacing: 1) {
                        ForEach(0..<19) { index in
                            SpectrumBar(
                                height: barHeights[index],
                                peakHeight: peakHeights[index],
                                maxHeight: geometry.size.height
                            )
                        }
                    }
                } else {
                    // Oscilloscope
                    WaveformView(heights: barHeights)
                }
            }
            .overlay(BeveledBorder(raised: false))
            .onTapGesture {
                mode = mode == .spectrum ? .oscilloscope : .spectrum
            }
        }
        .frame(width: 76, height: 16)
        .onReceive(timer) { _ in
            updateVisualization()
        }
    }
    
    private func updateVisualization() {
        // Simulate audio data
        for i in 0..<19 {
            // Generate new height
            let newHeight = CGFloat.random(in: 0...1) * 
                           (1.0 - CGFloat(i) / 19.0) * // Higher bars on left
                           (mode == .spectrum ? 1.0 : 0.7)
            
            // Smooth animation
            withAnimation(.linear(duration: 0.05)) {
                barHeights[i] = newHeight
            }
            
            // Update peaks (spectrum only)
            if mode == .spectrum {
                if newHeight > peakHeights[i] {
                    peakHeights[i] = newHeight
                    peakTimers[i] = Date()
                } else if Date().timeIntervalSince(peakTimers[i]) > 0.5 {
                    // Peak falls after 0.5 seconds
                    withAnimation(.linear(duration: 0.1)) {
                        peakHeights[i] = max(0, peakHeights[i] - 0.1)
                    }
                }
            }
        }
    }
}

struct SpectrumBar: View {
    let height: CGFloat
    let peakHeight: CGFloat
    let maxHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                // Peak indicator
                if peakHeight > 0 {
                    Rectangle()
                        .fill(peakColor(for: peakHeight))
                        .frame(height: 1)
                        .offset(y: -peakHeight * geometry.size.height)
                }
                
                // Bar segments
                ForEach(0..<Int(height * 8), id: \.self) { segment in
                    Rectangle()
                        .fill(segmentColor(for: CGFloat(segment) / 8.0))
                        .frame(height: 1)
                }
            }
        }
        .frame(width: 3)
    }
    
    private func segmentColor(for position: CGFloat) -> Color {
        if position > 0.7 {
            return Color(red: 1, green: 0, blue: 0) // Red
        } else if position > 0.4 {
            return Color(red: 1, green: 1, blue: 0) // Yellow
        } else {
            return WinAmpColors.lcdText // Green
        }
    }
    
    private func peakColor(for height: CGFloat) -> Color {
        if height > 0.7 {
            return Color(red: 1, green: 0, blue: 0)
        } else if height > 0.4 {
            return Color(red: 1, green: 1, blue: 0)
        } else {
            return WinAmpColors.lcdText
        }
    }
}

struct WaveformView: View {
    let heights: [CGFloat]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let step = width / CGFloat(heights.count - 1)
                
                path.move(to: CGPoint(x: 0, y: height / 2))
                
                for (index, value) in heights.enumerated() {
                    let x = CGFloat(index) * step
                    let y = (height / 2) - (value * height * 0.4) + 
                           (height / 2) * sin(CGFloat(index) * 0.5)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(WinAmpColors.lcdText, lineWidth: 1)
        }
    }
}