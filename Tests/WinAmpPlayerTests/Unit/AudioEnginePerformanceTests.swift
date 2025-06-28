//
//  AudioEnginePerformanceTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-06-28.
//  Performance tests for AudioEngine operations.
//

import XCTest
@testable import WinAmpPlayer

final class AudioEnginePerformanceTests: XCTestCase {
    var audioEngine: AudioEngine!
    var testFileURLs: [URL] = []
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
    }
    
    override func tearDown() {
        audioEngine = nil
        AudioTestFixtures.cleanup(testFileURLs)
        testFileURLs.removeAll()
        super.tearDown()
    }
    
    // MARK: - Load Performance Tests
    
    func testSmallFileLoadPerformance() throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 10.0)
        testFileURLs.append(file)
        
        measure {
            let expectation = self.expectation(description: "Load complete")
            
            Task {
                try await audioEngine.loadURL(file)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testLargeFileLoadPerformance() throws {
        let file = try AudioTestFixtures.createLargeAudioFile(duration: 600.0) // 10 minutes
        testFileURLs.append(file)
        
        measure {
            let expectation = self.expectation(description: "Load complete")
            
            Task {
                try await audioEngine.loadURL(file)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testMultipleFileLoadPerformance() throws {
        let files = try AudioTestFixtures.createBatchTestFiles(count: 10)
        testFileURLs.append(contentsOf: files)
        
        measure {
            let expectation = self.expectation(description: "All loads complete")
            
            Task {
                for file in files {
                    try await audioEngine.loadURL(file)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Seek Performance Tests
    
    func testSequentialSeekPerformance() throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 300.0)
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        measure {
            // Perform 100 sequential seeks
            for i in 0..<100 {
                let position = Double(i) * 3.0 // Every 3 seconds
                try? audioEngine.seek(to: position)
            }
        }
    }
    
    func testRandomSeekPerformance() throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 300.0)
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        // Generate random positions
        let positions = (0..<100).map { _ in TimeInterval.random(in: 0...300) }
        
        measure {
            for position in positions {
                try? audioEngine.seek(to: position)
            }
        }
    }
    
    func testSeekAccuracyPerformance() throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 300.0)
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        var totalError: TimeInterval = 0
        let seekCount = 50
        
        measure {
            totalError = 0
            
            for _ in 0..<seekCount {
                let targetPosition = TimeInterval.random(in: 0...300)
                try? audioEngine.seek(to: targetPosition)
                
                let actualPosition = audioEngine.currentTime
                let error = abs(targetPosition - actualPosition)
                totalError += error
            }
            
            let averageError = totalError / Double(seekCount)
            XCTAssertLessThan(averageError, 0.1) // Average error should be less than 100ms
        }
    }
    
    // MARK: - Playback Performance Tests
    
    func testPlaybackStartLatency() throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        measure {
            try? audioEngine.play()
            audioEngine.stop()
        }
    }
    
    func testPlayPauseTogglePerformance() throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        measure {
            for _ in 0..<100 {
                audioEngine.togglePlayPause()
            }
        }
    }
    
    // MARK: - State Update Performance Tests
    
    func testTimeUpdateFrequency() throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 10.0)
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        var updateCount = 0
        let startTime = Date()
        
        let cancellable = audioEngine.$currentTime
            .sink { _ in
                updateCount += 1
            }
        
        try audioEngine.play()
        
        // Play for 2 seconds
        Thread.sleep(forTimeInterval: 2.0)
        
        audioEngine.stop()
        cancellable.cancel()
        
        let elapsed = Date().timeIntervalSince(startTime)
        let updatesPerSecond = Double(updateCount) / elapsed
        
        // Should update approximately 20 times per second (based on updateInterval)
        XCTAssertGreaterThan(updatesPerSecond, 15)
        XCTAssertLessThan(updatesPerSecond, 25)
    }
    
    // MARK: - Volume Performance Tests
    
    func testVolumeChangePerformance() throws {
        let file = try AudioTestFixtures.createTestAudioFile()
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        let volumes = (0..<1000).map { _ in Float.random(in: 0...1) }
        
        measure {
            for volume in volumes {
                audioEngine.volume = volume
            }
        }
    }
    
    // MARK: - Format Support Performance Tests
    
    func testDifferentFormatLoadPerformance() throws {
        let formats = try AudioTestFixtures.createMultiFormatTestFiles()
        testFileURLs.append(contentsOf: formats.values)
        
        measure {
            let expectation = self.expectation(description: "All formats loaded")
            
            Task {
                for (format, url) in formats {
                    do {
                        try await audioEngine.loadURL(url)
                        print("Loaded \(format) format successfully")
                    } catch {
                        XCTFail("Failed to load \(format) format: \(error)")
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringLongPlayback() throws {
        let file = try AudioTestFixtures.createTestAudioFile(duration: 60.0)
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5.0)
        
        // Measure memory during playback
        let metrics: [XCTMetric] = [XCTMemoryMetric()]
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 1
        
        measure(metrics: metrics, options: measureOptions) {
            try? audioEngine.play()
            
            // Play for 5 seconds
            Thread.sleep(forTimeInterval: 5.0)
            
            audioEngine.stop()
        }
    }
    
    func testMemoryUsageWithMultipleLoads() throws {
        let files = try AudioTestFixtures.createBatchTestFiles(count: 20)
        testFileURLs.append(contentsOf: files)
        
        let metrics: [XCTMetric] = [XCTMemoryMetric()]
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 1
        
        measure(metrics: metrics, options: measureOptions) {
            let expectation = self.expectation(description: "All loads complete")
            
            Task {
                for file in files {
                    try await audioEngine.loadURL(file)
                    try? audioEngine.play()
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    audioEngine.stop()
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
    }
    
    // MARK: - Stress Tests
    
    func testExtendedPlaybackStress() throws {
        let file = try AudioTestFixtures.createLargeAudioFile(duration: 300.0) // 5 minutes
        testFileURLs.append(file)
        
        let loadExpectation = expectation(description: "Load complete")
        Task {
            try await audioEngine.loadURL(file)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 10.0)
        
        measure {
            try? audioEngine.play()
            
            // Simulate user interactions during playback
            for _ in 0..<50 {
                Thread.sleep(forTimeInterval: 0.1)
                
                let action = Int.random(in: 0..<4)
                switch action {
                case 0:
                    audioEngine.pause()
                    try? audioEngine.play()
                case 1:
                    let position = TimeInterval.random(in: 0...300)
                    try? audioEngine.seek(to: position)
                case 2:
                    audioEngine.volume = Float.random(in: 0...1)
                case 3:
                    audioEngine.skipForward(by: 10)
                default:
                    break
                }
            }
            
            audioEngine.stop()
        }
    }
}