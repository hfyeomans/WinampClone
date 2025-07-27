//
//  SkinnableMainPlayerView.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26
//  Main player window view with full skin support
//

import SwiftUI
import Combine
import AVFoundation
import AppKit

/// Main player window with skin support
public struct SkinnableMainPlayerView: View {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var volumeController: VolumeBalanceController
    @StateObject private var playlistController: PlaylistController
    @StateObject private var windowCommunicator = WindowCommunicator.shared
    @StateObject private var skinManager = SkinManager.shared
    
    // UI State
    @State private var isTimerMode = false
    @State private var seekProgress: Double = 0
    @State private var volume: Float = 0.7
    @State private var balance: Float = 0.0
    @State private var visualizationMode: VisualizationMode = .spectrum
    @State private var isVisualizationVisible = true
    @State private var shuffleEnabled = false
    @State private var repeatEnabled = false
    @State private var eqEnabled = false
    @State private var plEnabled = false
    
    // Track info
    @State private var currentTrack: Track?
    @State private var bitrate: Int? = 128
    @State private var sampleRate: Int? = 44100
    @State private var isStereo: Bool = true
    
    private let windowSize = CGSize(width: 275, height: 116)
    
    public init() {
        let engine = AudioEngine()
        let volumeCtrl = VolumeBalanceController(audioEngine: engine.audioEngine)
        let playlistCtrl = PlaylistController(audioEngine: engine, volumeController: volumeCtrl)
        engine.setVolumeController(volumeCtrl)
        _audioEngine = StateObject(wrappedValue: engine)
        _volumeController = StateObject(wrappedValue: volumeCtrl)
        _playlistController = StateObject(wrappedValue: playlistCtrl)
    }
    
