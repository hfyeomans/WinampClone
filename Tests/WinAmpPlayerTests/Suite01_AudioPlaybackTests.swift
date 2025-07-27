//
//  Suite01_AudioPlaybackTests.swift
//  WinAmpPlayerTests
//
//  SUITE-01: Audio Playback & Engine Tests
//  Priority: Critical
//

import XCTest
import AVFoundation
@testable import WinAmpPlayer

/// SUITE-01: Audio Playback & Engine Tests
/// Critical priority tests for core audio functionality
class Suite01_AudioPlaybackTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    var testBundle: Bundle!
    var fixturesURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize audio engine
        audioEngine = AudioEngine()
        
        // Set up test bundle and fixtures path
        testBundle = Bundle(for: type(of: self))
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        fixturesURL = testDir.appendingPathComponent("Fixtures/Audio")
        
        // Generate fixtures if needed
        if !FileManager.default.fileExists(atPath: fixturesURL.appendingPathComponent("44k_stereo.wav").path) {
            try TestFixtureGenerator.generateAllFixtures()
        }
        
        // Enable unit test mode to bypass hardware
        audioEngine.enableTestMode()
    }
    
    override func tearDownWithError() throws {
        audioEngine.stop()
        audioEngine = nil
        try super.tearDownWithError()
    }
    
    // MARK: - TEST-A1: Basic WAV Playback
    
    func testA1_BasicWAVPlayback() throws {
        // Arrange
        let wavURL = fixturesURL.appendingPathComponent("44k_stereo.wav")
        let expectation = XCTestExpectation(description: "Audio playback started")
        
        var playbackStarted = false
        let observer = NotificationCenter.default.addObserver(
            forName: .audioPlaybackStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let state = notification.userInfo?["state"] as? AudioEngine.PlaybackState,
               state == .playing {
                playbackStarted = true
                expectation.fulfill()
            }
        }
        
        // Act
        try audioEngine.loadURL(wavURL)
        audioEngine.play()
        
        // Wait for playback to start
        wait(for: [expectation], timeout: 2.0)
        
        // Assert
        XCTAssertTrue(playbackStarted, "Playback should have started")
        XCTAssertEqual(audioEngine.playbackState, .playing)
        XCTAssertTrue(audioEngine.isPlaying)
        
        // Wait a bit and check current time
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertGreaterThan(audioEngine.currentTime, 0, "Current time should advance during playback")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - TEST-A2: Pause/Resume Functionality
    
    func testA2_PauseResumeFunctionality() throws {
        // Arrange
        let wavURL = fixturesURL.appendingPathComponent("44k_stereo.wav")
        try audioEngine.loadURL(wavURL)
        audioEngine.play()
        Thread.sleep(forTimeInterval: 0.5)
        
        let timeBeforePause = audioEngine.currentTime
        
        // Act - Pause
        audioEngine.pause()
        Thread.sleep(forTimeInterval: 0.2)
        let timeAfterPause = audioEngine.currentTime
        
        // Assert pause state
        XCTAssertEqual(audioEngine.playbackState, .paused)
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertEqual(timeBeforePause, timeAfterPause, accuracy: 0.1, "Time should not advance while paused")
        
        // Act - Resume
        audioEngine.play()
        Thread.sleep(forTimeInterval: 0.3)
        let timeAfterResume = audioEngine.currentTime
        
        // Assert resume state
        XCTAssertEqual(audioEngine.playbackState, .playing)
        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertGreaterThan(timeAfterResume, timeAfterPause, "Time should advance after resume")
        
        // Verify time delta is approximately 0.3s
        let timeDelta = timeAfterResume - timeAfterPause
        XCTAssertEqual(timeDelta, 0.3, accuracy: 0.1, "Time advancement should match sleep duration")
    }
    
    // MARK: - TEST-A3: Stop Resets Playback
    
    func testA3_StopResetsPlayback() throws {
        // Arrange
        let wavURL = fixturesURL.appendingPathComponent("44k_stereo.wav")
        try audioEngine.loadURL(wavURL)
        audioEngine.play()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Verify playback has progressed
        XCTAssertGreaterThan(audioEngine.currentTime, 0)
        XCTAssertGreaterThan(audioEngine.framePosition, 0)
        
        // Act
        audioEngine.stop()
        
        // Assert
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.currentTime, 0, "Current time should reset to 0")
        XCTAssertEqual(audioEngine.framePosition, 0, "Frame position should reset to 0")
        XCTAssertFalse(audioEngine.isPlaying)
    }
    
    // MARK: - TEST-A4: Seek Boundary Handling
    
    func testA4_SeekBoundaryHandling() throws {
        // Arrange
        let wavURL = fixturesURL.appendingPathComponent("44k_stereo.wav")
        try audioEngine.loadURL(wavURL)
        
        let duration = audioEngine.duration
        XCTAssertGreaterThan(duration, 0, "Duration should be available after loading")
        
        // Test 1: Seek beyond duration
        audioEngine.seek(to: duration + 10)
        XCTAssertEqual(audioEngine.currentTime, duration, accuracy: 0.1, "Seek should clamp to duration")
        
        // Test 2: Seek to negative value
        audioEngine.seek(to: -5)
        XCTAssertEqual(audioEngine.currentTime, 0, "Seek should clamp to 0 for negative values")
        
        // Test 3: Valid seek
        let midPoint = duration / 2
        audioEngine.seek(to: midPoint)
        XCTAssertEqual(audioEngine.currentTime, midPoint, accuracy: 0.1, "Valid seek should work correctly")
        
        // Test 4: Verify progress is clamped 0...1
        XCTAssertGreaterThanOrEqual(audioEngine.progress, 0)
        XCTAssertLessThanOrEqual(audioEngine.progress, 1)
    }
    
    // MARK: - TEST-A5: Mono File Auto-Duplication
    
    func testA5_MonoFileAutoDuplication() throws {
        // Arrange
        let monoURL = fixturesURL.appendingPathComponent("mono_16k.wav")
        try audioEngine.loadURL(monoURL)
        
        // Enable visualization to capture audio data
        audioEngine.isVisualizationEnabled = true
        
        let expectation = XCTestExpectation(description: "Visualization data received")
        var capturedData: AudioVisualizationData?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .audioVisualizationDataAvailable,
            object: nil,
            queue: .main
        ) { notification in
            if let data = notification.userInfo?["data"] as? AudioVisualizationData {
                capturedData = data
                expectation.fulfill()
            }
        }
        
        // Act
        audioEngine.play()
        
        // Wait for visualization data
        wait(for: [expectation], timeout: 2.0)
        
        // Assert
        XCTAssertNotNil(capturedData, "Should receive visualization data")
        
        if let data = capturedData {
            // Check that left and right channels are identical (mono duplication)
            XCTAssertEqual(data.leftChannel.count, data.rightChannel.count)
            
            var allEqual = true
            for i in 0..<min(data.leftChannel.count, data.rightChannel.count) {
                if abs(data.leftChannel[i] - data.rightChannel[i]) > 0.001 {
                    allEqual = false
                    break
                }
            }
            
            XCTAssertTrue(allEqual, "Mono file should have identical left and right channels")
        }
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - TEST-A6: Unsupported Format Error Handling
    
    func testA6_UnsupportedFormatErrorHandling() throws {
        // Arrange
        let invalidURL = fixturesURL.appendingPathComponent("invalid.txt")
        
        // Act & Assert
        XCTAssertThrowsError(try audioEngine.loadURL(invalidURL)) { error in
            // Verify error type
            if let audioError = error as? AudioEngine.AudioError {
                XCTAssertEqual(audioError, .unsupportedFormat)
            } else {
                XCTFail("Expected AudioError.unsupportedFormat")
            }
        }
        
        // Verify error state
        XCTAssertEqual(audioEngine.playbackState, .error)
    }
    
    // MARK: - TEST-A7: Corrupt File Error Handling
    
    func testA7_CorruptFileErrorHandling() throws {
        // Arrange
        let corruptURL = fixturesURL.appendingPathComponent("corrupt.mp3")
        
        // Act & Assert
        XCTAssertThrowsError(try audioEngine.loadURL(corruptURL)) { error in
            // Verify error type
            if let audioError = error as? AudioEngine.AudioError {
                XCTAssertEqual(audioError, .fileLoadFailed)
            } else {
                XCTFail("Expected AudioError.fileLoadFailed")
            }
        }
    }
    
    // MARK: - TEST-A8: Audio System Interruption
    
    func testA8_AudioSystemInterruption() throws {
        // Arrange
        let wavURL = fixturesURL.appendingPathComponent("44k_stereo.wav")
        try audioEngine.loadURL(wavURL)
        audioEngine.play()
        
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Act - Simulate interruption began
        NotificationCenter.default.post(
            name: .audioSystemInterrupted,
            object: nil,
            userInfo: [
                "type": macOSAudioSystemManager.InterruptionType.began
            ]
        )
        
        // Give time for handling
        Thread.sleep(forTimeInterval: 0.1)
        
        // Assert - Should auto-pause
        XCTAssertEqual(audioEngine.playbackState, .paused)
        
        // Act - Simulate interruption ended
        NotificationCenter.default.post(
            name: .audioSystemInterrupted,
            object: nil,
            userInfo: [
                "type": macOSAudioSystemManager.InterruptionType.ended
            ]
        )
        
        // Assert - Should remain paused (user must manually resume)
        XCTAssertEqual(audioEngine.playbackState, .paused)
        XCTAssertFalse(audioEngine.isPlaying)
        
        // Verify no crash occurred
        XCTAssertNotNil(audioEngine)
    }
}

// Test helpers and extensions are now in TestExtensions.swift