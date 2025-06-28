# WinAmpPlayer

A modern, feature-rich WinAmp clone for macOS that combines classic functionality with innovative procedural skin generation.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![macOS](https://img.shields.io/badge/macOS-15.5+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Overview

WinAmpPlayer brings the beloved WinAmp experience to macOS with native performance and modern enhancements. This project faithfully recreates the classic WinAmp 2.x interface while adding innovative features like procedural skin generation and deep macOS integration.

## Features

### Core Audio Engine
- **Multi-format Support**: MP3, AAC/M4A, FLAC, OGG Vorbis, WAV, AIFF
- **Professional-grade Playback**: Gapless playback, smooth transitions, background audio
- **Advanced Playlist Management**: M3U/M3U8/PLS/XSPF support, smart playlists, shuffle algorithms
- **Audio Processing**: 10-band equalizer with presets, real-time visualization

### Classic Interface
- **Modular Window System**: Main player, equalizer, playlist editor with magnetic snapping
- **Visualization Engine**: FFT spectrum analyzer, oscilloscope, plugin API support
- **Full Skin Compatibility**: Complete support for WinAmp 2.x skins
- **Pixel-perfect Rendering**: Authentic recreation of the classic experience

### Modern Enhancements
- **Procedural Skin Generation**: Infinite unique skins using advanced algorithms
- **macOS Integration**: 
  - Media key support
  - Touch Bar controls
  - Notification Center integration
  - Spotlight search
  - AirPlay support
- **Performance Optimized**: Metal-accelerated visualizations, efficient memory usage

### Innovative Features
- **HCT Color System**: Harmonious palette generation with WCAG compliance
- **Texture Engine**: Perlin noise, Simplex noise, and Voronoi diagram generation
- **Smart Library**: Background scanning, duplicate detection, tag editing
- **Accessibility**: Full VoiceOver support and keyboard navigation

## Technology Stack

- **Language**: Swift 5.9+ with Rust components for skin generation
- **UI Framework**: SwiftUI with AppKit for advanced features
- **Audio**: AVFoundation and Core Audio for low-latency playback
- **Graphics**: Core Graphics with Metal acceleration
- **Database**: SQLite for media library
- **Build System**: Xcode with Swift Package Manager

## Installation

### Requirements
- macOS 15.5 or later
- Xcode 15.0 or later
- Rust toolchain (for building skin generator)

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/hfyeomans/WinampClone.git
cd WinampClone
```

2. Install Rust (if not already installed):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

3. Open in Xcode:
```bash
open WinAmpPlayer.xcodeproj
```

4. Build and run (⌘R)

### Pre-built Release

Download the latest DMG from the [Releases](https://github.com/hfyeomans/WinampClone/releases) page.

## Development Setup

### Project Structure

```
WinAmpPlayer/
├── Core/              # Core audio engine and playback logic
├── UI/                # SwiftUI views and window management
├── SkinEngine/        # Classic skin parsing and rendering
├── Generator/         # Rust-based procedural skin generator
├── Resources/         # Assets, default skins, and configurations
├── Tests/             # Unit and integration tests
└── Documentation/     # API documentation and guides
```

### Building Components

#### Swift Components
The main application is built through Xcode. Ensure you have the latest version of Xcode installed.

#### Rust Skin Generator
```bash
cd Generator
cargo build --release
```

### Running Tests

```bash
# Swift tests
swift test

# Rust tests
cd Generator && cargo test

# Visual regression tests
xcodebuild test -scheme WinAmpPlayer -destination 'platform=macOS'
```

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Process

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Swift: Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Rust: Use `rustfmt` and `clippy` for consistent formatting
- Documentation: All public APIs must be documented

### Testing Requirements

- Unit test coverage for new features
- Visual regression tests for UI changes
- Performance benchmarks for audio processing

## Roadmap

- [ ] Core audio engine with multi-format support
- [ ] Classic WinAmp 2.x interface recreation
- [ ] Full skin compatibility
- [ ] Procedural skin generation system
- [ ] macOS integration features
- [ ] App Store release
- [ ] iOS/iPadOS version
- [ ] Cloud sync support
- [ ] Streaming service integration

## Performance Targets

- Audio latency: < 10ms
- UI response time: < 16ms (60 FPS)
- Skin loading: < 500ms
- Memory usage: < 100MB base
- CPU usage: < 5% during playback

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 WinAmpPlayer Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Acknowledgments

- Original WinAmp team for creating an iconic music player
- The WinAmp community for preserving classic skins
- Apple for comprehensive audio and UI frameworks
- Contributors and testers who help improve this project

## Support

- **Issues**: [GitHub Issues](https://github.com/hfyeomans/WinampClone/issues)
- **Discussions**: [GitHub Discussions](https://github.com/hfyeomans/WinampClone/discussions)
- **Wiki**: [Project Wiki](https://github.com/hfyeomans/WinampClone/wiki)

---

*WinAmpPlayer - It really whips the llama's ass!*