# WinAmp Player - Pre-Release Testing Checklist for macOS 15.5

## System Requirements
- [x] macOS 15.5 or later
- [x] Xcode 15.0 or later  
- [x] Swift 5.9+
- [x] 4GB RAM minimum
- [x] 100MB free disk space

## Build Verification
- [ ] Clean build succeeds without warnings
- [ ] Release build optimization enabled
- [ ] Code signing configured (for distribution)
- [ ] Package.swift targets macOS 15.0+

## Core Functionality Testing

### Audio Engine
- [ ] MP3 playback works correctly
- [ ] AAC/M4A playback works correctly  
- [ ] FLAC playback works correctly
- [ ] WAV/AIFF playback works correctly
- [ ] OGG Vorbis playback works correctly
- [ ] Volume control (0-100%) responds correctly
- [ ] Balance control (-100% to +100%) works
- [ ] Seek functionality is smooth and accurate
- [ ] Play/Pause/Stop controls work reliably
- [ ] Gapless playback between tracks
- [ ] Proper cleanup when switching tracks

### User Interface
- [ ] Main window displays at correct size (275x116)
- [ ] Window snapping works (20px threshold)
- [ ] Window state persists across launches
- [ ] Transport controls are responsive
- [ ] Seek bar updates in real-time
- [ ] VU meters animate smoothly
- [ ] Time display toggles correctly
- [ ] Clutterbar buttons functional
- [ ] Dark theme consistent throughout

### Visualization System  
- [ ] Spectrum analyzer displays correctly
- [ ] Oscilloscope mode works
- [ ] Visualization runs at 60 FPS
- [ ] No GPU performance issues
- [ ] Plugin switching works smoothly
- [ ] CPU usage stays under 10%

### File Operations
- [ ] Drag and drop audio files
- [ ] File picker works correctly
- [ ] Playlist loading (M3U, PLS)
- [ ] Metadata extraction accurate
- [ ] Format detection reliable

### Window Management
- [ ] Multi-monitor support works
- [ ] Always-on-top toggle functions
- [ ] Window transparency adjustable
- [ ] Shade mode animation smooth
- [ ] Window docking behavior correct

## Performance Testing
- [ ] Memory usage under 100MB
- [ ] No memory leaks detected
- [ ] CPU usage <5% when idle
- [ ] GPU usage <15% with visualization
- [ ] App launches in <2 seconds
- [ ] Large files (>100MB) load smoothly

## Integration Testing
- [ ] Media keys work (Play/Pause)
- [ ] System audio output switching
- [ ] Sleep/wake handling correct
- [ ] Multiple instance prevention

## Automated Tests
```bash
# Run this command to execute all tests
./run_all_tests.sh
```

Expected results:
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Performance benchmarks meet targets
- [ ] Code coverage >80%
- [ ] No memory leaks detected

## Manual Test Scenarios

### Scenario 1: Basic Playback
1. Launch application
2. Drag MP3 file to window
3. Click play button
4. Adjust volume to 50%
5. Seek to middle of track
6. Click pause
7. Click stop

### Scenario 2: Playlist Operations
1. Create new playlist
2. Add 10 songs of different formats
3. Enable shuffle mode
4. Skip through tracks
5. Save playlist as M3U
6. Load saved playlist

### Scenario 3: Visualization Testing
1. Play audio file
2. Enable visualization
3. Switch between modes
4. Check CPU/GPU usage
5. Toggle fullscreen
6. Test all built-in visualizations

### Scenario 4: Window Management
1. Open all windows (Main, Playlist, EQ)
2. Snap windows together
3. Move to different monitor
4. Enable always-on-top
5. Use shade mode
6. Restart app and verify positions

## Known Issues
- [ ] Keyboard shortcuts not fully implemented
- [ ] EQ window UI not complete
- [ ] Playlist search not implemented
- [ ] No network streaming support

## Sign-off
- [ ] Development team approval
- [ ] QA testing complete
- [ ] Performance acceptable
- [ ] Documentation updated
- [ ] Release notes prepared

---

## Test Execution Commands

```bash
# Full test suite
./run_all_tests.sh

# Quick smoke test
swift test --filter AudioEngineTests

# Build for release
swift build -c release --arch arm64 --arch x86_64

# Create app bundle
./test_macos.sh --config release --package
```

## Support Information
- Minimum macOS: 15.5
- Recommended: macOS 15.5 or later
- Architecture: Universal (Apple Silicon + Intel)
- File size: ~10MB