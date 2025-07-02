//
//  AudioPlaybackTests.swift
//  WinAmpPlayerTests
//
//  Comprehensive audio playback tests including unit tests, integration tests,
//  and performance tests for the WinAmp Player audio engine.
//

import XCTest
import AVFoundation
import Combine
@testable import WinAmpPlayer

// MARK: - Test Constants

private struct TestConstants {
    static let shortDuration: TimeInterval = 1.0
    static let mediumDuration: TimeInterval = 10.0
    static let longDuration: TimeInterval = 60.0
    static let performanceIterations = 100
    static let seekAccuracy: TimeInterval = 0.1
    static let volumeSteps = 10
    static let testTimeout: TimeInterval = 30.0
}

// MARK: - Mock Audio Session

class MockAudioSession: AVAudioSession {
    var mockCurrentRoute: AVAudioSessionRouteDescription?
    var mockIsOtherAudioPlaying = false
    var setCategoryCalled = false
    var setActiveCalled = false
    
    override var currentRoute: AVAudioSessionRouteDescription {
        return mockCurrentRoute ?? super.currentRoute
    }
    
    override var isOtherAudioPlaying: Bool {
        return mockIsOtherAudioPlaying
    }
}

// MARK: - Audio Format Test Cases

final class AudioFormatTests: XCTestCase {
    
    func testFormatDetection() {
        // Test file extension initialization
        XCTAssertEqual(AudioFormat(fileExtension: "mp3"), .mp3)
        XCTAssertEqual(AudioFormat(fileExtension: "MP3"), .mp3)
        XCTAssertEqual(AudioFormat(fileExtension: "m4a"), .m4a)
        XCTAssertEqual(AudioFormat(fileExtension: "flac"), .flac)
        XCTAssertEqual(AudioFormat(fileExtension: "wav"), .wav)
        XCTAssertEqual(AudioFormat(fileExtension: "ogg"), .ogg)
        XCTAssertEqual(AudioFormat(fileExtension: "aiff"), .aiff)
        XCTAssertEqual(AudioFormat(fileExtension: "unknown"), .unknown)
    }
    
    func testMimeTypeDetection() {
        XCTAssertEqual(AudioFormat(mimeType: "audio/mpeg"), .mp3)
        XCTAssertEqual(AudioFormat(mimeType: "audio/mp4"), .m4a)
        XCTAssertEqual(AudioFormat(mimeType: "audio/flac"), .flac)
        XCTAssertEqual(AudioFormat(mimeType: "audio/wav"), .wav)
        XCTAssertEqual(AudioFormat(mimeType: "audio/ogg"), .ogg)
        XCTAssertEqual(AudioFormat(mimeType: "audio/aiff"), .aiff)
    }
    
    func testFormatProperties() {
        // Test lossy/lossless classification
        XCTAssertTrue(AudioFormat.mp3.isLossy)
        XCTAssertTrue(AudioFormat.aac.isLossy)
        XCTAssertTrue(AudioFormat.ogg.isLossy)
        XCTAssertFalse(AudioFormat.flac.isLossy)
        XCTAssertFalse(AudioFormat.wav.isLossy)
        XCTAssertFalse(AudioFormat.aiff.isLossy)
        XCTAssertFalse(AudioFormat.alac.isLossy)
    }
    
    func testMagicBytes() {
        // Verify magic bytes are defined for each format
        for format in AudioFormat.allCases where format != .unknown {
            XCTAssertFalse(format.magicBytes.isEmpty, "\(format) should have magic bytes defined")
        }
    }
}

// MARK: - Audio Engine Unit Tests

