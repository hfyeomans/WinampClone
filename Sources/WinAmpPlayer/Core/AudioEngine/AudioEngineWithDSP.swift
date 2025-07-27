//
//  AudioEngineWithDSP.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Extension to AudioEngine that adds DSP plugin support
//

import AVFoundation
import Combine

extension AudioEngine {
    
    /// Setup DSP processing in the audio chain
    func setupDSPProcessing() {
        // Get the DSP chain from plugin manager
        let dspChain = PluginManager.shared.activeDSPChain
        
        // Install tap after player node for DSP processing
        installDSPTap()
    }
    
    /// Install a tap for DSP processing
    private func installDSPTap() {
        // We need to intercept audio between player and mixer
        // This requires creating an intermediate mixer node
        
        let dspMixer = AVAudioMixerNode()
        audioEngine.attach(dspMixer)
        
        // Disconnect player from main mixer
        audioEngine.disconnectNodeOutput(playerNode)
        
        // Connect player -> DSP mixer -> main mixer
        let format = playerNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: dspMixer, format: format)
        audioEngine.connect(dspMixer, to: audioEngine.mainMixerNode, format: format)
        
        // Install tap on DSP mixer for processing
        let bufferSize = AVAudioFrameCount(4096) // Standard buffer size for DSP
        
        dspMixer.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processDSPBuffer(buffer)
        }
        
        logger.info("DSP processing chain installed")
    }
    
    /// Process audio buffer through DSP chain
    private func processDSPBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert to DSP buffer format
        guard var dspBuffer = DSPAudioBuffer(from: buffer) else {
            logger.warning("Failed to create DSP buffer")
            return
        }
        
        // Process through plugin manager's DSP chain
        do {
            try PluginManager.shared.processDSPAudio(&dspBuffer)
            
            // Copy processed data back to original buffer
            if let processedBuffer = dspBuffer.toAVAudioPCMBuffer() {
                // Copy frames back to original buffer
                buffer.frameLength = processedBuffer.frameLength
                
                if let srcChannelData = processedBuffer.floatChannelData,
                   let dstChannelData = buffer.floatChannelData {
                    for channel in 0..<Int(buffer.format.channelCount) {
                        memcpy(dstChannelData[channel],
                               srcChannelData[channel],
                               Int(buffer.frameLength) * MemoryLayout<Float>.size)
                    }
                }
            }
        } catch {
            logger.error("DSP processing failed: \(error.localizedDescription)")
        }
    }
    
    /// Prepare DSP chain for the current audio format
    func prepareDSPChain() {
        guard let audioFile = audioFile else { return }
        
        let format = audioFile.processingFormat
        let maxFrames = AVAudioFrameCount(8192) // Maximum expected buffer size
        
        do {
            try PluginManager.shared.activeDSPChain.prepare(
                format: format,
                maxFrames: maxFrames
            )
            logger.info("DSP chain prepared for format: \(format)")
        } catch {
            logger.error("Failed to prepare DSP chain: \(error)")
        }
    }
    
    /// Get total DSP latency in seconds
    var dspLatency: TimeInterval {
        let sampleRate = audioFile?.processingFormat.sampleRate ?? 44100
        let latencySamples = PluginManager.shared.activeDSPChain.totalLatency
        return TimeInterval(latencySamples) / sampleRate
    }
}

// MARK: - Visualization Data with Plugin Support

extension AudioEngine {
    
    /// Process visualization data through plugin system
    func processVisualizationData() {
        guard let visualizationData = currentVisualizationData else { return }
        
        // Convert to plugin format
        let audioData = VisualizationAudioData(
            samples: visualizationData.leftChannel, // Use left channel for mono compatibility
            frequencyData: fftProcessor?.performFFT(on: visualizationData.leftChannel),
            sampleRate: visualizationData.sampleRate,
            channelCount: 2,
            timestamp: visualizationData.timestamp,
            beatInfo: nil // Could add beat detection here
        )
        
        // Get render context (this would come from the visualization view)
        if let context = currentRenderContext {
            PluginManager.shared.processVisualizationData(audioData, context: context)
        }
    }
    
    /// Set the current render context for visualizations
    func setVisualizationRenderContext(_ context: VisualizationRenderContext) {
        currentRenderContext = context
    }
    
