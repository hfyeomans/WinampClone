# WinAmpPlayer Test Plan

## Overview

This document outlines the comprehensive manual testing procedures for WinAmpPlayer on macOS. Each test scenario includes expected behaviors, steps to reproduce, and acceptance criteria.

## Test Environment Requirements

- **macOS Version:** 15.5 or later
- **Hardware:** Apple Silicon (M1/M2/M3) or Intel Mac
- **Display:** Standard resolution and Retina displays
- **Audio Output:** Built-in speakers, headphones, and external audio devices
- **Test Files:** Various audio formats (MP3, AAC, FLAC, WAV, OGG, AIFF)

## 1. Audio Playback Testing

### 1.1 Basic Playback Controls

#### Play/Pause Functionality
**Test Scenario:** Verify play and pause controls work correctly
**Steps:**
1. Launch WinAmpPlayer
2. Load an audio file (drag & drop or File menu)
3. Click Play button
4. Click Pause button during playback
5. Click Play again to resume

**Expected Results:**
- Audio starts playing when Play is clicked
- Playback pauses at current position
- Playback resumes from paused position
- Play/Pause button icon updates accordingly
- Time counter continues from pause point

#### Stop Functionality
**Test Scenario:** Verify stop control resets playback
**Steps:**
1. Start playing a track
2. Click Stop button
3. Observe time counter and seek bar

**Expected Results:**
- Playback stops immediately
- Time counter resets to 00:00
- Seek bar returns to beginning
- Play button becomes active

#### Previous/Next Track Navigation
**Test Scenario:** Verify track navigation in playlist
**Steps:**
1. Load multiple tracks into playlist
2. Start playing first track
3. Click Next button
4. Click Previous button
5. Test at beginning and end of playlist

**Expected Results:**
- Next advances to next track in playlist
- Previous returns to previous track
- At playlist end, Next stops or loops (based on settings)
- At playlist start, Previous stays on first track

### 1.2 Audio Format Support

#### MP3 File Playback
**Test Scenario:** Verify MP3 files play correctly
**Test Files:**
- Standard bitrate (128kbps, 192kbps, 320kbps)
- Variable bitrate (VBR) files
- Different sample rates (44.1kHz, 48kHz)
- ID3v1 and ID3v2 tagged files

**Expected Results:**
- All MP3 variants play without issues
- Metadata displays correctly
- Duration shows accurately
- No audio artifacts or glitches

#### AAC/M4A File Playback
**Test Scenario:** Verify AAC/M4A files play correctly
**Test Files:**
- iTunes purchased files
- AAC-LC encoded files
- Different bitrates
- With and without DRM

**Expected Results:**
- Non-DRM files play normally
- Metadata from MP4 container displays
- Album artwork shows if present
- Appropriate error for DRM-protected files

#### FLAC File Playback
**Test Scenario:** Verify lossless FLAC playback
**Test Files:**
- Different compression levels (0-8)
- High-resolution files (24-bit/96kHz)
- Files with embedded cue sheets
- Files with Vorbis comments

**Expected Results:**
- Lossless quality maintained
- No performance issues with large files
- Metadata displays correctly
- Seek operations work smoothly

#### WAV File Playback
**Test Scenario:** Verify uncompressed WAV playback
**Test Files:**
- 16-bit/44.1kHz CD quality
- 24-bit high-resolution
- Different channel configurations (mono, stereo)
- Large file sizes (>100MB)

**Expected Results:**
- Immediate playback start
- Accurate duration calculation
- Memory usage remains reasonable
- No buffer underruns

#### OGG Vorbis Playback
**Test Scenario:** Verify OGG format support
**Test Files:**
- Different quality levels (q0 to q10)
- Files with multiple logical streams
- Files with extensive metadata

**Expected Results:**
- Smooth playback at all quality levels
- Vorbis comments display correctly
- Chained streams handled properly

#### AIFF File Playback
**Test Scenario:** Verify AIFF format support
**Test Files:**
- Standard AIFF files
- AIFF-C compressed variants
- Files with markers and loops

**Expected Results:**
- Native Apple format plays perfectly
- Metadata chunks interpreted correctly
- Large files handled efficiently

### 1.3 Seek and Time Navigation