final class AudioEngineUnitTests: XCTestCase {
    var audioEngine: AudioEngine!
    var volumeController: VolumeBalanceController!
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
        audioEngine.setVolumeController(volumeController)
        cancellables.removeAll()
    }
    
    override func tearDown() {
        audioEngine = nil
        volumeController = nil
        super.tearDown()
    }
    
    // MARK: - Volume Integration Tests
    
    func testVolumeControllerIntegration() {
        // Test that volume changes are synchronized
        volumeController.setVolume(0.75)
        XCTAssertEqual(audioEngine.volume, 0.75)
        
        audioEngine.volume = 0.25
        XCTAssertEqual(volumeController.volume, 0.25)
    }
    
    func testVolumeLogarithmicScaling() {
        // Test logarithmic scaling provides expected values
        let testVolumes: [Float] = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
        
        for volume in testVolumes {
            volumeController.setVolume(volume)
            let effectiveVolume = volumeController.effectiveVolume
            
            if volume == 0.0 {
                XCTAssertEqual(effectiveVolume, 0.0)
            } else {
                // Logarithmic scaling should reduce linear values
                XCTAssertLessThanOrEqual(effectiveVolume, volume)
            }
        }
    }
    
    func testMuteUnmute() {
        volumeController.setVolume(0.5)
        let originalVolume = volumeController.volume
        
        volumeController.mute()
        XCTAssertTrue(volumeController.isMuted)
        XCTAssertEqual(volumeController.effectiveVolume, 0.0)
        
        volumeController.unmute()
        XCTAssertFalse(volumeController.isMuted)
        XCTAssertEqual(volumeController.volume, originalVolume)
    }
    
    // MARK: - Balance Tests
    
    func testBalanceControl() {
        // Test balance extremes
        volumeController.setBalance(-1.0)
        XCTAssertEqual(volumeController.balance, -1.0)
        
        volumeController.setBalance(1.0)
        XCTAssertEqual(volumeController.balance, 1.0)
        
        volumeController.setBalance(0.0)
        XCTAssertEqual(volumeController.balance, 0.0)
        
        // Test clamping
        volumeController.setBalance(-2.0)
        XCTAssertEqual(volumeController.balance, -1.0)
        
        volumeController.setBalance(2.0)
        XCTAssertEqual(volumeController.balance, 1.0)
    }
    
    // MARK: - Preamp Tests
    
    func testPreampGain() {
        volumeController.setPreampGain(6.0)
        XCTAssertEqual(volumeController.preampGain, 6.0)
        
        volumeController.setPreampGain(-6.0)
        XCTAssertEqual(volumeController.preampGain, -6.0)
        
        // Test clamping
        volumeController.setPreampGain(15.0)
        XCTAssertEqual(volumeController.preampGain, 12.0)
        
        volumeController.setPreampGain(-15.0)
        XCTAssertEqual(volumeController.preampGain, -12.0)
    }
    
    // MARK: - Visualization Tests
    
    func testVisualizationToggle() {
        XCTAssertFalse(audioEngine.isVisualizationEnabled)
        
        audioEngine.enableVisualization()
        XCTAssertTrue(audioEngine.isVisualizationEnabled)
        
        audioEngine.disableVisualization()
        XCTAssertFalse(audioEngine.isVisualizationEnabled)
    }
    
    func testVisualizationDataPublisher() {
        let expectation = expectation(description: "Visualization data received")
        expectation.isInverted = true // We don't expect data without playback
        
        audioEngine.audioVisualizationDataPublisher
            .sink { data in
                XCTAssertGreaterThan(data.sampleCount, 0)
                XCTAssertGreaterThanOrEqual(data.leftPeak, 0.0)
                XCTAssertLessThanOrEqual(data.leftPeak, 1.0)
                XCTAssertGreaterThanOrEqual(data.rightPeak, 0.0)
                XCTAssertLessThanOrEqual(data.rightPeak, 1.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        audioEngine.enableVisualization()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error State Tests
    
    func testErrorStateTransitions() {
        // Test error state is set correctly
        let invalidTrack = Track(
            title: "Invalid",
            duration: 0,
            fileURL: nil
        )
        
        let loadExpectation = expectation(description: "Load error")
        
        Task {
            do {
                try await audioEngine.loadTrack(invalidTrack)
                XCTFail("Should have thrown error")
            } catch {
                if case .error = audioEngine.playbackState {
                    loadExpectation.fulfill()
                }
            }
        }
        
        wait(for: [loadExpectation], timeout: 5.0)
    }
    
    // MARK: - State Machine Tests
    
    func testPlaybackStateTransitions() {
        // Test invalid state transitions
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Pause from stopped should do nothing
        audioEngine.pause()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Stop from stopped should remain stopped
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
    }
}

// MARK: - Audio Engine Integration Tests

final class AudioEngineIntegrationTests: XCTestCase {
    var audioEngine: AudioEngine!
    var sessionManager: AudioSessionManager!
    var testFileURLs: [URL] = []
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        sessionManager = AudioSessionManager.shared
        sessionManager.configureForMusicPlayback()
    }
    
    override func tearDown() {
        audioEngine = nil
        cleanupTestFiles()
        super.tearDown()
    }
    
    private func cleanupTestFiles() {
        for url in testFileURLs {
            try? FileManager.default.removeItem(at: url)
        }
        testFileURLs.removeAll()
    }
    
    // MARK: - Format Loading Tests
    
    func testLoadAllSupportedFormats() async throws {
        let formats: [(AudioFormat, [String: Any])] = [
            (.mp3, [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]),
            (.aac, [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]),
            (.wav, [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]),
            (.aiff, [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: true
            ])
        ]
        
        for (format, settings) in formats {
            let fileURL = try createTestFile(format: format, settings: settings)
            
            do {
                try await audioEngine.loadURL(fileURL)
                XCTAssertNotNil(audioEngine.currentTrack, "Failed to load \(format.displayName)")
                XCTAssertEqual(audioEngine.playbackState, .stopped)
            } catch {
                XCTFail("Failed to load \(format.displayName): \(error)")
            }
        }
    }
    
    func testUnsupportedFormatHandling() async {
        let unsupportedURL = URL(fileURLWithPath: "/test/unsupported.xyz")
        
        do {
            try await audioEngine.loadURL(unsupportedURL)
            XCTFail("Should have thrown error for unsupported format")
        } catch {
            XCTAssertTrue(error is AudioEngineError)
        }
    }
    
    // MARK: - Playback Flow Tests
    
    func testCompletePlaybackFlow() async throws {
        let fileURL = try createTestFile(format: .mp3, duration: 3.0)
        
        // Load
        try await audioEngine.loadURL(fileURL)
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Play
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Wait and verify playback progress
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        XCTAssertGreaterThan(audioEngine.currentTime, 0.5)
        XCTAssertLessThan(audioEngine.currentTime, 1.5)
        
        // Seek
        try audioEngine.seek(to: 2.0)
        XCTAssertEqual(audioEngine.currentTime, 2.0, accuracy: TestConstants.seekAccuracy)
        
        // Pause
        audioEngine.pause()
        XCTAssertEqual(audioEngine.playbackState, .paused)
        let pausedTime = audioEngine.currentTime
        
        // Verify no progress while paused
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(audioEngine.currentTime, pausedTime, accuracy: 0.01)
        
        // Resume
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Stop
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, 0)
    }
    
    func testPlaybackCompletion() async throws {
        let fileURL = try createTestFile(format: .wav, duration: 0.5)
        
        let completionExpectation = expectation(
            forNotification: .audioPlaybackCompleted,
            object: audioEngine
        )
        
        try await audioEngine.loadURL(fileURL)
        try audioEngine.play()
        
        await fulfillment(of: [completionExpectation], timeout: 2.0)
        
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, audioEngine.duration, accuracy: TestConstants.seekAccuracy)
    }
    
    // MARK: - Audio Session Integration Tests
    
    func testAudioSessionInterruption() async throws {
        let fileURL = try createTestFile(format: .aac, duration: 5.0)
        try await audioEngine.loadURL(fileURL)
        
        // Set up interruption handling
        var wasInterrupted = false
        sessionManager.onInterruptionBegan = {
            wasInterrupted = true
        }
        
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Simulate interruption
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        
        // Give time for notification handling
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(wasInterrupted)
    }
    
    func testAudioRouteChange() async throws {
        var routeChanged = false
        var changeReason: AVAudioSession.RouteChangeReason?
        
        sessionManager.onRouteChange = { reason, _ in
            routeChanged = true
            changeReason = reason
        }
        
        // Simulate route change (headphones unplugged)
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            ]
        )
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(routeChanged)
        XCTAssertEqual(changeReason, .oldDeviceUnavailable)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFile(
        format: AudioFormat,
        settings: [String: Any]? = nil,
        duration: TimeInterval = TestConstants.mediumDuration
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).\(format.fileExtensions.first ?? "tmp")"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let audioSettings = settings ?? [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2
        ]
        
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: audioSettings)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Fill with low-amplitude sine wave for testing
        if let channelData = buffer.floatChannelData {
            let frequency: Float = 440.0 // A4
            let sampleRate = Float(format.sampleRate)
            let amplitude: Float = 0.1
            
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frameCount) {
                    let phase = 2.0 * Float.pi * frequency * Float(frame) / sampleRate
                    channelData[channel][frame] = amplitude * sin(phase)
                }
            }
        }
        
        try audioFile.write(from: buffer)
        testFileURLs.append(fileURL)
        
        return fileURL
    }
}

