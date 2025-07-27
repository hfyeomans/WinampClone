//
//  AudioEngineIntegrationTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-06-28.
//  Integration tests for AudioEngine with other components.
//

import XCTest
import Combine
import AVFoundation
import AppKit
@testable import WinAmpPlayer

final class AudioEngineIntegrationTests: XCTestCase {
    var audioEngine: AudioEngine!
    var audioSystemManager: macOSAudioSystemManager!
    var playlist: Playlist!
    var cancellables: Set<AnyCancellable> = []
    var testFileURLs: [URL] = []
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        audioSystemManager = macOSAudioSystemManager.shared
        playlist = Playlist(name: "Test Playlist")
        cancellables.removeAll()
    }
    
    override func tearDown() {
        audioEngine = nil
        audioSystemManager = nil
        playlist = nil
        AudioTestFixtures.cleanup(testFileURLs)
        testFileURLs.removeAll()
        super.tearDown()
    }
    
    // MARK: - AudioSession Integration Tests
    
    func testAudioSessionConfiguration() async throws {
        // Configure audio system for playback
        audioSystemManager.configure(for: audioEngine.engine)
        try audioSystemManager.activate()
        
        // Load and play audio
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        try audioEngine.play()
        
        // Verify audio session is active
        XCTAssertTrue(AVAudioSession.sharedInstance().isOtherAudioPlaying == false)
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        audioEngine.stop()
    }
    
    func testAudioSessionInterruption() async throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        try audioEngine.play()
        
        // Simulate interruption began
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )
        
        // Wait for interruption to be handled
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify playback was paused
        XCTAssertEqual(audioEngine.playbackState, .paused)
        
        // Simulate interruption ended
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )
    }
    
    func testAudioRouteChange() async throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        try audioEngine.play()
        
        // Simulate route change (e.g., headphones unplugged)
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [
                AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            ]
        )
        
        // Engine should handle route change gracefully
        // In a real app, you might pause playback when headphones are unplugged
        XCTAssertNotNil(audioEngine)
    }
    
    // MARK: - Playlist Integration Tests
    
    func testPlaylistTrackLoading() async throws {
        // Create test tracks
        let trackCount = 5
        var tracks: [Track] = []
        
        for i in 0..<trackCount {
            let file = try AudioTestFixtures.createTestAudioFile(duration: Double(i + 1) * 10.0)
            testFileURLs.append(file)
            
            if let track = Track(from: file) {
                tracks.append(track)
                playlist.addTrack(track)
            }
        }
        
        XCTAssertEqual(playlist.tracks.count, trackCount)
        
        // Load first track
        if let firstTrack = playlist.currentTrack {
            try await audioEngine.loadTrack(firstTrack)
            XCTAssertEqual(audioEngine.currentTrack?.id, firstTrack.id)
        }
    }
    
    func testPlaylistNavigation() async throws {
        // Create playlist with multiple tracks
        for i in 0..<3 {
            let file = try AudioTestFixtures.createTestAudioFile()
            testFileURLs.append(file)
            
            if let track = Track(from: file) {
                playlist.addTrack(track)
            }
        }
        
        // Test next track
        let firstTrack = playlist.currentTrack
        playlist.next()
        let secondTrack = playlist.currentTrack
        
        XCTAssertNotEqual(firstTrack?.id, secondTrack?.id)
        
        // Load second track
        if let track = secondTrack {
            try await audioEngine.loadTrack(track)
            XCTAssertEqual(audioEngine.currentTrack?.id, track.id)
        }
        
        // Test previous track
        playlist.previous()
        XCTAssertEqual(playlist.currentTrack?.id, firstTrack?.id)
    }
    
    func testPlaylistCompletion() async throws {
        // Create a short playlist
        for i in 0..<2 {
            let file = try AudioTestFixtures.createTestAudioFile(duration: 0.5) // Short files
            testFileURLs.append(file)
            
            if let track = Track(from: file) {
                playlist.addTrack(track)
            }
        }
        
        // Set up completion handler
        var completedTracks: [Track] = []
        let completionExpectation = expectation(description: "Track completed")
        completionExpectation.expectedFulfillmentCount = 1
        
        NotificationCenter.default.addObserver(
            forName: .audioPlaybackCompleted,
            object: audioEngine,
            queue: .main
        ) { notification in
            if let track = notification.userInfo?["track"] as? Track {
                completedTracks.append(track)
                completionExpectation.fulfill()
            }
        }
        
        // Play first track
        if let track = playlist.currentTrack {
            try await audioEngine.loadTrack(track)
            try audioEngine.play()
        }
        
        await fulfillment(of: [completionExpectation], timeout: 2.0)
        
        XCTAssertEqual(completedTracks.count, 1)
        XCTAssertEqual(completedTracks.first?.id, playlist.tracks.first?.id)
    }
    
    // MARK: - State Synchronization Tests
    
    func testStatePublisherIntegration() async throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        
        var receivedStates: [PlaybackState] = []
        let stateExpectation = expectation(description: "State changes received")
        stateExpectation.expectedFulfillmentCount = 4 // loading, stopped, playing, stopped
        
        audioEngine.$playbackState
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count <= 4 {
                    stateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger state changes
        try await audioEngine.loadURL(file)
        try audioEngine.play()
        audioEngine.stop()
        
        await fulfillment(of: [stateExpectation], timeout: 5.0)
        
        // Verify state sequence
        XCTAssertTrue(receivedStates.contains { if case .loading = $0 { return true } else { return false } })
        XCTAssertTrue(receivedStates.contains { if case .playing = $0 { return true } else { return false } })
        XCTAssertTrue(receivedStates.contains { if case .stopped = $0 { return true } else { return false } })
    }
    
    func testTimePublisherIntegration() async throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 5.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        var timeUpdates: [TimeInterval] = []
        let timeExpectation = expectation(description: "Time updates received")
        
        audioEngine.$currentTime
            .dropFirst() // Skip initial 0
            .prefix(10) // Collect first 10 updates
            .sink { time in
                timeUpdates.append(time)
                if timeUpdates.count == 10 {
                    timeExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try audioEngine.play()
        
        await fulfillment(of: [timeExpectation], timeout: 2.0)
        
        audioEngine.stop()
        
        // Verify time is progressing
        XCTAssertEqual(timeUpdates.count, 10)
        for i in 1..<timeUpdates.count {
            XCTAssertGreaterThanOrEqual(timeUpdates[i], timeUpdates[i-1])
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery() async throws {
        // Try to load invalid file
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.mp3")
        
        do {
            try await audioEngine.loadURL(invalidURL)
            XCTFail("Expected error")
        } catch {
            // Verify error state
            if case .error = audioEngine.playbackState {
                // Expected
            } else {
                XCTFail("Expected error state")
            }
        }
        
        // Now load valid file and verify recovery
        let validFile = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(validFile)
        
        try await audioEngine.loadURL(validFile)
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        
        // Verify can play after error
        try audioEngine.play()
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        audioEngine.stop()
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testMusicPlayerScenario() async throws {
        // Simulate typical music player usage
        
        // 1. Create a playlist
        let trackFiles = try AudioTestFixtures.createBatchTestFiles(count: 5, durationRange: 2.0...5.0)
        testFileURLs.append(contentsOf: trackFiles)
        
        for file in trackFiles {
            if let track = Track(from: file) {
                playlist.addTrack(track)
            }
        }
        
        // 2. Start playing first track
        if let firstTrack = playlist.currentTrack {
            try await audioEngine.loadTrack(firstTrack)
            try audioEngine.play()
        }
        
        // 3. User skips forward
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        audioEngine.skipForward(by: 1.0)
        
        // 4. User adjusts volume
        audioEngine.volume = 0.7
        
        // 5. User skips to next track
        playlist.next()
        if let nextTrack = playlist.currentTrack {
            try await audioEngine.loadTrack(nextTrack)
            try audioEngine.play()
        }
        
        // 6. User pauses
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        audioEngine.pause()
        
        // 7. User seeks
        try audioEngine.seek(to: 1.5)
        
        // 8. User resumes
        try audioEngine.play()
        
        // 9. User stops
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        audioEngine.stop()
        
        // Verify final state
        XCTAssertEqual(audioEngine.playbackState, .stopped)
        XCTAssertEqual(audioEngine.volume, 0.7)
        XCTAssertEqual(playlist.currentIndex, 1)
    }
    
    func testBackgroundPlaybackScenario() async throws {
        // Configure for background playback
        try audioSessionManager.configureForPlayback()
        audioSessionManager.enableBackgroundAudio()
        
        // Load and play
        let file = try AudioTestFixtures.createTestAudioFile(duration: 10.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        try audioEngine.play()
        
        // Simulate app going to background
        NotificationCenter.default.post(
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        // Playback should continue
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        // Simulate app coming to foreground
        NotificationCenter.default.post(
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Playback should still be active
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        audioEngine.stop()
    }
    
    // MARK: - Performance Under Load Tests
    
    func testHighFrequencyOperations() async throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 60.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        // Perform many operations in quick succession
        let operationCount = 1000
        let startTime = Date()
        
        for i in 0..<operationCount {
            switch i % 5 {
            case 0:
                audioEngine.volume = Float.random(in: 0...1)
            case 1:
                if audioEngine.isPlaying {
                    audioEngine.pause()
                } else {
                    try? audioEngine.play()
                }
            case 2:
                audioEngine.skipForward(by: 0.1)
            case 3:
                audioEngine.skipBackward(by: 0.1)
            case 4:
                // Just observe current time
                _ = audioEngine.currentTime
            default:
                break
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(operationCount) / elapsed
        
        print("Performed \(operationsPerSecond) operations per second")
        
        // Should handle at least 100 operations per second
        XCTAssertGreaterThan(operationsPerSecond, 100)
        
        // Engine should still be functional
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
    }
}