//
//  WindowManagerTests.swift
//  WinAmpPlayerTests
//
//  Created on 2025-07-02.
//

import XCTest
import SwiftUI
import Combine
@testable import WinAmpPlayer

class WindowManagerTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Window Registration Tests
    
    func testWindowRegistration() {
        let manager = WindowManager.shared
        let window = NSWindow()
        
        manager.registerWindow(window, type: .main)
        
        XCTAssertNotNil(manager.windows[.main])
        XCTAssertEqual(manager.windows[.main]?.type, .main)
        XCTAssertEqual(manager.windows[.main]?.window, window)
    }
    
    func testWindowUnregistration() {
        let manager = WindowManager.shared
        let window = NSWindow()
        
        manager.registerWindow(window, type: .equalizer)
        XCTAssertNotNil(manager.windows[.equalizer])
        
        manager.unregisterWindow(type: .equalizer)
        XCTAssertNil(manager.windows[.equalizer])
    }
    
    // MARK: - Window Operation Tests
    
    func testShowHideWindow() {
        let manager = WindowManager.shared
        let window = NSWindow()
        
        manager.registerWindow(window, type: .playlist)
        
        manager.showWindow(.playlist)
        XCTAssertTrue(manager.windows[.playlist]?.state.isVisible ?? false)
        
        manager.hideWindow(.playlist)
        XCTAssertFalse(manager.windows[.playlist]?.state.isVisible ?? true)
    }
    
    func testToggleWindow() {
        let manager = WindowManager.shared
        let window = NSWindow()
        
        manager.registerWindow(window, type: .library)
        
        // Initially hidden
        XCTAssertFalse(manager.windows[.library]?.state.isVisible ?? true)
        
        manager.toggleWindow(.library)
        XCTAssertTrue(manager.windows[.library]?.state.isVisible ?? false)
        
        manager.toggleWindow(.library)
        XCTAssertFalse(manager.windows[.library]?.state.isVisible ?? true)
    }
    
    // MARK: - Window State Tests
    
    func testShadeModeToggle() {
        let manager = WindowManager.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 116),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        manager.registerWindow(window, type: .main)
        
        manager.setShadeMode(true, for: .main)
        XCTAssertTrue(manager.windows[.main]?.state.isShaded ?? false)
        XCTAssertEqual(window.frame.height, WindowType.main.minSize.height)
        
        manager.setShadeMode(false, for: .main)
        XCTAssertFalse(manager.windows[.main]?.state.isShaded ?? true)
    }
    
    func testAlwaysOnTop() {
        let manager = WindowManager.shared
        let window = NSWindow()
        
        manager.registerWindow(window, type: .equalizer)
        
        manager.setAlwaysOnTop(true, for: .equalizer)
        XCTAssertTrue(manager.windows[.equalizer]?.state.isAlwaysOnTop ?? false)
        XCTAssertEqual(window.level, .floating)
        
        manager.setAlwaysOnTop(false, for: .equalizer)
        XCTAssertFalse(manager.windows[.equalizer]?.state.isAlwaysOnTop ?? true)
        XCTAssertEqual(window.level, .normal)
    }
    
    func testTransparency() {
        let manager = WindowManager.shared
        let window = NSWindow()
        
        manager.registerWindow(window, type: .playlist)
        
        manager.setTransparency(0.5, for: .playlist)
        XCTAssertEqual(manager.windows[.playlist]?.state.transparency, 0.5)
        XCTAssertEqual(window.alphaValue, 0.5)
    }
    
    // MARK: - Window Snapping Tests
    
    func testWindowSnapEvent() {
        let manager = WindowManager.shared
        let expectation = XCTestExpectation(description: "Window snap event")
        
        manager.windowSnapEventPublisher
            .sink { event in
                XCTAssertEqual(event.sourceWindow, .main)
                XCTAssertEqual(event.targetWindow, .equalizer)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // This would normally be triggered by window movement
        // For testing, we'll manually send the event
        manager.windowSnapEventPublisher.send(
            WindowSnapEvent(sourceWindow: .main, targetWindow: .equalizer, edge: .right)
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Layout Management Tests
    
    func testSaveAndRestoreLayout() {
        let manager = WindowManager.shared
        let layoutName = "TestLayout"
        
        // Set up some window states
        let mainWindow = NSWindow()
        manager.registerWindow(mainWindow, type: .main)
        manager.setAlwaysOnTop(true, for: .main)
        manager.setTransparency(0.8, for: .main)
        
        // Save layout
        manager.saveLayout(name: layoutName)
        
        // Modify states
        manager.setAlwaysOnTop(false, for: .main)
        manager.setTransparency(1.0, for: .main)
        
        // Restore layout
        manager.restoreLayout(name: layoutName)
        
        // Verify restored state
        XCTAssertTrue(manager.windows[.main]?.state.isAlwaysOnTop ?? false)
        XCTAssertEqual(manager.windows[.main]?.state.transparency, 0.8)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "WinAmpPlayer.Layout.\(layoutName)")
    }
    
    func testGetSavedLayouts() {
        let manager = WindowManager.shared
        let layouts = ["Layout1", "Layout2", "Layout3"]
        
        // Save multiple layouts
        for layout in layouts {
            manager.saveLayout(name: layout)
        }
        
        let savedLayouts = manager.getSavedLayouts()
        for layout in layouts {
            XCTAssertTrue(savedLayouts.contains(layout))
        }
        
        // Clean up
        for layout in layouts {
            UserDefaults.standard.removeObject(forKey: "WinAmpPlayer.Layout.\(layout)")
        }
    }
}