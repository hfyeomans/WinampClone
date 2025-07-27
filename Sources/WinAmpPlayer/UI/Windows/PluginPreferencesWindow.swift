//
//  PluginPreferencesWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Window for managing all plugins
//

import SwiftUI
import AppKit

/// Plugin preferences window
public struct PluginPreferencesWindow: View {
    @StateObject private var pluginManager = PluginManager.shared
    @State private var selectedCategory: PluginType = .visualization
    @State private var selectedPlugin: WAPlugin?
    @State private var showingPluginConfig = false
    
    public var body: some View {
        WinAmpWindow(
            configuration: WinAmpWindowConfiguration(
                title: "Plugin Preferences",
                windowType: .preferences,
                showTitleBar: true,
                resizable: true,
                minSize: CGSize(width: 600, height: 400),
                maxSize: CGSize(width: 800, height: 600)
            )
        ) {
            HSplitView {
                // Category list
                categoryList
                    .frame(width: 150)
                
                // Plugin list and details
                VSplitView {
                    pluginList
                        .frame(minHeight: 200)
                    
                    pluginDetails
                        .frame(minHeight: 150)
                }
            }
            .background(WinAmpColors.background)
        }
    }
    
    // MARK: - Category List
    
    private var categoryList: some View {
        VStack(spacing: 0) {
            Text("Categories")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(WinAmpColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(WinAmpColors.backgroundDark)
            
            Divider()
            
            List(PluginType.allCases, id: \.self, selection: $selectedCategory) { category in
                HStack {
                    Image(systemName: iconForCategory(category))
                        .font(.system(size: 12))
                        .frame(width: 20)
                    
                    Text(category.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Spacer()
                    
                    Text("\(countForCategory(category))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(WinAmpColors.textDim)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 2)
            }
            .listStyle(PlainListStyle())
            .background(WinAmpColors.backgroundLight)
        }
    }
    
    // MARK: - Plugin List
    
    private var pluginList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(selectedCategory.rawValue + " Plugins")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                
                Spacer()
                
                Button(action: scanForPlugins) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(pluginManager.isScanning)
                
                Button(action: addPlugin) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(WinAmpColors.backgroundDark)
            
            Divider()
            
            // Plugin table
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(pluginsForCategory(selectedCategory), id: \.metadata.identifier) { plugin in
                        PluginListItem(
                            plugin: plugin,
                            isSelected: selectedPlugin?.metadata.identifier == plugin.metadata.identifier,
                            onSelect: {
                                selectedPlugin = plugin
                            },
                            onToggle: {
                                togglePlugin(plugin)
                            }
                        )
                        .background(
                            selectedPlugin?.metadata.identifier == plugin.metadata.identifier ?
                            WinAmpColors.selection : Color.clear
                        )
                    }
                }
            }
            .background(WinAmpColors.backgroundLight)
        }
    }
    
    // MARK: - Plugin Details
    
    private var pluginDetails: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Plugin Details")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                
                Spacer()
                
