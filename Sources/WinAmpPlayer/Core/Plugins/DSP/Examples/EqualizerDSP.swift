//
//  EqualizerDSP.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Example DSP plugin: 10-band graphic equalizer
//

import Foundation
import AVFoundation
import Accelerate

/// 10-band graphic equalizer DSP plugin
public final class EqualizerDSPPlugin: BaseDSPPlugin {
    
    // Frequency bands (Hz)
    private let frequencyBands: [Float] = [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    
    // Biquad filters for each band
    private var filters: [[BiquadFilter]] = [] // [band][channel]
    
    // Current gain values in dB
    private var gains: [Float] = Array(repeating: 0.0, count: 10)
    
    public override var latency: Int {
        // Each biquad filter has 2 samples of latency
        return 2
    }
    
    public init() {
        let metadata = PluginMetadata(
            identifier: "com.winamp.dsp.equalizer",
            name: "10-Band Equalizer",
            type: .dsp,
            version: "1.0.0",
            author: "WinAmp Team",
            description: "Professional 10-band graphic equalizer with ±12dB range"
        )
        
        super.init(metadata: metadata)
        
        // Initialize parameters
        for (index, frequency) in frequencyBands.enumerated() {
            let param = DSPParameter(
                id: "band_\(index)",
                name: "\(formatFrequency(frequency)) Hz",
                type: .float(min: -12.0, max: 12.0, defaultValue: 0.0),
                unit: "dB"
            )
            parameters.append(param)
        }
        
        // Add preamp parameter
        let preampParam = DSPParameter(
            id: "preamp",
            name: "Preamp",
            type: .float(min: -12.0, max: 12.0, defaultValue: 0.0),
            unit: "dB"
        )
        parameters.append(preampParam)
    }
    
    public override func prepare(format: AVAudioFormat, maxFrames: AVAudioFrameCount) throws {
        try super.prepare(format: format, maxFrames: maxFrames)
        
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        
        // Initialize filters for each band and channel
        filters = []
        for bandIndex in 0..<frequencyBands.count {
            var bandFilters: [BiquadFilter] = []
            for _ in 0..<channelCount {
                let filter = BiquadFilter()
                let frequency = Double(frequencyBands[bandIndex])
                let gain = Double(gains[bandIndex])
                
                // Configure as peaking EQ filter
                filter.configurePeakingEQ(
                    sampleRate: sampleRate,
                    centerFrequency: frequency,
                    q: 0.7, // Q factor for moderate bandwidth
                    gainDB: gain
                )
                
                bandFilters.append(filter)
            }
            filters.append(bandFilters)
        }
    }
    
    public override func process(buffer: inout DSPAudioBuffer) throws {
        guard !filters.isEmpty else {
            throw DSPError.notPrepared
        }
        
        let channelCount = buffer.channelCount
        let frameCount = Int(buffer.frameCount)
        
        // Get preamp gain
        let preampGain = parameters.first(where: { $0.id == "preamp" })?.value as? Float ?? 0.0
        let preampLinear = pow(10.0, preampGain / 20.0)
        
        // Process each channel
        for channel in 0..<channelCount {
            let channelData = buffer.channel(channel)
            
            // Apply preamp if needed
            if preampGain != 0.0 {
                var frameCountVDSP = vDSP_Length(frameCount)
                vDSP_vsmul(channelData, 1, &preampLinear, channelData, 1, frameCountVDSP)
            }
            
            // Process through each band's filter
            for bandIndex in 0..<frequencyBands.count {
                if gains[bandIndex] != 0.0 {
                    filters[bandIndex][channel].process(
                        input: channelData,
                        output: channelData,
                        frameCount: frameCount
                    )
                }
            }
        }
    }
    
    public override func reset() {
        for bandFilters in filters {
            for filter in bandFilters {
                filter.reset()
            }
        }
    }
    
    public override func setParameter(id: String, value: Any) throws {
        try super.setParameter(id: id, value: value)
        
        // Update filter if it's a band parameter
        if id.starts(with: "band_"), 
           let bandIndex = Int(id.dropFirst(5)),
           bandIndex < frequencyBands.count,
           let gain = value as? Float {
            
            gains[bandIndex] = gain
            
            // Update all channel filters for this band
            if let format = format {
                let sampleRate = format.sampleRate
                let frequency = Double(frequencyBands[bandIndex])
                
                for channelFilter in filters[bandIndex] {
                    channelFilter.configurePeakingEQ(
                        sampleRate: sampleRate,
                        centerFrequency: frequency,
                        q: 0.7,
                        gainDB: Double(gain)
                    )
                }
            }
        }
    }
    
    private func formatFrequency(_ freq: Float) -> String {
        if freq >= 1000 {
            return String(format: "%.0fk", freq / 1000)
        } else {
            return String(format: "%.0f", freq)
        }
    }
}

// MARK: - Biquad Filter

/// Simple biquad filter implementation
private class BiquadFilter {
    // Filter coefficients
    private var a0: Double = 1.0
    private var a1: Double = 0.0
    private var a2: Double = 0.0
    private var b0: Double = 1.0
    private var b1: Double = 0.0
    private var b2: Double = 0.0
    
    // Filter state
    private var x1: Double = 0.0
    private var x2: Double = 0.0
    private var y1: Double = 0.0
    private var y2: Double = 0.0
    
    /// Configure as a peaking EQ filter
    func configurePeakingEQ(sampleRate: Double, centerFrequency: Double, q: Double, gainDB: Double) {
        let omega = 2.0 * Double.pi * centerFrequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        let A = pow(10.0, gainDB / 40.0)
        
        // Peaking EQ coefficients
        b0 = 1.0 + alpha * A
        b1 = -2.0 * cosOmega
        b2 = 1.0 - alpha * A
        a0 = 1.0 + alpha / A
        a1 = -2.0 * cosOmega
        a2 = 1.0 - alpha / A
        
        // Normalize coefficients
        let norm = 1.0 / a0
        b0 *= norm
        b1 *= norm
        b2 *= norm
        a1 *= norm
        a2 *= norm
    }
    
    /// Process audio samples
    func process(input: UnsafeMutablePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let x0 = Double(input[i])
            
            // Direct Form II
            let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            
            // Update state
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
            
            output[i] = Float(y0)
        }
    }
    
    /// Reset filter state
    func reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
    }
}