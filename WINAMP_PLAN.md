# WinAmp Clone Development Plan for macOS

## Project Overview

This document outlines the comprehensive development plan for creating a fully-functional WinAmp clone optimized for macOS 15.5. The project combines classic WinAmp functionality with modern macOS integration and an innovative procedural skin generation system.

## Key Adaptations for macOS

1. **Image Formats**: Convert BMP files to PNG for better compression and alpha channel support
2. **Archive Format**: Maintain .wsz as renamed .zip files (macOS compatible)
3. **Audio Framework**: Use AVFoundation or Core Audio instead of Windows audio APIs
4. **UI Framework**: Implement with SwiftUI or AppKit for native macOS experience
5. **File System**: Adapt to macOS file structure and permissions
6. **System Integration**: Support for macOS-specific features (Touch Bar, media keys, etc.)

## Technology Stack

- **Primary Language**: Swift (UI) + Rust (skin generator) + Objective-C (bridging)
- **UI Framework**: SwiftUI with AppKit for advanced features
- **Audio Engine**: AVFoundation / Core Audio
- **Database**: SQLite for media library
- **Testing Framework**: XCTest + Swift Testing
- **CI/CD**: GitHub Actions with macOS runners
- **Build System**: Xcode + Cargo (for Rust components)

## Development Timeline: 12 Sprints (24 weeks)

---

## Epic 1: Core Audio Engine
**Goal**: Build a robust audio playback engine supporting multiple formats with professional-grade features

### Sprint 1-2: Audio Foundation (Weeks 1-4)

#### Story 1.1: Audio Playback Core
**Description**: Implement the fundamental audio playback system using macOS native frameworks

**Tasks**:
- Set up AVFoundation audio player with proper session management
- Implement play/pause/stop/seek functionality with smooth transitions
- Create audio queue management system for gapless playback
- Implement volume and balance controls with logarithmic scaling
- Add audio routing support for multiple output devices
- Create audio session interruption handling (calls, notifications)
- Implement background audio playback capability

#### Story 1.2: File Format Support
**Description**: Add comprehensive codec support for popular audio formats

**Tasks**:
- Implement MP3 decoder with ID3v1/v2 tag support
- Add AAC/M4A support with iTunes metadata
- Add FLAC support with Vorbis comment parsing
- Add OGG Vorbis support
- Implement WAV/AIFF support for uncompressed audio
- Create unified metadata extraction interface
- Add format conversion capabilities
- Implement audio format detection system

#### Story 1.3: Playlist Management
**Description**: Create a flexible playlist system with advanced features

**Tasks**:
- Design playlist data model with CoreData
- Implement playlist file parsing (M3U, M3U8, PLS, XSPF)
- Add shuffle algorithms (random, intelligent)
- Implement repeat modes (off, all, one)
- Create playlist persistence system
- Add playlist import/export functionality
- Implement smart playlists with rules
- Create playlist version control for undo/redo

---

## Epic 2: UI Framework & Window System
**Goal**: Create the classic WinAmp interface adapted for macOS with modern enhancements

### Sprint 3-4: Main Window Implementation (Weeks 5-8)

#### Story 2.1: Window Management System
**Description**: Build a modular window system mimicking WinAmp's behavior

**Tasks**:
- Create modular window framework with SwiftUI
- Implement window snapping/docking with magnetic edges
- Add window state persistence across launches
- Create inter-window communication system
- Implement window shade mode
- Add always-on-top functionality
- Create window transparency controls
- Implement multi-monitor support

#### Story 2.2: Main Player Window
**Description**: Implement the iconic main player interface

**Tasks**:
- Design main window layout matching classic dimensions
- Implement transport controls with state management
  - Play button with state indicator
  - Pause functionality
  - Stop with position reset
  - Previous/Next track navigation
- Create time display with custom bitmap font rendering
- Add seek bar with real-time position tracking
- Implement volume slider with 0-100 range
- Add balance slider with center detent
- Create mono/stereo indicator
- Implement kbps/khz display
- Add clutterbar functionality

#### Story 2.3: Visualization System
**Description**: Create audio visualization components

**Tasks**:
- Implement FFT-based spectrum analyzer
  - 16-band frequency analysis
  - Customizable fall-off rates
  - Peak indicators
- Create oscilloscope view
  - Waveform rendering
  - Stereo/mono modes
- Add visualization switching system
- Implement visualization plugins API
- Optimize rendering with Metal
- Add FPS limiter for efficiency
- Create visualization recorder

### Sprint 5: Secondary Windows (Weeks 9-10)

