import Foundation
import AVFoundation
import Accelerate
import AppKit

/// Example of how to integrate the visualization plugin system with an audio player
public class VisualizationIntegrationExample {
    
    // MARK: - Properties
    
    private let pluginManager = VisualizationPluginManager.shared
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var fftAnalyzer: FFTAnalyzer?
    private var beatDetector: SimpleBeatDetector?
    
    // Visualization view
    public let visualizationView = PluginVisualizationView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    
    // MARK: - Setup
    
    public init() {
        setupAudioEngine()
        setupPlugins()
    }
    
    private func setupAudioEngine() {
        // Attach player node
        audioEngine.attach(playerNode)
        
        // Get main mixer node
        let mainMixer = audioEngine.mainMixerNode
        
        // Connect player to main mixer
        audioEngine.connect(playerNode, to: mainMixer, format: nil)
        
        // Install tap on mixer node to capture audio data
        let format = mainMixer.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        
        // Initialize FFT analyzer
        fftAnalyzer = FFTAnalyzer(bufferSize: 2048)
        beatDetector = SimpleBeatDetector(sampleRate: Float(sampleRate))
        
        // Install audio tap
        mainMixer.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        // Start engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func setupPlugins() {
        // Register additional custom plugins
        let matrixPlugin = MatrixRainVisualizationPlugin()
        pluginManager.register(matrixPlugin)
        
        // Activate default plugin
        pluginManager.activatePlugin(withIdentifier: "com.winamp.visualization.spectrum")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        // Perform FFT analysis
        let frequencyData = fftAnalyzer?.analyze(samples) ?? []
        
        // Detect beats
        let beatInfo = beatDetector?.processSamples(samples)
        
        // Create visualization data
        let audioData = VisualizationAudioData(
            samples: samples,
            frequencyData: frequencyData,
            sampleRate: buffer.format.sampleRate,
            channelCount: Int(buffer.format.channelCount),
            timestamp: CACurrentMediaTime(),
            beatInfo: beatInfo
        )
        
        // Update visualization view
        visualizationView.updateAudioData(audioData)
    }
    
    // MARK: - Playback Control
    
    public func play(url: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            
            playerNode.scheduleFile(audioFile, at: nil) {
                print("Playback completed")
            }
            
            playerNode.play()
        } catch {
            print("Failed to play audio file: \(error)")
        }
    }
    
    public func stop() {
        playerNode.stop()
    }
    
    // MARK: - Plugin Control
    
    public func switchToPlugin(withIdentifier identifier: String) {
        pluginManager.activatePlugin(withIdentifier: identifier)
    }
    
    public func availablePlugins() -> [(id: String, name: String)] {
        return pluginManager.availablePlugins().map {
            ($0.metadata.identifier, $0.metadata.name)
        }
    }
}

// MARK: - FFT Analyzer

private class FFTAnalyzer {
    private let bufferSize: Int
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup
    private var window: [Float]
    
    init(bufferSize: Int) {
        self.bufferSize = bufferSize
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        // Create Hanning window
        self.window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func analyze(_ samples: [Float]) -> [Float] {
        guard samples.count >= bufferSize else { return [] }
        
        // Apply window
        var windowedSamples = [Float](repeating: 0, count: bufferSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(bufferSize))
        
        // Prepare for FFT
        var realp = [Float](repeating: 0, count: bufferSize/2)
        var imagp = [Float](repeating: 0, count: bufferSize/2)
        
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: bufferSize/2) { complexPtr in
                var complexBuffer = DSPSplitComplex(realp: &realp, imagp: &imagp)
                vDSP_ctoz(complexPtr, 2, &complexBuffer, 1, vDSP_Length(bufferSize/2))
            }
        }
        
        // Perform FFT
        var complexBuffer = DSPSplitComplex(realp: &realp, imagp: &imagp)
        vDSP_fft_zrip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(kFFTDirection_Forward))
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: bufferSize/2)
        vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(bufferSize/2))
        
        // Convert to dB
        var dbMagnitudes = [Float](repeating: 0, count: bufferSize/2)
        var zero: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &zero, &dbMagnitudes, 1, vDSP_Length(bufferSize/2), 0)
        
        // Normalize
        var normalizedMagnitudes = dbMagnitudes.map { max(0, ($0 + 60) / 60) }
        
        return normalizedMagnitudes
    }
}

// MARK: - Simple Beat Detector

private class SimpleBeatDetector {
    private let sampleRate: Float
    private var energyHistory: [Float] = []
    private let historySize = 43 // ~1 second at 44.1kHz with 1024 samples
    private var lastBeatTime: TimeInterval = 0
    private var bpmHistory: [Double] = []
    
    init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }
    
    func processSamples(_ samples: [Float]) -> VisualizationAudioData.BeatInfo {
        // Calculate instant energy
        let energy = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        
        // Add to history
        energyHistory.append(energy)
        if energyHistory.count > historySize {
            energyHistory.removeFirst()
        }
        
        // Calculate average energy
        let averageEnergy = energyHistory.reduce(0, +) / Float(energyHistory.count)
        
        // Detect beat if current energy is significantly higher than average
        let beatThreshold: Float = 1.3
        let isBeat = energy > averageEnergy * beatThreshold
        
        // Calculate BPM
        var currentBPM: Double = 120 // Default
        if isBeat {
            let currentTime = CACurrentMediaTime()
            if lastBeatTime > 0 {
                let beatInterval = currentTime - lastBeatTime
                let instantBPM = 60.0 / beatInterval
                
                // Only accept reasonable BPM values
                if instantBPM > 60 && instantBPM < 200 {
                    bpmHistory.append(instantBPM)
                    if bpmHistory.count > 10 {
                        bpmHistory.removeFirst()
                    }
                    currentBPM = bpmHistory.reduce(0, +) / Double(bpmHistory.count)
                }
            }
            lastBeatTime = currentTime
        }
        
        let intensity = min(energy / (averageEnergy * 2), 1.0)
        
        return VisualizationAudioData.BeatInfo(
            isBeat: isBeat,
            bpm: currentBPM,
            intensity: intensity
        )
    }
}

// MARK: - Usage Example

/*
 To use the visualization system in your WinAmp clone:
 
 1. Create the integration:
    let visualization = VisualizationIntegrationExample()
 
 2. Add the visualization view to your window:
    window.contentView?.addSubview(visualization.visualizationView)
 
 3. Play audio:
    let audioURL = URL(fileURLWithPath: "/path/to/audio.mp3")
    visualization.play(url: audioURL)
 
 4. Switch between visualizations:
    // Get available plugins
    let plugins = visualization.availablePlugins()
    
    // Switch to a different plugin
    visualization.switchToPlugin(withIdentifier: "com.example.visualization.matrix")
 
 5. Configure the active plugin:
    if let plugin = VisualizationPluginManager.shared.currentPlugin {
        plugin.updateConfiguration(key: "barColor", value: CGColor(red: 1, green: 0, blue: 1, alpha: 1))
    }
 */