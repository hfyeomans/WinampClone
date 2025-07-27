import Foundation
import CoreGraphics
import AVFoundation
import SwiftUI
import Combine

// MARK: - Plugin Metadata

/// Metadata describing a visualization plugin
public struct VisualizationPluginMetadata {
    public let identifier: String
    public let name: String
    public let author: String
    public let version: String
    public let description: String
    public let iconName: String?
    
    public init(
        identifier: String,
        name: String,
        author: String,
        version: String,
        description: String,
        iconName: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.author = author
        self.version = version
        self.description = description
        self.iconName = iconName
    }
}

// MARK: - Plugin Capabilities

/// Capabilities that a visualization plugin supports
public struct VisualizationCapabilities: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let spectrum = VisualizationCapabilities(rawValue: 1 << 0)
    public static let waveform = VisualizationCapabilities(rawValue: 1 << 1)
    public static let beatDetection = VisualizationCapabilities(rawValue: 1 << 2)
    public static let customConfiguration = VisualizationCapabilities(rawValue: 1 << 3)
    public static let multiChannel = VisualizationCapabilities(rawValue: 1 << 4)
    public static let gpu = VisualizationCapabilities(rawValue: 1 << 5)
    
    public static let basic: VisualizationCapabilities = [.spectrum, .waveform]
    public static let advanced: VisualizationCapabilities = [.spectrum, .waveform, .beatDetection, .multiChannel]
}

// MARK: - Audio Data

/// Audio data provided to visualization plugins
public struct VisualizationAudioData {
    /// Raw PCM samples for the current frame
    public let samples: [Float]
    
    /// FFT frequency data (if available)
    public let frequencyData: [Float]?
    
    /// Sample rate of the audio
    public let sampleRate: Double
    
    /// Number of channels
    public let channelCount: Int
    
    /// Current playback time
    public let timestamp: TimeInterval
    
    /// Beat detection info (if available)
    public let beatInfo: BeatInfo?
    
    public struct BeatInfo {
        public let isBeat: Bool
        public let bpm: Double
        public let intensity: Float
    }
}

// MARK: - Rendering Context

/// Context for rendering visualizations
public protocol VisualizationRenderContext {
    /// The size of the rendering area
    var size: CGSize { get }
    
    /// The scale factor for the display
    var scale: CGFloat { get }
    
    /// Draw a path with the given color
    func drawPath(_ path: CGPath, color: CGColor, lineWidth: CGFloat)
    
    /// Fill a path with the given color
    func fillPath(_ path: CGPath, color: CGColor)
    
    /// Draw text at the given point
    func drawText(_ text: String, at point: CGPoint, attributes: [NSAttributedString.Key: Any])
    
    /// Draw an image
    func drawImage(_ image: CGImage, in rect: CGRect)
    
    /// Set the background color
    func setBackgroundColor(_ color: CGColor)
    
    /// Push a graphics state
    func pushState()
    
    /// Pop a graphics state
    func popState()
    
    /// Apply a transform
    func applyTransform(_ transform: CGAffineTransform)
}

// MARK: - Configuration

/// Type of configuration UI to display
public enum VisualizationConfigurationType {
    case slider(min: Double, max: Double, step: Double)
    case toggle
    case colorPicker
    case dropdown(options: [String])
    case text
}

/// Configuration options for a visualization plugin
public protocol VisualizationConfiguration {
    /// Human-readable name for this configuration option
    var displayName: String { get }
    
    /// Unique key for storing this configuration
    var key: String { get }
    
    /// Current value of the configuration
    var value: Any { get set }
    
    /// Type of configuration UI to display
    var type: VisualizationConfigurationType { get }
}

// MARK: - Main Plugin Protocol

/// Protocol that all visualization plugins must implement
public protocol VisualizationPlugin: WAPlugin {
    /// Visualization-specific metadata (derived from WAPlugin metadata)
    var visualizationMetadata: VisualizationPluginMetadata { get }
    
    /// Capabilities supported by this plugin
    var capabilities: VisualizationCapabilities { get }
    
    /// Configuration options for the plugin
    var configurationOptions: [VisualizationConfiguration] { get }
    
    /// Initialize the plugin
    init()
    
    /// Called when the plugin is activated
    func activate()
    
    /// Called when the plugin is deactivated
    func deactivate()
    
    /// Render the visualization for the given audio data
    func render(audioData: VisualizationAudioData, context: VisualizationRenderContext)
    
    /// Update configuration value
    func updateConfiguration(key: String, value: Any)
    
    /// Called when the window size changes
    func resize(to size: CGSize)
}

// MARK: - Plugin Manager

/// Manages loading and lifecycle of visualization plugins
public final class VisualizationPluginManager {
    public static let shared = VisualizationPluginManager()
    
