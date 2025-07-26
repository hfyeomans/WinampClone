//
//  MainPlayerView.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02
//  Main player window view replicating classic WinAmp interface
//

import SwiftUI
import Combine
import AVFoundation
import AppKit

// MARK: - Bitmap Font Style

struct BitmapText: View {
    let text: String
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundColor(color)
            .shadow(color: Color.black.opacity(0.5), radius: 1, x: 1, y: 1)
    }
}

// MARK: - LCD Display Component

struct LCDDisplay: View {
    let currentTime: String
    let duration: String
    let bitrate: Int?
    let sampleRate: Int?
    let isStereo: Bool
    @Binding var isTimerMode: Bool // true = remaining time, false = elapsed time
    
    var body: some View {
        HStack(spacing: 0) {
            // Main time display
            VStack(alignment: .leading, spacing: 0) {
                BitmapText(
                    text: isTimerMode ? "-\(duration)" : currentTime,
                    size: 20,
                    color: WinAmpColors.text
                )
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    isTimerMode.toggle()
                }
                
                // Bitrate and sample rate info
                HStack(spacing: 4) {
                    if let bitrate = bitrate {
                        BitmapText(
                            text: "\(bitrate)",
                            size: 9,
                            color: WinAmpColors.textDim
                        )
                    }
                    
                    if let sampleRate = sampleRate {
                        BitmapText(
                            text: "\(sampleRate/1000)",
                            size: 9,
                            color: WinAmpColors.textDim
                        )
                    }
                    
                    BitmapText(
                        text: isStereo ? "stereo" : "mono",
                        size: 9,
                        color: WinAmpColors.textDim
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(WinAmpColors.border, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Transport Button

struct TransportButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Button background
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isPressed ? WinAmpColors.buttonActive : WinAmpColors.backgroundLight,
                                WinAmpColors.background
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(isHovered ? WinAmpColors.borderHighlight : WinAmpColors.border, lineWidth: 1)
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(isHovered ? WinAmpColors.text : WinAmpColors.textDim)
            }
        }
        .frame(width: size, height: size)
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.05)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.05)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Seek Bar

struct SeekBar: View {
    @Binding var progress: Double
    let isEnabled: Bool
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var hoverProgress: Double? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black)
                    .frame(height: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(WinAmpColors.border, lineWidth: 1)
                    )
                
                // Progress fill
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WinAmpColors.accent,
                                WinAmpColors.text
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 6)
                    .offset(x: 1)
                
                // Hover indicator
                if let hoverProgress = hoverProgress {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(WinAmpColors.text.opacity(0.3))
                        .frame(width: 2, height: 10)
                        .offset(x: geometry.size.width * hoverProgress - 1)
                }
                
                // Thumb
                Circle()
                    .fill(WinAmpColors.text)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(WinAmpColors.background, lineWidth: 1)
                    )
                    .offset(x: geometry.size.width * progress - 6)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isEnabled {
                            isDragging = true
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            progress = newProgress
                        }
                    }
                    .onEnded { value in
                        if isEnabled {
                            isDragging = false
                            let finalProgress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(finalProgress)
                        }
                    }
            )
            .onHover { hovering in
                if hovering && isEnabled {
                    // Track mouse position for hover effect
                } else {
                    hoverProgress = nil
                }
            }
            .disabled(!isEnabled)
        }
    }
}

// MARK: - Volume/Balance Slider

struct WinAmpSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let hasCenter: Bool
    let onChanged: (Float) -> Void
    
    @State private var isDragging = false
    @State private var isHovered = false
    
    var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black)
                    .frame(height: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(WinAmpColors.border, lineWidth: 1)
                    )
                
                // Center notch (for balance)
                if hasCenter {
                    Rectangle()
                        .fill(WinAmpColors.borderHighlight)
                        .frame(width: 1, height: 8)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                // Thumb
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WinAmpColors.accent,
                                WinAmpColors.text
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(isHovered ? WinAmpColors.text : WinAmpColors.border, lineWidth: 1)
                    )
                    .offset(x: geometry.size.width * CGFloat(normalizedValue) - 7)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let normalizedX = max(0, min(1, Float(drag.location.x / geometry.size.width)))
                        let newValue = range.lowerBound + normalizedX * (range.upperBound - range.lowerBound)
                        
                        // Snap to center for balance
                        if hasCenter && abs(newValue) < 0.05 {
                            value = 0
                        } else {
                            value = newValue
                        }
                        onChanged(value)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}