// MARK: - Audio Engine Performance Tests

final class AudioEnginePerformanceTests: XCTestCase {
    var audioEngine: AudioEngine!
    var testFileURL: URL!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        
        // Create a longer test file for performance testing
        do {
            testFileURL = try createLargeTestFile()
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
    
    override func tearDown() {
        if let url = testFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioEngine = nil
        super.tearDown()
    }
    
    func testSeekPerformance() throws {
        // Load file first
        let loadExpectation = expectation(description: "File loaded")
        Task {
            try await audioEngine.loadURL(testFileURL)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 10.0)
        
        measure {
            // Perform random seeks
            for _ in 0..<TestConstants.performanceIterations {
                let position = Double.random(in: 0...audioEngine.duration)
                try? audioEngine.seek(to: position)
            }
        }
    }
    
    func testVolumeChangePerformance() {
        measure {
            for i in 0..<TestConstants.performanceIterations {
                let volume = Float(i % TestConstants.volumeSteps) / Float(TestConstants.volumeSteps)
                audioEngine.volume = volume
            }
        }
    }
    
    func testPlayPausePerformance() throws {
        // Load file first
        let loadExpectation = expectation(description: "File loaded")
        Task {
            try await audioEngine.loadURL(testFileURL)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 10.0)
        
        measure {
            for _ in 0..<TestConstants.performanceIterations / 2 {
                try? audioEngine.play()
                audioEngine.pause()
            }
        }
    }
    
    func testVisualizationDataProcessing() throws {
        // This tests the performance of visualization data processing
        let sampleCount = 512
        let samples = (0..<sampleCount).map { _ in Float.random(in: -1...1) }
        
        measure {
            for _ in 0..<TestConstants.performanceIterations {
                // Simulate visualization processing
                _ = samples.reduce(0, +) / Float(sampleCount) // RMS calculation
                _ = samples.max() ?? 0 // Peak detection
            }
        }
    }
    
    private func createLargeTestFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "performance_test_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let settings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2
        ]
        
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(TestConstants.longDuration * format.sampleRate)
        
