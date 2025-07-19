import Foundation
import Accelerate
import Combine

/// FFT processor for spectrum analysis using Accelerate framework
final class FFTProcessor: ObservableObject {
    
    // MARK: - Types
    
    enum FFTSize: Int, CaseIterable {
        case size256 = 256
        case size512 = 512
        case size1024 = 1024
        case size2048 = 2048
        
        var log2Size: Int {
            switch self {
            case .size256: return 8
            case .size512: return 9
            case .size1024: return 10
            case .size2048: return 11
            }
        }
    }
    
    // MARK: - Properties
    
    private let fftSize: FFTSize
    private let sampleRate: Float
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    private let bufferSizePow2: Int
    
    // Working buffers
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudes: [Float]
    private var window: [Float]
    
    // Smoothing
    private var previousBands: [Float] = []
    private let smoothingFactor: Float = 0.8
    private let decayFactor: Float = 0.95
    
    // Thread safety
    private let processQueue = DispatchQueue(label: "com.winamp.fftprocessor", attributes: .concurrent)
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    init(fftSize: FFTSize = .size1024, sampleRate: Float = 44100) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.log2n = vDSP_Length(fftSize.log2Size)
        self.bufferSizePow2 = fftSize.rawValue
        
        // Create FFT setup
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup
        
        // Initialize buffers
        self.realBuffer = [Float](repeating: 0, count: bufferSizePow2 / 2)
        self.imagBuffer = [Float](repeating: 0, count: bufferSizePow2 / 2)
        self.magnitudes = [Float](repeating: 0, count: bufferSizePow2 / 2)
        self.window = [Float](repeating: 0, count: bufferSizePow2)
        