    private var plugins: [String: VisualizationPlugin] = [:]
    private var activePlugin: VisualizationPlugin?
    private let queue = DispatchQueue(label: "com.winamp.visualization", qos: .userInteractive)
    
    private init() {
        loadBuiltInPlugins()
    }
    
    // MARK: - Plugin Management
    
    /// Register a plugin with the manager
    public func register(_ plugin: VisualizationPlugin) {
        queue.async { [weak self] in
            let id = plugin.metadata.identifier
            self?.plugins[id] = plugin
        }
    }
    
    /// Get all available plugins
    public func availablePlugins() -> [VisualizationPlugin] {
        queue.sync {
            Array(plugins.values)
        }
    }
    
    /// Activate a plugin by identifier
    public func activatePlugin(withIdentifier identifier: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Deactivate current plugin
            self.activePlugin?.deactivate()
            
            // Activate new plugin
            if let plugin = self.plugins[identifier] {
                plugin.activate()
                self.activePlugin = plugin
            }
        }
    }
    
    /// Get the currently active plugin
    public var currentPlugin: VisualizationPlugin? {
        queue.sync { activePlugin }
    }
    
    // MARK: - Rendering
    
    /// Process audio data and render visualization
    public func processAudioData(_ audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        queue.async { [weak self] in
            self?.activePlugin?.render(audioData: audioData, context: context)
        }
    }
    
    // MARK: - Plugin Discovery
    
    private func loadBuiltInPlugins() {
        // Register built-in plugins
        register(SpectrumVisualizationPlugin())
        register(OscilloscopeVisualizationPlugin())
    }
    
    /// Load external plugins from a directory
    public func loadExternalPlugins(from directory: URL) {
        // This would load dynamic frameworks or bundles
        // For now, we'll just log the intent
        print("Loading external plugins from: \(directory)")
    }
}

// MARK: - Built-in Spectrum Visualization

/// Built-in spectrum analyzer visualization
public final class SpectrumVisualizationPlugin: VisualizationPlugin {
    // MARK: - WAPlugin Requirements
    
    public let metadata = PluginMetadata(
        identifier: "com.winamp.visualization.spectrum",
        name: "Spectrum Analyzer",
        type: .visualization,
        version: "1.0.0",
        author: "WinAmp Team",
        description: "Classic spectrum analyzer with customizable colors and styles",
        iconName: "spectrum_icon"
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
    
    public let capabilities: VisualizationCapabilities = [.spectrum, .customConfiguration]
    
    private var barCount: Int = 32
    private var barColor: CGColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
    private var peakHold: Bool = true
    private var peaks: [Float] = []
    private var peakDecay: Float = 0.95
    
    public lazy var configurationOptions: [VisualizationConfiguration] = [
        SliderConfiguration(
            key: "barCount",
            displayName: "Number of Bars",
            value: Double(barCount),
            min: 8,
            max: 128,
            step: 8
        ),
        ColorConfiguration(
            key: "barColor",
            displayName: "Bar Color",
            color: barColor
        ),
        ToggleConfiguration(
            key: "peakHold",
            displayName: "Peak Hold",
            value: peakHold
        )
    ]
    
    public init() {
        peaks = Array(repeating: 0, count: barCount)
    }
    
    public func activate() {
        print("Spectrum analyzer activated")
    }
    
    public func deactivate() {
        print("Spectrum analyzer deactivated")
    }
    
    public func render(audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        context.setBackgroundColor(CGColor.black)
        
        guard let frequencyData = audioData.frequencyData else { return }
        
        let barWidth = context.size.width / CGFloat(barCount)
        let maxHeight = context.size.height * 0.8
        
        // Update peaks array if bar count changed
        if peaks.count != barCount {
            peaks = Array(repeating: 0, count: barCount)
        }
        
        for i in 0..<barCount {
            let frequencyIndex = i * frequencyData.count / barCount
            let magnitude = frequencyData[frequencyIndex]
            let normalizedMagnitude = min(magnitude * 2, 1.0) // Scale for visibility
            
            // Update peak
            if normalizedMagnitude > peaks[i] {
                peaks[i] = normalizedMagnitude
            } else {
                peaks[i] *= peakDecay
            }
            
            // Draw bar
            let barHeight = CGFloat(normalizedMagnitude) * maxHeight
            let barRect = CGRect(
                x: CGFloat(i) * barWidth + 2,
                y: context.size.height - barHeight,
                width: barWidth - 4,
                height: barHeight
            )
            
            let path = CGPath(rect: barRect, transform: nil)
            context.fillPath(path, color: barColor)
            
            // Draw peak
            if peakHold && peaks[i] > 0.01 {
                let peakY = context.size.height - (CGFloat(peaks[i]) * maxHeight)
                let peakRect = CGRect(
                    x: CGFloat(i) * barWidth + 2,
                    y: peakY - 2,
                    width: barWidth - 4,
                    height: 4
                )
                let peakPath = CGPath(rect: peakRect, transform: nil)
                context.fillPath(peakPath, color: CGColor.white)
            }
        }
    }
    
    public func updateConfiguration(key: String, value: Any) {
        switch key {
        case "barCount":
            if let count = value as? Int {
                barCount = count
            }
        case "barColor":
            // CGColor is a Core Foundation type, need to check CFTypeID
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                barColor = value as! CGColor
            }
        case "peakHold":
            if let hold = value as? Bool {
                peakHold = hold
            }
        default:
            break
        }
    }
    
