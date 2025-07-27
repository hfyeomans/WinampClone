# Sprint 8-9: Procedural Skin Generation - Test Plan

## Overview
This test plan covers the procedural skin generation system implementation, including build verification, unit tests, integration tests, and end-to-end functionality testing.

## 1. Build Verification Tests

### 1.1 Compilation Test
- [ ] Run `swift build` to ensure all new files compile without errors
- [ ] Verify no new warnings are introduced
- [ ] Check that all imports are properly resolved
- [ ] Ensure no circular dependencies exist

### 1.2 Project Structure Test
- [ ] Verify all new files are in correct directories:
  - [ ] `/Sources/WinAmpPlayer/Skins/Generation/` contains all generation components
  - [ ] `/Sources/WinAmpPlayer/Views/SkinGeneratorView.swift` exists
- [ ] Confirm all files are added to the project target
- [ ] Check that file naming conventions are consistent

## 2. Unit Tests

### 2.1 Color System Tests
- [ ] **HCT Color Space**
  - [ ] Test HCT to RGB conversion with known values
  - [ ] Test color clamping (hue: 0-360, chroma: 0-1, tone: 0-1)
  - [ ] Test edge cases (hue = 360, chroma = 0, tone = 1)
  
- [ ] **Palette Generation**
  - [ ] Test each color scheme type generates correct relationships:
    - [ ] Monochromatic: Same hue, different chroma/tone
    - [ ] Complementary: 180° hue difference
    - [ ] Analogous: ±30° hue difference
    - [ ] Triadic: 120° hue separation
    - [ ] Split-complementary: Correct angle calculations
    - [ ] Tetradic: 90° separations
  - [ ] Test tonal palette generation (13 tone levels)
  - [ ] Test theme adjustments (dark/light mode)

- [ ] **Contrast Validation**
  - [ ] Test WCAG contrast ratio calculations
  - [ ] Test contrast level checking (AA, AAA)
  - [ ] Test tone finding for target contrast

### 2.2 Configuration Parser Tests
- [ ] **TOML Parsing**
  - [ ] Test parsing valid TOML configurations
  - [ ] Test error handling for invalid TOML
  - [ ] Test missing required fields
  - [ ] Test default value application
  - [ ] Test inline table parsing
  - [ ] Test all 5 default templates parse correctly

- [ ] **Configuration Building**
  - [ ] Test metadata section parsing
  - [ ] Test theme section with all enum values
  - [ ] Test color configuration with HCT values
  - [ ] Test texture configuration parsing
  - [ ] Test component style parsing

### 2.3 Texture Engine Tests
- [ ] **Texture Generation**
  - [ ] Test each texture type generates non-nil image:
    - [ ] Solid color
    - [ ] Gradient (linear)
    - [ ] Perlin noise
    - [ ] Circuit pattern
    - [ ] Dot pattern
    - [ ] Line pattern
    - [ ] Wave pattern
    - [ ] Voronoi diagram
    - [ ] Checkerboard
  - [ ] Test texture scaling
  - [ ] Test texture opacity

- [ ] **Noise Generation**
  - [ ] Test Perlin noise determinism (same seed = same result)
  - [ ] Test fractal noise with different octaves
  - [ ] Test noise value ranges (0-1)

- [ ] **Texture Filters**
  - [ ] Test blur filter application
  - [ ] Test sharpen filter
  - [ ] Test emboss effect
  - [ ] Test drop shadow
  - [ ] Test glow effect
  - [ ] Test seamless tiling

### 2.4 Component Renderer Tests
- [ ] **Button Rendering**
  - [ ] Test each button type renders:
    - [ ] Play button (triangle icon)
    - [ ] Pause button (two bars)
    - [ ] Stop button (square)
    - [ ] Next button (double triangle + bar)
    - [ ] Previous button (bar + double triangle)
    - [ ] Eject button (triangle + line)
  - [ ] Test each button style:
    - [ ] Flat
    - [ ] Rounded
    - [ ] Beveled
    - [ ] Glass
    - [ ] Pill
    - [ ] Square
  - [ ] Test button states (normal, hover, pressed, disabled)

