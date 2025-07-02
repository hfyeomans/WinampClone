# Playlist Integration Guide

## Overview

The WinAmp Player now features a fully integrated playlist system that seamlessly works with the audio engine. This guide explains how the components work together.

## Architecture

### Core Components

1. **Playlist Model** (`Sources/WinAmpPlayer/Core/Models/Playlist.swift`)
   - Manages track collection and metadata
   - Handles shuffle modes (off, random, weighted, intelligent)
   - Supports repeat modes (off, all, one, A-B loop)
   - Tracks play history and statistics
   - Provides smart playlist functionality

2. **PlaylistController** (`Sources/WinAmpPlayer/Core/Controllers/PlaylistController.swift`)
   - Central bridge between UI, playlist model, and audio engine
   - Manages playback state and transitions
   - Handles play queue vs main playlist
   - Coordinates shuffle and repeat logic
   - Updates now playing information

3. **AudioQueueManager** (`Sources/WinAmpPlayer/Core/AudioEngine/AudioQueueManager.swift`)
   - Enhanced to work with Playlist model
   - Manages seamless track transitions
   - Supports crossfading between tracks
   - Prebuffers upcoming tracks for gapless playback

4. **PlaylistView** (`Sources/WinAmpPlayer/UI/Views/PlaylistView.swift`)
   - WinAmp-style playlist UI
   - Drag & drop support for reordering
   - Double-click to play
   - Context menu for track operations
   - Real-time updates of playing status

## Key Features

### Shuffle Modes
- **Off**: Sequential playback
- **Random**: Pure random selection
- **Weighted**: Less-played tracks have higher probability
- **Intelligent**: Groups by genre/mood for better flow

### Repeat Modes
- **Off**: Stop at end of playlist
- **All**: Loop entire playlist
- **One**: Repeat current track
- **A-B Loop**: Loop section of track

### Queue Management
- Separate play queue that takes priority over playlist
- Queue automatically cleared after playing
- Smooth transition back to playlist after queue

### Track Completion & Auto-advance
- Automatic progression to next track
- Respects shuffle and repeat settings
- Handles end-of-playlist scenarios

### Keyboard Shortcuts
- **Space**: Play/Pause
- **Left Arrow**: Previous track
- **Right Arrow**: Next track
- **Up Arrow**: Volume up
- **Down Arrow**: Volume down
- **S**: Toggle shuffle
- **R**: Cycle repeat mode
- **P**: Show/hide playlist

## Usage Example

```swift
// Initialize the system
let audioEngine = AudioEngine()
let volumeController = VolumeBalanceController(audioEngine: audioEngine.audioEngine)
let playlistController = PlaylistController(audioEngine: audioEngine, volumeController: volumeController)

// Create and load a playlist
let playlist = Playlist(name: "My Music")
playlist.addTracks(tracks)
playlistController.loadPlaylist(playlist)

// Start playback
try await playlistController.play()

// Control playback
try await playlistController.playNext()
playlistController.toggleShuffle()
playlistController.cycleRepeatMode()

// Add to queue
playlistController.addToQueue(track)
```

## Integration Points

### ContentView Integration
The main ContentView has been updated to use PlaylistController instead of directly controlling the AudioEngine. This provides:
- Unified playback control
- Automatic playlist management
- Consistent state across UI

### File Import
When files are imported:
1. Tracks are created from file URLs
2. Added to the current playlist
3. First track automatically starts playing
4. Subsequent imports add to playlist

### State Management
- PlaylistController maintains synchronized state
- Published properties update UI automatically
- Playlist changes persist across sessions

## Best Practices

1. **Always use PlaylistController** for playback control
2. **Load playlist before playing** to ensure proper initialization
3. **Handle errors gracefully** - tracks may fail to load
4. **Update playlist metadata** when tracks complete
5. **Clean up missing tracks** periodically

## Future Enhancements

- Playlist file format support (M3U, PLS, XSPF)
- Smart playlist creation UI
- Crossfade duration adjustment
- Gapless playback optimization
- Playlist sharing functionality