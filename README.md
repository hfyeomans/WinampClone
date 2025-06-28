# WinAmp Player for macOS

A modern recreation of the classic WinAmp player for macOS, built with SwiftUI.

## Project Structure

```
WinAmpPlayer/
├── Package.swift              # Swift Package Manager configuration
├── Sources/
│   └── WinAmpPlayer/
│       ├── WinAmpPlayerApp.swift    # Main app entry point
│       ├── Core/
│       │   ├── AudioEngine/
│       │   │   └── AudioEngine.swift    # Audio playback engine
│       │   └── Models/
│       │       ├── Track.swift          # Track data model
│       │       └── Playlist.swift       # Playlist data model
│       ├── UI/
│       │   ├── Views/
│       │   │   └── ContentView.swift    # Main window view
│       │   └── Components/              # Reusable UI components
│       ├── Skins/
│       │   ├── Engine/                  # Skin rendering engine
│       │   └── Parsers/                 # Skin format parsers
│       └── Resources/
│           ├── Assets/                  # Images and icons
│           └── Fonts/                   # Custom fonts
└── Tests/
    ├── WinAmpPlayerTests/
    │   ├── Unit/                        # Unit tests
    │   └── UI/                          # UI component tests
    └── WinAmpPlayerUITests/             # UI integration tests
```

## Building the Project

1. Open the project in Xcode:
   ```bash
   open Package.swift
   ```

2. Build and run using Xcode or via command line:
   ```bash
   swift build
   swift run
   ```

## Features

- Classic WinAmp-inspired UI
- Audio playback with AVFoundation
- Playlist management
- Skin support (planned)
- Equalizer (planned)

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+