#### Story 2.4: Equalizer Window
**Description**: Build the graphic equalizer with preset support

**Tasks**:
- Create 10-band EQ UI (-12db to +12db)
- Implement real-time audio processing pipeline
- Add preset management system
  - Built-in presets (Rock, Pop, Jazz, etc.)
  - Custom preset save/load
- Create auto-gain/preamp functionality
- Implement EQ on/off toggle
- Add EQ curve visualization
- Create A/B comparison mode
- Implement EQ automation

#### Story 2.5: Playlist Editor
**Description**: Create a full-featured playlist management interface

**Tasks**:
- Build playlist table view with custom rendering
- Implement drag-and-drop reordering
- Add multi-selection support
- Create search/filter functionality
- Implement context menus
  - Add/remove items
  - File info dialog
  - Jump to file
- Add column customization
- Create playlist sorting options
- Implement playlist statistics display

#### Story 2.6: Media Library (Optional)
**Description**: Modern media management system

**Tasks**:
- Design library database schema
- Implement background file scanning
- Create browse interface (artist/album/genre)
- Add advanced search functionality
- Implement smart playlist support
- Create tag editing capabilities
- Add album art management
- Implement duplicate detection

---

## Epic 3: Classic Skin Engine
**Goal**: Full compatibility with classic WinAmp 2.x skins

### Sprint 6-7: Skin Rendering System (Weeks 11-14)

#### Story 3.1: Skin File Parser
**Description**: Parse and process classic skin files

**Tasks**:
- Create .wsz/.zip unpacker with error handling
- Implement BMP to PNG converter
  - Preserve color indices
  - Handle transparency
- Parse skin configuration files
  - region.txt for hit testing
  - pledit.txt for colors
  - viscolor.txt for visualizations
- Build asset caching system
- Create skin validation system
- Implement fallback for missing assets
- Add skin metadata extraction

#### Story 3.2: Sprite-Based Rendering
**Description**: Implement pixel-perfect sprite rendering

**Tasks**:
- Create sprite sheet parser for all components
  - CBUTTONS.BMP parsing
  - TITLEBAR.BMP handling
  - NUMBERS.BMP extraction
- Implement button state management
  - Normal/pressed/hover states
  - Toggle button support
- Build slider rendering system
  - Volume (29 positions)
  - Balance (29 positions)
  - Seek bar positioning
- Add custom font rendering
  - Bitmap font support
  - Text scrolling
- Implement animation support

#### Story 3.3: Skin Application System
**Description**: Apply skins dynamically to the UI

**Tasks**:
- Create dynamic UI theming engine
- Implement region-based hit testing
- Add transparency/alpha support
- Build skin preview system
- Create skin manager interface
- Implement online skin browser
- Add skin randomizer
- Create skin editor mode

---

## Epic 4: Procedural Skin Generation
**Goal**: Innovative system for infinite unique skins

### Sprint 8-9: Generation Framework (Weeks 15-18)

#### Story 4.1: TOML Configuration Parser
**Description**: Parse and validate skin generation configurations

**Tasks**:
- Implement skin.toml parser with serde
- Create configuration validation
  - Schema validation
  - Value range checking
- Build default value system
- Add configuration inheritance
- Create configuration templates
- Implement hot-reload support
- Add configuration versioning
- Create migration system

#### Story 4.2: Palette Generation System
**Description**: Create harmonious color palettes algorithmically

**Tasks**:
- Implement HCT color space converter
- Create tonal palette generator
  - 13 tone levels per color
  - Chroma adjustment algorithms
- Add contrast ratio calculator (WCAG compliance)
- Build color harmony algorithms
  - Complementary schemes
  - Analogous schemes
  - Triadic schemes
- Implement theme variants (light/dark)
- Create color blindness filters
- Add palette export formats

#### Story 4.3: Procedural Texture Engine
**Description**: Generate textures algorithmically

**Tasks**:
- Implement Perlin noise generator
  - Octave control
  - Persistence parameters
- Add Simplex noise support
- Create Voronoi diagram generator
- Build texture blending system
- Implement texture filters
  - Blur/sharpen
  - Emboss/bevel
- Add texture tiling support
- Create texture preview system
- Implement GPU acceleration

### Sprint 10: Asset Generation (Weeks 19-20)

#### Story 4.4: Component Renderer
**Description**: Generate skin components programmatically

**Tasks**:
- Create button generator
  - Style variations (flat/3D/gradient)
  - Icon rendering
  - State variations
- Implement slider sprite generator
  - Track rendering
  - Thumb variations
- Build text/font renderer
  - Custom character sets
  - Anti-aliasing options
