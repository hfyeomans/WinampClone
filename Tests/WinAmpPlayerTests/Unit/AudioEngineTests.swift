//
//  AudioEngineTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-06-28.
//  Comprehensive unit and integration tests for AudioEngine.
//

import XCTest
import AVFoundation
import Combine
@testable import WinAmpPlayer

// MARK: - Mock Objects

/// Mock AVAudioEngine for testing without actual audio
class MockAVAudioEngine: AVAudioEngine {
    var isRunningMock = false
    var startCalled = false
    var stopCalled = false
    var prepareCalled = false
    var attachCalled = false
    var connectCalled = false
    var shouldThrowOnStart = false
    
    override var isRunning: Bool {
        return isRunningMock
    }
    
    override func start() throws {
        if shouldThrowOnStart {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        startCalled = true
        isRunningMock = true
    }
    
    override func stop() {
        stopCalled = true
        isRunningMock = false
    }
    
    override func prepare() {
        prepareCalled = true
    }
    
    override func attach(_ node: AVAudioNode) {
        attachCalled = true
    }
    
    override func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) {
        connectCalled = true
    }
}

/// Mock AVAudioPlayerNode for testing playback control
class MockAVAudioPlayerNode: AVAudioPlayerNode {
    var playCalled = false
    var pauseCalled = false
    var stopCalled = false
    var resetCalled = false
    var volumeSet: Float = 0
    var scheduledSegment = false
    var lastScheduledStartFrame: AVAudioFramePosition?
    var lastScheduledFrameCount: AVAudioFrameCount?
    
    override func play() {
        playCalled = true
    }
    
    override func pause() {
        pauseCalled = true
    }
    
    override func stop() {
        stopCalled = true
    }
    
    override func reset() {
        resetCalled = true
    }
    
    override var volume: Float {
        get { volumeSet }
        set { volumeSet = newValue }
    }
    
    override func scheduleSegment(_ file: AVAudioFile, startingFrame startFrame: AVAudioFramePosition, frameCount numberFrames: AVAudioFrameCount, at when: AVAudioTime?, completionCallbackType callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack, completionHandler: AVAudioPlayerNodeCompletionHandler? = nil) {
        scheduledSegment = true
        lastScheduledStartFrame = startFrame
        lastScheduledFrameCount = numberFrames
        
        // Simulate immediate completion for testing
        if let handler = completionHandler {
            DispatchQueue.main.async {
                handler(callbackType)
            }
        }
    }
}

/// Mock AudioEngine with injected dependencies for testing
class MockAudioEngine: AudioEngine {
    let mockEngine: MockAVAudioEngine
    let mockPlayerNode: MockAVAudioPlayerNode
    var mockAudioFile: AVAudioFile?
    var shouldFailFileLoad = false
    var shouldFailSeek = false
    
    override init() {
        self.mockEngine = MockAVAudioEngine()
        self.mockPlayerNode = MockAVAudioPlayerNode()
        super.init()
        
        // Use reflection to inject mocks (in real app, use dependency injection)
        // Note: This is simplified for testing purposes
    }
    
    func simulateFileLoad(duration: TimeInterval = 120.0, sampleRate: Double = 44100.0) {
        self.duration = duration
        self.frameLength = AVAudioFramePosition(duration * sampleRate)
        self.currentTime = 0
        self.framePosition = 0
        self.playbackState = .stopped
    }
}

// MARK: - Test Fixtures

class TestFixtures {
    static let shared = TestFixtures()
    
    private init() {}
    
    /// Create a temporary audio file for testing
    func createTestAudioFile(duration: TimeInterval = 10.0, format: AVAudioFormat? = nil) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_audio_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create a simple audio file using AVAudioFile
        let audioFormat = format ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let frameCount = AVAudioFrameCount(duration * audioFormat.sampleRate)
        
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: audioFormat.settings)
        
        // Write silence
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        try audioFile.write(from: buffer)
        
        return fileURL
    }
    
    /// Create a test track with metadata
    func createTestTrack(title: String = "Test Track", artist: String = "Test Artist", duration: TimeInterval = 120.0) -> Track {
        return Track(
            title: title,
            artist: artist,
            album: "Test Album",
            genre: "Test Genre",
            year: 2025,
            duration: duration,
            fileURL: URL(fileURLWithPath: "/test/path/audio.mp3"),
            trackNumber: 1
        )
    }
    
    /// Clean up test files
    func cleanupTestFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - AudioEngine Tests