#### Seek Bar Operation
**Test Scenario:** Verify seeking functionality
**Steps:**
1. Play a track
2. Click at various points on seek bar
3. Drag seek handle while playing
4. Drag seek handle while paused
5. Test with different file formats

**Expected Results:**
- Playback jumps to clicked position
- Smooth dragging without audio glitches
- Time display updates in real-time
- Works consistently across all formats

#### Keyboard Seek Controls
**Test Scenario:** Verify keyboard shortcuts for seeking
**Steps:**
1. Test left/right arrow keys (5-second jumps)
2. Test Shift+arrows (30-second jumps)
3. Test Cmd+arrows (1-minute jumps)

**Expected Results:**
- Accurate time jumps
- No audio artifacts during seek
- Works in both playing and paused states

### 1.4 Volume and Balance Controls

#### Volume Adjustment
**Test Scenario:** Verify volume control functionality
**Steps:**
1. Adjust volume slider from 0% to 100%
2. Use keyboard shortcuts (up/down arrows)
3. Test with different audio output devices
4. Verify system volume integration

**Expected Results:**
- Smooth volume transitions
- No distortion at maximum volume
- Volume persists between sessions
- Independent from system volume

#### Balance Control
**Test Scenario:** Verify stereo balance adjustment
**Steps:**
1. Load stereo audio file
2. Adjust balance slider left and right
3. Test with headphones for clarity
4. Verify center position

**Expected Results:**
- Audio pans smoothly left/right
- Center position is true stereo
- No volume loss at extremes
- Works with all stereo formats

## 2. Window Management Testing

### 2.1 Main Window Operations

#### Window Dragging and Positioning
**Test Scenario:** Verify window movement
**Steps:**
1. Click and drag title bar
2. Test window snapping to screen edges
3. Move between multiple displays
4. Test with window shade mode

**Expected Results:**
- Smooth dragging without lag
- Magnetic snapping at screen edges
- Proper multi-monitor support
- Window position saves on quit

#### Window Shade Mode
**Test Scenario:** Verify window shade functionality
**Steps:**
1. Double-click title bar
2. Test all controls in shade mode
3. Restore to full window
4. Test keyboard shortcuts

**Expected Results:**
- Smooth animation to shade mode
- All essential controls accessible
- Double-click restores window
- Visualization continues in shade

#### Always on Top
**Test Scenario:** Verify always-on-top feature
**Steps:**
1. Enable always on top
2. Switch between applications
3. Test with full-screen apps
4. Verify toggle persistence

**Expected Results:**
- Window stays above other windows
- Doesn't interfere with full-screen apps
- Setting persists between launches

### 2.2 Playlist Window

#### Playlist Management
**Test Scenario:** Verify playlist operations
**Steps:**
1. Add files via drag & drop
2. Add folders recursively
3. Reorder tracks by dragging
4. Delete selected tracks
5. Clear entire playlist

**Expected Results:**
- Multiple selection works (Cmd+click, Shift+click)
- Smooth drag reordering with visual feedback
- Delete key removes selected tracks
- Undo/redo functionality works

#### Playlist Sorting
**Test Scenario:** Verify sorting options
**Steps:**
1. Sort by title
2. Sort by artist
3. Sort by album
4. Sort by duration
5. Reverse sort order

**Expected Results:**
- Instant sorting with large playlists
- Stable sort (maintains relative order)
- Sort indicator shows current sort
- Remembers sort preference

#### Playlist Search
**Test Scenario:** Verify search functionality
**Steps:**
1. Type in search field
2. Test partial matches
3. Clear search
4. Search with special characters

**Expected Results:**
- Real-time filtering as you type
- Case-insensitive search
- Searches all metadata fields
- Escape key clears search

### 2.3 Equalizer Window

#### Preset Management
**Test Scenario:** Verify EQ presets
**Steps:**
1. Load built-in presets
2. Modify and save custom preset
3. Delete custom preset
4. Reset to flat response

**Expected Results:**
- Presets apply immediately
- Custom presets persist
- Smooth transitions between presets
- Auto-preset based on genre

#### Band Adjustment
**Test Scenario:** Verify EQ band controls
**Steps:**
1. Adjust individual frequency bands
2. Test preamp slider
3. Enable/disable EQ
4. Test with different audio content

**Expected Results:**
- ±12dB range per band
- No distortion at extremes
- Bypass works instantly
- Visual feedback on adjustments

