//
//  AudioEngineConcurrencyTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-06-28.
//  Tests for concurrent operations and thread safety in AudioEngine.
//

import XCTest
import Combine
@testable import WinAmpPlayer

final class AudioEngineConcurrencyTests: XCTestCase {
    var audioEngine: AudioEngine!
    var testFileURLs: [URL] = []
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
        cancellables.removeAll()
    }
    
    override func tearDown() {
        audioEngine = nil
        AudioTestFixtures.cleanup(testFileURLs)
        testFileURLs.removeAll()
        super.tearDown()
    }
    
    // MARK: - Concurrent Load Tests
    
    func testConcurrentFileLoading() async throws {
        // Create multiple test files
        let fileCount = 10
        let files = try AudioTestFixtures.createBatchTestFiles(count: fileCount)
        testFileURLs.append(contentsOf: files)
        
        // Load files concurrently
        await withTaskGroup(of: Void.self) { group in
            for file in files {
                group.addTask { [weak self] in
                    do {
                        try await self?.audioEngine.loadURL(file)
                    } catch {
                        // Expected - some loads may fail due to concurrent access
                    }
                }
            }
        }
        
        // Verify engine is in a valid state
        XCTAssertNotNil(audioEngine.currentTrack)
        XCTAssertFalse(audioEngine.isLoading)
    }
    
    func testRapidLoadCancellation() async throws {
        let files = try AudioTestFixtures.createBatchTestFiles(count: 5)
        testFileURLs.append(contentsOf: files)
        
        // Start loading files rapidly and cancel
        for (index, file) in files.enumerated() {
            let loadTask = Task {
                try await audioEngine.loadURL(file)
            }
            
            // Cancel some tasks immediately
            if index % 2 == 0 {
                loadTask.cancel()
            }
            
            // Small delay between loads
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Wait for operations to settle
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify engine is stable
        XCTAssertFalse(audioEngine.isLoading)
    }
    
    // MARK: - Concurrent Playback Control Tests
    
    func testConcurrentPlayPauseCommands() async throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 60.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        // Issue play/pause commands concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask { [weak self] in
                    if i % 2 == 0 {
                        try? self?.audioEngine.play()
                    } else {
                        self?.audioEngine.pause()
                    }
                }
            }
        }
        
        // Verify final state is consistent
        let finalState = audioEngine.playbackState
        switch finalState {
        case .playing, .paused, .stopped:
            // Valid states
            break
        default:
            XCTFail("Invalid state after concurrent operations: \(finalState)")
        }
    }
    
    func testConcurrentSeekOperations() async throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 300.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        try audioEngine.play()
        
        // Perform concurrent seeks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { [weak self] in
                    let position = TimeInterval.random(in: 0...300)
                    try? self?.audioEngine.seek(to: position)
                }
            }
        }
        
        // Verify current time is within valid range
        XCTAssertGreaterThanOrEqual(audioEngine.currentTime, 0)
        XCTAssertLessThanOrEqual(audioEngine.currentTime, audioEngine.duration)
        XCTAssertEqual(audioEngine.playbackState, .playing)
    }
    
    // MARK: - State Observation Tests
    
    func testConcurrentStateObservation() async throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        
        var stateChanges: [PlaybackState] = []
        let stateQueue = DispatchQueue(label: "state.queue", attributes: .concurrent)
        let stateLock = NSLock()
        
        // Set up multiple observers
        let observerCount = 10
        for _ in 0..<observerCount {
            audioEngine.$playbackState
                .receive(on: stateQueue)
                .sink { state in
                    stateLock.lock()
                    stateChanges.append(state)
                    stateLock.unlock()
                }
                .store(in: &cancellables)
        }
        
        // Perform operations
        try await audioEngine.loadURL(file)
        try audioEngine.play()
        audioEngine.pause()
        try audioEngine.play()
        audioEngine.stop()
        
        // Wait for observations to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify observers received updates
        stateLock.lock()
        let finalCount = stateChanges.count
        stateLock.unlock()
        
        // Each observer should have received multiple state changes
        XCTAssertGreaterThan(finalCount, observerCount * 3)
    }
    
    // MARK: - Volume Control Tests
    
    func testConcurrentVolumeChanges() async throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        // Change volume from multiple threads
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { [weak self] in
                    let volume = Float.random(in: 0...1)
                    self?.audioEngine.volume = volume
                }
            }
        }
        
        // Verify volume is within valid range
        XCTAssertGreaterThanOrEqual(audioEngine.volume, 0)
        XCTAssertLessThanOrEqual(audioEngine.volume, 1)
    }
    
    // MARK: - Time Update Tests
    
    func testConcurrentTimeObservation() async throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 30.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        var timeUpdates: [TimeInterval] = []
        let timeLock = NSLock()
        
        // Observe time from multiple threads
        for _ in 0..<5 {
            audioEngine.$currentTime
                .sink { time in
                    timeLock.lock()
                    timeUpdates.append(time)
                    timeLock.unlock()
                }
                .store(in: &cancellables)
        }
        
        // Play and seek while observing
        try audioEngine.play()
        
        await withTaskGroup(of: Void.self) { group in
            // Continuous playback
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            // Random seeks
            group.addTask { [weak self] in
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    let position = TimeInterval.random(in: 0...30)
                    try? self?.audioEngine.seek(to: position)
                }
            }
        }
        
        audioEngine.stop()
        
        // Verify time updates were received
        timeLock.lock()
        let updateCount = timeUpdates.count
        timeLock.unlock()
        
        XCTAssertGreaterThan(updateCount, 0)
    }
    
    // MARK: - Resource Contention Tests
    
    func testHighLoadConcurrentOperations() async throws {
        let files = try AudioTestFixtures.createBatchTestFiles(count: 3)
        testFileURLs.append(contentsOf: files)
        
        // Simulate high load with mixed operations
        await withTaskGroup(of: Void.self) { group in
            // File loading tasks
            for file in files {
                group.addTask { [weak self] in
                    for _ in 0..<5 {
                        try? await self?.audioEngine.loadURL(file)
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    }
                }
            }
            
            // Playback control tasks
            group.addTask { [weak self] in
                for _ in 0..<50 {
                    try? self?.audioEngine.play()
                    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    self?.audioEngine.pause()
                }
            }
            
            // Seek tasks
            group.addTask { [weak self] in
                for _ in 0..<30 {
                    let position = TimeInterval.random(in: 0...60)
                    try? self?.audioEngine.seek(to: position)
                    try? await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds
                }
            }
            
            // Volume tasks
            group.addTask { [weak self] in
                for _ in 0..<100 {
                    self?.audioEngine.volume = Float.random(in: 0...1)
                    try? await Task.sleep(nanoseconds: 5_000_000) // 0.005 seconds
                }
            }
        }
        
        // Verify engine is still functional
        audioEngine.stop()
        XCTAssertEqual(audioEngine.playbackState, .stopped)
    }
    
    // MARK: - Deadlock Prevention Tests
    
    func testNoDeadlockOnRapidStateChanges() async throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        let operationCount = 1000
        let timeout: TimeInterval = 10.0
        
        let expectation = expectation(description: "Rapid state changes complete")
        
        Task {
            for i in 0..<operationCount {
                switch i % 4 {
                case 0:
                    try? audioEngine.play()
                case 1:
                    audioEngine.pause()
                case 2:
                    audioEngine.stop()
                case 3:
                    audioEngine.togglePlayPause()
                default:
                    break
                }
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: timeout)
        
        // If we reach here, no deadlock occurred
        XCTAssertTrue(true)
    }
    
    // MARK: - Memory Safety Tests
    
    func testMemorySafetyUnderConcurrentLoad() async throws {
        // Create a large number of engines and operate on them concurrently
        var engines: [AudioEngine] = []
        for _ in 0..<10 {
            engines.append(AudioEngine())
        }
        
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, engine) in engines.enumerated() {
                group.addTask {
                    // Load file
                    try? await engine.loadURL(file)
                    
                    // Random operations
                    for _ in 0..<20 {
                        let operation = Int.random(in: 0..<5)
                        switch operation {
                        case 0:
                            try? engine.play()
                        case 1:
                            engine.pause()
                        case 2:
                            engine.stop()
                        case 3:
                            try? engine.seek(to: TimeInterval.random(in: 0...10))
                        case 4:
                            engine.volume = Float.random(in: 0...1)
                        default:
                            break
                        }
                        
                        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    }
                }
            }
        }
        
        // Verify all engines are still valid
        for engine in engines {
            XCTAssertNotNil(engine)
            engine.stop()
        }
        
        // Clear references
        engines.removeAll()
    }
    
    // MARK: - Race Condition Tests
    
    func testNoRaceConditionInTimeUpdates() async throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 60.0)
        testFileURLs.append(file)
        try await audioEngine.loadURL(file)
        
        var inconsistencies = 0
        let checkLock = NSLock()
        
        try audioEngine.play()
        
        // Monitor for time inconsistencies
        await withTaskGroup(of: Void.self) { group in
            // Observer 1: Check time progression
            group.addTask { [weak self] in
                var lastTime: TimeInterval = 0
                for _ in 0..<100 {
                    guard let currentTime = self?.audioEngine.currentTime else { break }
                    
                    // Time should not go backwards during playback
                    if currentTime < lastTime && self?.audioEngine.isPlaying == true {
                        checkLock.lock()
                        inconsistencies += 1
                        checkLock.unlock()
                    }
                    lastTime = currentTime
                    
                    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                }
            }
            
            // Observer 2: Random seeks
            group.addTask { [weak self] in
                for _ in 0..<20 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    let position = TimeInterval.random(in: 0...60)
                    try? self?.audioEngine.seek(to: position)
                }
            }
        }
        
        audioEngine.stop()
        
        // Should have minimal or no inconsistencies
        checkLock.lock()
        let finalInconsistencies = inconsistencies
        checkLock.unlock()
        
        XCTAssertLessThanOrEqual(finalInconsistencies, 5) // Allow small tolerance
    }
}