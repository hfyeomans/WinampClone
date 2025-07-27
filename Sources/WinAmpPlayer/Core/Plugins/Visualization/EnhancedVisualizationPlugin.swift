//
//  EnhancedVisualizationPlugin.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Enhanced visualization plugin that bridges old and new plugin systems
//

import Foundation
import SwiftUI
import Combine
import CoreGraphics

/// Enhanced base class for visualization plugins that implements both old and new protocols
open class EnhancedVisualizationPlugin: WAPlugin, VisualizationPlugin {
    
    // MARK: - WAPlugin Requirements
    
    public let metadata: PluginMetadata
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
    
    // Default implementation - override in subclasses
    open var capabilities: VisualizationCapabilities { .basic }
    open var configurationOptions: [VisualizationConfiguration] { [] }
    
    // MARK: - Protected Properties
    
    protected weak var host: PluginHost?
    protected var isActive = false
    
    // MARK: - Initialization
    
    public init(
        identifier: String,
        name: String,
        author: String,
        version: String,
        description: String,
        iconName: String? = nil
    ) {
        self.metadata = PluginMetadata(
            identifier: identifier,
            name: name,
            type: .visualization,
            version: version,
            author: author,
            description: description,
            iconName: iconName
        )
    }
    
    // Required by VisualizationPlugin protocol
    public required init() {
        fatalError("Use init(identifier:name:author:version:description:iconName:) instead")
    }
    
    // MARK: - WAPlugin Methods
    
    public func initialize(host: PluginHost) async throws {
        self.host = host
        state = .loaded
        stateSubject.send(.loaded)
        
        host.log("Visualization plugin initialized", level: .info, from: metadata.identifier)
    }
    
    public func activate() async throws {
        activate() // Call old protocol method
        isActive = true
        state = .active
        stateSubject.send(.active)
    }
    
    public func deactivate() async throws {
        deactivate() // Call old protocol method
        isActive = false
        state = .loaded
        stateSubject.send(.loaded)
    }
    
    public func shutdown() async {
        if isActive {
            try? await deactivate()
        }
        state = .unloaded
        stateSubject.send(.unloaded)
    }
    
    public func configurationView() -> AnyView? {
        // Create a configuration view from the old-style configuration options
        guard !configurationOptions.isEmpty else { return nil }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                ForEach(configurationOptions.indices, id: \.self) { index in
                    ConfigurationItemView(
                        configuration: configurationOptions[index],
                        onChange: { [weak self] newValue in
                            self?.updateConfiguration(
                                key: self?.configurationOptions[index].key ?? "",
                                value: newValue
                            )
                        }
                    )
                }
            }
            .padding()
        )
    }
    
    public func exportSettings() -> Data? {
        // Export configuration values
        let settings = configurationOptions.reduce(into: [String: Any]()) { result, config in
            result[config.key] = config.value
        }
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    public func importSettings(_ data: Data) throws {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PluginError.invalidConfiguration
        }
        
        for (key, value) in settings {
            updateConfiguration(key: key, value: value)
        }
    }
    
    public func handleMessage(_ message: PluginMessage) {
        // Handle plugin messages if needed
    }
    
    // MARK: - VisualizationPlugin Methods (Default Implementations)
    
    open func activate() {
        // Override in subclasses
    }
    
    open func deactivate() {
        // Override in subclasses
    }
    
    open func render(audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        // Override in subclasses
    }
    
    open func updateConfiguration(key: String, value: Any) {
        // Override in subclasses
    }
    
    open func resize(to size: CGSize) {
        // Override in subclasses
    }
}

// MARK: - Configuration Item View

private struct ConfigurationItemView: View {
    let configuration: VisualizationConfiguration
    let onChange: (Any) -> Void
    
    @State private var sliderValue: Double = 0
    @State private var toggleValue: Bool = false
    @State private var selectedIndex: Int = 0
    @State private var textValue: String = ""
    @State private var colorComponents: [CGFloat] = [0, 0, 0, 1]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(configuration.displayName)
                .font(.system(size: 12, weight: .medium))
            
            switch configuration.type {
            case .slider(let min, let max, let step):
                HStack {
                    Slider(
                        value: $sliderValue,
                        in: min...max,
                        step: step,
                        onEditingChanged: { _ in
                            onChange(sliderValue)
                        }
                    )
                    
                    Text(String(format: "%.1f", sliderValue))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 40)
                }
                .onAppear {
                    sliderValue = configuration.value as? Double ?? min
                }
                
