//
//  ConversionExample.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Example usage of the AudioConverter and ConversionPresets.
//

import Foundation

/// Example demonstrating audio conversion usage
class AudioConversionExample {
    
    private let converter = AudioConverter()
    
    /// Convert a single file with a preset
    func convertWithPreset() {
        let sourceURL = URL(fileURLWithPath: "/path/to/source.wav")
        let outputURL = URL(fileURLWithPath: "/path/to/output.m4a")
        
        // Use iTunes Plus quality preset
        converter.convertAudioFile(
            from: sourceURL,
            to: outputURL,
            preset: .StandardQuality.aac256,
            progress: { progress in
                print("Progress: \(Int(progress.progress * 100))%")
            },
            completion: { result in
                switch result {
                case .success(let url):
                    print("Conversion completed: \(url)")
                case .failure(let error):
                    print("Conversion failed: \(error)")
                }
            }
        )
    }
    
    /// Convert with custom settings
    func convertWithCustomSettings() {
        let sourceURL = URL(fileURLWithPath: "/path/to/source.flac")
        let outputURL = URL(fileURLWithPath: "/path/to/output.mp3")
        
        // Create custom settings
        let settings = AudioConverter.ConversionSettings(
            outputFormat: .mp3,
            bitrate: 192000,  // 192 kbps
            sampleRate: 44100,
            channelCount: 2,
            preserveMetadata: true,
            overwriteExisting: false,
            quality: 0.8
        )
        
        converter.convertAudioFile(
            from: sourceURL,
            to: outputURL,
            settings: settings,
            completion: { result in
                switch result {
                case .success(let url):
                    print("Custom conversion completed: \(url)")
                case .failure(let error):
                    print("Conversion failed: \(error)")
                }
            }
        )
    }
    
    /// Batch convert multiple files
    func batchConvert() {
        let sourceFiles = [
            URL(fileURLWithPath: "/path/to/file1.wav"),
            URL(fileURLWithPath: "/path/to/file2.wav"),
            URL(fileURLWithPath: "/path/to/file3.wav")
        ]
        let outputDirectory = URL(fileURLWithPath: "/path/to/converted/")
        
        // Convert all to FLAC lossless
        converter.convertAudioFiles(
            from: sourceFiles,
            to: outputDirectory,
            settings: ConversionPreset.HighQuality.flac.settings,
            progress: { progress in
                print("Batch progress: \(progress.completedFiles)/\(progress.totalFiles) files")
                if let currentFile = progress.currentFile {
                    print("Currently converting: \(currentFile.lastPathComponent)")
                }
            },
            completion: { result in
                switch result {
                case .success(let urls):
                    print("Batch conversion completed: \(urls.count) files converted")
                case .failure(let error):
                    print("Batch conversion failed: \(error)")
                }
            }
        )
    }
    
    /// Build a custom preset
    func createCustomPreset() {
        let customPreset = ConversionPresetBuilder()
            .withName("Podcast Export")
            .withDescription("Optimized for podcast distribution")
            .withOutputFormat(.mp3)
            .withBitrate(96000)  // 96 kbps
            .withSampleRate(44100)
            .withChannelCount(1)  // Mono
            .withQuality(0.7)
            .withMetadataPreservation(true)
            .build()
        
        // Use the custom preset
        let sourceURL = URL(fileURLWithPath: "/path/to/podcast.wav")
        let outputURL = URL(fileURLWithPath: "/path/to/podcast_compressed.mp3")
        
        converter.convertAudioFile(
            from: sourceURL,
            to: outputURL,
            preset: customPreset,
            completion: { result in
                print("Podcast conversion: \(result)")
            }
        )
    }
    
    /// Get recommended presets for a format
    func showRecommendedPresets() {
        // Get recommended presets for converting FLAC files
        let flacPresets = ConversionPreset.recommendedPresets(for: .flac)
        
        print("Recommended presets for FLAC:")
        for preset in flacPresets {
            print("- \(preset.name): \(preset.description)")
            print("  Output format: \(preset.settings.outputFormat.displayName)")
            print("  Estimated size: \(Int(preset.estimatedSizeRatio * 100))% of original")
        }
    }
    
