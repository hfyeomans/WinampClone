import Foundation
import CoreGraphics
import AppKit
import SwiftUI
import Combine

/// Example custom visualization plugin - Matrix Rain effect
/// This demonstrates how to create a custom visualization using the plugin API
public final class MatrixRainVisualizationPlugin: VisualizationPlugin {
    
    // MARK: - WAPlugin Requirements
    
    public let metadata = PluginMetadata(
        identifier: "com.example.visualization.matrix",
        name: "Matrix Rain",
        type: .visualization,
        version: "1.0.0",
        author: "Example Developer",
        description: "Digital rain effect inspired by The Matrix, reactive to audio",
        iconName: "matrix_icon"
    )
    
    public private(set) var state: PluginState = .unloaded
    private let stateSubject = CurrentValueSubject<PluginState, Never>(.unloaded)
    public var statePublisher: AnyPublisher<PluginState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - VisualizationPlugin Requirements
    
    public var visualizationMetadata: VisualizationPluginMetadata {
        VisualizationPluginMetadata(
            identifier: metadata.identifier,
            name: metadata.name,
            author: metadata.author,
            version: metadata.version,
            description: metadata.description,
            iconName: metadata.iconName
        )
    }
    
    public let capabilities: VisualizationCapabilities = [.spectrum, .beatDetection, .customConfiguration]
    
    // MARK: - Configuration
    
    private var rainColor: CGColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
    private var dropSpeed: Double = 1.0
    private var dropDensity: Int = 50
    private var reactToBeats: Bool = true
    private var glowIntensity: Double = 0.8
    
    public lazy var configurationOptions: [VisualizationConfiguration] = [
        MatrixColorConfiguration(
            key: "rainColor",
            displayName: "Rain Color",
            color: rainColor
        ),
        MatrixSliderConfiguration(
            key: "dropSpeed",
            displayName: "Drop Speed",
            value: dropSpeed,
            min: 0.5,
            max: 3.0,
            step: 0.1
        ),
        MatrixSliderConfiguration(
            key: "dropDensity",
            displayName: "Drop Density",
            value: Double(dropDensity),
            min: 10,
            max: 100,
            step: 10
        ),
        MatrixToggleConfiguration(
            key: "reactToBeats",
            displayName: "React to Beats",
            value: reactToBeats
        ),
        MatrixSliderConfiguration(
            key: "glowIntensity",
            displayName: "Glow Intensity",
            value: glowIntensity,
            min: 0.0,
            max: 1.0,
            step: 0.1
        )
    ]
    
    // MARK: - Rain Drop Management
    
    private struct RainDrop {
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var characters: [Character]
        var intensity: CGFloat
        
        mutating func update(deltaTime: TimeInterval, height: CGFloat) {
            y += speed * CGFloat(deltaTime) * 60
            if y > height + CGFloat(characters.count) * 20 {
                y = -CGFloat(characters.count) * 20
                regenerateCharacters()
            }
        }
        
        mutating func regenerateCharacters() {
            let chars = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789"
            characters = (0..<Int.random(in: 5...15)).map { _ in
                chars.randomElement()!
            }
        }
    }
    
    private var rainDrops: [RainDrop] = []
    private var lastUpdateTime: TimeInterval = 0
    private var beatFlash: CGFloat = 0
    
    // MARK: - Plugin Lifecycle
    
    public init() {
        // Initialize with empty drops array
    }
    
    public func activate() {
        // Initialize rain drops
        initializeRainDrops()
        lastUpdateTime = Date().timeIntervalSince1970
    }
    
    public func deactivate() {
        // Clear resources
        rainDrops.removeAll()
    }
    
    // MARK: - Rendering
    
    public func render(audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        let currentTime = audioData.timestamp
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        
        // Handle beat detection
        if let beatInfo = audioData.beatInfo, beatInfo.isBeat && reactToBeats {
            beatFlash = CGFloat(beatInfo.intensity)
        } else {
            beatFlash *= 0.9 // Decay
        }
        
        // Set background
        let bgIntensity = beatFlash * 0.1
        let bgColor = CGColor(red: bgIntensity, green: bgIntensity, blue: bgIntensity, alpha: 1)
        context.setBackgroundColor(bgColor)
        
        // Update and render rain drops
        for i in 0..<rainDrops.count {
            rainDrops[i].update(deltaTime: deltaTime, height: context.size.height)
            renderRainDrop(&rainDrops[i], audioData: audioData, context: context)
        }
    }
    
