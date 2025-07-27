//
//  TestHarness.swift
//  TestsSupport
//
//  Test harness utilities for WinAmp Player testing
//

import Foundation
import XCTest
@testable import WinAmpPlayer

// MARK: - App Launcher

public struct AppLauncher {
    /// Launch the app for UI testing with specified arguments
    public static func launchForUITest(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-UITestMode"]
        app.launch()
        return app
    }
}

// MARK: - Audio Test Harness

public struct AudioTestHarness {
    /// Inject a test audio file into the audio engine
    public static func inject(fileURL: URL) throws -> Track {
        let track = Track(
            title: fileURL.deletingPathExtension().lastPathComponent,
            artist: "Test Artist",
            album: "Test Album",
            genre: "Test",
            year: 2025,
            duration: 180.0,
            fileURL: fileURL,
            trackNumber: 1,
            albumArtwork: nil
        )
        return track
    }
}

// MARK: - Skin Test Harness

public struct SkinTestHarness {
    /// Install a test skin
    public static func installSkin(_ skinURL: URL) throws {
        let skinManager = SkinManager.shared
        _ = try skinManager.installSkin(from: skinURL)
    }
}

// MARK: - Plugin Test Harness

public struct PluginTestHarness {
    /// Install a test plugin
    public static func installPlugin(_ pluginURL: URL) throws {
        let pluginManager = PluginManager.shared
        _ = try pluginManager.loadPlugin(from: pluginURL)
    }
}

// MARK: - Test Launch Arguments

public struct TestLaunchArguments {
    public static let uiTestMode = "-UITestMode"
    public static let unitTestMode = "-UnitTestMode"
    public static let disableNetwork = "-DisableNetwork"
    public static let disableAnimations = "-DisableAnimations"
    public static let testSkinPath = "-TestSkinPath"
    public static let testAudioPath = "-TestAudioPath"
}

// MARK: - Performance Measurement

public struct PerformanceMeasurement {
    private let metrics: [XCTMetric]
    private let options: XCTMeasureOptions
    
    public init(metrics: [XCTMetric] = [XCTClockMetric()]) {
        self.metrics = metrics
        self.options = XCTMeasureOptions()
        options.iterationCount = 5
    }
    
    public func measure(_ block: () throws -> Void) rethrows {
        let testCase = XCTestCase()
        testCase.measure(metrics: metrics, options: options) {
            try? block()
        }
    }
}

// MARK: - Test File Creators

public struct TestFileCreators {
    /// Create a corrupt audio file for testing
    public static func createCorruptAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("corrupt.mp3")
        
        // Write some garbage data that looks like MP3 header but isn't valid
        var data = Data()
        data.append(contentsOf: [0xFF, 0xFB]) // MP3 sync word
        data.append(contentsOf: Array(repeating: 0x00, count: 100)) // Invalid data
        
        try? data.write(to: fileURL)
        return fileURL
    }
    
    /// Create an invalid format file
    public static func createInvalidFormatFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid.txt")
        
        let content = "This is not an audio file"
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
}

// MARK: - Expectation Helpers

public extension XCTestCase {
    /// Wait for a condition to be true
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool,
        description: String = "Condition"
    ) {
        let expectation = self.expectation(description: "\(description) to be true")
        
        DispatchQueue.global().async {
            while !condition() {
                Thread.sleep(forTimeInterval: 0.1)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    /// Wait for a notification
    func waitForNotification(
        _ name: Notification.Name,
        timeout: TimeInterval = 5.0,
        handler: ((Notification) -> Void)? = nil
    ) {
        let expectation = self.expectation(forNotification: name, object: nil) { notification in
            handler?(notification)
            return true
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Mock Objects

public class MockAudioEngine: AudioEngine {
    public var playCallCount = 0
    public var pauseCallCount = 0
    public var stopCallCount = 0
    public var seekCallCount = 0
    
    public override func play() {
        playCallCount += 1
        super.play()
    }
    
    public override func pause() {
        pauseCallCount += 1
        super.pause()
    }
    
    public override func stop() {
        stopCallCount += 1
        super.stop()
    }
    
    public override func seek(to time: TimeInterval) {
        seekCallCount += 1
        super.seek(to: time)
    }
}

// MARK: - Test Data Generators

public struct TestDataGenerator {
    /// Generate random audio visualization data
    public static func generateVisualizationData(
        fftSize: Int = 512,
        leftAmplitude: Float = 0.5,
        rightAmplitude: Float = 0.5
    ) -> AudioVisualizationData {
        let leftChannel = (0..<fftSize).map { _ in Float.random(in: 0...leftAmplitude) }
        let rightChannel = (0..<fftSize).map { _ in Float.random(in: 0...rightAmplitude) }
        
        return AudioVisualizationData(
            leftChannel: leftChannel,
            rightChannel: rightChannel,
            fftSize: fftSize,
            sampleRate: 44100,
            timestamp: Date()
        )
    }
    
    /// Generate test plugin metadata
    public static func generatePluginMetadata(
        type: PluginType,
        name: String? = nil
    ) -> PluginMetadata {
        let pluginName = name ?? "Test \(type.rawValue) Plugin"
        return PluginMetadata(
            identifier: "com.test.\(type.rawValue.lowercased())",
            name: pluginName,
            type: type,
            version: "1.0.0",
            author: "Test Author",
            description: "Test \(type.rawValue) plugin for testing"
        )
    }
}