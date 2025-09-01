#!/bin/bash

# Build script for WinAmpPlayer macOS app bundle

echo "Building WinAmpPlayer for production..."

# Clean previous builds
rm -rf WinAmpPlayer_Release.app

# Build in release mode
swift build -c release

# Create app bundle structure
APP_NAME="WinAmpPlayer_Release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/WinAmpPlayer "$MACOS_DIR/WinAmpPlayer"

# Copy Metal shaders if they exist
if [ -d ".build/release/WinAmpPlayer_WinAmpPlayer.bundle" ]; then
    cp -r .build/release/WinAmpPlayer_WinAmpPlayer.bundle "$RESOURCES_DIR/"
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>WinAmpPlayer</string>
    <key>CFBundleExecutable</key>
    <string>WinAmpPlayer</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.WinAmpPlayer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>WinAmpPlayer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs access to microphone for audio processing.</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
EOF

echo "App bundle created: $APP_BUNDLE"
echo "To run the app, use: open $APP_BUNDLE"