//
//  Suite06_EdgeCasesTests.swift
//  WinAmpPlayerTests
//
//  SUITE-06: Edge Cases & Error Handling Tests
//  Priority: High
//

import XCTest
import AVFoundation
@testable import WinAmpPlayer

/// SUITE-06: Edge Cases & Error Handling Tests
/// High priority tests for edge cases and error scenarios
class Suite06_EdgeCasesTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    var skinManager: SkinManager!
    var pluginManager: PluginManager!
    var fixturesURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize components
        audioEngine = AudioEngine()
        skinManager = SkinManager.shared
        pluginManager = PluginManager.shared
        
        // Reset state
        skinManager.reset()
        pluginManager.reset()
        
        // Set up fixtures path
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        fixturesURL = testDir.appendingPathComponent("Fixtures")
        
        // Generate fixtures if needed
        let audioFixtureURL = fixturesURL.appendingPathComponent("Audio/44k_stereo.wav")
        if !FileManager.default.fileExists(atPath: audioFixtureURL.path) {
            try TestFixtureGenerator.generateAllFixtures()
        }
        
        // Enable test mode
        audioEngine.enableTestMode()
    }
    
    override func tearDownWithError() throws {
        audioEngine.stop()
        audioEngine = nil
        skinManager = nil
        pluginManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - TEST-E1: Simultaneous Skin Change & Playback
    
    func testE1_SimultaneousSkinChangeAndPlayback() throws {
        // Arrange
        let audioURL = fixturesURL.appendingPathComponent("Audio/44k_stereo.wav")
        let skinURL = fixturesURL.appendingPathComponent("Skins/classic.wsz")
        
        // Start playback
        try audioEngine.loadURL(audioURL)
        audioEngine.play()
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertEqual(audioEngine.playbackState, .playing)
        let playbackTimeBefore = audioEngine.currentTime
        
        // Prepare multiple skins
        let skin1 = try skinManager.installSkin(from: skinURL)
        let defaultSkin = skinManager.currentSkin
        
        // Act - Rapid skin changes during playback
        let skinChangeQueue = DispatchQueue(label: "skin-change", attributes: .concurrent)
        let group = DispatchGroup()
        
        var lastAppliedSkin: Skin?
        var exceptions: [Error] = []
        let exceptionsLock = NSLock()
        
        // Perform 3 rapid skin changes
        for i in 0..<3 {
            group.enter()
            skinChangeQueue.async {
                do {
                    let skinToApply = (i % 2 == 0) ? skin1 : defaultSkin
                    try self.skinManager.applySkin(skinToApply)
                    lastAppliedSkin = skinToApply
                } catch {
                    exceptionsLock.lock()
                    exceptions.append(error)
                    exceptionsLock.unlock()
                }
                group.leave()
            }
        }
        
        // Wait for all skin changes
        group.wait()
        Thread.sleep(forTimeInterval: 0.2)
        
        // Assert
        XCTAssertTrue(exceptions.isEmpty, "No exceptions should occur during skin changes")
        XCTAssertNotNil(lastAppliedSkin, "A skin should be applied")
        XCTAssertEqual(skinManager.currentSkin.id, lastAppliedSkin?.id, "Final skin should match last request")
        
        // Verify playback uninterrupted
        XCTAssertEqual(audioEngine.playbackState, .playing, "Playback should continue")
        let playbackTimeAfter = audioEngine.currentTime
        XCTAssertGreaterThan(playbackTimeAfter, playbackTimeBefore, "Playback should have progressed")
    }
    
    // MARK: - TEST-E2: Audio Device Hot-Swap
    
    func testE2_AudioDeviceHotSwap() async throws {
        // Arrange
        let audioURL = fixturesURL.appendingPathComponent("Audio/44k_stereo.wav")
        try audioEngine.loadURL(audioURL)
        audioEngine.play()
        
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        let resumeExpectation = XCTestExpectation(description: "Audio resumes after device change")
        var didResume = false
        
        // Monitor for resume
        let observer = NotificationCenter.default.addObserver(
            forName: .audioPlaybackStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let state = notification.userInfo?["state"] as? AudioEngine.PlaybackState,
               state == .playing,
               didResume == false {
                didResume = true
                resumeExpectation.fulfill()
            }
        }
        
        // Act - Simulate audio route change
        NotificationCenter.default.post(
            name: .audioRouteChanged,
            object: nil,
            userInfo: [
                "reason": "newDeviceAvailable"
            ]
        )
        
        // Wait for auto-resume
        wait(for: [resumeExpectation], timeout: 1.0)
        
        // Assert
        XCTAssertTrue(didResume, "Audio should resume after device change")
        XCTAssertEqual(audioEngine.playbackState, .playing)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - TEST-E3: Maximum DSP Chain Length
    
    func testE3_MaximumDSPChainLength() throws {
        // Arrange
        let baseDSP = TestDSPPlugin(name: "Test DSP", type: .dsp)
        pluginManager.registerPlugin(baseDSP)
        
        // Measure baseline performance
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        let baselineStart = Date()
        pluginManager.processDSPChain(buffer)
        let baselineTime = Date().timeIntervalSince(baselineStart)
        
        // Act - Add 20 instances of the same DSP
        for i in 0..<20 {
            let dsp = TestDSPPlugin(name: "DSP \(i)", type: .dsp)
            pluginManager.registerPlugin(dsp)
            try await pluginManager.addDSP(dsp)
        }
        
        // Verify chain length
        XCTAssertEqual(pluginManager.activeDSPChainCount, 20)
        
        // Process with full chain
        let fullChainStart = Date()
        pluginManager.processDSPChain(buffer)
        let fullChainTime = Date().timeIntervalSince(fullChainStart)
        
        // Assert
        // Performance should degrade less than 2x baseline
        let performanceRatio = fullChainTime / max(baselineTime, 0.0001)
        XCTAssertLessThan(performanceRatio, 2.0, "Performance should not degrade more than 2x")
        
        // Verify no stack overflow by processing multiple times
        for _ in 0..<10 {
            pluginManager.processDSPChain(buffer)
        }
        
        // Should reach here without crashing
        XCTAssertTrue(true, "No stack overflow occurred")
    }
    
    // MARK: - TEST-E4: Window Close While Visualization Rendering
    
    func testE4_WindowCloseWhileVisualizationRendering() async throws {
        // Arrange
        let visualizations = pluginManager.visualizationPlugins
        guard let visualization = visualizations.first else {
            XCTFail("No visualization plugins available")
            return
        }
        
        // Activate visualization
        try await pluginManager.activateVisualization(visualization)
        
        // Start rendering
        var isRendering = true
        let renderQueue = DispatchQueue(label: "viz-render")
        
        // Capture last frame
        var lastFrame: CGImage?
        
        renderQueue.async {
            while isRendering {
                let mockData = AudioVisualizationData(
                    leftChannel: Array(repeating: Float.random(in: 0...1), count: 512),
                    rightChannel: Array(repeating: Float.random(in: 0...1), count: 512),
                    fftData: Array(repeating: Float.random(in: 0...1), count: 256)
                )
                
                self.pluginManager.processVisualizationData(mockData)
                
                // Capture frame
                if let frame = self.pluginManager.currentVisualizationFrame {
                    lastFrame = frame
                }
                
                Thread.sleep(forTimeInterval: 0.016) // ~60 FPS
            }
        }
        
        // Let it render for a bit
        Thread.sleep(forTimeInterval: 0.1)
        
        // Act - Simulate window close
        NotificationCenter.default.post(
            name: NSWindow.willCloseNotification,
            object: nil
        )
        
        // Stop rendering
        isRendering = false
        
        // Give time for cleanup
        Thread.sleep(forTimeInterval: 0.1)
        
        // Assert
        // App should remain running (no crash)
        XCTAssertNotNil(pluginManager, "Plugin manager should still exist")
        
        // Simulate window reopen
        NotificationCenter.default.post(
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        // Should retain last visualization frame
        XCTAssertNotNil(lastFrame, "Should have captured at least one frame")
        
        // Can reactivate visualization
        do {
            try await pluginManager.activateVisualization(visualization)
        } catch {
            XCTFail("Should be able to reactivate visualization: \(error)")
        }
    }
}

// MARK: - Test Helpers

extension PluginManager {
    /// Get current visualization frame for testing
    var currentVisualizationFrame: CGImage? {
        // This would be implemented in the actual plugin manager
        // to capture the current rendered frame
        return nil
    }
}

// AudioVisualizationData is defined in AudioEngine.swift