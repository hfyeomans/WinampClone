import AVFoundation
import Combine

/// Controller for managing volume, balance, and audio levels in the WinAmp player
public class VolumeBalanceController: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var volume: Float = 1.0
    @Published public private(set) var balance: Float = 0.0
    @Published public private(set) var preampGain: Float = 0.0
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var leftPeakLevel: Float = 0.0
    @Published public private(set) var rightPeakLevel: Float = 0.0
    @Published public private(set) var isNormalizationEnabled: Bool = false
    @Published public private(set) var replayGain: Float = 0.0
    
    // MARK: - Private Properties
    
    private let audioEngine: AVAudioEngine
    private let mainMixerNode: AVAudioMixerNode
    private let volumeMixerNode: AVAudioMixerNode
    private let balanceMixerNode: AVAudioMixerNode
    private let preampMixerNode: AVAudioMixerNode
    
    private var volumeBeforeMute: Float = 1.0
    private var fadeTimer: Timer?
    private var peakLevelTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    private let minVolume: Float = 0.0
    private let maxVolume: Float = 1.0
    private let minBalance: Float = -1.0
    private let maxBalance: Float = 1.0
    private let minPreampGain: Float = -12.0
    private let maxPreampGain: Float = 12.0
    private let fadeStepDuration: TimeInterval = 0.01
    private let peakLevelUpdateInterval: TimeInterval = 0.05
    
    // MARK: - Initialization
    
    public init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
        self.mainMixerNode = audioEngine.mainMixerNode
        self.volumeMixerNode = AVAudioMixerNode()
        self.balanceMixerNode = AVAudioMixerNode()
        self.preampMixerNode = AVAudioMixerNode()
        
        setupAudioNodes()
        startPeakLevelMonitoring()
    }
    
    deinit {
        fadeTimer?.invalidate()
        peakLevelTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupAudioNodes() {
        // Add mixer nodes to the audio engine
        audioEngine.attach(volumeMixerNode)
        audioEngine.attach(balanceMixerNode)
        audioEngine.attach(preampMixerNode)
        
        // Connect nodes in series: input -> preamp -> balance -> volume -> output
        let format = audioEngine.outputNode.inputFormat(forBus: 0)
        
        // Note: Actual connections would be made by the AudioEngine class
        // This controller just manages the mixer nodes
    }
    
    // MARK: - Volume Control
    
    /// Set the volume with logarithmic scaling
    /// - Parameter value: Volume level from 0.0 to 1.0
    public func setVolume(_ value: Float) {
        let clampedValue = max(minVolume, min(maxVolume, value))
        volume = clampedValue
        
        if !isMuted {
            applyVolume(logarithmicScale(clampedValue))
        }
    }
    
    /// Apply logarithmic scaling for natural volume perception
    private func logarithmicScale(_ linearValue: Float) -> Float {
        // Use a logarithmic curve for more natural volume control
        // This gives finer control at lower volumes
        if linearValue <= 0.0 {
            return 0.0
        }
        
        // Convert to dB scale and back
        let minDB: Float = -60.0
        let maxDB: Float = 0.0
        let db = minDB + (maxDB - minDB) * pow(linearValue, 2.0)
        return pow(10.0, db / 20.0)
    }
    
    private func applyVolume(_ scaledVolume: Float) {
        volumeMixerNode.outputVolume = scaledVolume
    }
    
    // MARK: - Balance Control
    
    /// Set the stereo balance
    /// - Parameter value: Balance from -1.0 (left) to 1.0 (right), 0.0 is center
    public func setBalance(_ value: Float) {
        let clampedValue = max(minBalance, min(maxBalance, value))
        balance = clampedValue
        applyBalance(clampedValue)
    }
    
    private func applyBalance(_ balanceValue: Float) {
        // Calculate left and right channel gains
        var leftGain: Float = 1.0
        var rightGain: Float = 1.0
        
        if balanceValue < 0 {
            // Pan left: reduce right channel
            rightGain = 1.0 + balanceValue
        } else if balanceValue > 0 {
            // Pan right: reduce left channel
            leftGain = 1.0 - balanceValue
        }
        
        // Apply pan using 3D positioning (more natural than simple gain adjustment)
        balanceMixerNode.pan = balanceValue
        
        // For more precise control, we could also adjust individual channel gains
        // This would require tap processing on the audio node
    }
    
    // MARK: - Smooth Fade Methods
    
    /// Fade in the volume smoothly
    /// - Parameters:
    ///   - duration: Fade duration in seconds
    ///   - targetVolume: Target volume (0.0 to 1.0)
    ///   - completion: Completion handler
    public func fadeIn(duration: TimeInterval, 
                      targetVolume: Float = 1.0,
                      completion: (() -> Void)? = nil) {
        fade(from: volume, to: targetVolume, duration: duration, completion: completion)
    }
    
    /// Fade out the volume smoothly
    /// - Parameters:
    ///   - duration: Fade duration in seconds
    ///   - completion: Completion handler
    public func fadeOut(duration: TimeInterval,
                       completion: (() -> Void)? = nil) {
        fade(from: volume, to: 0.0, duration: duration, completion: completion)
    }
    
    private func fade(from startVolume: Float,
                     to targetVolume: Float,
                     duration: TimeInterval,
                     completion: (() -> Void)?) {
        // Cancel any existing fade
        fadeTimer?.invalidate()
        
        let steps = Int(duration / fadeStepDuration)
        let volumeStep = (targetVolume - startVolume) / Float(steps)
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeStepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            
            if currentStep >= steps {
                self.setVolume(targetVolume)
                timer.invalidate()
                self.fadeTimer = nil
                completion?()
            } else {
                let newVolume = startVolume + (volumeStep * Float(currentStep))
                self.setVolume(newVolume)
            }
        }
    }
    
    // MARK: - EQ Preamp Gain
    
    /// Set the EQ preamp gain
    /// - Parameter gain: Gain in dB (-12 to +12)
    public func setPreampGain(_ gain: Float) {
        let clampedGain = max(minPreampGain, min(maxPreampGain, gain))
        preampGain = clampedGain
        applyPreampGain(clampedGain)
    }
    
    private func applyPreampGain(_ gainDB: Float) {
        // Convert dB to linear gain
        let linearGain = pow(10.0, gainDB / 20.0)
        preampMixerNode.outputVolume = linearGain
    }
    
    // MARK: - Mute Functionality
    
    /// Toggle mute state
    public func toggleMute() {
        if isMuted {
            unmute()
        } else {
            mute()
        }
    }
    
    /// Mute the audio
    public func mute() {
        if !isMuted {
            volumeBeforeMute = volume
            isMuted = true
            applyVolume(0.0)
        }
    }
    
    /// Unmute the audio
    public func unmute() {
        if isMuted {
            isMuted = false
            applyVolume(logarithmicScale(volumeBeforeMute))
        }
    }
    
    // MARK: - Volume Normalization / Replay Gain
    
    /// Enable or disable volume normalization
    public func setNormalizationEnabled(_ enabled: Bool) {
        isNormalizationEnabled = enabled
        applyNormalization()
    }
    
    /// Set the replay gain value
    /// - Parameter gain: Replay gain in dB
    public func setReplayGain(_ gain: Float) {
        replayGain = gain
        if isNormalizationEnabled {
            applyNormalization()
        }
    }
    
    private func applyNormalization() {
        if isNormalizationEnabled {
            // Apply replay gain on top of current volume
            let replayGainLinear = pow(10.0, replayGain / 20.0)
            let normalizedVolume = volume * replayGainLinear
            
            // Prevent clipping
            let clampedVolume = min(normalizedVolume, 1.0)
            applyVolume(logarithmicScale(clampedVolume))
        } else {
            // Reset to normal volume
            applyVolume(logarithmicScale(volume))
        }
    }
    
    // MARK: - Peak Level Monitoring
    
    private func startPeakLevelMonitoring() {
        // Install tap on the main mixer to monitor levels
        let format = mainMixerNode.outputFormat(forBus: 0)
        
        mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processPeakLevels(buffer: buffer)
        }
        
        // Start timer for UI updates
        peakLevelTimer = Timer.scheduledTimer(withTimeInterval: peakLevelUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePeakLevels()
        }
    }
    
    private var leftPeakBuffer: Float = 0.0
    private var rightPeakBuffer: Float = 0.0
    
    private func processPeakLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        if channelCount >= 1 {
            // Process left channel
            let leftSamples = channelData[0]
            var leftPeak: Float = 0.0
            
            for i in 0..<frameLength {
                let sample = abs(leftSamples[i])
                if sample > leftPeak {
                    leftPeak = sample
                }
            }
            
            leftPeakBuffer = max(leftPeakBuffer, leftPeak)
        }
        
        if channelCount >= 2 {
            // Process right channel
            let rightSamples = channelData[1]
            var rightPeak: Float = 0.0
            
            for i in 0..<frameLength {
                let sample = abs(rightSamples[i])
                if sample > rightPeak {
                    rightPeak = sample
                }
            }
            
            rightPeakBuffer = max(rightPeakBuffer, rightPeak)
        } else if channelCount == 1 {
            // Mono: use same value for both channels
            rightPeakBuffer = leftPeakBuffer
        }
    }
    
    private func updatePeakLevels() {
        // Apply peak decay for smooth VU meter animation
        let decayFactor: Float = 0.95
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update published values
            self.leftPeakLevel = self.leftPeakBuffer
            self.rightPeakLevel = self.rightPeakBuffer
            
            // Apply decay
            self.leftPeakBuffer *= decayFactor
            self.rightPeakBuffer *= decayFactor
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get the current effective volume (considering mute state and normalization)
    public var effectiveVolume: Float {
        if isMuted {
            return 0.0
        }
        
        var effective = logarithmicScale(volume)
        
        if isNormalizationEnabled {
            let replayGainLinear = pow(10.0, replayGain / 20.0)
            effective *= replayGainLinear
            effective = min(effective, 1.0)
        }
        
        return effective
    }
    
    /// Convert linear volume to decibels
    public func volumeToDecibels(_ linearVolume: Float) -> Float {
        if linearVolume <= 0.0 {
            return -Float.infinity
        }
        return 20.0 * log10(linearVolume)
    }
    
    /// Convert decibels to linear volume
    public func decibelsToVolume(_ db: Float) -> Float {
        return pow(10.0, db / 20.0)
    }
    
    /// Reset all settings to defaults
    public func reset() {
        setVolume(1.0)
        setBalance(0.0)
        setPreampGain(0.0)
        setNormalizationEnabled(false)
        setReplayGain(0.0)
        unmute()
    }
}

// MARK: - VU Meter Data

public extension VolumeBalanceController {
    /// Structure representing VU meter levels
    struct VUMeterLevels {
        public let left: Float
        public let right: Float
        public let leftDB: Float
        public let rightDB: Float
        
        init(left: Float, right: Float) {
            self.left = left
            self.right = right
            self.leftDB = left > 0 ? 20.0 * log10(left) : -Float.infinity
            self.rightDB = right > 0 ? 20.0 * log10(right) : -Float.infinity
        }
    }
    
    /// Get current VU meter levels
    var vuMeterLevels: VUMeterLevels {
        return VUMeterLevels(left: leftPeakLevel, right: rightPeakLevel)
    }
}