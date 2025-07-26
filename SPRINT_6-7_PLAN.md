# Sprint 6-7: Classic Skin Support - Implementation Plan

## Overview
Sprint 6-7 focuses on implementing the classic WinAmp skin system, allowing users to apply custom visual themes to the player. This involves parsing skin files, managing sprite sheets, and dynamically applying visual changes.

## Technical Analysis

### Skin File Format
Classic WinAmp skins use the .wsz format (essentially a .zip file) containing:
- **BMP files**: Sprite sheets for UI elements
- **Configuration files**: Define regions, colors, and behaviors
- **Structure**:
  ```
  skin.wsz/
  ├── main.bmp          # Main window sprites
  ├── cbuttons.bmp      # Control buttons
  ├── titlebar.bmp      # Title bar elements
  ├── shufrep.bmp       # Shuffle/repeat buttons
  ├── volume.bmp        # Volume slider
  ├── balance.bmp       # Balance slider
  ├── posbar.bmp        # Position/seek bar
  ├── playpaus.bmp      # Play/pause buttons
  ├── numbers.bmp       # Number sprites
  ├── monoster.bmp      # Mono/stereo indicators
  ├── eqmain.bmp        # Equalizer window
  ├── pledit.bmp        # Playlist editor
  ├── pledit.txt        # Playlist colors config
  ├── viscolor.txt      # Visualization colors
  └── region.txt        # Hit regions for buttons
  ```

### Implementation Strategy

#### Phase 1: Skin File Parser (Story 3.1)
1. **ZIP/WSZ Handler**
   - Decompress .wsz files to temporary directory
   - Validate skin structure and required files
   - Handle missing files with defaults

2. **BMP Parser**
   - Convert BMP to native image formats
   - Extract sprite regions based on WinAmp specs
   - Handle transparency (color key: RGB 255,0,255)

3. **Configuration Parser**
   - Parse pledit.txt for playlist colors
   - Parse viscolor.txt for visualization colors
   - Parse region.txt for button hit regions

4. **Asset Management**
   - Cache parsed sprites in memory
   - Implement fallback to default skin
   - Handle skin switching without restart

#### Phase 2: Sprite-Based Rendering (Story 3.2)
1. **Sprite Sheet Management**
   - Define sprite regions for each UI element
   - Handle button states (normal, pressed, hover)
   - Support animated elements

2. **Dynamic UI Rendering**
   - Replace SwiftUI components with sprite rendering
   - Maintain exact pixel positioning
   - Handle scaling for retina displays

3. **Custom Drawing**
   - Implement bitmap font rendering
   - Draw sliders with sprite segments
   - Render visualization with skin colors

#### Phase 3: Skin Application System (Story 3.3)
1. **Theme Engine**
   - Apply skin to all windows simultaneously
   - Update colors, sprites, and regions
   - Maintain UI state during skin change

2. **Skin Manager**
   - List available skins
   - Preview skins before applying
   - Download skins from repository

3. **User Interface**
   - Skin browser window
   - Drag-and-drop skin installation
   - Skin editor mode (future)

## Technical Considerations

### SwiftUI Integration
- Custom ViewModifier for skinned components
- NSViewRepresentable for bitmap rendering
- Combine publishers for skin change notifications

### Performance
- Lazy loading of skin assets
- Sprite atlas for efficient rendering
- Metal acceleration for scaling

### Compatibility
- Support classic 2.x skin format
- Handle modern WinAmp 5.x skins (subset)
- Provide converter for incompatible formats

## Implementation Order

### Week 1: Parser and Asset Management
1. Create SkinParser class with .wsz decompression
2. Implement BMP to NSImage conversion
3. Parse configuration files
4. Build sprite extraction logic
5. Create SkinAsset cache system

### Week 2: Rendering and Application
1. Create SpriteRenderer view
2. Implement skinnable button component
3. Build skinnable slider component
4. Apply skins to main window
5. Extend to secondary windows

## Testing Strategy

1. **Unit Tests**
   - Skin file parsing
   - Sprite extraction accuracy
   - Configuration parsing

2. **Integration Tests**
   - Skin switching performance
   - Memory management
   - UI state preservation

3. **Visual Tests**
   - Pixel-perfect rendering
   - Transparency handling
   - Animation smoothness

## File Structure
```
Sources/WinAmpPlayer/
├── Skins/
│   ├── Parser/
│   │   ├── SkinParser.swift
│   │   ├── BMPParser.swift
│   │   ├── ConfigParser.swift
│   │   └── SpriteExtractor.swift
│   ├── Rendering/
│   │   ├── SpriteRenderer.swift
│   │   ├── SkinnableButton.swift
│   │   ├── SkinnableSlider.swift
│   │   └── BitmapFont.swift
│   ├── Management/
│   │   ├── SkinManager.swift
│   │   ├── SkinAssetCache.swift
│   │   └── DefaultSkin.swift
│   └── Models/
│       ├── Skin.swift
│       ├── SkinAsset.swift
│       └── SkinConfiguration.swift
```

## Dependencies
- ZIPFoundation (for .wsz extraction)
- CoreGraphics (for bitmap manipulation)
- Metal (optional, for performance)

## Success Criteria
1. Successfully parse and display classic WinAmp 2.x skins
2. Smooth skin switching without UI glitches
3. Pixel-perfect rendering matching original WinAmp
4. Performance: < 100ms skin switch time
5. Memory: < 50MB per loaded skin

## Risk Mitigation
- **Risk**: Complex sprite sheet layouts
  - **Mitigation**: Create comprehensive sprite map documentation
- **Risk**: Performance with high-res skins
  - **Mitigation**: Implement level-of-detail system
- **Risk**: SwiftUI limitations for pixel-perfect rendering
  - **Mitigation**: Use NSView where necessary

## Future Enhancements
- Skin creation tools
- Online skin repository
- Modern skin format support
- Animated skin elements
- Color customization UI