    private func renderRainDrop(_ drop: inout RainDrop, audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        let fontSize: CGFloat = 16
        let lineHeight: CGFloat = 20
        
        // Get audio reactivity
        var audioIntensity: CGFloat = 0
        if let frequencyData = audioData.frequencyData {
            let index = Int(drop.x / context.size.width * CGFloat(frequencyData.count))
            if index < frequencyData.count {
                audioIntensity = CGFloat(frequencyData[index])
            }
        }
        
        // Render each character in the drop
        for (index, char) in drop.characters.enumerated() {
            let y = drop.y + CGFloat(index) * lineHeight
            
            // Skip if outside visible area
            if y < -lineHeight || y > context.size.height + lineHeight {
                continue
            }
            
            // Calculate fade based on position in drop
            let fade = 1.0 - (CGFloat(index) / CGFloat(drop.characters.count))
            let intensity = fade * drop.intensity * (1.0 + audioIntensity + beatFlash)
            
            // Apply glow effect for the leading character
            if index == 0 && glowIntensity > 0 {
                let glowAlpha = intensity * CGFloat(glowIntensity)
                let glowColor = CGColor(
                    colorSpace: rainColor.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                    components: (rainColor.components ?? [0, 1, 0, 1]).map { $0 * 1.5 }
                ) ?? rainColor
                
                // Create a semi-transparent glow color
                let glowColorWithAlpha = CGColor(
                    colorSpace: glowColor.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                    components: (glowColor.components ?? [0, 1, 0, 1]).dropLast().map { $0 } + [glowAlpha]
                ) ?? glowColor
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize * 1.2, weight: .bold),
                    .foregroundColor: glowColorWithAlpha
                ]
                
                context.drawText(
                    String(char),
                    at: CGPoint(x: drop.x, y: y),
                    attributes: attributes
                )
            }
            
