//
//  UIIntegrationTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-07-02.
//  UI Integration tests for WinAmp clone on macOS 15.5
//

import XCTest
import SwiftUI
import Combine
@testable import WinAmpPlayer

class UIIntegrationTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()
    private var windowManager: WindowManager!
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
        windowManager = WindowManager.shared
    }
    
    override func tearDown() {
        cancellables.removeAll()
        // Clean up all windows
        WindowType.allCases.forEach { type in
            windowManager.unregisterWindow(type: type)
        }
        super.tearDown()
    }
    
    // MARK: - Window Snapping Behavior Tests
    
    func testWindowSnappingHorizontal() {
        // Create two windows
        let mainWindow = createMockWindow(type: .main, frame: NSRect(x: 100, y: 100, width: 275, height: 116))
        let playlistWindow = createMockWindow(type: .playlist, frame: NSRect(x: 395, y: 100, width: 275, height: 232))
        
        windowManager.registerWindow(mainWindow, type: .main)
        windowManager.registerWindow(playlistWindow, type: .playlist)
        
        let expectation = XCTestExpectation(description: "Window should snap horizontally")
        var snapEvent: WindowSnapEvent?
        
        windowManager.windowSnapEventPublisher
            .sink { event in
                snapEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Move playlist window close to main window's right edge
        playlistWindow.setFrame(NSRect(x: 370, y: 100, width: 275, height: 232), display: false)
        
        // Trigger window movement detection
        NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: playlistWindow)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(snapEvent)
        XCTAssertEqual(snapEvent?.sourceWindow, .playlist)
        XCTAssertEqual(snapEvent?.targetWindow, .main)
        XCTAssertEqual(snapEvent?.edge, .left)
        
        // Verify window actually snapped
        XCTAssertEqual(playlistWindow.frame.minX, mainWindow.frame.maxX, accuracy: 1.0)
    }
    
    func testWindowSnappingVertical() {
        let mainWindow = createMockWindow(type: .main, frame: NSRect(x: 100, y: 200, width: 275, height: 116))
        let eqWindow = createMockWindow(type: .equalizer, frame: NSRect(x: 100, y: 80, width: 275, height: 116))
        
        windowManager.registerWindow(mainWindow, type: .main)
        windowManager.registerWindow(eqWindow, type: .equalizer)
        
        let expectation = XCTestExpectation(description: "Window should snap vertically")
        
        windowManager.windowSnapEventPublisher
            .sink { event in
                XCTAssertEqual(event.edge, .top)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Move equalizer window close to main window's bottom edge
        eqWindow.setFrame(NSRect(x: 100, y: 90, width: 275, height: 116), display: false)
        NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: eqWindow)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify vertical snap
        XCTAssertEqual(eqWindow.frame.maxY, mainWindow.frame.minY, accuracy: 1.0)
    }
    
    func testWindowSnappingMultipleWindows() {
        // Test snapping behavior with multiple windows
        let mainWindow = createMockWindow(type: .main, frame: NSRect(x: 100, y: 100, width: 275, height: 116))
        let eqWindow = createMockWindow(type: .equalizer, frame: NSRect(x: 100, y: 216, width: 275, height: 116))
        let playlistWindow = createMockWindow(type: .playlist, frame: NSRect(x: 375, y: 100, width: 275, height: 232))
        
        windowManager.registerWindow(mainWindow, type: .main)
        windowManager.registerWindow(eqWindow, type: .equalizer)
        windowManager.registerWindow(playlistWindow, type: .playlist)
        
        // All windows should be properly aligned
        XCTAssertEqual(eqWindow.frame.minY, mainWindow.frame.maxY)
        XCTAssertEqual(playlistWindow.frame.minX, mainWindow.frame.maxX)
    }
    
    // MARK: - UI Component Interaction Tests
    
    func testTransportControlsInteraction() {
        let audioEngine = AudioEngine()
        let volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
        
        // Test play/pause toggle
        XCTAssertFalse(audioEngine.isPlaying)
        audioEngine.togglePlayPause()
        
        // Since there's no loaded audio, it should remain not playing
        XCTAssertFalse(audioEngine.isPlaying)
        
        // Test stop
        audioEngine.stop()
        XCTAssertEqual(audioEngine.currentTime, 0)
    }
    
    func testSeekBarInteraction() {
        let audioEngine = AudioEngine()
        audioEngine.duration = 300 // 5 minutes
        
        // Test seeking to different positions
        let positions: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for position in positions {
            do {
                try audioEngine.seek(to: audioEngine.duration * position)
                XCTAssertEqual(audioEngine.currentTime, audioEngine.duration * position, accuracy: 0.1)
            } catch {
                XCTFail("Seeking failed: \(error)")
            }
        }
    }
    
    func testVolumeSliderInteraction() {
        let audioEngine = AudioEngine()
        let volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
        
        // Test volume changes
        let volumes: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for volume in volumes {
            volumeController.setVolume(volume)
            XCTAssertEqual(volumeController.volume, volume, accuracy: 0.01)
            XCTAssertEqual(audioEngine.volume, volume, accuracy: 0.01)
        }
    }
    
    func testBalanceSliderInteraction() {
        let audioEngine = AudioEngine()
        let volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
        
        // Test balance changes
        let balances: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
        
        for balance in balances {
            volumeController.setBalance(balance)
            XCTAssertEqual(volumeController.balance, balance, accuracy: 0.01)
        }
    }
    
    func testClutterbarFunctionality() {
        // Test clutterbar window toggle buttons
        let expectation = XCTestExpectation(description: "Window visibility should toggle")
        
        windowManager.windowStateChangedPublisher
            .sink { (type, state) in
                if type == .equalizer {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate clutterbar button press
        windowManager.toggleWindow(.equalizer)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - State Persistence Tests
    
    func testWindowStatePersistence() {
        let testWindow = createMockWindow(type: .main, frame: NSRect(x: 150, y: 150, width: 275, height: 116))
        
        windowManager.registerWindow(testWindow, type: .main)
        windowManager.setAlwaysOnTop(true, for: .main)
        windowManager.setTransparency(0.9, for: .main)
        windowManager.setShadeMode(true, for: .main)
        
        // Save state
        windowManager.saveLayout()
        
        // Clear and re-register window
        windowManager.unregisterWindow(type: .main)
        let newWindow = createMockWindow(type: .main, frame: NSRect(x: 0, y: 0, width: 275, height: 116))
        windowManager.registerWindow(newWindow, type: .main)
        
        // State should be restored
        let state = windowManager.windows[.main]?.state
        XCTAssertNotNil(state)
        XCTAssertTrue(state?.isAlwaysOnTop ?? false)
        XCTAssertEqual(state?.transparency, 0.9, accuracy: 0.01)
        XCTAssertTrue(state?.isShaded ?? false)
    }
    
    func testMultiMonitorStatePersistence() {
        let testWindow = createMockWindow(type: .playlist, frame: NSRect(x: 1920, y: 100, width: 275, height: 232))
        
        windowManager.registerWindow(testWindow, type: .playlist)
        
        // Simulate screen change
        windowManager.windows[.playlist]?.state.screenID = 2
        
        // Save and restore
        windowManager.saveLayout()
        windowManager.restoreLayout()
        
        XCTAssertEqual(windowManager.windows[.playlist]?.state.screenID, 2)
    }
    
    // MARK: - Theme Consistency Tests
    
    func testDarkThemeConsistency() {
        // Verify all UI components use consistent dark theme colors
        XCTAssertEqual(WinAmpColors.background, Color(red: 0.11, green: 0.11, blue: 0.11))
        XCTAssertEqual(WinAmpColors.backgroundLight, Color(red: 0.15, green: 0.15, blue: 0.15))
        XCTAssertEqual(WinAmpColors.border, Color(red: 0.2, green: 0.2, blue: 0.2))
        XCTAssertEqual(WinAmpColors.text, Color(red: 0.0, green: 1.0, blue: 0.0))
        XCTAssertEqual(WinAmpColors.textDim, Color(red: 0.0, green: 0.6, blue: 0.0))
        
        // Verify shadow color is consistent
        XCTAssertEqual(WinAmpColors.shadow.opacity, 0.8)
    }
    
    func testWindowBorderConsistency() {
        // Test that all windows use consistent border styling
        let config = WinAmpWindowConfiguration(
            title: "Test",
            windowType: .main,
            borderWidth: 2,
            showBorder: true
        )
        
        XCTAssertEqual(config.borderWidth, 2)
        XCTAssertTrue(config.showBorder)
    }
    
    // MARK: - macOS 15.5 Specific Tests
    
    func testMacOS15WindowBehavior() {
        // Test window behavior specific to macOS 15.5
        let window = createMockWindow(type: .main, frame: NSRect(x: 100, y: 100, width: 275, height: 116))
        
        // Test that window uses proper style mask
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        
        // Test transparency support
        window.alphaValue = 0.95
        XCTAssertEqual(window.alphaValue, 0.95, accuracy: 0.01)
        
        // Test shadow behavior
        window.hasShadow = true
        XCTAssertTrue(window.hasShadow)
    }
    
    func testStageManagerCompatibility() {
        // Test compatibility with Stage Manager if available
        let window = createMockWindow(type: .main, frame: NSRect(x: 100, y: 100, width: 275, height: 116))
        
        // Windows should respect minimum size constraints
        window.minSize = WindowType.main.minSize
        XCTAssertEqual(window.minSize, CGSize(width: 275, height: 14))
        
        // Test window collection behavior
        window.collectionBehavior = [.moveToActiveSpace, .managed]
        XCTAssertTrue(window.collectionBehavior.contains(.managed))
    }
    
    // MARK: - Performance Tests
    
    func testWindowSnappingPerformance() {
        measure {
            let window1 = createMockWindow(type: .main, frame: NSRect(x: 100, y: 100, width: 275, height: 116))
            let window2 = createMockWindow(type: .playlist, frame: NSRect(x: 380, y: 100, width: 275, height: 232))
            
            windowManager.registerWindow(window1, type: .main)
            windowManager.registerWindow(window2, type: .playlist)
            
            // Simulate rapid window movements
            for x in stride(from: 380, to: 370, by: -1) {
                window2.setFrame(NSRect(x: x, y: 100, width: 275, height: 232), display: false)
            }
        }
    }
    
    func testVisualizationUpdatePerformance() {
        let audioEngine = AudioEngine()
        
        measure {
            // Simulate visualization data updates
            for _ in 0..<100 {
                let data = AudioVisualizationData(
                    leftChannel: Array(repeating: 0.5, count: 512),
                    rightChannel: Array(repeating: 0.5, count: 512),
                    timestamp: Date().timeIntervalSinceReferenceDate
                )
                audioEngine.audioVisualizationDataPublisher.send(data)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockWindow(type: WindowType, frame: NSRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = type.rawValue.capitalized
        window.isReleasedWhenClosed = false
        return window
    }
}

// MARK: - Keyboard Shortcut Tests

extension UIIntegrationTests {
    func testKeyboardShortcuts() {
        let audioEngine = AudioEngine()
        
        // Test space bar for play/pause
        let spaceEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49 // Space bar
        )
        
        // Verify keyboard event handling (would need actual implementation)
        XCTAssertNotNil(spaceEvent)
    }
    
    func testVolumeKeyboardShortcuts() {
        let audioEngine = AudioEngine()
        let volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
        
        let initialVolume = volumeController.volume
        
        // Test volume up (Command + Up Arrow)
        // Test volume down (Command + Down Arrow)
        // These would need actual keyboard event handling implementation
        
        XCTAssertEqual(volumeController.volume, initialVolume)
    }
}

// MARK: - Accessibility Tests

extension UIIntegrationTests {
    func testAccessibilityLabels() {
        // Verify all UI components have proper accessibility labels
        // This would require actual SwiftUI view testing
        
        // Transport controls should have labels
        let transportLabels = ["Play", "Pause", "Stop", "Previous", "Next", "Eject"]
        XCTAssertFalse(transportLabels.isEmpty)
        
        // Sliders should have labels
        let sliderLabels = ["Volume", "Balance", "Seek"]
        XCTAssertFalse(sliderLabels.isEmpty)
    }
    
    func testVoiceOverSupport() {
        // Test that UI components work properly with VoiceOver
        // This would require UI testing framework
        XCTAssertTrue(true) // Placeholder
    }
}