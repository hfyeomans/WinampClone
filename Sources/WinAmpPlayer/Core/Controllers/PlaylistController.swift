//
//  PlaylistController.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Central controller that bridges between UI, playlist model, and audio engine.
//

import Foundation
import Combine
import AVFoundation

/// Central controller for playlist management and playback coordination
@MainActor
class PlaylistController: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentPlaylist: Playlist?
    @Published var isPlaying: Bool = false
    @Published var currentTrack: Track? {
        didSet {
            if let track = currentTrack {
                updateNowPlayingInfo(track)
            }
        }
    }
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.5
    @Published var isLoading: Bool = false
    
    // Queue management
    @Published var playQueue: [Track] = []
    @Published var queueIndex: Int?
    
    // MARK: - Dependencies
    
    private let audioEngine: AudioEngine
    private let audioQueueManager: AudioQueueManager
    private var volumeController: VolumeBalanceController?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var trackCompletionObserver: Any?
    private var isTransitioning = false
    
    // MARK: - Initialization
    
    init(audioEngine: AudioEngine, volumeController: VolumeBalanceController? = nil) {
        self.audioEngine = audioEngine
        self.audioQueueManager = AudioQueueManager(audioEngine: audioEngine)
        self.volumeController = volumeController
        
        setupBindings()
        setupNotifications()
    }
    
    deinit {
        if let observer = trackCompletionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Sync with audio engine state
        audioEngine.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPlaying)
        
        audioEngine.$currentTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTime)
        
        audioEngine.$duration
            .receive(on: DispatchQueue.main)
            .assign(to: &$duration)
        
        audioEngine.$volume
            .receive(on: DispatchQueue.main)
            .assign(to: &$volume)
        
        audioEngine.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        // Monitor playback state changes
        audioEngine.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handlePlaybackStateChange(state)
            }
            .store(in: &cancellables)
        
        // Sync current track
        audioEngine.$currentTrack
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTrack)
    }
    
    private func setupNotifications() {
        // Listen for track completion
        trackCompletionObserver = NotificationCenter.default.addObserver(
            forName: .audioPlaybackCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackCompletion()
        }
    }
    
    // MARK: - Playlist Management
    
    /// Load a playlist and prepare for playback
    func loadPlaylist(_ playlist: Playlist) {
        currentPlaylist = playlist
        
        // If playlist has a current track, prepare it
        if let track = playlist.currentTrack {
            Task {
                try? await prepareTrack(track)
            }
        }
    }
    
    /// Create a new playlist from tracks
    func createPlaylist(name: String, tracks: [Track]) -> Playlist {
        let playlist = Playlist(name: name, tracks: tracks)
        currentPlaylist = playlist
        return playlist
    }
    
    // MARK: - Playback Control
    
    /// Play the current track or resume playback
    func play() async throws {
        if let playlist = currentPlaylist {
            if playlist.currentTrack == nil && !playlist.isEmpty {
                // No current track, start from beginning
                _ = playlist.selectTrack(at: 0)
            }
            
            if let track = playlist.currentTrack {
                if audioEngine.currentTrack?.id != track.id {
                    // Load the track if it's different
                    try await audioEngine.loadTrack(track)
                }
                try audioEngine.play()
                updatePlaylistPlayCount()
            }
        } else if !playQueue.isEmpty {
            // Play from queue
            try await playFromQueue()
        }
    }
    
    /// Pause playback
    func pause() {
        audioEngine.pause()
    }
    
    /// Toggle play/pause
    func togglePlayPause() async throws {
        if isPlaying {
            pause()
        } else {
            try await play()
        }
    }
    
    /// Stop playback and reset position
    func stop() {
        audioEngine.stop()
        currentTime = 0
    }
    
    /// Play next track
    func playNext() async throws {
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
        
        // Check play queue first
        if !playQueue.isEmpty && queueIndex != nil {
            try await playNextFromQueue()
            return
        }
        
        // Otherwise use playlist
        guard let playlist = currentPlaylist else { return }
        
        if let nextTrack = playlist.selectNextTrack() {
            try await audioEngine.loadTrack(nextTrack)
            try audioEngine.play()
            updatePlaylistPlayCount()
        } else {
            // End of playlist
            stop()
        }
    }
    
    /// Play previous track
    func playPrevious() async throws {
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
        
        // If we're more than 3 seconds into the track, restart it
        if currentTime > 3.0 {
            try audioEngine.seek(to: 0)
            return
        }
        
        guard let playlist = currentPlaylist else { return }
        
        if let previousTrack = playlist.selectPreviousTrack() {
            try await audioEngine.loadTrack(previousTrack)
            try audioEngine.play()
            updatePlaylistPlayCount()
        }
    }
    
    /// Play a specific track
    func playTrack(_ track: Track) async throws {
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
        
        if let playlist = currentPlaylist,
           let index = playlist.tracks.firstIndex(where: { $0.id == track.id }) {
            _ = playlist.selectTrack(at: index)
        }
        
        try await audioEngine.loadTrack(track)
        try audioEngine.play()
        updatePlaylistPlayCount()
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) throws {
        try audioEngine.seek(to: time)
    }
    
    // MARK: - Queue Management
    
    /// Add track to play queue
    func addToQueue(_ track: Track) {
        playQueue.append(track)
        audioQueueManager.addToQueue(track)
    }
    
    /// Add multiple tracks to play queue
    func addToQueue(_ tracks: [Track]) {
        playQueue.append(contentsOf: tracks)
        audioQueueManager.addToQueue(tracks)
    }
    
    /// Clear play queue
    func clearQueue() {
        playQueue.removeAll()
        queueIndex = nil
        audioQueueManager.clearQueue()
    }
    
    /// Play next track from queue
    private func playNextFromQueue() async throws {
        guard let currentIndex = queueIndex else {
            queueIndex = 0
            if !playQueue.isEmpty {
                let track = playQueue[0]
                try await audioEngine.loadTrack(track)
                try audioEngine.play()
            }
            return
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex < playQueue.count {
            queueIndex = nextIndex
            let track = playQueue[nextIndex]
            try await audioEngine.loadTrack(track)
            try audioEngine.play()
        } else {
            // Queue finished, clear it
            clearQueue()
            // Continue with playlist
            try await playNext()
        }
    }
    
    /// Play from queue starting at the beginning
    private func playFromQueue() async throws {
        queueIndex = 0
        if !playQueue.isEmpty {
            let track = playQueue[0]
            try await audioEngine.loadTrack(track)
            try audioEngine.play()
        }
    }
    
    // MARK: - Shuffle & Repeat
    
    /// Toggle shuffle mode
    func toggleShuffle() {
        guard let playlist = currentPlaylist else { return }
        
        let newMode: ShuffleMode = playlist.shuffleMode == .off ? .random : .off
        playlist.setShuffleMode(newMode)
        
        // Also update audio queue manager
        audioQueueManager.toggleShuffle()
    }
    
    /// Set repeat mode
    func setRepeatMode(_ mode: RepeatMode) {
        currentPlaylist?.repeatMode = mode
    }
    
    /// Cycle through repeat modes
    func cycleRepeatMode() {
        guard let playlist = currentPlaylist else { return }
        
        switch playlist.repeatMode {
        case .off:
            playlist.repeatMode = .all
        case .all:
            playlist.repeatMode = .one
        case .one:
            playlist.repeatMode = .off
        case .abLoop:
            playlist.repeatMode = .off
        }
    }
    
    // MARK: - Volume Control
    
    /// Set volume
    func setVolume(_ volume: Float) {
        audioEngine.volume = volume
        volumeController?.setVolume(volume)
    }
    
    /// Set balance
    func setBalance(_ balance: Float) {
        volumeController?.setBalance(balance)
    }
    
    // MARK: - Private Methods
    
    private func prepareTrack(_ track: Track) async throws {
        try await audioEngine.loadTrack(track)
    }
    
    private func handlePlaybackStateChange(_ state: PlaybackState) {
        switch state {
        case .stopped:
            isPlaying = false
        case .playing:
            isPlaying = true
        case .paused:
            isPlaying = false
        case .loading:
            isLoading = true
        case .error(let error):
            isPlaying = false
            isLoading = false
            // Handle error appropriately
            print("Playback error: \(error)")
        }
    }
    
    private func handleTrackCompletion() {
        Task {
            do {
                try await playNext()
            } catch {
                print("Failed to play next track: \(error)")
            }
        }
    }
    
    private func updatePlaylistPlayCount() {
        guard let playlist = currentPlaylist,
              let index = playlist.currentTrackIndex else { return }
        
        // This will update the play count and last played date
        playlist.playlistItems[index].playCountInPlaylist += 1
        playlist.playlistItems[index].lastPlayedInPlaylist = Date()
        playlist.metadata.totalPlayCount += 1
        playlist.metadata.lastPlayedDate = Date()
    }
    
    private func updateNowPlayingInfo(_ track: Track) {
        // Update system now playing info (for media keys, etc.)
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        
        if let artworkData = track.albumArtwork,
           let image = NSImage(data: artworkData) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

// MARK: - Keyboard Shortcuts Support

extension PlaylistController {
    /// Handle keyboard shortcut for play/pause (Space)
    func handlePlayPauseShortcut() {
        Task {
            try? await togglePlayPause()
        }
    }
    
    /// Handle keyboard shortcut for next track (Right Arrow)
    func handleNextTrackShortcut() {
        Task {
            try? await playNext()
        }
    }
    
    /// Handle keyboard shortcut for previous track (Left Arrow)
    func handlePreviousTrackShortcut() {
        Task {
            try? await playPrevious()
        }
    }
    
    /// Handle keyboard shortcut for volume up (Up Arrow)
    func handleVolumeUpShortcut() {
        let newVolume = min(1.0, volume + 0.05)
        setVolume(newVolume)
    }
    
    /// Handle keyboard shortcut for volume down (Down Arrow)
    func handleVolumeDownShortcut() {
        let newVolume = max(0.0, volume - 0.05)
        setVolume(newVolume)
    }
    
    /// Handle keyboard shortcut for shuffle toggle (S)
    func handleShuffleShortcut() {
        toggleShuffle()
    }
    
    /// Handle keyboard shortcut for repeat cycle (R)
    func handleRepeatShortcut() {
        cycleRepeatMode()
    }
}

// MARK: - Media Player Framework imports

import MediaPlayer