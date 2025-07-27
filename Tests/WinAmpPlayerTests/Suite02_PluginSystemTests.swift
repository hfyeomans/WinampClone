//
//  Suite02_PluginSystemTests.swift
//  WinAmpPlayerTests
//
//  SUITE-02: Plugin System Tests
//  Priority: High
//

import XCTest
import AVFoundation
@testable import WinAmpPlayer

/// SUITE-02: Plugin System Tests
/// High priority tests for plugin functionality
class Suite02_PluginSystemTests: XCTestCase {
    
    var pluginManager: PluginManager!
    var fixturesURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize plugin manager
        pluginManager = PluginManager.shared
        
        // Reset plugin manager state
        pluginManager.reset()
        
        // Set up fixtures path
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        fixturesURL = testDir.appendingPathComponent("Fixtures/Plugins")
        
        // Generate fixtures if needed
        if !FileManager.default.fileExists(atPath: fixturesURL.appendingPathComponent("dummyViz.waplugin").path) {
            try TestFixtureGenerator.generateAllFixtures()
        }
    }
    
    override func tearDownWithError() throws {
        pluginManager.reset()
        pluginManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - TEST-P1: Built-in Visualization Enumeration
    
    func testP1_BuiltInVisualizationEnumeration() throws {
        // Act
        let visualizations = pluginManager.visualizationPlugins
        
        // Assert
        XCTAssertFalse(visualizations.isEmpty, "Should have built-in visualizations")
        
        // Check for expected built-in visualizations
        let visualizationNames = visualizations.map { $0.metadata.name }
        XCTAssertTrue(visualizationNames.contains("Spectrum Analyzer"), "Should contain Spectrum visualization")
        XCTAssertTrue(visualizationNames.contains("Oscilloscope"), "Should contain Oscilloscope visualization")
        XCTAssertTrue(visualizationNames.contains("Matrix Rain"), "Should contain Matrix visualization")
        
        // Verify all are visualization type
        for viz in visualizations {
            XCTAssertEqual(viz.metadata.type, .visualization)
        }
    }
    
    // MARK: - TEST-P2: Activate Visualization
    
    func testP2_ActivateVisualization() async throws {
        // Arrange
        let visualizations = pluginManager.visualizationPlugins
        guard let spectrum = visualizations.first(where: { $0.metadata.name == "Spectrum Analyzer" }) else {
            XCTFail("Spectrum visualization not found")
            return
        }
        
        var renderCallCount = 0
        let expectation = XCTestExpectation(description: "Visualization renders frames")
        expectation.expectedFulfillmentCount = 5
        
        // Create mock visualization data
        let mockData = AudioVisualizationData(
            leftChannel: Array(repeating: 0.5, count: 512),
            rightChannel: Array(repeating: 0.5, count: 512),
            leftPeak: 0.5,
            rightPeak: 0.5,
            sampleRate: 44100,
            timestamp: Date().timeIntervalSince1970
        )
        
        // Set up render callback monitoring
        if let vizPlugin = spectrum as? TestVisualizationPlugin {
            vizPlugin.onRender = { _ in
                renderCallCount += 1
                expectation.fulfill()
            }
        }
        
        // Act
        try await pluginManager.activateVisualization(spectrum)
        
        // Feed fake visualization data for 5 frames
        for _ in 0..<5 {
            pluginManager.processVisualizationData(mockData)
            try await Task.sleep(nanoseconds: 20_000_000) // ~50 FPS
        }
        
        // Wait for renders
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert
        XCTAssertEqual(pluginManager.activeVisualization?.metadata.identifier, spectrum.metadata.identifier)
        XCTAssertEqual(renderCallCount, 5, "Should have rendered 5 frames")
    }
    
    // MARK: - TEST-P3: Switch Visualization
    
    func testP3_SwitchVisualization() async throws {
        // Arrange
        let visualizations = pluginManager.visualizationPlugins
        guard let spectrum = visualizations.first(where: { $0.metadata.name == "Spectrum Analyzer" }),
              let oscilloscope = visualizations.first(where: { $0.metadata.name == "Oscilloscope" }) else {
            XCTFail("Required visualizations not found")
            return
        }
        
        var spectrumDeactivated = false
        var oscilloscopeActivated = false
        
        // Monitor lifecycle calls
        if let spectrumViz = spectrum as? TestVisualizationPlugin {
            spectrumViz.onDeactivate = {
                spectrumDeactivated = true
            }
        }
        
        if let oscilloscopeViz = oscilloscope as? TestVisualizationPlugin {
            oscilloscopeViz.onActivate = {
                oscilloscopeActivated = true
            }
        }
        
        // Act
        try await pluginManager.activateVisualization(spectrum)
        XCTAssertEqual(pluginManager.activeVisualization?.metadata.identifier, spectrum.metadata.identifier)
        
        // Switch to oscilloscope
        try await pluginManager.activateVisualization(oscilloscope)
        
        // Assert
        XCTAssertTrue(spectrumDeactivated, "Spectrum should be deactivated")
        XCTAssertTrue(oscilloscopeActivated, "Oscilloscope should be activated")
        XCTAssertEqual(pluginManager.activeVisualization?.metadata.identifier, oscilloscope.metadata.identifier)
    }
    
    // MARK: - TEST-P4: DSP Chain Add/Remove
    
    func testP4_DSPChainAddRemove() async throws {
        // Arrange
        let reverb = TestDSPPlugin(name: "Reverb")
        let equalizer = TestDSPPlugin(name: "Equalizer")
        pluginManager.registerPlugin(reverb)
        pluginManager.registerPlugin(equalizer)
        
        // Create test audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Act 1: Add DSP effects
        try await pluginManager.addDSP(reverb)
        XCTAssertEqual(pluginManager.activeDSPChain.count, 1)
        
        try await pluginManager.addDSP(equalizer)
        XCTAssertEqual(pluginManager.activeDSPChain.count, 2)
        
        // Act 2: Process buffer
        var processOrder: [String] = []
        
        reverb.onProcess = { _ in
            processOrder.append("Reverb")
        }
        
        equalizer.onProcess = { _ in
            processOrder.append("Equalizer")
        }
        
        pluginManager.processDSPChain(buffer)
        
        // Assert process order
        XCTAssertEqual(processOrder, ["Reverb", "Equalizer"], "DSP effects should process in order")
        
        // Act 3: Remove DSP
        pluginManager.removeDSP(reverb)
        XCTAssertEqual(pluginManager.activeDSPChain.count, 1)
        XCTAssertFalse(pluginManager.activeDSPChain.contains { $0.metadata.identifier == reverb.metadata.identifier })
    }
    
    // MARK: - TEST-P5: General Plugin Lifecycle
    
    func testP5_GeneralPluginLifecycle() async throws {
        // Arrange
        let generalPlugin = TestGeneralPlugin(name: "Test General")
        generalPlugin.menuItems = ["Hello", "World"]
        
        var initialized = false
        var activated = false
        var eventReceived = false
        
        generalPlugin.onInitialize = { _ in
            initialized = true
        }
        
        generalPlugin.onActivate = {
            activated = true
        }
        
        generalPlugin.onPlayerEvent = { event in
            if event == .trackStarted {
                eventReceived = true
            }
        }
        
        // Act 1: Load plugin
        pluginManager.registerPlugin(generalPlugin)
        
        // Act 2: Activate plugin
        try await pluginManager.activateGeneralPlugin(generalPlugin)
        
        // Assert initialization and activation
        XCTAssertTrue(initialized, "Plugin should be initialized")
        XCTAssertTrue(activated, "Plugin should be activated")
        
        // Act 3: Send player event
        pluginManager.sendPlayerEvent(.trackStarted)
        
        // Assert event handling
        XCTAssertTrue(eventReceived, "Plugin should receive player event")
        
        // Verify menu items are exposed
        let menuItems = pluginManager.getMenuItems(for: generalPlugin)
        XCTAssertEqual(menuItems, ["Hello", "World"])
    }
    
    // MARK: - TEST-P6: Plugin Capability Denial
    
    func testP6_PluginCapabilityDenial() async throws {
        // Arrange
        let generalPlugin = TestGeneralPlugin(name: "Capability Test")
        var denialHandled = false
        
        generalPlugin.onInitialize = { host in
            // Request unavailable capability
            let granted = host.requestCapability("root_access")
            
            // React to denial
            if !granted {
                denialHandled = true
            }
        }
        
        // Act
        pluginManager.registerPlugin(generalPlugin)
        try await pluginManager.activateGeneralPlugin(generalPlugin)
        
        // Assert
        XCTAssertTrue(denialHandled, "Plugin should handle capability denial gracefully")
    }
    
    // MARK: - TEST-P7: Faulty Plugin Isolation
    
    func testP7_FaultyPluginIsolation() async throws {
        // Arrange
        let crashPlugin = TestCrashPlugin(name: "Crash Test", type: .general)
        let normalPlugin = TestGeneralPlugin(name: "Normal Plugin")
        
        var errorLogged = false
        
        // Monitor error logging
        let errorExpectation = XCTestExpectation(description: "Error logged")
        
        // Hook into plugin manager error handling
        PluginManager.testOnError = { error, level in
            if level == .error {
                errorLogged = true
                errorExpectation.fulfill()
            }
        }
        
        // Act
        pluginManager.registerPlugin(normalPlugin)
        pluginManager.registerPlugin(crashPlugin)
        
        // Try to activate crash plugin
        do {
            try await pluginManager.activateGeneralPlugin(crashPlugin)
            XCTFail("Crash plugin should throw error")
        } catch {
            // Expected
        }
        
        // Wait for error logging
        await fulfillment(of: [errorExpectation], timeout: 1.0)
        
        // Assert
        XCTAssertTrue(errorLogged, "Error should be logged")
        XCTAssertFalse(pluginManager.activeGeneralPlugins.contains { $0.metadata.identifier == crashPlugin.metadata.identifier },
                      "Crash plugin should not be in active list")
        
        // Verify app stability - normal plugin should still work
        do {
            try await pluginManager.activateGeneralPlugin(normalPlugin)
            XCTAssertTrue(pluginManager.activeGeneralPlugins.contains { $0.metadata.identifier == normalPlugin.metadata.identifier },
                         "Normal plugin should work despite crash plugin")
        } catch {
            XCTFail("Normal plugin should not fail: \(error)")
        }
    }
}

// Test plugin classes are now in MockPlugins.swift