    /// Check if conversion is supported
    func checkConversionSupport() {
        let conversions: [(AudioFormat, AudioFormat)] = [
            (.flac, .mp3),
            (.wav, .aac),
            (.mp3, .flac),
            (.opus, .mp3),  // This might not be supported
            (.aac, .alac)
        ]
        
        for (source, target) in conversions {
            let isSupported = AudioConverter.isConversionSupported(from: source, to: target)
            print("\(source.displayName) → \(target.displayName): \(isSupported ? "Supported" : "Not supported")")
        }
    }
    
    /// Cancel conversion
    func cancelConversion() {
        // Start a conversion
        let sourceURL = URL(fileURLWithPath: "/path/to/large_file.wav")
        let outputURL = URL(fileURLWithPath: "/path/to/output.mp3")
        
        converter.convertAudioFile(
            from: sourceURL,
            to: outputURL,
            preset: .StandardQuality.mp3_256vbr,
            progress: { progress in
                print("Progress: \(Int(progress.progress * 100))%")
                
                // Cancel at 50%
                if progress.progress >= 0.5 {
                    self.converter.cancelAllConversions()
                    print("Conversion cancelled at 50%")
                }
            },
            completion: { result in
                if case .failure(let error) = result,
                   case .cancelled = error {
                    print("Conversion was cancelled")
                }
            }
        )
    }
}

// MARK: - SwiftUI Integration Example

import SwiftUI

struct ConversionView: View {
    @State private var sourceFile: URL?
    @State private var selectedPreset: ConversionPreset = .StandardQuality.aac256
    @State private var isConverting = false
    @State private var progress: Double = 0.0
    @State private var errorMessage: String?
    
    private let converter = AudioConverter()
    
    var body: some View {
        VStack(spacing: 20) {
            // File selection
            if let sourceFile = sourceFile {
                HStack {
                    Image(systemName: "music.note")
                    Text(sourceFile.lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    Button("Change") {
                        selectFile()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button("Select Audio File") {
                    selectFile()
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Preset selection
            Picker("Conversion Preset", selection: $selectedPreset) {
                ForEach(ConversionPreset.allPresets, id: \.name) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .disabled(isConverting)
            
            // Preset details
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedPreset.description)
                    .font(.caption)
                Text("Output: \(selectedPreset.settings.outputFormat.displayName)")
                    .font(.caption)
                if let bitrate = selectedPreset.settings.bitrate {
                    Text("Bitrate: \(bitrate / 1000) kbps")
                        .font(.caption)
                }
                Text("Estimated size: \(Int(selectedPreset.estimatedSizeRatio * 100))% of original")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            // Progress
            if isConverting {
                ProgressView(value: progress) {
                    Text("Converting...")
                }
                .progressViewStyle(.linear)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Convert button
            Button(action: convertFile) {
                if isConverting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text("Converting...")
                    }
                } else {
                    Text("Convert")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sourceFile == nil || isConverting)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Audio Converter")
    }
    
    private func selectFile() {
        // In a real app, this would open a file picker
        // For demo purposes, we'll just set a dummy file
        sourceFile = URL(fileURLWithPath: "/Users/Music/sample.wav")
    }
    
    private func convertFile() {
        guard let sourceFile = sourceFile else { return }
        
        isConverting = true
        progress = 0.0
        errorMessage = nil
        
        // Generate output filename
        let outputDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputFilename = sourceFile.deletingPathExtension().lastPathComponent + "." + selectedPreset.settings.outputFormat.fileExtensions.first!
        let outputURL = outputDir.appendingPathComponent(outputFilename)
        
        converter.convertAudioFile(
            from: sourceFile,
            to: outputURL,
            preset: selectedPreset,
            progress: { conversionProgress in
                DispatchQueue.main.async {
                    self.progress = conversionProgress.progress
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isConverting = false
                    
                    switch result {
                    case .success(let url):
                        print("Conversion successful: \(url)")
                        // Show success message or play sound
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }
}