## 3. Visualization System Testing

### 3.1 Built-in Visualizations

#### Oscilloscope Display
**Test Scenario:** Verify waveform visualization
**Steps:**
1. Enable oscilloscope mode
2. Test with different audio sources
3. Adjust visualization size
4. Test color themes

**Expected Results:**
- Smooth waveform rendering
- Responsive to audio changes
- No lag or stuttering
- Proper stereo representation

#### Spectrum Analyzer
**Test Scenario:** Verify frequency spectrum display
**Steps:**
1. Enable spectrum analyzer
2. Test different bar styles
3. Adjust peak fall speed
4. Test with various music genres

**Expected Results:**
- Accurate frequency representation
- Smooth animation at 60 FPS
- Peak indicators work correctly
- Bass frequencies properly weighted

#### VU Meters
**Test Scenario:** Verify level meter accuracy
**Steps:**
1. Enable VU meter mode
2. Test with normalized audio
3. Test with quiet passages
4. Verify peak hold indicators

**Expected Results:**
- Accurate level representation
- Proper ballistics (rise/fall time)
- Peak LEDs activate at 0dB
- Stereo channels independent

### 3.2 Advanced Visualizations

#### Matrix Rain Effect
**Test Scenario:** Verify custom shader visualization
**Steps:**
1. Enable Matrix rain visualization
2. Test performance impact
3. Adjust effect parameters
4. Test window resizing

**Expected Results:**
- Smooth animation without drops
- Audio-reactive rain speed
- Maintains aspect ratio
- GPU acceleration working

#### Full-Screen Mode
**Test Scenario:** Verify full-screen visualizations
**Steps:**
1. Enter full-screen mode
2. Test keyboard controls
3. Switch between visualizations
4. Exit full-screen

**Expected Results:**
- Smooth transition to full-screen
- All keyboard shortcuts work
- No UI elements visible
- Escape key exits properly

## 4. UI Component Testing

### 4.1 Transport Controls

#### Button Responsiveness
**Test Scenario:** Verify all button controls
**Steps:**
1. Test hover states
2. Test pressed states
3. Verify tooltips
4. Test rapid clicking

**Expected Results:**
- Visual feedback on hover
- Pressed state clearly visible
- Tooltips appear after delay
- No double-trigger issues

#### Keyboard Shortcuts
**Test Scenario:** Verify all keyboard shortcuts
**Complete List:**
- Space: Play/Pause
- S: Stop
- Z: Previous track
- X: Play
- C: Pause
- V: Stop
- B: Next track
- L: Open file
- Cmd+O: Open file
- Cmd+L: Open location
- J: Jump to time
- Cmd+J: Jump to track
- R: Toggle repeat
- Shift+R: Toggle shuffle
- Up/Down: Volume control
- Left/Right: Seek control
- M: Mute toggle
- E: Toggle equalizer
- Cmd+K: Preferences
- Cmd+Q: Quit

**Expected Results:**
- All shortcuts work as documented
- No conflicts with system shortcuts
- Work regardless of focused window
- Customizable in preferences

### 4.2 Display Components

#### Time Display
**Test Scenario:** Verify time display modes
**Steps:**
1. Click to toggle elapsed/remaining
2. Verify accuracy during playback
3. Test with long files (>1 hour)
4. Check formatting consistency

**Expected Results:**
- Toggle between -MM:SS and MM:SS
- Accurate to the second
- Hours display when needed
- Monospace font maintains alignment

#### Track Information Display
**Test Scenario:** Verify metadata display
**Steps:**
1. Load files with complete tags
2. Load files with missing tags
3. Test scrolling long titles
4. Verify special character support

**Expected Results:**
- All standard tags display
- Graceful handling of missing data
- Smooth horizontal scrolling
- Unicode characters render correctly

#### Bitrate and Frequency Display
**Test Scenario:** Verify technical info display
**Steps:**
1. Load various bitrate files
2. Verify VBR indication
3. Check sample rate display
4. Test format indication

**Expected Results:**
- Accurate bitrate display
- "VBR" shown for variable files
- Sample rate in kHz
- Format badge (MP3, FLAC, etc.)

## 5. File Loading Testing

### 5.1 Drag and Drop Support

#### File Drag and Drop
**Test Scenario:** Verify file drag operations
**Steps:**
1. Drag single file to main window
2. Drag multiple files
3. Drag to playlist window
4. Drag unsupported file types