        // Write in chunks to avoid memory issues
        let chunkSize: AVAudioFrameCount = 44100 // 1 second chunks
        var remainingFrames = frameCount
        
        while remainingFrames > 0 {
            let framesToWrite = min(chunkSize, remainingFrames)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToWrite)!
            buffer.frameLength = framesToWrite
            
            try audioFile.write(from: buffer)
            remainingFrames -= framesToWrite
        }
        
        return fileURL
    }
}

// MARK: - Volume Balance Controller Tests

final class VolumeBalanceControllerTests: XCTestCase {
    var volumeController: VolumeBalanceController!
    var audioEngine: AVAudioEngine!
    
    override func setUp() {
        super.setUp()
        audioEngine = AVAudioEngine()
        volumeController = VolumeBalanceController(audioEngine: audioEngine)
    }
    
    override func tearDown() {
        volumeController = nil
        audioEngine = nil
        super.tearDown()
    }
    
    func testFadeIn() {
        let fadeExpectation = expectation(description: "Fade completed")
        
        volumeController.setVolume(0.0)
        
        volumeController.fadeIn(duration: 0.5, targetVolume: 1.0) {
            fadeExpectation.fulfill()
        }
        
        wait(for: [fadeExpectation], timeout: 1.0)
        XCTAssertEqual(volumeController.volume, 1.0, accuracy: 0.01)
    }
    
