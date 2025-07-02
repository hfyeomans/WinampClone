# Audio Conversion Module

This module provides audio format conversion capabilities for the WinAmpPlayer, allowing conversion between various audio formats with customizable quality settings.

## Features

- **Format Support**: Convert between MP3, AAC, M4A, FLAC, WAV, AIFF, and Apple Lossless (ALAC)
- **Batch Conversion**: Convert multiple files at once
- **Quality Presets**: Pre-configured settings for common use cases
- **Custom Settings**: Fine-tune bitrate, sample rate, channels, and more
- **Progress Tracking**: Monitor conversion progress in real-time
- **Metadata Preservation**: Keep track information during conversion

## Components

### AudioConverter

The main conversion engine that handles:
- Single file conversion
- Batch file conversion
- Progress reporting
- Cancellation support

### ConversionPresets

Pre-configured conversion settings organized by quality level:

#### High Quality (Lossless)
- **FLAC Lossless**: Perfect quality with ~50-60% file size reduction
- **Apple Lossless (ALAC)**: Apple's lossless format for iTunes/Apple Music
- **WAV Uncompressed**: Maximum compatibility
- **WAV Hi-Res**: 24-bit/96kHz studio quality

#### Standard Quality
- **AAC 256kbps**: iTunes Plus quality
- **AAC 192kbps**: Very good quality with smaller files
- **MP3 320kbps**: Maximum MP3 quality
- **MP3 256kbps VBR**: Variable bitrate for optimal balance

#### Compressed
- **AAC 128kbps**: Good quality, small size
- **MP3 128kbps**: Basic quality, maximum compatibility
- **AAC Voice**: Optimized for spoken content

## Usage Examples

### Basic Conversion with Preset

```swift
let converter = AudioConverter()

converter.convertAudioFile(
    from: sourceURL,
    to: outputURL,
    preset: .StandardQuality.aac256,
    completion: { result in
        switch result {
        case .success(let url):
            print("Converted: \(url)")
        case .failure(let error):
            print("Error: \(error)")
        }
    }
)
```

### Custom Settings

```swift
let settings = AudioConverter.ConversionSettings(
    outputFormat: .mp3,
    bitrate: 192000,
    sampleRate: 44100,
    channelCount: 2,
    preserveMetadata: true,
    quality: 0.8
)

converter.convertAudioFile(
    from: sourceURL,
    to: outputURL,
    settings: settings,
    completion: { result in
        // Handle result
    }
)
```

### Batch Conversion

```swift
converter.convertAudioFiles(
    from: sourceFiles,
    to: outputDirectory,
    settings: ConversionPreset.HighQuality.flac.settings,
    progress: { progress in
        print("\(progress.completedFiles)/\(progress.totalFiles)")
    },
    completion: { result in
        // Handle result
    }
)
```

### Custom Preset Builder

```swift
let customPreset = ConversionPresetBuilder()
    .withName("Podcast Export")
    .withOutputFormat(.mp3)
    .withBitrate(96000)
    .withChannelCount(1)  // Mono
    .withQuality(0.7)
    .build()
```

## Integration with WinAmpPlayer

The conversion module integrates seamlessly with the existing audio engine:

1. Uses the same `AudioFormat` enum from FormatDetection
2. Compatible with the metadata system
3. Can be triggered from playlist context menus
4. Supports background conversion while playing

## Performance Considerations

- Conversions run on a concurrent queue to avoid blocking the UI
- Large files may take significant time, especially for lossless formats
- Batch operations process files sequentially to manage system resources
- Progress callbacks are throttled to avoid excessive updates

## Limitations

- Opus format support is limited due to AVFoundation constraints
- Some exotic formats may require additional codecs
- DRM-protected files cannot be converted
- Maximum file size depends on available disk space

## Future Enhancements

- Hardware acceleration for faster conversion
- Queue management with pause/resume
- Conversion history and presets saving
- Integration with cloud storage services
- Advanced audio processing (normalization, EQ)