# WinAmpPlayer Test Suite

This directory contains comprehensive tests for the WinAmpPlayer audio engine and related components.

## Test Structure

```
Tests/
├── WinAmpPlayerTests/
│   ├── Unit/
│   │   ├── AudioEngineTests.swift           # Core functionality tests
│   │   ├── AudioEngineConcurrencyTests.swift # Thread safety and concurrent operations
│   │   └── AudioEnginePerformanceTests.swift # Performance benchmarks
│   ├── Integration/
│   │   └── AudioEngineIntegrationTests.swift # Integration with other components
│   └── Fixtures/
│       └── AudioTestFixtures.swift          # Helper utilities for test audio files
└── README.md
```

## Running Tests

### All Tests
```bash
swift test
```

### Specific Test Class
```bash
swift test --filter AudioEngineTests
```

### Unit Tests Only
```bash
swift test --filter "Unit"
```

### Integration Tests Only
```bash
swift test --filter "Integration"
```

### Performance Tests
```bash
swift test --filter "Performance"
```

## Test Categories

### Unit Tests (`AudioEngineTests.swift`)
- **Basic Functionality**: Play, pause, stop, seek operations
- **State Transitions**: Playback state management and transitions
- **Volume Control**: Volume adjustment accuracy
- **File Loading**: Support for various audio formats
- **Error Handling**: Invalid files, missing files, format errors
- **Time Tracking**: Current time and duration accuracy
- **Memory Management**: Cleanup and deinitialization

### Concurrency Tests (`AudioEngineConcurrencyTests.swift`)
- **Thread Safety**: Concurrent operations from multiple threads
- **Race Conditions**: Time update consistency
- **Deadlock Prevention**: Rapid state changes
- **Resource Contention**: High-load scenarios
- **Memory Safety**: Concurrent access to shared resources

### Performance Tests (`AudioEnginePerformanceTests.swift`)
- **Load Performance**: File loading speed for various sizes
- **Seek Performance**: Sequential and random seek operations
- **Playback Latency**: Time to start playback
- **Memory Usage**: Memory consumption during playback
- **Format Support**: Performance across different audio formats

### Integration Tests (`AudioEngineIntegrationTests.swift`)
- **Audio Session**: Integration with iOS audio session
- **Playlist Management**: Track navigation and completion
- **Background Playback**: App lifecycle handling
- **Error Recovery**: Recovery from error states
- **Real-World Scenarios**: Typical music player usage patterns

## Test Fixtures

The `AudioTestFixtures` class provides utilities for creating test audio files:

- `createTestAudioFile()`: Creates a test audio file with sine wave
- `createSilentAudioFile()`: Creates a silent audio file
- `createMultiFormatTestFiles()`: Creates files in various formats (AAC, WAV, AIFF)
- `createTestTrack()`: Creates a Track object with metadata
- `createInvalidAudioFile()`: Creates an invalid file for error testing

## Mocking

The test suite includes mock implementations for testing without actual audio:

- `MockAVAudioEngine`: Simulates AVAudioEngine behavior
- `MockAVAudioPlayerNode`: Simulates audio player node operations

## Best Practices

1. **Cleanup**: All test files are automatically cleaned up after tests
2. **Isolation**: Each test is independent and doesn't affect others
3. **Timeouts**: Async operations have appropriate timeouts
4. **Assertions**: Tests use specific assertions for accuracy
5. **Performance**: Performance tests measure specific metrics

## Continuous Integration

These tests are designed to run in CI environments:

- No UI dependencies for unit tests
- Deterministic behavior (no random failures)
- Reasonable timeouts for all async operations
- Clear error messages for debugging

## Adding New Tests

When adding new tests:

1. Place unit tests in the `Unit/` directory
2. Place integration tests in the `Integration/` directory
3. Use `AudioTestFixtures` for creating test audio files
4. Follow the existing naming conventions
5. Add appropriate documentation comments
6. Ensure proper cleanup of resources

## Known Limitations

- Some tests require actual audio files (cannot be fully mocked)
- Performance tests may vary based on hardware
- Background audio tests require proper entitlements