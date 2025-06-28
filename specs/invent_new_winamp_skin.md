Engineering Specification: Generative Classic Skin System
Document ID:

LlamaWhipper-ENG-SPEC-SKIN-001

Version:

1.0

Status:

Draft

Author:

Lead Systems Architect

Date:

June 28, 2025

Related Documents:

Project LlamaWhipper: A Product and Engineering Plan

1. Introduction and Scope
1.1. Purpose

This document provides a detailed engineering specification for the design, implementation, and testing of the Generative Classic Skin System for Project LlamaWhipper. It builds upon the architectural foundations laid out in the "Project LlamaWhipper: A Product and Engineering Plan," specifically Section 2.1 (The Classic Skinning Engine) and Section 3.1 (GUI Framework).

The primary goal of this specification is to define a framework that enables the procedural generation of an infinite variety of unique, aesthetically pleasing, and functionally complete classic Winamp skins (.wsz files). This moves beyond simply rendering pre-existing, manually created skins and establishes a scalable system for skin creation.

1.2. Scope

This specification covers the following areas:

The definitive file structure and asset requirements for a compatible .wsz classic skin.

The architecture of a procedural generation engine for creating all necessary skin assets.

A declarative configuration format for defining the parameters of a generated skin.

The development workflow, including tooling, version control, and CI/CD integration for skin generation.

A comprehensive testing strategy, including automated visual regression testing to ensure quality and consistency.

This document is intended for software engineers, UI/UX designers, and QA engineers involved in the development of Project LlamaWhipper.

2. Classic Skin File Format (.wsz)
To ensure full compatibility, the LlamaWhipper rendering engine must support the classic Winamp skin format. A .wsz file is a standard .zip archive with a renamed file extension. The archive contains a collection of bitmap (   

.bmp) image files that define the player's entire visual appearance.   

2.1. Required Bitmap Assets

The following table details the mandatory and optional bitmap assets that constitute a complete classic skin. The generative system specified in this document must be capable of producing all required assets.

Asset Filename

Required

Description

Main Window

MAIN.BMP

Yes

The main player window background and layout.   

TITLEBAR.BMP

Yes

The title bar, including textures for active and inactive states.   

CBUTTONS.BMP

Yes

A sprite sheet for the core transport controls (Prev, Play, Pause, Stop, Next) in normal and pressed states.   

PLAYPAUS.BMP

Yes

A sprite sheet for the play/pause state indicators.   

SHUFREP.BMP

Yes

A sprite sheet for the shuffle and repeat toggle buttons, including on/off and pressed states for each.   

VOLUME.BMP

Yes

A sprite sheet for the volume slider, containing 29 states (28 levels + mute).   

BALANCE.BMP

Yes

A sprite sheet for the balance slider, containing 29 states.   

POSBAR.BMP

Yes

A sprite sheet for the seek bar knob, containing 29 states.   

NUMBERS.BMP

Yes

A sprite sheet containing images for digits 0-9 and other symbols for the time display.   

TEXT.BMP

Yes

A sprite sheet containing the pixel font for the song title display.   

MONOSTER.BMP

Yes

A sprite sheet for the mono and stereo indicators.   

Playlist Editor

PLEDIT.BMP

Yes

The frame, buttons, scrollbar elements, and other UI assets for the playlist editor window.   

Equalizer

EQMAIN.BMP

Yes

The main frame, buttons, and slider backgrounds for the graphic equalizer window.   

EQ_EX.BMP

No

Optional assets for the equalizer's "window shade" mode.   

General Purpose

GEN.BMP

No

Assets for the general purpose window frame, used by the Media Library and other plugins.   

GENEX.BMP

No

A sprite sheet for buttons and sliders used within the general purpose window.   

Other

VIDEO.BMP

No

Frame for the video window.   

2.2. Other Assets

Cursor Files (.cur): Skins can optionally include custom cursor files to override system cursors when hovering over specific UI elements.   

Configuration Files: Text files like pledit.txt (for playlist font colors) and region.txt (for mapping irregular window shapes) may be included.

