# WinAmp Player macOS Refactoring Plan

## Executive Summary

This document provides a comprehensive engineering specification for refactoring the WinAmp Player codebase from iOS-specific implementations to proper macOS architecture. The plan is divided into manageable chunks that can be completed incrementally while maintaining code stability.

## Architecture Analysis

### Current Problems
1. **iOS Dependencies**: The codebase uses AVAudioSession which is iOS-only
2. **Platform Assumptions**: UI and audio components assume iOS paradigms
3. **Missing Protocol Conformances**: ObservableObject not implemented where needed
4. **API Mismatches**: Method signatures and deprecated APIs
5. **Type System Issues**: Struct/class mismatches, duplicate declarations

### Proposed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    WinAmp Player macOS                      │
├─────────────────────────────────────────────────────────────┤
│                      UI Layer (SwiftUI)                     │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │MainPlayerView│  │PlaylistView  │  │EqualizerView   │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   Core Audio Layer                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          macOSAudioEngine (AVAudioEngine)           │  │
│  ├─────────────────────────────────────────────────────┤  │
│  │ AudioDeviceManager │ AudioFormatHandler │ AudioTap  │  │
│  └─────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                               │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────┐   │
│  │Track Model   │  │Playlist    │  │AudioProperties  │   │
│  └──────────────┘  └────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Refactoring Chunks

### Phase 1: Foundation Fixes (Priority: Critical)

#### Chunk 1.1: Add Missing Imports and Fix ObservableObject Conformances
**Files**: Multiple files across the codebase
**Dependencies**: None
**Estimated Time**: 1-2 hours

**Tasks**:
1. Add `import Combine` to files that use Combine types:
   - AudioEngineExample.swift
   - FFTProcessor.swift
   - PlaylistController.swift
   - SmartPlaylistEngine.swift
   
2. Add ObservableObject conformance:
   ```swift
   // FFTProcessor.swift
   final class FFTProcessor: ObservableObject {
   
   // WindowCommunicator.swift
   class WindowCommunicator: ObservableObject {
   ```

3. Fix any @Published properties that need to be added

**Verification**: Code compiles without "cannot find type" errors

---

#### Chunk 1.2: Fix Simple Compilation Errors
**Files**: Various
**Dependencies**: Chunk 1.1
**Estimated Time**: 2-3 hours

**Tasks**:
1. Fix method signature in AudioDecoderFactory.swift:
   ```swift
   // Line 160: Change
   detectFormat(at: url)
   // To:
   detectFormat(from: url)
   ```

2. Fix duplicate `genres` declaration in ID3v1Parser.swift
   - Remove duplicate array definition
   - Ensure single source of truth

3. Fix enum raw values in MP4MetadataParser.swift
   - Ensure all enum cases have unique raw values

4. Update deprecated APIs in AIFFDecoder.swift:
   ```swift
   // Replace deprecated:
   item.commonMetadata
   item.stringValue
   item.dataValue
   
   // With async versions:
   try await item.load(.commonMetadata)
   try await item.load(.stringValue)
   try await item.load(.dataValue)
   ```

**Verification**: These specific compilation errors are resolved

---

### Phase 2: Audio System Refactoring (Priority: Critical)

#### Chunk 2.1: Create macOS Audio Device Management
**Files**: New file to replace AudioOutputManager.swift
**Dependencies**: Phase 1 complete
**Estimated Time**: 4-6 hours

**Tasks**:
1. Create `macOSAudioDeviceManager.swift`:
   ```swift
   import Foundation
   import CoreAudio
   import AVFoundation
   
   final class macOSAudioDeviceManager: ObservableObject {
       @Published var availableDevices: [AudioDevice] = []
       @Published var currentDevice: AudioDevice?
       
       struct AudioDevice {
           let id: AudioDeviceID
           let name: String
           let uid: String
           let isInput: Bool
           let isOutput: Bool
       }
       
       // Use CoreAudio APIs for device enumeration
       private func enumerateDevices() {
           // AudioObjectGetPropertyData for device list
       }
       
       // Use AVAudioEngine for routing
       func setOutputDevice(_ device: AudioDevice, for engine: AVAudioEngine) {
           // Configure AVAudioEngine output node
       }
   }
   ```

2. Implement device enumeration using CoreAudio
3. Implement device switching for AVAudioEngine
4. Add property listeners for device changes

**Verification**: Can list and switch between audio devices on macOS

---

#### Chunk 2.2: Replace iOS Audio Session with macOS Audio System
**Files**: AudioEngine.swift, new macOSAudioSystemManager.swift
**Dependencies**: Chunk 2.1
**Estimated Time**: 6-8 hours

**Tasks**:
1. Remove AudioSessionManager.swift (already done by test agents)
2. Remove AudioOutputManager.swift (already done by test agents)

3. Create `macOSAudioSystemManager.swift`:
   ```swift
   import Foundation
   import AVFoundation
   
   final class macOSAudioSystemManager: ObservableObject {
       private var audioEngine: AVAudioEngine
       private let deviceManager = macOSAudioDeviceManager()
       
       // Handle interruptions using NSWorkspace notifications
       private func setupInterruptionHandling() {
           NotificationCenter.default.addObserver(
               self,
               selector: #selector(handleInterruption),
               name: NSWorkspace.willSleepNotification,
               object: nil
           )
       }
       
       // Route changes handled by deviceManager
       // No AVAudioSession needed on macOS
   }
   ```