- [ ] **Slider Rendering**
  - [ ] Test volume slider generation
  - [ ] Test balance slider with center indicator
  - [ ] Test position slider
  - [ ] Test each slider style:
    - [ ] Classic (beveled groove)
    - [ ] Modern (rounded track)
    - [ ] Minimal (flat)
    - [ ] Groove (recessed center)
    - [ ] Rail (raised edges)

- [ ] **Window Components**
  - [ ] Test title bar with gradient
  - [ ] Test main window background
  - [ ] Test display area rendering
  - [ ] Test visualization area

### 2.5 Skin Packager Tests
- [ ] **Sprite Generation**
  - [ ] Test all required sprites are generated
  - [ ] Test sprite dimensions match WinAmp standards
  - [ ] Test sprite sheet layout for control buttons
  - [ ] Test BMP conversion produces valid files
  - [ ] Test magenta transparency color

- [ ] **Configuration Files**
  - [ ] Test viscolor.txt generation (24 RGB values)
  - [ ] Test pledit.txt generation with correct format
  - [ ] Test skin.xml metadata generation

- [ ] **Archive Creation**
  - [ ] Test ZIP file creation
  - [ ] Test all required files are included
  - [ ] Test file naming conventions
  - [ ] Test archive can be extracted

## 3. Integration Tests

### 3.1 Generation Pipeline Tests
- [ ] **End-to-End Generation**
  - [ ] Test complete skin generation from config
  - [ ] Test palette → texture → component → package flow
  - [ ] Test error propagation through pipeline
  - [ ] Test cancellation handling

### 3.2 Skin Manager Integration
- [ ] Test generated skin installation
- [ ] Test skin appears in available skins list
- [ ] Test skin can be applied
- [ ] Test skin preview generation

### 3.3 File System Integration
- [ ] Test temporary file cleanup
- [ ] Test output directory creation
- [ ] Test file naming with timestamps
- [ ] Test handling of duplicate names

## 4. UI Tests

### 4.1 Skin Generator View Tests
- [ ] **Template Selection**
  - [ ] Test loading each template updates UI controls
  - [ ] Test template values apply correctly
  - [ ] Test switching between templates

- [ ] **Control Interactions**
  - [ ] Test color sliders update preview
  - [ ] Test theme mode switching
  - [ ] Test visual style selection
  - [ ] Test texture controls enable/disable
  - [ ] Test component style selection

- [ ] **Preview Updates**
  - [ ] Test preview updates on parameter change
  - [ ] Test preview shows accurate representation
  - [ ] Test preview performance with rapid changes

- [ ] **Generation Actions**
  - [ ] Test single skin generation
  - [ ] Test random skin generation
  - [ ] Test batch generation UI
  - [ ] Test progress indication
  - [ ] Test error alerts

### 4.2 Menu Integration Tests
- [ ] Test "Generate Skin..." menu item appears
- [ ] Test keyboard shortcut (Cmd+Shift+G)
- [ ] Test window opens correctly
- [ ] Test window can be closed and reopened

## 5. Performance Tests

### 5.1 Generation Performance
- [ ] Test single skin generation time < 1 second
- [ ] Test batch generation scales linearly
- [ ] Test memory usage remains stable
- [ ] Test no memory leaks during generation

### 5.2 UI Responsiveness
- [ ] Test UI remains responsive during generation
- [ ] Test preview updates don't block UI
- [ ] Test parameter changes are smooth

## 6. Error Handling Tests

### 6.1 Invalid Input Tests
- [ ] Test invalid TOML syntax handling
- [ ] Test missing required fields
- [ ] Test out-of-range values
- [ ] Test invalid file paths

