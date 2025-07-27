//
//  Suite03_SkinSystemTests.swift
//  WinAmpPlayerTests
//
//  SUITE-03: Skin System Tests
//  Priority: High
//

import XCTest
import AppKit
@testable import WinAmpPlayer

/// SUITE-03: Skin System Tests
/// High priority tests for skin functionality
class Suite03_SkinSystemTests: XCTestCase {
    
    var skinManager: SkinManager!
    var fixturesURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize skin manager
        skinManager = SkinManager.shared
        
        // Reset to default state
        skinManager.reset()
        
        // Set up fixtures path
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        fixturesURL = testDir.appendingPathComponent("Fixtures/Skins")
        
        // Generate fixtures if needed
        if !FileManager.default.fileExists(atPath: fixturesURL.appendingPathComponent("classic.wsz").path) {
            try TestFixtureGenerator.generateAllFixtures()
        }
    }
    
    override func tearDownWithError() throws {
        skinManager.reset()
        skinManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - TEST-S1: Default Skin Loads on First Launch
    
    func testS1_DefaultSkinLoadsOnFirstLaunch() throws {
        // Act - Skin manager should load default skin on init
        let currentSkin = skinManager.currentSkin
        
        // Assert
        XCTAssertNotNil(currentSkin, "Current skin should not be nil")
        XCTAssertTrue(currentSkin.isDefault, "Should be using default skin")
        XCTAssertEqual(currentSkin.name, "Default", "Default skin should be named 'Default'")
        
        // Verify sprites are available
        let mainBackground = skinManager.getSprite(for: .mainBackground)
        XCTAssertNotNil(mainBackground, "Main background sprite should be available")
        
        let playButton = skinManager.getSprite(for: .playButton)
        XCTAssertNotNil(playButton, "Play button sprite should be available")
    }
    
    // MARK: - TEST-S2: Apply External Skin
    
    func testS2_ApplyExternalSkin() throws {
        // Arrange
        let classicSkinURL = fixturesURL.appendingPathComponent("classic.wsz")
        
        let skinChangeExpectation = XCTestExpectation(description: "Skin change notification")
        var notificationReceived = false
        var newSkinName: String?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .skinDidChange,
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            newSkinName = notification.userInfo?["skinName"] as? String
            skinChangeExpectation.fulfill()
        }
        
        // Act
        let installedSkin = try skinManager.installSkin(from: classicSkinURL)
        try skinManager.applySkin(installedSkin)
        
        // Wait for notification
        wait(for: [skinChangeExpectation], timeout: 2.0)
        
        // Assert
        XCTAssertTrue(notificationReceived, "Should receive skin change notification")
        XCTAssertEqual(skinManager.currentSkin.id, installedSkin.id)
        XCTAssertEqual(skinManager.currentSkin.name, "Classic Test Skin")
        XCTAssertEqual(newSkinName, "Classic Test Skin")
        XCTAssertFalse(skinManager.currentSkin.isDefault)
        
        // Verify sprite update
        let mainBackground = skinManager.getSprite(for: .mainBackground)
        XCTAssertNotNil(mainBackground, "Should have main background sprite from new skin")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - TEST-S3: Skin Fade Animation
    
    func testS3_SkinFadeAnimation() throws {
        // This test would measure the fade animation duration
        // In a real implementation, we'd need to hook into the view layer
        
        // Arrange
        let classicSkinURL = fixturesURL.appendingPathComponent("classic.wsz")
        let skin = try skinManager.installSkin(from: classicSkinURL)
        
        let animationStart = Date()
        var animationDuration: TimeInterval = 0
        
        let animationExpectation = XCTestExpectation(description: "Animation completed")
        
        // Monitor animation completion via notification
        let observer = NotificationCenter.default.addObserver(
            forName: .skinAnimationCompleted,
            object: nil,
            queue: .main
        ) { _ in
            animationDuration = Date().timeIntervalSince(animationStart)
            animationExpectation.fulfill()
        }
        
        // Act
        try skinManager.applySkin(skin, animated: true)
        
        // Wait for animation
        wait(for: [animationExpectation], timeout: 1.0)
        
        // Assert
        XCTAssertEqual(animationDuration, 0.3, accuracy: 0.05, "Animation should take ~0.3s ±50ms")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - TEST-S4: Invalid Skin Handling
    
    func testS4_InvalidSkinHandling() throws {
        // Arrange
        let corruptSkinURL = fixturesURL.appendingPathComponent("corrupt.wsz")
        
        let errorExpectation = XCTestExpectation(description: "Error notification")
        var errorReceived = false
        var errorInfo: Error?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .skinLoadingFailed,
            object: nil,
            queue: .main
        ) { notification in
            errorReceived = true
            errorInfo = notification.userInfo?["error"] as? Error
            errorExpectation.fulfill()
        }
        
        // Act & Assert
        XCTAssertThrowsError(try skinManager.installSkin(from: corruptSkinURL)) { error in
            // Verify error type
            if let skinError = error as? SkinManager.SkinError {
                XCTAssertEqual(skinError, .invalidSkinFile)
            }
        }
        
        // Wait for error notification
        wait(for: [errorExpectation], timeout: 1.0)
        
        // Assert notification
        XCTAssertTrue(errorReceived, "Should receive error notification")
        XCTAssertNotNil(errorInfo, "Error should be included in notification")
        
        // Verify skin manager state is unchanged
        XCTAssertTrue(skinManager.currentSkin.isDefault, "Should still be using default skin")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - TEST-S5: Skin Pack Install Multiple
    
    func testS5_SkinPackInstallMultiple() throws {
        // Arrange
        let skinPackURL = fixturesURL.appendingPathComponent("generated.zip")
        let initialCount = skinManager.availableSkins.count
        
        // Act
        let installedSkins = try skinManager.installSkinPack(from: skinPackURL)
        
        // Assert
        XCTAssertEqual(installedSkins.count, 3, "Should install 3 skins from pack")
        XCTAssertEqual(skinManager.availableSkins.count, initialCount + 3, "Available skins should increase by 3")
        
        // Verify each skin
        for (index, skin) in installedSkins.enumerated() {
            XCTAssertEqual(skin.name, "Generated Skin \(index + 1)")
            XCTAssertTrue(skinManager.availableSkins.contains { $0.id == skin.id })
        }
    }
    
    // MARK: - TEST-S6: Delete Current Skin Reverts to Default
    
    func testS6_DeleteCurrentSkinRevertsToDefault() throws {
        // Arrange
        let classicSkinURL = fixturesURL.appendingPathComponent("classic.wsz")
        let customSkin = try skinManager.installSkin(from: classicSkinURL)
        try skinManager.applySkin(customSkin)
        
        // Verify we're using custom skin
        XCTAssertEqual(skinManager.currentSkin.id, customSkin.id)
        XCTAssertFalse(skinManager.currentSkin.isDefault)
        
        // Act
        try skinManager.deleteSkin(customSkin)
        
        // Assert
        XCTAssertTrue(skinManager.currentSkin.isDefault, "Should revert to default skin")
        XCTAssertEqual(skinManager.currentSkin.name, "Default")
        XCTAssertFalse(skinManager.availableSkins.contains { $0.id == customSkin.id },
                      "Deleted skin should not be in available skins")
        
        // Verify sprites fallback to default
        let mainBackground = skinManager.getSprite(for: .mainBackground)
        XCTAssertNotNil(mainBackground, "Should have default main background sprite")
    }
}

// MARK: - SkinManager Test Extensions

extension SkinManager {
    /// Reset to initial state for testing
    func reset() {
        // Clear all custom skins
        availableSkins.removeAll { !$0.isDefault }
        
        // Reset to default skin
        if let defaultSkin = availableSkins.first(where: { $0.isDefault }) {
            try? applySkin(defaultSkin, animated: false)
        }
    }
    
    // Animation completion callback would be handled via notification or delegate
    
    /// Skin loading error type
    enum SkinError: Error, Equatable {
        case invalidSkinFile
        case missingRequiredFiles
        case unsupportedVersion
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let skinDidChange = Notification.Name("skinDidChange")
    static let skinLoadingFailed = Notification.Name("skinLoadingFailed")
    static let skinAnimationCompleted = Notification.Name("skinAnimationCompleted")
}

// MARK: - Sprite Types

extension SkinManager {
    enum SpriteType {
        case mainBackground
        case playButton
        case pauseButton
        case stopButton
        case nextButton
        case prevButton
        case ejectButton
        case volumeSlider
        case balanceSlider
        case seekBar
    }
}