// MARK: - Main Player Clutterbar Button

struct MainPlayerClutterbarButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(isHovered ? WinAmpColors.text : WinAmpColors.textDim)
                .frame(width: 16, height: 12)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WinAmpColors.backgroundLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(WinAmpColors.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Main Player View

public struct MainPlayerView: View {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var volumeController: VolumeBalanceController
    @StateObject private var windowCommunicator = WindowCommunicator.shared
    @StateObject private var fftProcessor = FFTProcessor()
    
    // UI State
    @State private var isTimerMode = false
    @State private var seekProgress: Double = 0
    @State private var volume: Float = 0.7
    @State private var balance: Float = 0.0
    @State private var visualizationMode: VisualizationMode = .spectrum
    @State private var isVisualizationVisible = true
    @State private var visualizationData: AudioVisualizationData?
    
    // Track info
    @State private var currentTrack: Track?
    @State private var bitrate: Int? = 128
    @State private var sampleRate: Int? = 44100
    @State private var isStereo: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        let engine = AudioEngine()
        let controller = VolumeBalanceController(audioEngine: engine.audioEngine)
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: controller)
    }
    
    public var body: some View {
        WinAmpWindow(
            configuration: WinAmpWindowConfiguration(
                title: "WINAMP",
                windowType: .main,
                resizable: false,
                minSize: CGSize(width: 275, height: 116),
                maxSize: CGSize(width: 275, height: 116)
            )
        ) {
            VStack(spacing: 0) {
                // Visualization area (classic WinAmp position)
                if isVisualizationVisible {
                    HStack(spacing: 4) {
                        // Visualization display
                        SimpleVisualizationView(
                            mode: $visualizationMode,
                            audioEngine: audioEngine
                        )
                        .frame(height: 16)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(WinAmpColors.border, lineWidth: 1)
                        )
                        
                        // Mode toggle button
                        Button(action: {
                            visualizationMode = visualizationMode == .spectrum ? .oscilloscope : .spectrum
                        }) {
                            Image(systemName: visualizationMode == .spectrum ? "waveform.path.ecg" : "waveform")
                                .font(.system(size: 8))
                                .foregroundColor(WinAmpColors.text)
                                .frame(width: 20, height: 16)
                                .background(WinAmpColors.backgroundLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 1)
                                        .stroke(WinAmpColors.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                }
                
                // Main content area
                VStack(spacing: 4) {
                    // Top section with LCD display and clutterbar
                    HStack(spacing: 4) {
                    // LCD Display
                    LCDDisplay(
                        currentTime: formatTime(audioEngine.currentTime),
                        duration: formatTime(audioEngine.duration - audioEngine.currentTime),
                        bitrate: bitrate,
                        sampleRate: sampleRate,
                        isStereo: isStereo,
                        isTimerMode: $isTimerMode
                    )
                    
                    Spacer()
                    
                    // Clutterbar
                    HStack(spacing: 2) {
                        MainPlayerClutterbarButton(icon: "option") {
                            // Options menu
                        }
                        MainPlayerClutterbarButton(icon: "filemenu.and.selection") {
                            // File menu
                        }
                        MainPlayerClutterbarButton(icon: "waveform") {
                            isVisualizationVisible.toggle()
                        }
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                
                // Track info display
                if let track = currentTrack {
                    HStack {
                        BitmapText(
                            text: "\(track.displayArtist) - \(track.displayTitle)",
                            size: 11,
                            color: WinAmpColors.text
                        )
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                } else {
                    HStack {
                        BitmapText(
                            text: "WINAMP 5.0",
                            size: 11,
                            color: WinAmpColors.textDim
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                }
                
                // Seek bar
                SeekBar(
                    progress: $seekProgress,
                    isEnabled: audioEngine.duration > 0,
                    onSeek: { progress in
                        try? audioEngine.seek(to: audioEngine.duration * progress)
                    }
                )
                .frame(height: 12)
                .padding(.horizontal, 8)
                
                // Transport controls
                HStack(spacing: 2) {
                    TransportButton(icon: "backward.fill", action: previousTrack, size: 30)
                    TransportButton(icon: audioEngine.isPlaying ? "pause.fill" : "play.fill", action: togglePlayPause, size: 36)
                    TransportButton(icon: "stop.fill", action: stop, size: 30)
                    TransportButton(icon: "forward.fill", action: nextTrack, size: 30)
                    
                    Spacer()
                    
                    // Eject button
                    TransportButton(icon: "eject.fill", action: openFile, size: 24)
                }
                .padding(.horizontal, 8)
                
                // Volume and balance controls
                HStack(spacing: 8) {
                    // Volume
                    VStack(spacing: 2) {
                        BitmapText(text: "VOL", size: 8, color: WinAmpColors.textDim)
                        WinAmpSlider(
                            value: $volume,
                            range: 0...1,
                            hasCenter: false,
                            onChanged: { value in
                                audioEngine.volume = value
                                volumeController.setVolume(value)
                                broadcastVolumeChange()
                            }
                        )
                        .frame(width: 60)
                    }
                    
                    // Balance
                    VStack(spacing: 2) {
                        BitmapText(text: "BAL", size: 8, color: WinAmpColors.textDim)
                        WinAmpSlider(
                            value: $balance,
                            range: -1...1,
                            hasCenter: true,
                            onChanged: { value in
                                volumeController.setBalance(value)
                                broadcastVolumeChange()
                            }
                        )
                        .frame(width: 60)
                    }
                    
                    Spacer()
                    
                    // Window buttons
                    HStack(spacing: 2) {
                        MainPlayerClutterbarButton(icon: "waveform.badge.plus") {
                            WindowManager.shared.toggleWindow(.equalizer)
                        }
                        MainPlayerClutterbarButton(icon: "list.bullet") {
                            WindowManager.shared.toggleWindow(.playlist)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                }
            }
            .frame(width: 275, height: 116)
            .background(WinAmpColors.background)
        }
        .onAppear {
            setupAudioEngine()
            setupKeyboardShortcuts()
            updateSeekProgress()
        }
        .onReceive(audioEngine.$currentTime) { _ in
            updateSeekProgress()
        }
        .onReceive(audioEngine.$currentTrack) { track in
            currentTrack = track
            updateTrackInfo()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        audioEngine.setVolumeController(volumeController)
        audioEngine.volume = volume
        
        // Enable visualization
        audioEngine.enableVisualization()
        
        // Register window
        WindowCommunicator.shared.registerWindow("main")
    }
    
    private func setupKeyboardShortcuts() {
        // This would be implemented with proper keyboard event handling
        // Space = play/pause
        // Arrow keys = seek
    }
    
    private func updateSeekProgress() {
        if !audioEngine.isPlaying || audioEngine.duration == 0 {
            return
        }
        seekProgress = audioEngine.currentTime / audioEngine.duration
    }
    
    private func updateTrackInfo() {
        guard let track = currentTrack else {
            bitrate = nil
            sampleRate = nil
            return
        }
        
        // Update audio properties
        if let properties = track.audioProperties {
            bitrate = properties.bitrate.map { $0 / 1000 } // Convert to kbps
            sampleRate = properties.sampleRate
            isStereo = (properties.channelCount ?? 2) > 1
        }
        
        // Broadcast track change
        broadcastTrackChange()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    
    private func togglePlayPause() {
        audioEngine.togglePlayPause()
        broadcastPlaybackState()
    }
    
    private func stop() {
        audioEngine.stop()
        seekProgress = 0
        broadcastPlaybackState()
    }
    
    private func previousTrack() {
        // This would be implemented with playlist integration
        WindowCommunicator.shared.send(
            PlaylistSelectionMessage(
                sourceWindowID: "main",
                targetWindowID: "playlist",
                selectedIndex: nil,
                selectedIndices: nil
            )
        )
    }
    
    private func nextTrack() {
        // This would be implemented with playlist integration
        WindowCommunicator.shared.send(
            PlaylistSelectionMessage(
                sourceWindowID: "main",
                targetWindowID: "playlist",
                selectedIndex: nil,
                selectedIndices: nil
            )
        )
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = Track.supportedExtensions
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                try? await audioEngine.loadURL(url)
                try? audioEngine.play()
            }
        }
    }
    
    // MARK: - Window Communication
    
    private func broadcastPlaybackState() {
        let state: PlaybackStateMessage.PlaybackState
        switch audioEngine.playbackState {
        case .playing:
            state = .playing
        case .paused:
            state = .paused
        case .stopped:
            state = .stopped
        case .loading:
            state = .loading
        default:
            state = .stopped
        }
        
        WindowCommunicator.shared.broadcastPlaybackState(
            state,
            position: audioEngine.currentTime,
            from: "main"
        )
    }
    
    private func broadcastTrackChange() {
        guard let track = currentTrack else { return }
        
        let trackInfo = TrackChangeMessage.TrackInfo(
            title: track.displayTitle,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            bitrate: track.audioProperties?.bitrate,
            sampleRate: track.audioProperties?.sampleRate,
            fileURL: track.fileURL
        )
        
        WindowCommunicator.shared.broadcastTrackChange(trackInfo, from: "main")
    }
    
    private func broadcastVolumeChange() {
        WindowCommunicator.shared.broadcastVolumeChange(
            volume: volume,
            balance: balance,
            from: "main"
        )
    }
}

// MARK: - Simple Visualization View

struct SimpleVisualizationView: View {
    @Binding var mode: VisualizationMode
    @ObservedObject var audioEngine: AudioEngine
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 16)
    @State private var waveformPoints: [CGFloat] = Array(repeating: 0.5, count: 32)
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            if mode == .spectrum {
                // Spectrum analyzer bars
                HStack(spacing: 1) {
                    ForEach(0..<barHeights.count, id: \.self) { index in
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            WinAmpColors.accent,
                                            WinAmpColors.text
                                        ]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: barHeights[index] * geometry.size.height)
                        }
                    }
                }
            } else {
                // Oscilloscope waveform
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(waveformPoints.count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: waveformPoints[0] * height))
                    
                    for i in 1..<waveformPoints.count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: waveformPoints[i] * height))
                    }
                }
                .stroke(WinAmpColors.text, lineWidth: 1)
            }
        }
        .onReceive(timer) { _ in
            updateVisualization()
        }
        .onReceive(audioEngine.audioVisualizationDataPublisher) { data in
            updateVisualizationWithData(data)
        }
    }
    
    private func updateVisualization() {
        if audioEngine.isPlaying {
            if mode == .spectrum {
                // Simulate spectrum data with random variations
                for i in 0..<barHeights.count {
                    let targetHeight = CGFloat.random(in: 0.1...0.8) * 
                                      (1.0 - CGFloat(i) / CGFloat(barHeights.count))
                    barHeights[i] = barHeights[i] * 0.7 + targetHeight * 0.3
                }
            } else {
                // Simulate waveform with sine wave variations
                let phase = Date().timeIntervalSince1970 * 2
                for i in 0..<waveformPoints.count {
                    let x = Double(i) / Double(waveformPoints.count - 1)
                    let wave = sin(x * .pi * 4 + phase) * 0.3 + 0.5
                    waveformPoints[i] = CGFloat(wave)
                }
            }
        } else {
            // Decay to zero when not playing
            if mode == .spectrum {
                for i in 0..<barHeights.count {
                    barHeights[i] *= 0.9
                }
            } else {
                for i in 0..<waveformPoints.count {
                    waveformPoints[i] = waveformPoints[i] * 0.9 + 0.5 * 0.1
                }
            }
        }
    }
    
    private func updateVisualizationWithData(_ data: AudioVisualizationData) {
        // If we have real audio data, use it
        if mode == .spectrum && !data.leftChannel.isEmpty {
            // Convert time-domain to frequency-domain using simple averaging
            let samplesPerBar = data.leftChannel.count / barHeights.count
            for i in 0..<barHeights.count {
                var sum: Float = 0
                let start = i * samplesPerBar
                let end = min((i + 1) * samplesPerBar, data.leftChannel.count)
                
                for j in start..<end {
                    sum += abs(data.leftChannel[j])
                }
                
                let average = sum / Float(samplesPerBar)
                barHeights[i] = CGFloat(average)
            }
        } else if mode == .oscilloscope && !data.leftChannel.isEmpty {
            // Use waveform data directly
            let step = data.leftChannel.count / waveformPoints.count
            for i in 0..<waveformPoints.count {
                let index = min(i * step, data.leftChannel.count - 1)
                waveformPoints[i] = CGFloat(data.leftChannel[index]) * 0.5 + 0.5
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MainPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        MainPlayerView()
            .preferredColorScheme(.dark)
    }
}
#endif