            case .toggle:
                Toggle("", isOn: $toggleValue)
                    .labelsHidden()
                    .onChange(of: toggleValue) { newValue in
                        onChange(newValue)
                    }
                    .onAppear {
                        toggleValue = configuration.value as? Bool ?? false
                    }
                
            case .colorPicker:
                ColorPicker("", selection: Binding(
                    get: {
                        Color(
                            red: colorComponents[0],
                            green: colorComponents[1],
                            blue: colorComponents[2],
                            opacity: colorComponents[3]
                        )
                    },
                    set: { color in
                        let nsColor = NSColor(color)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                        colorComponents = [r, g, b, a]
                        
                        let cgColor = CGColor(
                            colorSpace: CGColorSpaceCreateDeviceRGB(),
                            components: colorComponents
                        )
                        onChange(cgColor ?? CGColor.black)
                    }
                ))
                .labelsHidden()
                .onAppear {
                    if let cgColor = configuration.value as? CGColor,
                       let components = cgColor.components {
                        colorComponents = Array(components)
                    }
                }
                
            case .dropdown(let options):
                Picker("", selection: $selectedIndex) {
                    ForEach(0..<options.count, id: \.self) { index in
                        Text(options[index])
                            .tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedIndex) { newValue in
                    onChange(options[newValue])
                }
                .onAppear {
                    if let stringValue = configuration.value as? String,
                       let index = options.firstIndex(of: stringValue) {
                        selectedIndex = index
                    } else if let intValue = configuration.value as? Int {
                        selectedIndex = intValue
                    }
                }
                
            case .text:
                TextField("", text: $textValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
                    .onSubmit {
                        onChange(textValue)
                    }
                    .onAppear {
                        textValue = configuration.value as? String ?? ""
                    }
            }
        }
    }
}

// MARK: - Update Existing Visualizations

/// Updated spectrum visualization using enhanced base class
public final class EnhancedSpectrumVisualizationPlugin: EnhancedVisualizationPlugin {
    
    private var barCount: Int = 32
    private var barColor: CGColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
    private var peakHold: Bool = true
    private var peaks: [Float] = []
    private var peakDecay: Float = 0.95
    
    public override var capabilities: VisualizationCapabilities {
        [.spectrum, .customConfiguration]
    }
    
    public override var configurationOptions: [VisualizationConfiguration] {
        [
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
    }
    
    public init() {
        super.init(
            identifier: "com.winamp.visualization.spectrum.enhanced",
            name: "Enhanced Spectrum Analyzer",
            author: "WinAmp Team",
            version: "2.0.0",
            description: "Enhanced spectrum analyzer with new plugin system",
            iconName: "spectrum_icon"
        )
        
        peaks = Array(repeating: 0, count: barCount)
    }
    
    public override func render(audioData: VisualizationAudioData, context: VisualizationRenderContext) {
        // Implementation same as original SpectrumVisualizationPlugin
        context.setBackgroundColor(CGColor.black)
        
        guard let frequencyData = audioData.frequencyData else { return }
        
        let barWidth = context.size.width / CGFloat(barCount)
        let maxHeight = context.size.height * 0.8
        
        if peaks.count != barCount {
            peaks = Array(repeating: 0, count: barCount)
        }
        
        for i in 0..<barCount {
            let frequencyIndex = i * frequencyData.count / barCount
            let magnitude = frequencyData[frequencyIndex]
            let normalizedMagnitude = min(magnitude * 2, 1.0)
            
            if normalizedMagnitude > peaks[i] {
                peaks[i] = normalizedMagnitude
            } else {
                peaks[i] *= peakDecay
            }
            
            let barHeight = CGFloat(normalizedMagnitude) * maxHeight
            let barRect = CGRect(
                x: CGFloat(i) * barWidth + 2,
                y: context.size.height - barHeight,
                width: barWidth - 4,
                height: barHeight
            )
            
            let path = CGPath(rect: barRect, transform: nil)
            context.fillPath(path, color: barColor)
            
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
    
    public override func updateConfiguration(key: String, value: Any) {
        switch key {
        case "barCount":
            if let count = value as? Int {
                barCount = count
            }
        case "barColor":
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
}