3. Procedural Skin Generation Framework
To enable the creation of a vast number of unique skins, we will implement a procedural generation system. This system will algorithmically create all necessary bitmap assets based on a high-level, declarative configuration file, rather than requiring manual creation in an image editor. This approach aligns with the project's core philosophy of infinite malleability.   

3.1. Generative Principles

The framework will be based on the principles of Generative UI, where the final appearance is the result of a set of rules and parameters. This system will combine several techniques:   

Palette Generation: A small set of base colors will be used to algorithmically generate a full, harmonious, and accessible color palette.   

Procedural Textures: Noise functions (e.g., Perlin, Simplex, Voronoi) will be used to generate non-uniform, organic-looking textures for window backgrounds and other elements.   

Component Assembly: The generated palettes and textures will be programmatically combined to render the final bitmap assets (MAIN.BMP, CBUTTONS.BMP, etc.).

3.2. Skin Definition File: skin.toml

Each generated skin will be defined by a single skin.toml file. TOML is chosen for its human-readability and its prevalence in the Rust ecosystem. This file is the canonical source of truth for a skin's design.   

The skin.toml file will have the following structure:

Ini, TOML
# skin.toml

# Metadata for the skin
[metadata]
name = "LlamaWhipper Dark"
author = "Project LlamaWhipper Team"
version = "1.0"

# Defines the core color palette for the skin
[palette]
# Base colors from which the entire theme is derived.
# Can be defined as hex strings.
primary = "#4D96FF"
secondary = "#FFB400"
background = "#1E1E1E"
surface = "#2C2C2C"
error = "#FF5252"

# Defines the generation parameters for procedural textures
[textures]
# Parameters for the main window background texture
[textures.main_background]
type = "Perlin" # Algorithm (e.g., Perlin, Simplex, Voronoi, Flat)
octaves = 4
persistence = 0.5
lacunarity = 2.0
scale = 0.1
seed = 1337

# Defines properties for specific UI components
[components]
# Font settings for the song title display
[components.title_font]
color_source = "primary" # Use the 'primary' color from the palette
style = "pixelated" # "pixelated", "smooth"

# Settings for the main transport buttons
[components.buttons]
style = "inset" # "inset", "outset", "flat"
corner_radius = 2.0
3.3. Palette Generation Subsystem

The palette generator will take the base colors defined in [palette] and produce a full tonal palette for each. This ensures consistent and accessible color usage across the entire UI.   

Algorithm: The system will implement a color generation algorithm based on a perceptually uniform color space like HCT (Hue, Chroma, Tone) or OKLCH.   

Process:

A source color (e.g., palette.primary) is converted to the HCT color space.

A tonal palette is generated by creating variants of the source color at fixed tone (lightness) levels (e.g., 10, 20,..., 90, 100). Chroma may be adjusted to maintain vibrancy at different tones.   

This process is repeated for primary, secondary, neutral, and error colors.

Output: The generator produces a set of named color roles (e.g., primary, on_primary, primary_container, surface, on_surface) that are used by subsequent generation steps. This ensures, for example, that text (on_surface) always has sufficient contrast with its background (surface).

3.4. Procedural Texture Subsystem

This subsystem generates the bitmap data for textures defined in the [textures] section of skin.toml.

Algorithms: The system will support multiple procedural noise algorithms, including Perlin/Simplex noise and Voronoi diagrams, to create a variety of textures from metallic and rocky to smooth gradients.   

Implementation: Rust libraries such as noise-rs can be used as a foundation for implementing the noise functions. The funutd library provides a good reference for a 3D procedural texture system.   

Process:

For each pixel of a target bitmap (e.g., a portion of MAIN.BMP), its (x, y) coordinates are passed to the selected noise function.

The noise function returns a value (e.g., between -1.0 and 1.0).

This value is mapped to a color from the generated palette to produce the final pixel color. This can create effects like shadows, highlights, and material grain.

3.5. Component Rendering Subsystem

This subsystem assembles the final .bmp sprite sheets by combining generated palettes and textures.

Buttons (CBUTTONS.BMP):

A base button shape is drawn (e.g., a rectangle with a specified corner_radius).

