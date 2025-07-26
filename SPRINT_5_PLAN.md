# Sprint 5: Secondary Windows Implementation Plan

## Overview
Sprint 5 focuses on implementing the secondary windows that complement the main player window, providing advanced functionality for playlist management, audio equalization, and media library browsing.

## Stories

### Story 2.4: Equalizer Window 🎚️
**Description**: Build a graphic equalizer with preset support matching classic WinAmp EQ

**Acceptance Criteria**:
- 10-band EQ with -12dB to +12dB range
- Real-time audio processing integration
- Preset management (Rock, Pop, Jazz, etc.)
- Auto-gain/preamp functionality
- EQ on/off toggle
- Classic WinAmp styling

**Technical Requirements**:
- Use AVAudioUnitEQ for audio processing
- SwiftUI for UI with custom sliders
- CoreData for preset persistence
- Window snapping to main player

### Story 2.5: Playlist Editor 📝
**Description**: Create a full-featured playlist management interface

**Acceptance Criteria**:
- Table view with drag-and-drop reordering
- Multi-selection support
- Search/filter functionality
- Context menus for file operations
- Column customization
- Sorting options
- Classic WinAmp playlist styling

**Technical Requirements**:
- NSTableView or SwiftUI List
- File drag-and-drop from Finder
- Playlist persistence
- Integration with PlaylistController

### Story 3.6: Library/Browser Window 📚
**Description**: Media library organization with browsing capabilities

**Acceptance Criteria**:
- Tree view for folder navigation
- Media file scanning
- Metadata display
- Quick search
- Album art display
- Integration with playlist creation

**Technical Requirements**:
- File system traversal
- Metadata caching
- Background scanning
- SQLite for library database

## Implementation Order

1. **Playlist Editor** (Most essential for usability)
   - Basic window and table view
   - Drag and drop support
   - Integration with existing playlist system
   - Context menus and operations

2. **Equalizer Window** (Audio enhancement)
   - Window UI with sliders
   - AVAudioUnitEQ integration
   - Preset system
   - Real-time processing

3. **Library Browser** (Advanced feature)
   - Basic file browser
   - Metadata scanning
   - Database integration
   - Search functionality

## Window Management Requirements

All windows must:
- Support window snapping/docking
- Persist position and state
- Communicate via WindowCommunicator
- Match classic WinAmp aesthetics
- Support shade mode where applicable
- Work with multi-monitor setups

## Testing Strategy

- Unit tests for each window component
- Integration tests for window communication
- Audio processing tests for EQ
- Performance tests for library scanning
- UI tests for drag-and-drop operations

## Sprint Timeline

- Week 1: Playlist Editor implementation
- Week 2: Equalizer Window and Library Browser
- Ongoing: Testing, bug fixes, and polish

## Dependencies

- Existing WindowManager system
- PlaylistController for playlist operations
- AudioEngine for EQ integration
- MetadataExtractor for library scanning