**Expected Results:**
- Visual drop feedback
- Multiple files queue properly
- Invalid files show error
- No app crashes on invalid files

#### Folder Drag and Drop
**Test Scenario:** Verify folder operations
**Steps:**
1. Drag folder with audio files
2. Drag nested folder structure
3. Drag folder with mixed content
4. Test large folder (>1000 files)

**Expected Results:**
- Recursive scanning works
- Only audio files added
- Progress indicator for large folders
- Maintains folder structure in playlist

### 5.2 File Browser Integration

#### Open File Dialog
**Test Scenario:** Verify file browser
**Steps:**
1. Use Cmd+O to open dialog
2. Navigate folder structure
3. Multi-select files
4. Use Quick Look preview

**Expected Results:**
- Standard macOS file dialog
- Audio files highlighted
- Preview plays in Quick Look
- Recently used locations saved

#### URL/Stream Support
**Test Scenario:** Verify network stream support
**Steps:**
1. Open URL dialog (Cmd+L)
2. Enter HTTP audio stream
3. Enter podcast URL
4. Test invalid URLs

**Expected Results:**
- Streams buffer and play
- Metadata updates from stream
- Error handling for dead streams
- Bookmark favorite streams

## 6. Playlist Format Testing

### 6.1 M3U/M3U8 Support

#### Loading M3U Playlists
**Test Scenario:** Verify M3U playlist loading
**Steps:**
1. Load standard M3U file
2. Load M3U8 (UTF-8) file
3. Test relative and absolute paths
4. Load playlist with comments

**Expected Results:**
- All referenced files found
- Extended M3U info parsed
- UTF-8 characters handled
- Comments ignored properly

#### Saving M3U Playlists
**Test Scenario:** Verify M3U export
**Steps:**
1. Create playlist
2. Save as M3U
3. Save as M3U8
4. Choose relative/absolute paths

**Expected Results:**
- Valid M3U format
- Extended info included
- Path options work correctly
- Encoding handled properly

### 6.2 PLS Format Support

#### PLS File Operations
**Test Scenario:** Verify PLS format support
**Steps:**
1. Load PLS playlist
2. Verify numbering
3. Test with URLs
4. Save as PLS

**Expected Results:**
- Proper INI format parsing
- File and URL entries work
- Length information preserved
- NumberOfEntries accurate

### 6.3 XSPF Format Support

#### XML Playlist Format
**Test Scenario:** Verify XSPF support
**Steps:**
1. Load XSPF playlist
2. Test with metadata
3. Verify track ordering
4. Export to XSPF

**Expected Results:**
- Valid XML parsing
- Rich metadata preserved
- Links and locations work
- Proper XML escaping

## 7. Performance Testing

### 7.1 Large File Handling

#### Memory Usage
**Test Scenario:** Monitor memory with large files
**Steps:**
1. Load 1GB+ WAV file
2. Monitor Activity Monitor
3. Perform seek operations
4. Load multiple large files

**Expected Results:**
- Reasonable memory usage
- No memory leaks
- Smooth seeking
- Stable performance

#### CPU Usage
**Test Scenario:** Verify CPU efficiency
**Steps:**
1. Play various formats
2. Enable visualizations
3. Minimize to background
4. Test on battery power

**Expected Results:**
- Low CPU usage (<10%)
- Efficient codec usage
- Lower usage when minimized
- Battery-friendly operation

### 7.2 Playlist Performance

#### Large Playlist Management
**Test Scenario:** Test with 10,000+ tracks
**Steps:**
1. Load massive playlist
2. Test scrolling speed
3. Test sorting speed
4. Search performance

**Expected Results:**
- Smooth scrolling
- Sorting under 1 second
- Instant search results
- No beach balls

## 8. Error Handling Testing

### 8.1 File Error Scenarios

#### Corrupted File Handling
**Test Scenario:** Test corrupted audio files
**Steps:**
1. Load truncated MP3
2. Load file with bad headers
3. Load zero-byte file
4. Test during playback

**Expected Results:**
- Graceful error messages
- Skip to next track
- No crashes
- Error logged

#### Missing File Handling
**Test Scenario:** Test missing playlist entries
**Steps:**
1. Load playlist
2. Move/delete referenced files
3. Attempt playback
4. Save playlist