The style parameter ("inset", "outset", "flat") determines how highlights and shadows from the palette are applied to create a 3D effect.

Glyphs for "Play," "Pause," etc., are drawn onto the button shape using a contrasting color.

States (normal, pressed) are rendered by shifting highlights/shadows or changing the base color.

Text (TEXT.BMP, NUMBERS.BMP):

A predefined pixel font will be used as a template.

The generator will render the font's glyphs onto the sprite sheet using the specified color_source from the palette.

Windows (MAIN.BMP, etc.):

The procedural texture for the background is generated first.

Pre-rendered component elements (like buttons and sliders) are then blitted (copied) onto the background canvas at their correct coordinates as defined by the classic Winamp layout.

4. Development and CI/CD Workflow
A streamlined workflow is essential for efficiently creating, testing, and distributing skins.

4.1. Tooling: skin-generator

A dedicated command-line interface (CLI) tool, skin-generator, will be developed.

Functionality: skin-generator --input <path/to/skin.toml> --output <path/to/skin.wsz>

Implementation: The tool will be a Rust binary that encapsulates all the logic defined in Section 3. It will read a .toml file, execute the generation pipeline, and package the resulting .bmp and other assets into a .wsz archive.

4.2. Version Control

Source of Truth: The skin.toml definition files are the canonical source for skins and must be checked into version control.

Generated Files: The generated .wsz files are build artifacts and must not be checked into version control. They will be generated as needed by the CI/CD pipeline.

4.3. CI/CD Pipeline (GitHub Actions)

A GitHub Actions workflow will be created to automate the building, testing, and release of skins.   

Trigger: The workflow will trigger on a push to the main branch that modifies any file within the skin_definitions/ directory.

Jobs:

build_and_test_skins:

Runs on ubuntu-latest.

Checks out the repository.

Installs the Rust toolchain.

Builds the skin-generator tool in release mode.

For each skin.toml file found in skin_definitions/:

Runs the skin-generator to produce a .wsz file.

Executes the visual regression tests (see Section 5).

Uploads the generated .wsz files as workflow artifacts.

create_release_assets:

Runs only when a new version tag (e.g., v1.2.0) is pushed.

Downloads the .wsz artifacts from the build_and_test_skins job.

Uploads each .wsz file as a release asset to the corresponding GitHub Release.   

5. Testing and Quality Assurance
Given the visual nature of skins, a robust automated testing strategy is critical to prevent regressions.

5.1. Unit and Integration Testing

The skin-generator tool itself will have a comprehensive suite of unit tests covering:

skin.toml parsing logic.

Palette generation algorithms (asserting correct color values).

Procedural texture function outputs.

Correct .wsz file packaging.

5.2. Visual Regression Testing

The primary method for ensuring skin quality will be automated screenshot-based visual regression testing.   

Concept: For each skin, a "baseline" or "golden" screenshot of the LlamaWhipper player rendered with that skin is stored in the repository. On every CI run, a new screenshot is generated and compared pixel-by-pixel to the baseline. If any differences are detected, the test fails.   

Implementation:

A dedicated test runner binary will be created. This binary will launch a headless instance of the LlamaWhipper application, load a specific skin, and capture a screenshot of the main window.

The Rust crate insta will be used for snapshot management. While    

insta is typically used for text snapshots, it can be adapted for image comparison.

The image crate will be used to load the baseline and newly captured screenshots and compare them.   

Workflow:

Baseline Generation: A developer runs cargo insta review locally to approve a new screenshot as the baseline. The baseline PNG is stored in a snapshots directory alongside the test code.   

CI Execution: The build_and_test_skins job in the CI pipeline runs the visual tests.

Failure Analysis: If a test fails, the CI job fails. The workflow will be configured to upload a "diff" image as an artifact, which visually highlights the differences between the baseline and the new screenshot. This allows developers to quickly identify the regression without needing to run the test locally.

Future Enhancements: To reduce false positives from minor anti-aliasing differences across platforms, an AI-powered image comparison tool could be integrated in the future. These tools can semantically differentiate between insignificant rendering noise and meaningful style changes.   