                if selectedPlugin != nil {
                    Button("Configure...") {
                        showingPluginConfig = true
                    }
                    .font(.system(size: 11))
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedPlugin?.configurationView() == nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(WinAmpColors.backgroundDark)
            
            Divider()
            
            // Details content
            if let plugin = selectedPlugin {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Basic info
                        DetailRow(label: "Name:", value: plugin.metadata.name)
                        DetailRow(label: "Version:", value: plugin.metadata.version)
                        DetailRow(label: "Author:", value: plugin.metadata.author)
                        DetailRow(label: "Type:", value: plugin.metadata.type.rawValue)
                        
                        if !plugin.metadata.description.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description:")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(WinAmpColors.textDim)
                                
                                Text(plugin.metadata.description)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(WinAmpColors.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        if let website = plugin.metadata.website {
                            HStack {
                                Text("Website:")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(WinAmpColors.textDim)
                                
                                Button(website.absoluteString) {
                                    NSWorkspace.shared.open(website)
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(WinAmpColors.accent)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // Type-specific info
                        pluginSpecificInfo(for: plugin)
                    }
                    .padding()
                }
            } else {
                Text("Select a plugin to view details")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(WinAmpColors.textDim)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(WinAmpColors.backgroundLight)
        .sheet(isPresented: $showingPluginConfig) {
            if let plugin = selectedPlugin,
               let configView = plugin.configurationView() {
                VStack {
                    HStack {
                        Text("\(plugin.metadata.name) Configuration")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Spacer()
                        
                        Button("Done") {
                            showingPluginConfig = false
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    configView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 400, height: 300)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func pluginSpecificInfo(for plugin: WAPlugin) -> some View {
        switch plugin.metadata.type {
        case .visualization:
            if let vizPlugin = plugin as? VisualizationPlugin {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Capabilities:")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(WinAmpColors.textDim)
                    
                    Text(formatCapabilities(vizPlugin.capabilities))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(WinAmpColors.text)
                }
            }
            
        case .dsp:
            if let dspPlugin = plugin as? DSPPlugin {
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Latency:", value: "\(dspPlugin.latency) samples")
                    DetailRow(label: "In-place:", value: dspPlugin.canProcessInPlace ? "Yes" : "No")
                    
                    if !dspPlugin.parameters.isEmpty {
                        Text("Parameters: \(dspPlugin.parameters.count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(WinAmpColors.text)
                    }
                }
            }
            
        case .general:
            if let generalPlugin = plugin as? GeneralPlugin {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Features:")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(WinAmpColors.textDim)
                    
                    if !generalPlugin.menuItems.isEmpty {
                        Text("• Adds \(generalPlugin.menuItems.count) menu items")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(WinAmpColors.text)
                    }
                    
                    if !generalPlugin.toolbarItems.isEmpty {
                        Text("• Adds \(generalPlugin.toolbarItems.count) toolbar items")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(WinAmpColors.text)
                    }
                    
                    if generalPlugin.statusBarView != nil {
                        Text("• Provides status bar widget")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(WinAmpColors.text)
                    }
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func iconForCategory(_ category: PluginType) -> String {
        switch category {
        case .visualization:
            return "waveform"
        case .dsp:
            return "slider.horizontal.3"
        case .general:
            return "puzzlepiece"
        case .input:
            return "arrow.down.doc"
        case .output:
            return "speaker.wave.2"
        }
    }
    
    private func countForCategory(_ category: PluginType) -> Int {
        switch category {
        case .visualization:
            return pluginManager.visualizationPlugins.count
        case .dsp:
            return pluginManager.dspPlugins.count
        case .general:
            return pluginManager.generalPlugins.count
        default:
            return 0
        }
    }
    
    private func pluginsForCategory(_ category: PluginType) -> [WAPlugin] {
        switch category {
        case .visualization:
            return pluginManager.visualizationPlugins
        case .dsp:
            return pluginManager.dspPlugins
        case .general:
            return pluginManager.generalPlugins
        default:
            return []
        }
    }
    
    private func togglePlugin(_ plugin: WAPlugin) {
        Task {
            switch plugin.metadata.type {
            case .visualization:
                if let vizPlugin = plugin as? VisualizationPlugin {
                    if pluginManager.activeVisualization?.metadata.identifier == vizPlugin.metadata.identifier {
                        await pluginManager.activateVisualization(pluginManager.visualizationPlugins.first!)
                    } else {
                        await pluginManager.activateVisualization(vizPlugin)
                    }
                }
                
            case .dsp:
                if let dspPlugin = plugin as? DSPPlugin {
                    if pluginManager.activeDSPChain.allEffects.contains(where: { $0.metadata.identifier == dspPlugin.metadata.identifier }) {
                        pluginManager.removeDSPFromChain(dspPlugin)
                    } else {
                        pluginManager.addDSPToChain(dspPlugin)
                    }
                }
                
            case .general:
                if let generalPlugin = plugin as? GeneralPlugin {
                    if pluginManager.activeGeneralPlugins.contains(where: { $0.metadata.identifier == generalPlugin.metadata.identifier }) {
                        await pluginManager.deactivateGeneralPlugin(generalPlugin)
                    } else {
                        await pluginManager.activateGeneralPlugin(generalPlugin)
                    }
                }
                
            default:
                break
            }
        }
    }
    
    private func scanForPlugins() {
        Task {
            await pluginManager.scanForPlugins()
        }
    }
    
    private func addPlugin() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["waplugin"]
        panel.allowsMultipleSelection = true
        panel.prompt = "Add Plugin"
        
        if panel.runModal() == .OK {
            Task {
                for url in panel.urls {
                    try? await pluginManager.loadPlugin(from: url)
                }
            }
        }
    }
    
    private func formatCapabilities(_ capabilities: VisualizationCapabilities) -> String {
        var caps: [String] = []
        
        if capabilities.contains(.spectrum) { caps.append("Spectrum") }
        if capabilities.contains(.waveform) { caps.append("Waveform") }
        if capabilities.contains(.beatDetection) { caps.append("Beat Detection") }
        if capabilities.contains(.customConfiguration) { caps.append("Configurable") }
        if capabilities.contains(.multiChannel) { caps.append("Multi-channel") }
        if capabilities.contains(.gpu) { caps.append("GPU Accelerated") }
        
        return caps.joined(separator: ", ")
    }
}

// MARK: - Supporting Views

private struct PluginListItem: View {
    let plugin: WAPlugin
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    
    @State private var isActive = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            // Plugin info
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.metadata.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? WinAmpColors.textHighlight : WinAmpColors.text)
                
                Text("v\(plugin.metadata.version) by \(plugin.metadata.author)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WinAmpColors.textDim)
            }
            
            Spacer()
            
            // Enable/Disable button
            Button(isActive ? "Disable" : "Enable") {
                onToggle()
            }
            .font(.system(size: 10))
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            updateActiveState()
        }
        .onChange(of: plugin.state) { _ in
            updateActiveState()
        }
    }
    
    private func updateActiveState() {
        isActive = plugin.state == .active
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(WinAmpColors.textDim)
                .frame(width: 80, alignment: .trailing)
            
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(WinAmpColors.text)
            
            Spacer()
        }
    }
}