### 6.2 Resource Error Tests
- [ ] Test disk space exhaustion handling
- [ ] Test write permission errors
- [ ] Test image generation failures

## 7. Compatibility Tests

### 7.1 Generated Skin Compatibility
- [ ] Test generated .wsz files open in WinAmp
- [ ] Test all sprites display correctly
- [ ] Test colors apply properly
- [ ] Test no missing components

### 7.2 Cross-Platform Tests
- [ ] Test BMP files are readable on Windows
- [ ] Test ZIP archives extract on all platforms
- [ ] Test text encoding compatibility

## 8. Regression Tests

### 8.1 Existing Functionality
- [ ] Test classic skin loading still works
- [ ] Test skin switching performance unchanged
- [ ] Test no impact on audio playback
- [ ] Test plugin system still functions

## 9. Manual Testing Checklist

### 9.1 User Workflow Tests
1. [ ] Open skin generator from menu
2. [ ] Select "Modern Dark" template
3. [ ] Adjust primary color hue to 120 (green)
4. [ ] Change button style to "Glass"
5. [ ] Enable background texture (Noise)
6. [ ] Click "Generate Skin"
7. [ ] Verify skin is created and installed
8. [ ] Apply the generated skin
9. [ ] Verify all UI elements look correct

### 9.2 Batch Generation Test
1. [ ] Click "Batch Generate..."
2. [ ] Set count to 5
3. [ ] Click "Generate Batch"
4. [ ] Verify 5 unique skins are created
5. [ ] Check each skin has variations
6. [ ] Verify all skins are valid

### 9.3 Random Generation Test
1. [ ] Click "Random Skin" 10 times
2. [ ] Verify each skin is unique
3. [ ] Verify all skins are aesthetically reasonable
4. [ ] Check no crashes or errors

## 10. Acceptance Criteria

### Must Pass
- [ ] All code compiles without errors
- [ ] Skin generator UI opens and functions
- [ ] Can generate at least one valid skin
- [ ] Generated skins install and display correctly
- [ ] No crashes during normal usage
- [ ] No memory leaks
- [ ] Performance meets requirements (< 1s generation)

### Should Pass
- [ ] All texture types work correctly
- [ ] All component styles render properly
- [ ] Batch generation completes successfully
- [ ] Preview updates smoothly
- [ ] Error messages are helpful

### Nice to Have
- [ ] Generated skins work in original WinAmp
- [ ] Accessibility features work correctly
- [ ] Keyboard navigation fully supported

## Test Execution Plan

1. **Phase 1: Build & Unit Tests** (30 min)
   - Run build verification
   - Execute unit tests for each component
   - Document any failures

2. **Phase 2: Integration Tests** (45 min)
   - Test complete generation pipeline
   - Test skin manager integration
   - Verify file system operations

3. **Phase 3: UI & Manual Tests** (60 min)
   - Test all UI interactions
   - Execute manual test scenarios
   - Test edge cases and error conditions

4. **Phase 4: Performance & Compatibility** (30 min)
   - Measure generation times
   - Test resource usage
   - Verify cross-platform compatibility

## Test Results Documentation

For each test:
- [ ] Pass/Fail status
- [ ] Any error messages or unexpected behavior
- [ ] Screenshots of UI issues
- [ ] Performance measurements where applicable
- [ ] Suggestions for fixes

## Known Issues & Limitations

1. HCT to RGB conversion uses simplified algorithm (not full CAM16)
2. BMP export doesn't support alpha channel (uses magenta for transparency)
3. Some texture types may be computationally expensive at large sizes
4. Preview may lag with rapid parameter changes

## Sign-off Criteria

- [ ] All "Must Pass" criteria are met
- [ ] At least 90% of "Should Pass" criteria are met  
- [ ] No critical bugs remain open
- [ ] Performance meets requirements
- [ ] Code review completed
- [ ] Documentation updated