        // Create Hann window for better frequency resolution
        vDSP_hann_window(&window, vDSP_Length(bufferSizePow2), Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    // MARK: - Public Methods
    
    /// Perform FFT on audio samples and return magnitude spectrum
    /// - Parameter samples: Input audio samples (will be padded/truncated to FFT size)
    /// - Returns: Magnitude spectrum in dB scale
    func performFFT(samples: [Float]) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        
        // Prepare input buffer
        var inputBuffer = [Float](repeating: 0, count: bufferSizePow2)
        let sampleCount = min(samples.count, bufferSizePow2)
        
        // Copy samples and apply window
        if sampleCount > 0 {
            inputBuffer[0..<sampleCount] = samples[0..<sampleCount]
            vDSP_vmul(inputBuffer, 1, window, 1, &inputBuffer, 1, vDSP_Length(bufferSizePow2))
        }
        
        // Convert to split complex format
        var splitComplex = DSPSplitComplex(
            realp: UnsafeMutablePointer(mutating: realBuffer),
            imagp: UnsafeMutablePointer(mutating: imagBuffer)
        )
        
        inputBuffer.withUnsafeBufferPointer { inputPtr in
            vDSP_ctoz(
                inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: bufferSizePow2 / 2) { $0 },
                2,
                &splitComplex,
                1,
                vDSP_Length(bufferSizePow2 / 2)
            )
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSizePow2 / 2))
        
        // Convert to dB scale with noise floor
        var scaledMagnitudes = magnitudes
        var scale = Float(1.0 / Float(bufferSizePow2))
        vDSP_vsmul(scaledMagnitudes, 1, &scale, &scaledMagnitudes, 1, vDSP_Length(bufferSizePow2 / 2))
        
        // Convert to dB (20 * log10)
        let minDB: Float = -80.0
        for i in 0..<scaledMagnitudes.count {
            let magnitude = scaledMagnitudes[i]
            if magnitude > 0 {
                scaledMagnitudes[i] = 20.0 * log10(magnitude)
                scaledMagnitudes[i] = max(scaledMagnitudes[i], minDB)
            } else {
                scaledMagnitudes[i] = minDB
            }
        }
        
        return scaledMagnitudes
    }
    
    /// Get frequency bands from magnitude spectrum with logarithmic distribution
    /// - Parameters:
    ///   - magnitudes: Magnitude spectrum from FFT
    ///   - bandCount: Number of frequency bands (typically 16-32)
    /// - Returns: Array of band values normalized to 0-1 range
    func getBands(magnitudes: [Float], bandCount: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        
        var bands = [Float](repeating: 0, count: bandCount)
        
        // Frequency range for each bin
        let binFrequency = sampleRate / Float(bufferSizePow2)
        
        // Define frequency ranges with logarithmic distribution
        // Start from 40Hz to avoid DC and very low frequencies
        let minFreq: Float = 40.0
        let maxFreq: Float = min(20000.0, sampleRate / 2.0) // Nyquist limit
        
        // Calculate band boundaries using logarithmic scale
        let logMinFreq = log10(minFreq)
        let logMaxFreq = log10(maxFreq)
        let logStep = (logMaxFreq - logMinFreq) / Float(bandCount)
        
        for bandIndex in 0..<bandCount {
            // Calculate frequency range for this band
            let logStartFreq = logMinFreq + Float(bandIndex) * logStep
            let logEndFreq = logMinFreq + Float(bandIndex + 1) * logStep
            let startFreq = pow(10, logStartFreq)
            let endFreq = pow(10, logEndFreq)
            
            // Convert to bin indices
            let startBin = Int(startFreq / binFrequency)
            let endBin = min(Int(endFreq / binFrequency), magnitudes.count - 1)
            
            if startBin < endBin && startBin < magnitudes.count {
                // Average the magnitudes in this frequency range
                var sum: Float = 0
                var count = 0
                
                for bin in startBin...endBin {
                    sum += magnitudes[bin]
                    count += 1
                }
                
                if count > 0 {
                    // Convert from dB to linear scale for visualization
                    let avgDB = sum / Float(count)
                    let normalized = (avgDB + 80.0) / 80.0 // Normalize from -80dB to 0dB
                    bands[bandIndex] = max(0, min(1, normalized))
                }
            }
        }
        
        // Apply smoothing and decay
        if previousBands.count == bandCount {
            for i in 0..<bandCount {
                // Smooth with previous value
                let smoothed = bands[i] * (1.0 - smoothingFactor) + previousBands[i] * smoothingFactor
                
                // Apply decay for falling bands
                if smoothed < previousBands[i] {
                    bands[i] = previousBands[i] * decayFactor
                } else {
                    bands[i] = smoothed
                }
            }
        }
        
        previousBands = bands
        return bands
    }
    
    /// Get the frequency for a specific FFT bin
    /// - Parameter bin: FFT bin index
    /// - Returns: Frequency in Hz
    func getFrequencyForBin(bin: Int) -> Float {
        return Float(bin) * sampleRate / Float(bufferSizePow2)
    }
    
    /// Get frequency bands with custom frequency ranges
    /// - Parameters:
    ///   - magnitudes: Magnitude spectrum from FFT
    ///   - frequencyRanges: Array of (startFreq, endFreq) tuples in Hz
    /// - Returns: Array of band values for each frequency range
    func getCustomBands(magnitudes: [Float], frequencyRanges: [(Float, Float)]) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        
        var bands = [Float](repeating: 0, count: frequencyRanges.count)
        let binFrequency = sampleRate / Float(bufferSizePow2)
        
        for (index, (startFreq, endFreq)) in frequencyRanges.enumerated() {
            let startBin = Int(startFreq / binFrequency)
            let endBin = min(Int(endFreq / binFrequency), magnitudes.count - 1)
            
            if startBin < endBin && startBin < magnitudes.count {
                var sum: Float = 0
                var count = 0
                
                for bin in startBin...endBin {
                    sum += magnitudes[bin]
                    count += 1
                }
                
                if count > 0 {
                    let avgDB = sum / Float(count)
                    let normalized = (avgDB + 80.0) / 80.0
                    bands[index] = max(0, min(1, normalized))
                }
            }
        }
        
        return bands
    }
    
    /// Reset the smoothing history
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        previousBands.removeAll()
    }
    
    // MARK: - Configuration
    
    /// Update smoothing factor (0-1, higher = more smoothing)
    func setSmoothingFactor(_ factor: Float) {
        lock.lock()
        defer { lock.unlock() }
        
        self.smoothingFactor = max(0, min(1, factor))
    }
    
    /// Update decay factor (0-1, higher = slower decay)
    func setDecayFactor(_ factor: Float) {
        lock.lock()
        defer { lock.unlock() }
        
        self.decayFactor = max(0, min(1, factor))
    }
    
    /// Get current FFT size
    var currentFFTSize: FFTSize {
        return fftSize
    }
    
    /// Get number of frequency bins available
    var frequencyBinCount: Int {
        return bufferSizePow2 / 2
    }
    
    /// Get maximum analyzable frequency (Nyquist frequency)
    var maxFrequency: Float {
        return sampleRate / 2.0
    }
}

// MARK: - Convenience Methods

extension FFTProcessor {
    
    /// Get classic WinAmp-style 16-band spectrum
    func getWinAmpBands(magnitudes: [Float]) -> [Float] {
        return getBands(magnitudes: magnitudes, bandCount: 16)
    }
    
    /// Get high-resolution 32-band spectrum
    func getHighResBands(magnitudes: [Float]) -> [Float] {
        return getBands(magnitudes: magnitudes, bandCount: 32)
    }
    
    /// Process audio buffer and return frequency bands in one call
    func processAudioBuffer(_ samples: [Float], bandCount: Int = 16) -> [Float] {
        let magnitudes = performFFT(samples: samples)
        return getBands(magnitudes: magnitudes, bandCount: bandCount)
    }
}