    private var currentRenderContext: VisualizationRenderContext?
}

// MARK: - Player Event Notifications

extension AudioEngine {
    
    /// Send player events to general plugins
    private func notifyPlugins(event: PlayerEvent) {
        PluginManager.shared.sendPlayerEvent(event)
    }
    
    /// Override track loading to notify plugins
    func loadURLWithPluginSupport(_ url: URL) async throws {
        // Load the track
        try await loadURL(url)
        
        // Notify plugins
        notifyPlugins(event: .trackChanged(currentTrack))
    }
    
    /// Override playback state changes to notify plugins
    private func updatePlaybackStateWithPlugins(_ newState: PlaybackState) {
        playbackState = newState
        
        let pluginState: PlayerEvent.PlaybackState
        switch newState {
        case .playing:
            pluginState = .playing
        case .paused:
            pluginState = .paused
        case .stopped:
            pluginState = .stopped
        case .loading:
            pluginState = .loading
        default:
            pluginState = .stopped
        }
        
        notifyPlugins(event: .playbackStateChanged(pluginState))
    }
    
    /// Override volume changes to notify plugins
    var volumeWithPlugins: Float {
        get { volume }
        set {
            volume = newValue
            notifyPlugins(event: .volumeChanged(newValue))
        }
    }
}

// MARK: - FFT Processor (moved from separate file for integration)

class FFTProcessor {
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    private let n: Int
    private let nOver2: Int
    
    private var window: [Float]
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    
    init(bufferSize: Int = 2048) {
        // Ensure power of 2
        let log2Size = vDSP_Length(log2(Float(bufferSize)))
        self.log2n = log2Size
        self.n = 1 << log2Size
        self.nOver2 = n / 2
        
        // Create FFT setup
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup
        
        // Initialize buffers
        self.window = [Float](repeating: 0, count: n)
        self.realBuffer = [Float](repeating: 0, count: nOver2)
        self.imagBuffer = [Float](repeating: 0, count: nOver2)
        
        // Create Hamming window
        vDSP_hamm_window(&window, vDSP_Length(n), 0)
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func performFFT(on samples: [Float]) -> [Float] {
        // Ensure we have enough samples
        guard samples.count >= n else {
            return []
        }
        
        // Apply window
        var windowedSamples = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(n))
        
        // Convert to split complex format
        windowedSamples.withUnsafeBufferPointer { samplesPtr in
            realBuffer.withUnsafeMutableBufferPointer { realPtr in
                imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: realPtr.baseAddress!,
                        imagp: imagPtr.baseAddress!
                    )
                    
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: nOver2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(nOver2))
                    }
                    
                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Calculate magnitudes
                    var magnitudes = [Float](repeating: 0, count: nOver2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(nOver2))
                    
                    // Convert to dB scale
                    var scaledMagnitudes = [Float](repeating: 0, count: nOver2)
                    var scale = Float(1.0 / Float(n))
                    vDSP_vsmul(magnitudes, 1, &scale, &scaledMagnitudes, 1, vDSP_Length(nOver2))
                    
                    // Convert to dB
                    var dbMagnitudes = [Float](repeating: 0, count: nOver2)
                    var one = Float(1.0)
                    vDSP_vdbcon(scaledMagnitudes, 1, &one, &dbMagnitudes, 1, vDSP_Length(nOver2), 1)
                    
                    // Normalize to 0-1 range (-60dB to 0dB)
                    var normalizedMagnitudes = [Float](repeating: 0, count: nOver2)
                    var minDB = Float(-60.0)
                    var range = Float(60.0)
                    vDSP_vsadd(dbMagnitudes, 1, &minDB, &normalizedMagnitudes, 1, vDSP_Length(nOver2))
                    vDSP_vsdiv(normalizedMagnitudes, 1, &range, &normalizedMagnitudes, 1, vDSP_Length(nOver2))
                    
                    // Clamp to 0-1
                    var zero = Float(0.0)
                    var one = Float(1.0)
                    vDSP_vclip(normalizedMagnitudes, 1, &zero, &one, &normalizedMagnitudes, 1, vDSP_Length(nOver2))
                    
                    return normalizedMagnitudes
                }
            }
        }
    }
}