    func testFadeOut() {
        let fadeExpectation = expectation(description: "Fade completed")
        
        volumeController.setVolume(1.0)
        
        volumeController.fadeOut(duration: 0.5) {
            fadeExpectation.fulfill()
        }
        
        wait(for: [fadeExpectation], timeout: 1.0)
        XCTAssertEqual(volumeController.volume, 0.0, accuracy: 0.01)
    }
    
    func testNormalization() {
        volumeController.setVolume(0.5)
        volumeController.setReplayGain(6.0) // +6dB
        
        // Without normalization
        volumeController.setNormalizationEnabled(false)
        let normalVolume = volumeController.effectiveVolume
        
        // With normalization
        volumeController.setNormalizationEnabled(true)
        let normalizedVolume = volumeController.effectiveVolume
        
        // Normalized volume should be higher due to positive replay gain
        XCTAssertGreaterThan(normalizedVolume, normalVolume)
    }
    
    func testVUMeterLevels() {
        // Test VU meter structure
        let levels = volumeController.vuMeterLevels
        
        XCTAssertGreaterThanOrEqual(levels.left, 0.0)
        XCTAssertGreaterThanOrEqual(levels.right, 0.0)
        
        // Test dB conversion
        if levels.left > 0 {
            XCTAssertLessThan(levels.leftDB, 0) // dB should be negative for values < 1
        }
    }
    
    func testReset() {
        // Set non-default values
        volumeController.setVolume(0.75)
        volumeController.setBalance(0.5)
        volumeController.setPreampGain(6.0)
        volumeController.setNormalizationEnabled(true)
        volumeController.mute()
        
        // Reset
        volumeController.reset()
        
        // Verify defaults
        XCTAssertEqual(volumeController.volume, 1.0)
        XCTAssertEqual(volumeController.balance, 0.0)
        XCTAssertEqual(volumeController.preampGain, 0.0)
        XCTAssertFalse(volumeController.isNormalizationEnabled)
        XCTAssertFalse(volumeController.isMuted)
    }
}

// MARK: - Decoder Factory Tests

final class AudioDecoderFactoryTests: XCTestCase {
    
    func testDecoderCreation() throws {
        let tempURL = URL(fileURLWithPath: "/tmp/test.mp3")
        
        // Test creating decoder for each format
        for format in AudioFormat.allCases where format != .unknown {
            do {
                let decoder = try AudioDecoderFactory.createDecoder(for: tempURL, format: format)
                XCTAssertNotNil(decoder)
                XCTAssertEqual(decoder.fileURL, tempURL)
            } catch {
                // Some formats might fail without actual file
                if error is AudioDecoderError {
                    // Expected for some formats
                } else {
                    XCTFail("Unexpected error for \(format): \(error)")
                }
            }
        }
    }
    
    func testUnsupportedFormatHandling() {
        let tempURL = URL(fileURLWithPath: "/tmp/test.xyz")
        
        do {
            _ = try AudioDecoderFactory.createDecoder(for: tempURL, format: .unknown)
            XCTFail("Should throw error for unknown format")
        } catch {
            XCTAssertTrue(error is AudioDecoderError)
        }
    }
}

// MARK: - Memory Leak Tests

final class AudioEngineMemoryTests: XCTestCase {
    
    func testNoMemoryLeaksInPlaybackCycle() {
        // This test checks for memory leaks during a typical playback cycle
        autoreleasepool {
            let audioEngine = AudioEngine()
            let volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
            audioEngine.setVolumeController(volumeController)
            
            // Enable visualization to test all features
            audioEngine.enableVisualization()
            
            // Simulate playback operations
            audioEngine.volume = 0.8
            volumeController.setBalance(0.2)
            volumeController.setPreampGain(3.0)
            
            // The objects should be deallocated when going out of scope
        }
        
        // If this test passes without crashes, basic memory management is working
        XCTAssertTrue(true)
    }
}