    public func resize(to size: CGSize) {
        // Handle resize if needed
    }
    
    // MARK: - WAPlugin Lifecycle Methods
    
    public func initialize(host: PluginHost) async throws {
        stateSubject.send(.loading)
        peaks = Array(repeating: 0.0, count: barCount)
        stateSubject.send(.loaded)
    }
    
    public func activate() async throws {
        stateSubject.send(.active)
    }
    
    public func deactivate() async throws {
        stateSubject.send(.loaded)
    }
    
    public func shutdown() async {
        peaks.removeAll()
        stateSubject.send(.unloaded)
    }
    
    public func configurationView() -> AnyView? {
        return nil // Could return SwiftUI configuration view
    }
    
    public func exportSettings() -> Data? {
        let settings: [String: Any] = [
            "barCount": barCount,
            "barColor": barColor,
            "peakHold": peakHold
        ]
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    public func importSettings(_ data: Data) throws {
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PluginError.invalidConfiguration
        }
        
        if let count = settings["barCount"] as? Int {
            barCount = count
        }
        if let color = settings["barColor"] as? CGColor {
            barColor = color
        }
        if let hold = settings["peakHold"] as? Bool {
            peakHold = hold
        }
    }
    
    public func handleMessage(_ message: PluginMessage) {
        // Handle inter-plugin messages if needed
    }
}

// MARK: - Built-in Oscilloscope Visualization

/// Built-in oscilloscope visualization
public final class OscilloscopeVisualizationPlugin: VisualizationPlugin {
    // MARK: - WAPlugin Requirements
    
    public let metadata = PluginMetadata(
        identifier: "com.winamp.visualization.oscilloscope",
        name: "Oscilloscope",
        type: .visualization,
        version: "1.0.0",
        author: "WinAmp Team",
        description: "Classic waveform oscilloscope display",
        iconName: "oscilloscope_icon"
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
    
    public let capabilities: VisualizationCapabilities = [.waveform, .customConfiguration]
    
    private var lineColor: CGColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
    private var lineWidth: CGFloat = 2.0
    private var drawMode: DrawMode = .line
    
    private enum DrawMode: String, CaseIterable {
        case line = "Line"
        case dots = "Dots"
        case filled = "Filled"
    }
    
    public lazy var configurationOptions: [VisualizationConfiguration] = [
        ColorConfiguration(
            key: "lineColor",
            displayName: "Line Color",
            color: lineColor
        ),
        SliderConfiguration(
            key: "lineWidth",
            displayName: "Line Width",
            value: Double(lineWidth),
            min: 0.5,
            max: 5.0,
            step: 0.5
        ),
        DropdownConfiguration(
            key: "drawMode",
            displayName: "Draw Mode",
            value: drawMode.rawValue,
            options: DrawMode.allCases.map { $0.rawValue }
        )
    ]
    
    public init() {}
    
    public func activate() {
        print("Oscilloscope activated")
    }
    
    public func deactivate() {
        print("Oscilloscope deactivated")
    }
    
    public func render(audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        context.setBackgroundColor(CGColor.black)
        
        let samples = audioData.samples
        guard !samples.isEmpty else { return }
        
        let midY = context.size.height / 2
        let amplitude = context.size.height * 0.4
        
        switch drawMode {
        case .line:
            drawLineMode(samples: samples, context: context, midY: midY, amplitude: amplitude)
        case .dots:
            drawDotsMode(samples: samples, context: context, midY: midY, amplitude: amplitude)
        case .filled:
            drawFilledMode(samples: samples, context: context, midY: midY, amplitude: amplitude)
        }
    }
    
    private func drawLineMode(samples: [Float], context: VisualizationRenderContext, midY: CGFloat, amplitude: CGFloat) {
        let path = CGMutablePath()
        let step = max(1, samples.count / Int(context.size.width))
        
        for (index, i) in stride(from: 0, to: samples.count, by: step).enumerated() {
            let x = CGFloat(index) * context.size.width / CGFloat(samples.count / step)
            let y = midY - CGFloat(samples[i]) * amplitude
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.drawPath(path, color: lineColor, lineWidth: lineWidth)
    }
    
    private func drawDotsMode(samples: [Float], context: VisualizationRenderContext, midY: CGFloat, amplitude: CGFloat) {
        let step = max(1, samples.count / Int(context.size.width))
        
        for (index, i) in stride(from: 0, to: samples.count, by: step).enumerated() {
            let x = CGFloat(index) * context.size.width / CGFloat(samples.count / step)
            let y = midY - CGFloat(samples[i]) * amplitude
            
            let dotRect = CGRect(
                x: x - lineWidth/2,
                y: y - lineWidth/2,
                width: lineWidth,
                height: lineWidth
            )
            let path = CGPath(ellipseIn: dotRect, transform: nil)
            context.fillPath(path, color: lineColor)
        }
    }
    
    private func drawFilledMode(samples: [Float], context: VisualizationRenderContext, midY: CGFloat, amplitude: CGFloat) {
        let path = CGMutablePath()
        let step = max(1, samples.count / Int(context.size.width))
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        for (index, i) in stride(from: 0, to: samples.count, by: step).enumerated() {
            let x = CGFloat(index) * context.size.width / CGFloat(samples.count / step)
            let y = midY - CGFloat(samples[i]) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: context.size.width, y: midY))
        path.closeSubpath()
        
        // Create a semi-transparent version of the line color
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let components = lineColor.components ?? [0, 0, 0, 1]
        let semiTransparentColor = CGColor(
            colorSpace: colorSpace,
            components: [components[0], components[1], components[2], 0.5]
        ) ?? lineColor
        
        context.fillPath(path, color: semiTransparentColor)
    }
    
    public func updateConfiguration(key: String, value: Any) {
        switch key {
        case "lineColor":
            // CGColor is a Core Foundation type, need to check CFTypeID
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                lineColor = value as! CGColor
            }
        case "lineWidth":
            if let width = value as? Double {
                lineWidth = CGFloat(width)
            }
        case "drawMode":
            if let modeString = value as? String,
               let mode = DrawMode(rawValue: modeString) {
                drawMode = mode
            }
        default:
            break
        }
    }
    