4. Update AudioEngine.swift:
   - Remove all AVAudioSession references
   - Remove iOS-specific interruption handling
   - Use macOSAudioSystemManager instead
   - Remove UIApplication references

**Verification**: AudioEngine compiles without iOS dependencies

---

#### Chunk 2.3: Fix Audio Engine Integration
**Files**: AudioEngine.swift, VolumeBalanceController.swift
**Dependencies**: Chunk 2.2
**Estimated Time**: 3-4 hours

**Tasks**:
1. Update AudioEngine initialization:
   ```swift
   public init() {
       self.audioEngine = AVAudioEngine()
       self.playerNode = AVAudioPlayerNode()
       self.audioSystemManager = macOSAudioSystemManager()
       setupAudioEngine()
   }
   ```

2. Fix audio tap implementation for macOS
3. Update volume/balance to work with AVAudioEngine directly
4. Remove any remaining iOS-specific code

**Verification**: Audio playback works on macOS

---

### Phase 3: Data Layer Fixes (Priority: High)

#### Chunk 3.1: Fix NSCache Type Issues
**Files**: Files using NSCache with structs
**Dependencies**: None
**Estimated Time**: 2-3 hours

**Tasks**:
1. Find all NSCache usage with value types
2. Options:
   - Convert cached structs to classes
   - Use a different caching mechanism
   - Create wrapper classes for struct caching
   
   ```swift
   // Example wrapper approach:
   final class CacheWrapper<T> {
       let value: T
       init(_ value: T) { self.value = value }
   }
   
   let cache = NSCache<NSString, CacheWrapper<MyStruct>>()
   ```

**Verification**: NSCache compilation errors resolved

---

#### Chunk 3.2: Fix Model Decodable Conformances
**Files**: Track.swift, others with Decodable issues
**Dependencies**: None
**Estimated Time**: 2-3 hours

**Tasks**:
1. Ensure all nested types conform to Codable
2. Add custom Decodable implementation if needed
3. Fix any circular dependencies in model types

**Verification**: All model types compile with Codable conformance

---

### Phase 4: UI Layer Updates (Priority: Medium)

#### Chunk 4.1: Update UI for macOS Paradigms
**Files**: MainPlayerView.swift, ContentView.swift
**Dependencies**: Phase 2 complete
**Estimated Time**: 3-4 hours

**Tasks**:
1. Remove any iOS-specific UI code
2. Update for macOS window management
3. Fix any AppKit/SwiftUI integration issues
4. Ensure proper macOS event handling

**Verification**: UI displays correctly on macOS

---

### Phase 5: Testing and Validation (Priority: High)

#### Chunk 5.1: Create macOS-specific Tests
**Files**: Test files
**Dependencies**: All phases complete
**Estimated Time**: 4-6 hours

**Tasks**:
1. Update existing tests for macOS
2. Create audio device management tests
3. Test all audio formats
4. Test UI on different macOS versions

**Verification**: All tests pass

---

## Implementation Order

1. **Day 1**: Phase 1 (Foundation Fixes)
   - Chunk 1.1: Add missing imports (1-2 hrs)
   - Chunk 1.2: Fix simple errors (2-3 hrs)

2. **Day 2-3**: Phase 2 (Audio System)
   - Chunk 2.1: Audio device management (4-6 hrs)
   - Chunk 2.2: Replace audio session (6-8 hrs)

3. **Day 4**: Phase 2 & 3
   - Chunk 2.3: Fix audio integration (3-4 hrs)
   - Chunk 3.1: Fix NSCache issues (2-3 hrs)

4. **Day 5**: Phase 3 & 4
   - Chunk 3.2: Fix model conformances (2-3 hrs)
   - Chunk 4.1: Update UI for macOS (3-4 hrs)

5. **Day 6**: Phase 5
   - Chunk 5.1: Testing and validation (4-6 hrs)

## Success Criteria

- [ ] All compilation errors resolved
- [ ] No iOS-specific APIs in use
- [ ] Audio playback works on macOS
- [ ] All tests pass
- [ ] Performance meets targets
- [ ] UI functions correctly on macOS

## Risk Mitigation

1. **Incremental Changes**: Each chunk is independently testable
2. **Version Control**: Commit after each successful chunk
3. **Fallback Plan**: Can revert individual chunks if needed
4. **Testing**: Verify each chunk before proceeding

## Notes from Test Agent Analysis

The test agents already attempted some fixes:
- ✅ Deleted iOS-specific AudioOutputManager.swift
- ✅ Deleted iOS-specific AudioSessionManager.swift
- ✅ Added ObservableObject to FFTProcessor
- ✅ Added ObservableObject to WindowCommunicator
- ✅ Added missing Combine imports

We should incorporate these changes and build upon them.

---

This plan provides a systematic approach to refactoring the WinAmp Player for macOS, with clear chunks that can be completed incrementally while maintaining stability.