            // Draw the character
            let alpha = min(intensity, 1.0)
            // Create a semi-transparent rain color
            let colorWithAlpha = CGColor(
                colorSpace: rainColor.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                components: (rainColor.components ?? [0, 1, 0, 1]).dropLast().map { $0 } + [alpha]
            ) ?? rainColor
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: colorWithAlpha
            ]
            
            context.drawText(
                String(char),
                at: CGPoint(x: drop.x, y: y),
                attributes: attributes
            )
        }
    }
    
    // MARK: - Configuration Updates
    
    public func updateConfiguration(key: String, value: Any) {
        switch key {
        case "rainColor":
            // CGColor is a Core Foundation type, need to check CFTypeID
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                rainColor = value as! CGColor
            }
        case "dropSpeed":
            if let speed = value as? Double {
                dropSpeed = speed
                // Update existing drops
                for i in 0..<rainDrops.count {
                    rainDrops[i].speed = CGFloat(dropSpeed) * CGFloat.random(in: 0.5...1.5)
                }
            }
        case "dropDensity":
            if let density = value as? Int {
                dropDensity = density
                initializeRainDrops() // Reinitialize with new density
            }
        case "reactToBeats":
            if let react = value as? Bool {
                reactToBeats = react
            }
        case "glowIntensity":
            if let intensity = value as? Double {
                glowIntensity = intensity
            }
        default:
            break
        }
    }
    
    public func resize(to size: CGSize) {
        // Redistribute drops across new width
        for i in 0..<rainDrops.count {
            rainDrops[i].x = CGFloat.random(in: 0...size.width)
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeRainDrops() {
        rainDrops.removeAll()
        
        for _ in 0..<dropDensity {
            var drop = RainDrop(
                x: 0,
                y: 0,
                speed: CGFloat(dropSpeed),
                characters: [],
                intensity: CGFloat.random(in: 0.5...1.0)
            )
            drop.regenerateCharacters()
            drop.x = CGFloat.random(in: 0...1000) // Will be adjusted on resize
            drop.y = CGFloat.random(in: -500...1000)
            drop.speed = CGFloat(dropSpeed) * CGFloat.random(in: 0.5...1.5)
            rainDrops.append(drop)
        }
    }
    
    // MARK: - WAPlugin Lifecycle Methods
    
    public func initialize(host: PluginHost) async throws {
        stateSubject.send(.initializing)
        // Initialize plugin with host
        stateSubject.send(.inactive)
    }
    
    public func activate() async throws {
        stateSubject.send(.activating)
        stateSubject.send(.active)
    }
    
    public func deactivate() async throws {
        stateSubject.send(.deactivating)
        stateSubject.send(.inactive)
    }
    
    public func shutdown() async {
        stateSubject.send(.unloading)
        rainDrops.removeAll()
        stateSubject.send(.unloaded)
    }
    
    public func configurationView() -> AnyView? {
        return nil // Could return SwiftUI configuration view
    }
    
    public func exportSettings() -> Data? {
        let settings = [
            "rainColor": rainColor,
            "dropSpeed": dropSpeed,
            "dropDensity": dropDensity,
            "reactToBeats": reactToBeats,
            "glowIntensity": glowIntensity
        ]
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    public func importSettings(_ data: Data) throws {
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PluginError.configurationError("Invalid settings format")
        }
        
        if let color = settings["rainColor"] as? CGColor {
            rainColor = color
        }
        if let speed = settings["dropSpeed"] as? Double {
            dropSpeed = speed
        }
        if let density = settings["dropDensity"] as? Int {
            dropDensity = density
        }
        if let beats = settings["reactToBeats"] as? Bool {
            reactToBeats = beats
        }
        if let glow = settings["glowIntensity"] as? Double {
            glowIntensity = glow
        }
    }
    
    public func handleMessage(_ message: PluginMessage) {
        // Handle inter-plugin messages if needed
    }
}

// MARK: - Custom Configuration Classes

private class MatrixColorConfiguration: VisualizationConfiguration {
    let displayName: String
    let key: String
    var value: Any
    let type: VisualizationConfigurationType = .colorPicker
    
    init(key: String, displayName: String, color: CGColor) {
        self.key = key
        self.displayName = displayName
        self.value = color
    }
}

private class MatrixSliderConfiguration: VisualizationConfiguration {
    let displayName: String
    let key: String
    var value: Any
    let type: VisualizationConfigurationType
    
    init(key: String, displayName: String, value: Double, min: Double, max: Double, step: Double) {
        self.key = key
        self.displayName = displayName
        self.value = value
        self.type = .slider(min: min, max: max, step: step)
    }
}

private class MatrixToggleConfiguration: VisualizationConfiguration {
    let displayName: String
    let key: String
    var value: Any
    let type: VisualizationConfigurationType = .toggle
    
    init(key: String, displayName: String, value: Bool) {
        self.key = key
        self.displayName = displayName
        self.value = value
    }
}

// MARK: - Usage Example

/*
 To use this custom visualization plugin:
 
 1. Create an instance of the plugin:
    let matrixPlugin = MatrixRainVisualizationPlugin()
 
 2. Register it with the plugin manager:
    VisualizationPluginManager.shared.register(matrixPlugin)
 
 3. Activate it:
    VisualizationPluginManager.shared.activatePlugin(withIdentifier: "com.example.visualization.matrix")
 
 4. In your audio processing loop, send audio data:
    let audioData = VisualizationAudioData(
        samples: audioSamples,
        frequencyData: fftData,
        sampleRate: 44100,
        channelCount: 2,
        timestamp: CACurrentMediaTime(),
        beatInfo: beatDetector.currentBeatInfo()
    )
    
    VisualizationPluginManager.shared.processAudioData(audioData, context: renderContext)
 
 5. Configure the plugin:
    matrixPlugin.updateConfiguration(key: "rainColor", value: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    matrixPlugin.updateConfiguration(key: "dropSpeed", value: 2.0)
 */