    public func resize(to size: CGSize) {
        // Handle resize if needed
    }
    
    // MARK: - WAPlugin Lifecycle Methods
    
    public func initialize(host: PluginHost) async throws {
        stateSubject.send(.loading)
        // Initialize plugin with host
        stateSubject.send(.loaded)
    }
    
    public func activate() async throws {
        stateSubject.send(.active)
    }
    
    public func deactivate() async throws {
        stateSubject.send(.loaded)
    }
    
    public func shutdown() async {
        stateSubject.send(.unloaded)
    }
    
    public func configurationView() -> AnyView? {
        return nil // Could return SwiftUI configuration view
    }
    
    public func exportSettings() -> Data? {
        let settings: [String: Any] = [
            "lineColor": lineColor,
            "lineWidth": lineWidth,
            "drawMode": drawMode.rawValue
        ]
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    public func importSettings(_ data: Data) throws {
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PluginError.invalidConfiguration
        }
        
        if let color = settings["lineColor"] as? CGColor {
            lineColor = color
        }
        if let width = settings["lineWidth"] as? CGFloat {
            lineWidth = width
        }
        if let modeString = settings["drawMode"] as? String,
           let mode = DrawMode(rawValue: modeString) {
            drawMode = mode
        }
    }
    
    public func handleMessage(_ message: PluginMessage) {
        // Handle inter-plugin messages if needed
    }
}

// MARK: - Configuration Implementations

public class SliderConfiguration: VisualizationConfiguration {
    public let displayName: String
    public let key: String
    public var value: Any
    public let type: VisualizationConfigurationType
    
    init(key: String, displayName: String, value: Double, min: Double, max: Double, step: Double) {
        self.key = key
        self.displayName = displayName
        self.value = value
        self.type = .slider(min: min, max: max, step: step)
    }
}

public class ColorConfiguration: VisualizationConfiguration {
    public let displayName: String
    public let key: String
    public var value: Any
    public let type: VisualizationConfigurationType = .colorPicker
    
    init(key: String, displayName: String, color: CGColor) {
        self.key = key
        self.displayName = displayName
        self.value = color
    }
}

public class ToggleConfiguration: VisualizationConfiguration {
    public let displayName: String
    public let key: String
    public var value: Any
    public let type: VisualizationConfigurationType = .toggle
    
    init(key: String, displayName: String, value: Bool) {
        self.key = key
        self.displayName = displayName
        self.value = value
    }
}

public class DropdownConfiguration: VisualizationConfiguration {
    public let displayName: String
    public let key: String
    public var value: Any
    public let type: VisualizationConfigurationType
    
    init(key: String, displayName: String, value: String, options: [String]) {
        self.key = key
        self.displayName = displayName
        self.value = value
        self.type = .dropdown(options: options)
    }
}