**Expected Results:**
- Clear indication of missing files
- Option to locate moved files
- Continue with valid files
- Warning when saving

### 8.2 System Error Scenarios

#### Audio Device Changes
**Test Scenario:** Test device switching
**Steps:**
1. Play audio
2. Disconnect headphones
3. Connect Bluetooth device
4. Change system output

**Expected Results:**
- Seamless device switching
- No playback interruption
- Volume adjusts appropriately
- Follows system preferences

#### Sleep/Wake Handling
**Test Scenario:** Test system sleep
**Steps:**
1. Play audio
2. Put system to sleep
3. Wake system
4. Test with lid close

**Expected Results:**
- Playback pauses on sleep
- Can resume after wake
- Window state preserved
- No audio glitches

## 9. Integration Testing

### 9.1 System Integration

#### Media Key Support
**Test Scenario:** Verify media keys
**Steps:**
1. Test Play/Pause key
2. Test Previous/Next keys
3. Test with Touch Bar
4. Test with external keyboards

**Expected Results:**
- All media keys work
- Touch Bar controls update
- Works when not focused
- No conflicts with other apps

#### Notification Center
**Test Scenario:** Verify notifications
**Steps:**
1. Enable track change notifications
2. Test notification actions
3. Test Do Not Disturb mode
4. Verify notification settings

**Expected Results:**
- Track info in notifications
- Action buttons work
- Respects system settings
- Can disable in preferences

### 9.2 File System Integration

#### Quick Look Plugin
**Test Scenario:** Verify Quick Look
**Steps:**
1. Select audio file in Finder
2. Press Space for Quick Look
3. Test playback controls
4. Test with WinAmpPlayer running

**Expected Results:**
- Audio preview works
- Basic controls available
- Doesn't interfere with app
- Metadata displays

#### Spotlight Integration
**Test Scenario:** Verify Spotlight search
**Steps:**
1. Search for artist names
2. Search for album titles
3. Search for track names
4. Open results in app

**Expected Results:**
- Indexed tracks appear
- Metadata searchable
- Opens in WinAmpPlayer
- Recent files prioritized

## 10. Accessibility Testing

### 10.1 VoiceOver Support

#### Screen Reader Navigation
**Test Scenario:** Test with VoiceOver
**Steps:**
1. Enable VoiceOver
2. Navigate all controls
3. Test playlist navigation
4. Verify announcements

**Expected Results:**
- All controls labeled
- Logical navigation order
- Status announcements work
- No inaccessible areas

### 10.2 Keyboard Navigation

#### Full Keyboard Control
**Test Scenario:** Test without mouse
**Steps:**
1. Tab through all controls
2. Test all shortcuts
3. Navigate playlists
4. Access all menus

**Expected Results:**
- Tab order logical
- Focus indicators visible
- All features accessible
- Escape key conventions

## Test Execution Checklist

### Pre-Test Setup
- [ ] Install fresh build
- [ ] Prepare test audio files
- [ ] Configure test environment
- [ ] Clear preferences
- [ ] Document system specs

### Core Functionality
- [ ] Basic playback controls
- [ ] All audio formats
- [ ] Seek operations
- [ ] Volume/balance
- [ ] Playlist management

### UI and Visualization
- [ ] Window management
- [ ] All visualizations
- [ ] Theme switching
- [ ] Display components
- [ ] Keyboard shortcuts

### File Operations
- [ ] Drag and drop
- [ ] File browser
- [ ] Playlist formats
- [ ] Stream support
- [ ] Error handling

### System Integration
- [ ] Media keys
- [ ] Notifications
- [ ] Audio devices
- [ ] Sleep/wake
- [ ] Accessibility

### Performance
- [ ] Memory usage
- [ ] CPU efficiency
- [ ] Large files
- [ ] Large playlists
- [ ] Battery impact

### Final Verification
- [ ] No crashes observed
- [ ] All features functional
- [ ] Performance acceptable
- [ ] Error handling graceful
- [ ] Ready for release

## Bug Reporting Template

**Title:** [Component] Brief description

**Environment:**
- macOS Version:
- Hardware:
- Build Version:

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Result:**

**Actual Result:**

**Additional Notes:**

**Attachments:**
- Screenshots
- Crash logs
- Sample files