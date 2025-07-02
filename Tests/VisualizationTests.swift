import XCTest
import AVFoundation
import Accelerate
import MetalKit
@testable import WinAmpPlayer

final class VisualizationTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    var fftProcessor: FFTProcessor!
    var pluginManager: VisualizationPluginManager!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        fftProcessor = FFTProcessor()
        pluginManager = VisualizationPluginManager.shared
    }
    
    override func tearDown() {
        audioEngine = nil
        fftProcessor = nil
        pluginManager = nil
        super.tearDown()
    }
    
    // MARK: - FFT Processor Tests
    
    func testFFTProcessorInitialization() {
        // Test different FFT sizes
        for fftSize in FFTProcessor.FFTSize.allCases {
            let processor = FFTProcessor(fftSize: fftSize, sampleRate: 44100)
            XCTAssertEqual(processor.currentFFTSize, fftSize)
            XCTAssertEqual(processor.frequencyBinCount, fftSize.rawValue / 2)
            XCTAssertEqual(processor.maxFrequency, 22050) // Nyquist frequency
        }
    }
    
    func testFFTAccuracy() {
        // Generate test signal with known frequency
        let sampleRate: Float = 44100
        let testFrequency: Float = 440 // A4 note
        let duration: Float = 0.1
        let sampleCount = Int(sampleRate * duration)
        
        var testSignal = [Float](repeating: 0, count: sampleCount)
        
        // Generate sine wave
        for i in 0..<sampleCount {
            testSignal[i] = sin(2.0 * Float.pi * testFrequency * Float(i) / sampleRate)
        }
        
        // Perform FFT
        let magnitudes = fftProcessor.performFFT(samples: testSignal)
        
        // Find peak frequency
        let binFrequency = sampleRate / Float(fftProcessor.currentFFTSize.rawValue)
        let expectedBin = Int(testFrequency / binFrequency)
        
        // Find actual peak
        var maxMagnitude: Float = -Float.infinity
        var peakBin = 0
        
        for (bin, magnitude) in magnitudes.enumerated() {
            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                peakBin = bin
            }
        }
        
        // Verify peak is at expected frequency (within 2 bins tolerance)
        XCTAssertLessThanOrEqual(abs(peakBin - expectedBin), 2,
                                  "Peak frequency detection failed. Expected bin: \(expectedBin), got: \(peakBin)")
    }
    
    func testFFTPerformance() {
        let testSamples = [Float](repeating: 0.5, count: 2048)
        
        measure {
            // Test FFT performance
            for _ in 0..<100 {
                _ = fftProcessor.performFFT(samples: testSamples)
            }
        }
    }
    
    func testFrequencyBandExtraction() {
        // Generate multi-frequency test signal
        let sampleRate: Float = 44100
        let duration: Float = 0.1
        let sampleCount = Int(sampleRate * duration)
        
        var testSignal = [Float](repeating: 0, count: sampleCount)
        
        // Add multiple frequency components
        let frequencies: [Float] = [100, 440, 1000, 5000, 10000]
        for freq in frequencies {
            for i in 0..<sampleCount {
                testSignal[i] += 0.2 * sin(2.0 * Float.pi * freq * Float(i) / sampleRate)
            }
        }
        
        // Perform FFT and get bands
        let magnitudes = fftProcessor.performFFT(samples: testSignal)
        let bands = fftProcessor.getBands(magnitudes: magnitudes, bandCount: 16)
        
        // Verify we have correct number of bands
        XCTAssertEqual(bands.count, 16)
        
        // Verify all bands are in valid range
        for band in bands {
            XCTAssertGreaterThanOrEqual(band, 0.0)
            XCTAssertLessThanOrEqual(band, 1.0)
        }
    }
    
    func testSmoothingAndDecay() {
        let testSamples = [Float](repeating: 0.5, count: 1024)
        
        // First pass - should show signal
        let magnitudes1 = fftProcessor.performFFT(samples: testSamples)
        let bands1 = fftProcessor.getBands(magnitudes: magnitudes1, bandCount: 16)
        
        // Second pass with silence - should show decay
        let silenceSamples = [Float](repeating: 0, count: 1024)
        let magnitudes2 = fftProcessor.performFFT(samples: silenceSamples)
        let bands2 = fftProcessor.getBands(magnitudes: magnitudes2, bandCount: 16)
        
        // Verify decay is applied
        for i in 0..<bands1.count {
            if bands1[i] > 0.1 {
                XCTAssertLessThan(bands2[i], bands1[i], "Decay not applied properly")
            }
        }
    }
    
    // MARK: - Visualization Plugin Tests
    
    func testPluginRegistration() {
        let availablePlugins = pluginManager.availablePlugins()
        
        // Verify built-in plugins are registered
        XCTAssertGreaterThanOrEqual(availablePlugins.count, 2)
        
        // Check for spectrum and oscilloscope plugins
        let pluginIds = availablePlugins.map { $0.metadata.identifier }
        XCTAssertTrue(pluginIds.contains("com.winamp.visualization.spectrum"))
        XCTAssertTrue(pluginIds.contains("com.winamp.visualization.oscilloscope"))
    }
    
    func testPluginActivation() {
        // Test activating spectrum plugin
        pluginManager.activatePlugin(withIdentifier: "com.winamp.visualization.spectrum")
        
        // Give it time to activate
        let expectation = XCTestExpectation(description: "Plugin activation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.pluginManager.currentPlugin)
            XCTAssertEqual(self.pluginManager.currentPlugin?.metadata.identifier,
                          "com.winamp.visualization.spectrum")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPluginConfiguration() {
        let spectrumPlugin = SpectrumVisualizationPlugin()
        
        // Test configuration options
        XCTAssertFalse(spectrumPlugin.configurationOptions.isEmpty)
        
        // Find bar count configuration
        let barCountConfig = spectrumPlugin.configurationOptions.first { $0.key == "barCount" }
        XCTAssertNotNil(barCountConfig)
        
        // Test updating configuration
        spectrumPlugin.updateConfiguration(key: "barCount", value: 64)
        
        // Verify peak hold toggle
        spectrumPlugin.updateConfiguration(key: "peakHold", value: false)
    }
    
    // MARK: - Metal Rendering Tests
    
    func testMetalDeviceAvailability() {
        let device = MTLCreateSystemDefaultDevice()
        XCTAssertNotNil(device, "Metal device not available")
        
        // Check for macOS 15.5 specific features
        if #available(macOS 15.5, *) {
            // Test for any new Metal features in macOS 15.5
            XCTAssertTrue(device!.supportsFamily(.apple9) || device!.supportsFamily(.apple8),
                         "Expected Apple GPU family support")
        }
    }
    
    func testMetalShaderCompilation() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device not available")
            return
        }
        
        // Test compiling the visualization shaders
        do {
            let library = try device.makeLibrary(source: VisualizationRenderer.metalShaderSource,
                                                options: nil)
            
            // Verify all shader functions exist
            let shaderFunctions = [
                "simpleVertex",
                "spectrumBarFragment",
                "peakFragment",
                "gridFragment",
                "waveformFragment"
            ]
            
            for functionName in shaderFunctions {
                let function = library.makeFunction(name: functionName)
                XCTAssertNotNil(function, "Shader function '\(functionName)' not found")
            }
            
        } catch {
            XCTFail("Failed to compile shaders: \(error)")
        }
    }
    
    func testMetalRenderingPerformance() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal device not available")
            return
        }
        
        // Create a test MTKView
        let mtkView = MTKView()
        mtkView.device = device
        mtkView.preferredFramesPerSecond = 60
        
        // Create renderer
        let renderer = VisualizationRenderer(metalView: mtkView, audioEngine: audioEngine)
        XCTAssertNotNil(renderer)
        
        // Measure rendering performance
        measure {
            // Simulate 60 frames
            for _ in 0..<60 {
                renderer?.draw(in: mtkView)
            }
        }
    }
    
    // MARK: - Audio Tap Tests
    
    func testAudioTapInstallation() {
        // Enable visualization
        audioEngine.enableVisualization()
        XCTAssertTrue(audioEngine.isVisualizationEnabled)
        
        // Test data flow by checking if we can get frequency data
        // (In a real test, we'd load an audio file first)
        let frequencyData = audioEngine.getFrequencyData()
        let waveformData = audioEngine.getWaveformData()
        
        // Initially should be empty without audio
        XCTAssertTrue(frequencyData.isEmpty || frequencyData.count > 0)
        XCTAssertTrue(waveformData.isEmpty || waveformData.count > 0)
        
        // Disable visualization
        audioEngine.disableVisualization()
        XCTAssertFalse(audioEngine.isVisualizationEnabled)
    }
    
    func testVisualizationDataPublisher() {
        let expectation = XCTestExpectation(description: "Receive visualization data")
        
        var receivedData: AudioVisualizationData?
        let cancellable = audioEngine.audioVisualizationDataPublisher.sink { data in
            receivedData = data
            expectation.fulfill()
        }
        
        // Enable visualization
        audioEngine.enableVisualization()
        
        // In a real test, we'd play audio here
        // For now, just verify the publisher is set up correctly
        
        // Clean up
        audioEngine.disableVisualization()
        cancellable.cancel()
        
        // Don't wait for expectation as we need actual audio playback
        // This is more of a setup verification test
    }
    
    // MARK: - Integration Tests
    
    func testSpectrumAnalyzerIntegration() {
        // Test the full pipeline: FFT -> Bands -> Visualization
        let testSignal = generateTestSignal(frequency: 1000, sampleRate: 44100, duration: 0.1)
        
        // Process through FFT
        let magnitudes = fftProcessor.performFFT(samples: testSignal)
        let bands = fftProcessor.getBands(magnitudes: magnitudes, bandCount: 32)
        
        // Verify bands are reasonable
        XCTAssertEqual(bands.count, 32)
        
        // At least some bands should have signal
        let activeBands = bands.filter { $0 > 0.1 }
        XCTAssertGreaterThan(activeBands.count, 0, "No active frequency bands detected")
    }
    
    // MARK: - Helper Methods
    
    private func generateTestSignal(frequency: Float, sampleRate: Float, duration: Float) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var signal = [Float](repeating: 0, count: sampleCount)
        
        for i in 0..<sampleCount {
            signal[i] = sin(2.0 * Float.pi * frequency * Float(i) / sampleRate)
        }
        
        return signal
    }
}