- Add window frame generator
  - Corner rendering
  - Border styles
- Create visualization color generator

#### Story 4.5: Skin Packager
**Description**: Package generated assets into skins

**Tasks**:
- Create PNG sprite sheet assembler
  - Optimal packing algorithm
  - Compression settings
- Implement .wsz archive creator
- Add metadata embedding
  - Author information
  - Generation parameters
  - Thumbnail creation
- Build batch generation support
- Create distribution formats
- Implement skin signing
- Add update mechanism

---

## Epic 5: Testing & Quality Assurance
**Goal**: Ensure reliability and visual consistency

### Sprint 11: Testing Infrastructure (Weeks 21-22)

#### Story 5.1: Unit Testing Suite
**Description**: Comprehensive unit test coverage

**Tasks**:
- Audio engine unit tests
  - Playback state machine
  - Format support
  - Queue management
- Skin parser tests
  - File format validation
  - Asset extraction
- Color algorithm tests
  - Palette generation
  - Contrast calculations
- Playlist logic tests
  - Shuffle algorithms
  - Import/export
- UI component tests
- Performance benchmarks

#### Story 5.2: Visual Regression Testing
**Description**: Automated visual testing system

**Tasks**:
- Set up screenshot capture system
- Implement pixel-by-pixel comparison
- Create baseline management
  - Version control integration
  - Platform-specific baselines
- Add CI/CD integration
- Create diff visualization
- Implement fuzzy matching
- Add performance metrics
- Create test report generator

#### Story 5.3: Integration Testing
**Description**: End-to-end testing scenarios

**Tasks**:
- Create automated UI testing
- Implement audio playback testing
- Add skin loading tests
- Create memory leak detection
- Implement stress testing
- Add compatibility testing
- Create user journey tests
- Implement accessibility testing

---

## Epic 6: Polish & Distribution
**Goal**: Prepare for public release

### Sprint 12: Final Polish (Weeks 23-24)

#### Story 6.1: macOS Integration
**Description**: Deep integration with macOS features

**Tasks**:
- Implement media key support
- Add Touch Bar support
  - Transport controls
  - Seek functionality
  - Volume adjustment
- Create dock menu
  - Playback controls
  - Recent files
- Implement Spotlight integration
- Add Notification Center support
- Create Shortcuts app actions
- Implement Handoff support
- Add AirPlay integration

#### Story 6.2: User Experience
**Description**: Polish the user experience

**Tasks**:
- Add first-run tutorial
- Create comprehensive preferences
  - Audio settings
  - Interface options
  - Keyboard shortcuts
- Implement global hotkeys
- Add accessibility features
  - VoiceOver support
  - Keyboard navigation
- Create help documentation
- Implement crash recovery
- Add usage analytics (opt-in)

#### Story 6.3: Distribution Preparation
**Description**: Prepare for release

**Tasks**:
- Create app bundle with icon
- Implement Sparkle auto-updater
- Add Sentry crash reporting
- Create DMG installer
  - Background image
  - License agreement
- Implement license validation
- Create App Store version
- Add notarization workflow
- Create release notes system

## File Format Conversions

- **BMP → PNG**: Automatic conversion with alpha channel support
- **.cur → NSCursor**: Custom cursor format adaptation
- **Region files → CALayer masks**: Hit testing adaptation
- **Pixel fonts → Core Graphics**: Native font rendering
- **Playlist formats**: Universal playlist support

## Performance Targets

- Audio latency: < 10ms
- UI response time: < 16ms (60 FPS)
- Skin loading: < 500ms
- Memory usage: < 100MB base
- CPU usage: < 5% during playback

## Success Criteria

1. Full compatibility with WinAmp 2.x skins
2. Support for all major audio formats
3. Native macOS user experience
4. Procedural skin generation working
5. Performance targets met
6. Accessibility compliance
7. App Store approval ready

## Risk Mitigation

1. **Skin Compatibility**: Maintain test suite of popular skins
2. **Audio Performance**: Use Core Audio for low-level control
3. **Memory Management**: Implement aggressive caching strategies
4. **UI Responsiveness**: Offload heavy work to background queues
5. **Cross-platform**: Design with potential iOS port in mind

## Future Enhancements

1. iOS/iPadOS version
2. Cloud sync support
3. Streaming service integration
4. AI-powered playlist generation
5. Social features
6. Plugin marketplace
7. Apple Watch companion app
8. Spatial audio support

---

This plan provides a structured 12-sprint roadmap to build a feature-complete WinAmp clone optimized for macOS, with modern enhancements while maintaining the classic experience users love.