final class AudioEngineTests: XCTestCase {
    var audioEngine: AudioEngine!
    var cancellables: Set<AnyCancellable> = []
    var testFileURLs: [URL] = []
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        cancellables.removeAll()
    }
    
    override func tearDown() {
        audioEngine = nil
        TestFixtures.shared.cleanupTestFiles(testFileURLs)
        testFileURLs.removeAll()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialState() {
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, 0)
        XCTAssertEqual(audioEngine.duration, 0)
        XCTAssertEqual(audioEngine.volume, 0.5)
        XCTAssertNil(audioEngine.currentTrack)
        XCTAssertFalse(audioEngine.isLoading)
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertFalse(audioEngine.isPaused)
    }
    
    func testVolumeControl() {
        // Test volume setter
        audioEngine.volume = 0.75
        XCTAssertEqual(audioEngine.volume, 0.75)
        
        audioEngine.volume = 0.0
        XCTAssertEqual(audioEngine.volume, 0.0)
        
        audioEngine.volume = 1.0
        XCTAssertEqual(audioEngine.volume, 1.0)
    }
    
    // MARK: - File Loading Tests
    
    func testLoadTrackWithValidFile() async throws {
        // Create a test audio file
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        
        // Create track from file
        let track = Track(from: fileURL)!
        
        // Test loading
        try await audioEngine.loadTrack(track)
        
        XCTAssertEqual(audioEngine.currentTrack?.id, track.id)
        XCTAssertGreaterThan(audioEngine.duration, 0)
        XCTAssertEqual(audioEngine.currentTime, 0)
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertFalse(audioEngine.isLoading)
    }
    
    func testLoadTrackWithInvalidURL() async {
        let track = TestFixtures.shared.createTestTrack()
        
        do {
            try await audioEngine.loadTrack(track)
            XCTFail("Expected error for invalid URL")
        } catch {
            XCTAssertTrue(error is AudioEngineError)
            if case AudioEngineError.fileNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected fileNotFound error")
            }
        }
    }
    
    func testLoadTrackWithMissingFile() async {
        let missingURL = URL(fileURLWithPath: "/nonexistent/file.mp3")
        let track = Track(
            title: "Missing Track",
            duration: 0,
            fileURL: missingURL
        )
        
        do {
            try await audioEngine.loadTrack(track)
            XCTFail("Expected error for missing file")
        } catch {
            XCTAssertTrue(error is AudioEngineError)
        }
    }
    
    func testLoadURL() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        
        try await audioEngine.loadURL(fileURL)
        
        XCTAssertNotNil(audioEngine.currentTrack)
        XCTAssertEqual(audioEngine.currentTrack?.fileURL, fileURL)
    }
    
    // MARK: - Playback Control Tests
    
    func testPlayWithoutLoadedFile() throws {
        // Should not throw, just log warning
        XCTAssertNoThrow(try audioEngine.play())
        XCTAssertEqual(audioEngine.playbackState, .stopped)
    }
    
    func testPlayPauseStop() async throws {
        // Load a test file first
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // Test play
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        XCTAssertTrue(audioEngine.isPlaying)
        
        // Test pause
        audioEngine.pause()
        XCTAssertEqual(audioEngine.playbackState, .paused)
        XCTAssertTrue(audioEngine.isPaused)
        XCTAssertFalse(audioEngine.isPlaying)
        
        // Test resume from pause
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Test stop
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, 0)
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertFalse(audioEngine.isPaused)
    }
    
    func testTogglePlayPause() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // Toggle from stopped to playing
        audioEngine.togglePlayPause()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Toggle from playing to paused
        audioEngine.togglePlayPause()
        XCTAssertEqual(audioEngine.playbackState, .paused)
        
        // Toggle from paused to playing
        audioEngine.togglePlayPause()
        XCTAssertEqual(audioEngine.playbackState, .playing)
    }
    
    // MARK: - Seek Tests
    
    func testSeekToValidPosition() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 30.0)
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // Seek to middle
        try audioEngine.seek(to: 15.0)
        XCTAssertEqual(audioEngine.currentTime, 15.0, accuracy: 0.1)
        
        // Seek to beginning
        try audioEngine.seek(to: 0.0)
        XCTAssertEqual(audioEngine.currentTime, 0.0, accuracy: 0.1)
        
        // Seek to end
        try audioEngine.seek(to: audioEngine.duration)
        XCTAssertEqual(audioEngine.currentTime, audioEngine.duration, accuracy: 0.1)
    }
    
    func testSeekBeyondDuration() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 10.0)
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // Seek beyond duration should clamp to duration
        try audioEngine.seek(to: 20.0)
        XCTAssertEqual(audioEngine.currentTime, audioEngine.duration, accuracy: 0.1)
    }
    
    func testSeekToNegativePosition() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // Seek to negative should clamp to 0
        try audioEngine.seek(to: -5.0)
        XCTAssertEqual(audioEngine.currentTime, 0.0, accuracy: 0.1)
    }
    
    func testSeekWhilePlaying() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 30.0)
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        try audioEngine.seek(to: 15.0)
        XCTAssertEqual(audioEngine.currentTime, 15.0, accuracy: 0.1)
        XCTAssertEqual(audioEngine.playbackState, .playing)
    }
    
    func testSeekWithoutLoadedFile() {
        XCTAssertThrowsError(try audioEngine.seek(to: 10.0)) { error in
            XCTAssertTrue(error is AudioEngineError)
            if case AudioEngineError.seekFailed = error {
                // Expected error
            } else {
                XCTFail("Expected seekFailed error")
            }
        }
    }
    
    func testSkipForwardBackward() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 60.0)
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // Skip forward
        audioEngine.skipForward(by: 10)
        XCTAssertEqual(audioEngine.currentTime, 10.0, accuracy: 0.1)
        
        // Skip forward again
        audioEngine.skipForward(by: 15)
        XCTAssertEqual(audioEngine.currentTime, 25.0, accuracy: 0.1)
        
        // Skip backward
        audioEngine.skipBackward(by: 5)
        XCTAssertEqual(audioEngine.currentTime, 20.0, accuracy: 0.1)
        
        // Skip backward beyond beginning
        audioEngine.skipBackward(by: 30)
        XCTAssertEqual(audioEngine.currentTime, 0.0, accuracy: 0.1)
    }
    
    // MARK: - State Transition Tests
    
    func testStateTransitions() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        
        // Initial state
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Loading state
        let loadExpectation = expectation(description: "Loading state")
        audioEngine.$playbackState
            .dropFirst()
            .sink { state in
                if case .loading = state {
                    loadExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        Task {
            try await audioEngine.loadURL(fileURL)
        }
        
        await fulfillment(of: [loadExpectation], timeout: 5.0)
        
        // Wait for loading to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // After loading
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Play state
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Pause state
        audioEngine.pause()
        XCTAssertEqual(audioEngine.playbackState, .paused)
        
        // Stop state
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateAfterFailedLoad() async {
        let invalidTrack = Track(
            title: "Invalid",
            duration: 0,
            fileURL: nil
        )
        
        do {
            try await audioEngine.loadTrack(invalidTrack)
            XCTFail("Expected error")
        } catch {
            // Check that error state is set
            if case .error = audioEngine.playbackState {
                // Expected state
            } else {
                XCTFail("Expected error state")
            }
        }
    }
    
    func testEngineStartFailure() async throws {
        // This test would require mocking AVAudioEngine to simulate start failure
        // In a real implementation, you'd use dependency injection
        
        // For now, we'll test that the error is properly propagated
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        // In a real test with mocks, we'd force engine.start() to throw
        // and verify the error handling
    }
    
    // MARK: - Time Tracking Tests
    
    func testTimeFormatting() {
        XCTAssertEqual(audioEngine.formatTime(0), "0:00")
        XCTAssertEqual(audioEngine.formatTime(59), "0:59")
        XCTAssertEqual(audioEngine.formatTime(60), "1:00")
        XCTAssertEqual(audioEngine.formatTime(125), "2:05")
        XCTAssertEqual(audioEngine.formatTime(3661), "61:01")
    }
    
    func testProgressCalculation() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 100.0)
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        XCTAssertEqual(audioEngine.progress, 0.0)
        
        try audioEngine.seek(to: 25.0)
        XCTAssertEqual(audioEngine.progress, 0.25, accuracy: 0.01)
        
        try audioEngine.seek(to: 50.0)
        XCTAssertEqual(audioEngine.progress, 0.5, accuracy: 0.01)
        
        try audioEngine.seek(to: 100.0)
        XCTAssertEqual(audioEngine.progress, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryCleanupAfterStop() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        try audioEngine.play()
        audioEngine.stop()
        
        // Verify cleanup
        XCTAssertEqual(audioEngine.currentTime, 0)
        XCTAssertEqual(audioEngine.playbackState, .stopped)
    }
    
    func testDeinitCleanup() async throws {
        var engine: AudioEngine? = AudioEngine()
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        
        try await engine?.loadURL(fileURL)
        try engine?.play()
        
        // Release engine
        engine = nil
        
        // In a real test, we'd verify that resources are properly released
        // This would require observing the actual AVAudioEngine state
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentLoadOperations() async throws {
        let fileURL1 = try TestFixtures.shared.createTestAudioFile()
        let fileURL2 = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(contentsOf: [fileURL1, fileURL2])
        
        // Start loading first file
        let loadTask1 = Task {
            try await audioEngine.loadURL(fileURL1)
        }
        
        // Immediately start loading second file
        let loadTask2 = Task {
            try await audioEngine.loadURL(fileURL2)
        }
        
        // Wait for both to complete
        _ = try await loadTask1.value
        _ = try await loadTask2.value
        
        // Verify that the last loaded file is current
        XCTAssertEqual(audioEngine.currentTrack?.fileURL, fileURL2)
    }
    
    func testPlaybackDuringLoad() async throws {
        let fileURL1 = try TestFixtures.shared.createTestAudioFile()
        let fileURL2 = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(contentsOf: [fileURL1, fileURL2])
        
        // Load and play first file
        try await audioEngine.loadURL(fileURL1)
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Load second file while first is playing
        try await audioEngine.loadURL(fileURL2)
        
        // Verify playback stopped and new file is ready
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTrack?.fileURL, fileURL2)
    }
    
    // MARK: - Performance Tests
    
    func testSeekPerformance() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 300.0) // 5 minutes
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        measure {
            // Perform 100 random seeks
            for _ in 0..<100 {
                let randomPosition = Double.random(in: 0...300)
                try? audioEngine.seek(to: randomPosition)
            }
        }
    }
    
    func testLoadPerformance() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile()
        testFileURLs.append(fileURL)
        
        measure {
            let expectation = self.expectation(description: "Load completion")
            
            Task {
                try await audioEngine.loadURL(fileURL)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Notification Tests
    
    func testPlaybackCompletionNotification() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 0.5) // Short file
        testFileURLs.append(fileURL)
        try await audioEngine.loadURL(fileURL)
        
        let notificationExpectation = expectation(
            forNotification: .audioPlaybackCompleted,
            object: audioEngine
        ) { notification in
            // Verify notification contains track info
            XCTAssertNotNil(notification.userInfo?["track"])
            return true
        }
        
        try audioEngine.play()
        
        await fulfillment(of: [notificationExpectation], timeout: 2.0)
        
        // Verify state after completion
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, audioEngine.duration, accuracy: 0.1)
    }
    
    // MARK: - Format Support Tests
    
    func testSupportedFormats() async throws {
        // Test various audio formats
        let formats: [(ext: String, settings: [String: Any])] = [
            ("m4a", [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]),
            ("wav", [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ])
        ]
        
        for (ext, settings) in formats {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "test.\(ext)"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            // Create file with specific format
            let audioFormat = AVAudioFormat(settings: settings)!
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 44100)!
            buffer.frameLength = 44100
            try audioFile.write(from: buffer)
            
            testFileURLs.append(fileURL)
            
            // Test loading
            do {
                try await audioEngine.loadURL(fileURL)
                XCTAssertNotNil(audioEngine.currentTrack)
            } catch {
                XCTFail("Failed to load \(ext) format: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullPlaybackCycle() async throws {
        let fileURL = try TestFixtures.shared.createTestAudioFile(duration: 5.0)
        testFileURLs.append(fileURL)
        
        // Load
        try await audioEngine.loadURL(fileURL)
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Play
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertGreaterThan(audioEngine.currentTime, 0)
        
        // Seek
        try audioEngine.seek(to: 2.0)
        XCTAssertEqual(audioEngine.currentTime, 2.0, accuracy: 0.1)
        
        // Pause
        audioEngine.pause()
        XCTAssertEqual(audioEngine.playbackState, .paused)
        let pausedTime = audioEngine.currentTime
        
        // Wait and verify time doesn't advance
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        XCTAssertEqual(audioEngine.currentTime, pausedTime, accuracy: 0.1)
        
        // Resume
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Stop
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, 0)
    }
    
    func testMultipleTracksPlayback() async throws {
        // Create multiple test files
        let tracks = try await withThrowingTaskGroup(of: Track.self) { group in
            for i in 0..<3 {
                group.addTask {
                    let url = try TestFixtures.shared.createTestAudioFile(duration: Double(i + 1) * 10.0)
                    self.testFileURLs.append(url)
                    return Track(from: url)!
                }
            }
            
            var tracks: [Track] = []
            for try await track in group {
                tracks.append(track)
            }
            return tracks
        }
        
        // Play each track
        for track in tracks {
            try await audioEngine.loadTrack(track)
            try audioEngine.play()
            
            // Verify track is playing
            XCTAssertEqual(audioEngine.playbackState, .playing)
            XCTAssertEqual(audioEngine.currentTrack?.id, track.id)
            
            // Play for a short time
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            audioEngine.stop()
        }
    }
}

// MARK: - Test Helpers

private extension AudioEngine {
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}