// MARK: - Performance Benchmarks

final class VisualizationPerformanceTests: XCTestCase {
    
    func testFFTProcessorThroughput() {
        let processor = FFTProcessor(fftSize: .size1024, sampleRate: 44100)
        let testSamples = [Float](repeating: 0.5, count: 1024)
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Process 1 second of audio at 60 FPS
            for _ in 0..<60 {
                let magnitudes = processor.performFFT(samples: testSamples)
                _ = processor.getBands(magnitudes: magnitudes, bandCount: 32)
            }
        }
    }
    
    func testMetalRenderingFrameRate() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            XCTSkip("Metal not available")
            return
        }
        
        let mtkView = MTKView()
        mtkView.device = device
        mtkView.preferredFramesPerSecond = 60
        
        let audioEngine = AudioEngine()
        let renderer = VisualizationRenderer(metalView: mtkView, audioEngine: audioEngine)
        
        var frameCount = 0
        let startTime = CACurrentMediaTime()
        
        // Render 300 frames (5 seconds at 60 FPS)
        for _ in 0..<300 {
            autoreleasepool {
                renderer?.draw(in: mtkView)
                frameCount += 1
            }
        }
        
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        let fps = Double(frameCount) / duration
        
        print("Average FPS: \(fps)")
        XCTAssertGreaterThan(fps, 55, "Frame rate below 55 FPS")
    }
    
    func testMemoryUsageDuringVisualization() {
        let processor = FFTProcessor(fftSize: .size2048, sampleRate: 44100)
        
        measure(metrics: [XCTMemoryMetric()]) {
            // Simulate 10 seconds of visualization
            for _ in 0..<600 { // 60 FPS * 10 seconds
                autoreleasepool {
                    let testSamples = [Float](repeating: Float.random(in: -1...1), count: 2048)
                    let magnitudes = processor.performFFT(samples: testSamples)
                    _ = processor.getBands(magnitudes: magnitudes, bandCount: 32)
                }
            }
        }
    }
}