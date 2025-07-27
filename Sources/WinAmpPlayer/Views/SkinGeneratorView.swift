//
//  SkinGeneratorView.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  UI for procedural skin generation
//

import SwiftUI

struct SkinGeneratorView: View {
    @StateObject private var generator = SkinGenerator.shared
    @State private var selectedTemplate = "modern_dark"
    @State private var customConfig = SkinGenerationConfig(
        metadata: SkinGenerationConfig.Metadata(name: "Custom Skin"),
        colors: SkinGenerationConfig.Colors(
            primary: HCTColor(hue: 210, chroma: 0.8, tone: 0.5)
        )
    )
    
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var previewImage: NSImage?
    
    // Color controls
    @State private var primaryHue: Double = 210
    @State private var primaryChroma: Double = 0.8
    @State private var primaryTone: Double = 0.5
    @State private var colorScheme: ColorScheme = .complementary
    
    // Theme controls
    @State private var themeMode: ThemeMode = .dark
    @State private var visualStyle: VisualStyle = .modern
    
    // Texture controls
    @State private var useBackgroundTexture = true
    @State private var backgroundTextureType: TextureType = .noise
    @State private var textureOpacity: Double = 0.2
    
    // Component controls
    @State private var buttonStyle: ButtonStyle = .rounded
    @State private var sliderStyle: SliderStyle = .modern
    @State private var cornerRadius: Double = 4.0
    
    // Batch generation
    @State private var batchCount = 5
    @State private var showBatchOptions = false
    
    var body: some View {
        HSplitView {
            // Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    templateSection
                    metadataSection
                    colorSection
                    themeSection
                    textureSection
                    componentSection
                    generationSection
                }
                .padding()
            }
            .frame(minWidth: 300, idealWidth: 350)
            