    public var body: some View {
        ZStack {
            // Background sprite
            SpriteView(.mainBackground)
                .frame(width: windowSize.width, height: windowSize.height)
            
            VStack(spacing: 0) {
                // Title bar
                titleBar
                    .frame(height: 14)
                
                // Main content
                VStack(spacing: 0) {
                    // Top section with displays
                    HStack(spacing: 0) {
                        // Time display
                        timeDisplay
                            .frame(width: 88, height: 26)
                            .padding(.leading, 24)
                        
                        // Bitrate/Frequency display
                        VStack(spacing: 0) {
                            HStack(spacing: 2) {
                                SkinnableBitrateDisplay(bitrate: bitrate)
                                SkinnableSampleRateDisplay(sampleRate: sampleRate)
                            }
                            .frame(height: 10)
                            
                            // Stereo/Mono indicator
                            if isStereo {
                                SpriteView(.stereoIndicator)
                            } else {
                                SpriteView(.monoIndicator)
                            }
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                        
                        // Visualization
                        if isVisualizationVisible {
                            visualizationView
                                .frame(width: 76, height: 16)
                                .padding(.trailing, 8)
                        }
                    }
                    .frame(height: 30)
                    .padding(.top, 4)
                    
                    // Track info marquee
                    trackInfoView
                        .frame(height: 14)
                        .padding(.horizontal, 10)
                    
                    // Transport controls
                    HStack(spacing: 0) {
                        TransportControlButton(type: .previous, action: previousTrack)
                        TransportControlButton(type: .play, action: togglePlayPause)
                        TransportControlButton(type: .pause, action: togglePlayPause)
                        TransportControlButton(type: .stop, action: stop)
                        TransportControlButton(type: .next, action: nextTrack)
                        
                        Spacer()
                        
                        TransportControlButton(type: .eject, action: openFile)
                            .padding(.trailing, 4)
                    }
                    .frame(height: 18)
                    .padding(.leading, 16)
                    .padding(.top, 2)
                    
                    // Shuffle/Repeat toggles
                    HStack(spacing: 0) {
                        SkinnableToggleButton(
                            isOn: $shuffleEnabled,
                            offNormal: .shuffleButton(false, .normal),
                            offPressed: .shuffleButton(false, .pressed),
                            onNormal: .shuffleButton(true, .normal),
                            onPressed: .shuffleButton(true, .pressed)
                        )
                        
                        SkinnableToggleButton(
                            isOn: $repeatEnabled,
                            offNormal: .repeatButton(false, .normal),
                            offPressed: .repeatButton(false, .pressed),
                            onNormal: .repeatButton(true, .normal),
                            onPressed: .repeatButton(true, .pressed)
                        )
                        
                        Spacer()
                    }
                    .frame(height: 15)
                    .padding(.leading, 16)
                    .padding(.top, 2)
                    
                    // Bottom section with sliders and window buttons
                    HStack(spacing: 8) {
                        // Volume slider
                        SkinnableVolumeSlider(volume: $volume) { value in
                            audioEngine.volume = value
                            volumeController.setVolume(value)
                            broadcastVolumeChange()
                        }
                        .frame(width: 68, height: 13)
                        
                        // Balance slider
                        SkinnableBalanceSlider(balance: $balance) { value in
                            volumeController.setBalance(value)
                            broadcastVolumeChange()
                        }
                        .frame(width: 38, height: 13)
                        
                        Spacer()
                        
                        // Window buttons
                        HStack(spacing: 4) {
                            SkinnableToggleButton(
                                isOn: $eqEnabled,
                                offNormal: .equalizerButton(false, .normal),
                                offPressed: .equalizerButton(false, .pressed),
                                onNormal: .equalizerButton(true, .normal),
                                onPressed: .equalizerButton(true, .pressed)
                            )
                            .onChange(of: eqEnabled) { newValue in
                                if newValue {
                                    SecondaryWindowManager.shared.toggleWindow(.equalizer, audioEngine: audioEngine)
                                }
                            }
                            
                            SkinnableToggleButton(
                                isOn: $plEnabled,
                                offNormal: .playlistButton(false, .normal),
                                offPressed: .playlistButton(false, .pressed),
                                onNormal: .playlistButton(true, .normal),
                                onPressed: .playlistButton(true, .pressed)
                            )
                            .onChange(of: plEnabled) { newValue in
                                if newValue {
                                    SecondaryWindowManager.shared.toggleWindow(.playlist, playlistController: playlistController)
                                }
                            }
                        }
                    }
                    .frame(height: 15)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    
                    // Position slider
                    SkinnablePositionSlider(
                        position: $seekProgress,
                        duration: audioEngine.duration,
                        onSeek: { position in
                            try? audioEngine.seek(to: position)
                        }
                    )
                    .frame(height: 10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .skinTransition(style: .fade)
        .onAppear {
            setupAudioEngine()
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
    
    // MARK: - Components
    
    private var titleBar: some View {
        ZStack {
            // Title bar background
            if audioEngine.isPlaying {
                SpriteView(.titleBarActive)
            } else {
                SpriteView(.titleBarInactive)
            }
            
            HStack {
                // Menu button
                SkinnableButton(
                    normal: .menuButton(.normal),
                    pressed: .menuButton(.pressed),
                    action: { /* Show menu */ }
                )
                .frame(width: 9, height: 9)
                .padding(.leading, 6)
                
                Spacer()
                
                // Window controls
                HStack(spacing: 0) {
                    SkinnableButton(
                        normal: .minimizeButton(.normal),
                        pressed: .minimizeButton(.pressed),
                        action: { NSApp.keyWindow?.miniaturize(nil) }
                    )
                    .frame(width: 9, height: 9)
                    
                    SkinnableButton(
                        normal: .shadeButton(.normal),
                        pressed: .shadeButton(.pressed),
                        action: { /* Toggle shade mode */ }
                    )
                    .frame(width: 9, height: 9)
                    
                    SkinnableButton(
                        normal: .closeButton(.normal),
                        pressed: .closeButton(.pressed),
                        action: { NSApp.terminate(nil) }
                    )
                    .frame(width: 9, height: 9)
                }
                .padding(.trailing, 6)
            }
        }
    }
    
    private var timeDisplay: some View {
        VStack(spacing: 0) {
            SkinnableTimeDisplay(
                time: isTimerMode ? (audioEngine.duration - audioEngine.currentTime) : audioEngine.currentTime,
                showRemaining: isTimerMode
            )
            .onTapGesture {
                isTimerMode.toggle()
            }
            
            // Play status indicator
            HStack(spacing: 1) {
                if audioEngine.isPlaying {
                    SpriteView(.playingIndicator)
                } else if audioEngine.playbackState == .paused {
                    SpriteView(.pausedIndicator)
                } else {
                    SpriteView(.stoppedIndicator)
                }
            }
        }
    }
    
    private var trackInfoView: some View {
        Group {
            if let track = currentTrack {
                Text("\(track.displayArtist) - \(track.displayTitle)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(WinAmpColors.text))
                    .lineLimit(1)
            } else {
                Text("WINAMP")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(WinAmpColors.textDim))
            }
        }
    }
    
    private var visualizationView: some View {
        // Placeholder for visualization
        Rectangle()
            .fill(Color.black)
            .overlay(
                SimpleVisualizationView(
                    mode: $visualizationMode,
                    audioEngine: audioEngine
                )
            )
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        audioEngine.setVolumeController(volumeController)
        audioEngine.volume = volume
        audioEngine.enableVisualization()
        WindowCommunicator.shared.registerWindow("main")
    }
    
    private func updateSeekProgress() {
        if audioEngine.duration > 0 {
            seekProgress = audioEngine.currentTime
        }
    }
    
    private func updateTrackInfo() {
        guard let track = currentTrack else {
            bitrate = nil
            sampleRate = nil
            return
        }
        
        if let properties = track.audioProperties {
            bitrate = properties.bitrate.map { $0 / 1000 }
            sampleRate = properties.sampleRate
            isStereo = (properties.channelCount ?? 2) > 1
        }
        
        broadcastTrackChange()
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
        Task {
            try? await playlistController.playPrevious()
        }
    }
    
    private func nextTrack() {
        Task {
            try? await playlistController.playNext()
        }
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