            // Preview
            VStack {
                if let preview = previewImage {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 550, maxHeight: 232)
                        .background(Color.black)
                        .border(Color.gray.opacity(0.3))
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 550, height: 232)
                        .overlay(
                            Text("Preview will appear here")
                                .foregroundColor(.secondary)
                        )
                }
                
                if case .generating(let progress) = generator.state {
                    ProgressView(value: progress)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert("Generation Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            updatePreview()
        }
    }
    
    // MARK: - Sections
    
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Templates")
                .font(.headline)
            
            Picker("Template", selection: $selectedTemplate) {
                ForEach(Array(generator.availableTemplates.keys.sorted()), id: \.self) { template in
                    Text(template.replacingOccurrences(of: "_", with: " ").capitalized)
                        .tag(template)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedTemplate) { _ in
                loadTemplate()
            }
            
            Button("Load Template") {
                loadTemplate()
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metadata")
                .font(.headline)
            
            TextField("Skin Name", text: .constant(customConfig.metadata.name))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Author", text: .constant(customConfig.metadata.author))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colors")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Primary Color")
                    .font(.subheadline)
                
                HStack {
                    Text("Hue:")
                    Slider(value: $primaryHue, in: 0...360)
                    Text("\(Int(primaryHue))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Chroma:")
                    Slider(value: $primaryChroma, in: 0...1)
                    Text("\(Int(primaryChroma * 100))%")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Tone:")
                    Slider(value: $primaryTone, in: 0...1)
                    Text("\(Int(primaryTone * 100))%")
                        .frame(width: 40)
                }
            }
            
            Picker("Color Scheme", selection: $colorScheme) {
                Text("Monochromatic").tag(ColorScheme.monochromatic)
                Text("Complementary").tag(ColorScheme.complementary)
                Text("Analogous").tag(ColorScheme.analogous)
                Text("Triadic").tag(ColorScheme.triadic)
                Text("Split Complementary").tag(ColorScheme.splitComplementary)
                Text("Tetradic").tag(ColorScheme.tetradic)
            }
            .pickerStyle(MenuPickerStyle())
        }
        .onChange(of: primaryHue) { _ in updateConfig() }
        .onChange(of: primaryChroma) { _ in updateConfig() }
        .onChange(of: primaryTone) { _ in updateConfig() }
        .onChange(of: colorScheme) { _ in updateConfig() }
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme")
                .font(.headline)
            
            Picker("Mode", selection: $themeMode) {
                Text("Dark").tag(ThemeMode.dark)
                Text("Light").tag(ThemeMode.light)
                Text("Auto").tag(ThemeMode.auto)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Picker("Style", selection: $visualStyle) {
                Text("Modern").tag(VisualStyle.modern)
                Text("Retro").tag(VisualStyle.retro)
                Text("Minimal").tag(VisualStyle.minimal)
                Text("Glass").tag(VisualStyle.glass)
                Text("Cyberpunk").tag(VisualStyle.cyberpunk)
                Text("Vaporwave").tag(VisualStyle.vaporwave)
            }
            .pickerStyle(MenuPickerStyle())
        }
        .onChange(of: themeMode) { _ in updateConfig() }
        .onChange(of: visualStyle) { _ in updateConfig() }
    }
    
    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Textures")
                .font(.headline)
            
            Toggle("Use Background Texture", isOn: $useBackgroundTexture)
            
            if useBackgroundTexture {
                Picker("Texture Type", selection: $backgroundTextureType) {
                    Text("Solid").tag(TextureType.solid)
                    Text("Gradient").tag(TextureType.gradient)
                    Text("Noise").tag(TextureType.noise)
                    Text("Circuit").tag(TextureType.circuit)
                    Text("Dots").tag(TextureType.dots)
                    Text("Lines").tag(TextureType.lines)
                    Text("Waves").tag(TextureType.waves)
                    Text("Voronoi").tag(TextureType.voronoi)
                    Text("Checkerboard").tag(TextureType.checkerboard)
                }
                .pickerStyle(MenuPickerStyle())
                
                HStack {
                    Text("Opacity:")
                    Slider(value: $textureOpacity, in: 0...1)
                    Text("\(Int(textureOpacity * 100))%")
                        .frame(width: 40)
                }
            }
        }
        .onChange(of: useBackgroundTexture) { _ in updateConfig() }
        .onChange(of: backgroundTextureType) { _ in updateConfig() }
        .onChange(of: textureOpacity) { _ in updateConfig() }
    }
    
    private var componentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Components")
                .font(.headline)
            
            Picker("Button Style", selection: $buttonStyle) {
                Text("Flat").tag(ButtonStyle.flat)
                Text("Rounded").tag(ButtonStyle.rounded)
                Text("Beveled").tag(ButtonStyle.beveled)
                Text("Glass").tag(ButtonStyle.glass)
                Text("Pill").tag(ButtonStyle.pill)
                Text("Square").tag(ButtonStyle.square)
            }
            .pickerStyle(MenuPickerStyle())
            
            Picker("Slider Style", selection: $sliderStyle) {
                Text("Classic").tag(SliderStyle.classic)
                Text("Modern").tag(SliderStyle.modern)
                Text("Minimal").tag(SliderStyle.minimal)
                Text("Groove").tag(SliderStyle.groove)
                Text("Rail").tag(SliderStyle.rail)
            }
            .pickerStyle(MenuPickerStyle())
            
            HStack {
                Text("Corner Radius:")
                Slider(value: $cornerRadius, in: 0...20)
                Text("\(Int(cornerRadius))")
                    .frame(width: 30)
            }
        }
        .onChange(of: buttonStyle) { _ in updateConfig() }
        .onChange(of: sliderStyle) { _ in updateConfig() }
        .onChange(of: cornerRadius) { _ in updateConfig() }
    }
    
    private var generationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generation")
                .font(.headline)
            
            HStack {
                Button("Generate Skin") {
                    generateSkin()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
                
                Button("Random Skin") {
                    generateRandomSkin()
                }
                .disabled(isGenerating)
                
                Button("Batch Generate...") {
                    showBatchOptions.toggle()
                }
                .disabled(isGenerating)
            }
            
            if showBatchOptions {
                HStack {
                    Stepper("Count: \(batchCount)", value: $batchCount, in: 2...20)
                    
                    Button("Generate Batch") {
                        generateBatch()
                    }
                    .disabled(isGenerating)
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadTemplate() {
        Task {
            do {
                if let templateContent = generator.availableTemplates[selectedTemplate] {
                    let config = try ConfigurationParser.parse(from: templateContent)
                    
                    await MainActor.run {
                        // Update UI controls from config
                        primaryHue = config.colors.primary.hue
                        primaryChroma = config.colors.primary.chroma
                        primaryTone = config.colors.primary.tone
                        colorScheme = config.colors.scheme
                        themeMode = config.theme.mode
                        visualStyle = config.theme.style
                        
                        if let bgTexture = config.textures.background {
                            useBackgroundTexture = true
                            backgroundTextureType = bgTexture.type
                            textureOpacity = bgTexture.opacity
                        } else {
                            useBackgroundTexture = false
                        }
                        
                        buttonStyle = config.components.buttonStyle
                        sliderStyle = config.components.sliderStyle
                        cornerRadius = config.components.cornerRadius
                        
                        customConfig = config
                        updatePreview()
                    }
                }
            } catch {
                showError(error)
            }
        }
    }
    
    private func updateConfig() {
        // Update custom config from UI controls
        customConfig = SkinGenerationConfig(
            metadata: customConfig.metadata,
            theme: SkinGenerationConfig.Theme(
                mode: themeMode,
                style: visualStyle
            ),
            colors: SkinGenerationConfig.Colors(
                primary: HCTColor(
                    hue: primaryHue,
                    chroma: primaryChroma,
                    tone: primaryTone
                ),
                scheme: colorScheme
            ),
            textures: SkinGenerationConfig.Textures(
                background: useBackgroundTexture ? TextureConfig(
                    type: backgroundTextureType,
                    opacity: textureOpacity
                ) : nil
            ),
            components: SkinGenerationConfig.Components(
                buttonStyle: buttonStyle,
                sliderStyle: sliderStyle,
                cornerRadius: cornerRadius
            )
        )
        
        updatePreview()
    }
    
    private func updatePreview() {
        Task {
            let preview = await generator.generatePreview(for: customConfig)
            await MainActor.run {
                self.previewImage = preview
            }
        }
    }
    
    private func generateSkin() {
        // Update config from UI values before generating
        updateConfig()
        
        Task {
            isGenerating = true
            do {
                let skin = try await generator.generateSkin(from: customConfig)
                await MainActor.run {
                    isGenerating = false
                    // Show success message or open skin
                    NSWorkspace.shared.activateFileViewerSelecting([
                        SkinManager.shared.skinsDirectory.appendingPathComponent("\(skin.config.metadata.name).wsz")
                    ])
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    showError(error)
                }
            }
        }
    }
    
    private func generateRandomSkin() {
        Task {
            isGenerating = true
            do {
                let skin = try await generator.generateRandomSkin()
                await MainActor.run {
                    isGenerating = false
                    NSWorkspace.shared.activateFileViewerSelecting([
                        SkinManager.shared.skinsDirectory.appendingPathComponent("\(skin.config.metadata.name).wsz")
                    ])
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    showError(error)
                }
            }
        }
    }
    
    private func generateBatch() {
        Task {
            isGenerating = true
            do {
                _ = try await generator.generateBatch(
                    baseConfig: customConfig,
                    count: batchCount,
                    variations: .all
                )
                await MainActor.run {
                    isGenerating = false
                    showBatchOptions = false
                    // Open folder containing generated skins
                    NSWorkspace.shared.selectFile(
                        nil,
                        inFileViewerRootedAtPath: SkinManager.shared.skinsDirectory.path
                    )
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    showError(error)
                }
            }
        }
    }
    
    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - Window Management
// Note: openSkinGenerator is handled by SecondaryWindowManager.openWindow(.skinGenerator)