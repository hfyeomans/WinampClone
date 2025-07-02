#!/bin/bash

# WinAmpPlayer macOS Build and Test Script
# Supports macOS 15.5 and later
# Version: 1.0.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="WinAmpPlayer"
BUNDLE_ID="com.winampplayer.macos"
MIN_MACOS_VERSION="14.0"
MIN_XCODE_VERSION="15.0"
BUILD_DIR=".build"
RELEASE_DIR="releases"
TEST_REPORT_DIR="test_reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Default values
BUILD_CONFIG="debug"
RUN_TESTS=true
OPEN_XCODE=false
BUILD_AND_RUN=false
TEST_SUITE="all"
GENERATE_COVERAGE=false
PACKAGE_APP=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check macOS version
check_macos_version() {
    print_info "Checking macOS version..."
    MACOS_VERSION=$(sw_vers -productVersion)
    
    if [[ $(echo -e "$MACOS_VERSION\n$MIN_MACOS_VERSION" | sort -V | head -n1) != "$MIN_MACOS_VERSION" ]]; then
        print_error "macOS $MIN_MACOS_VERSION or later is required. You have $MACOS_VERSION"
        exit 1
    fi
    
    print_success "macOS $MACOS_VERSION detected ✓"
}

# Function to check Xcode version
check_xcode_version() {
    print_info "Checking Xcode version..."
    
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed. Please install Xcode from the App Store."
        exit 1
    fi
    
    XCODE_VERSION=$(xcodebuild -version | grep "Xcode" | cut -d' ' -f2)
    
    if [[ $(echo -e "$XCODE_VERSION\n$MIN_XCODE_VERSION" | sort -V | head -n1) != "$MIN_XCODE_VERSION" ]]; then
        print_error "Xcode $MIN_XCODE_VERSION or later is required. You have $XCODE_VERSION"
        exit 1
    fi
    
    print_success "Xcode $XCODE_VERSION detected ✓"
}

# Function to check Swift version
check_swift_version() {
    print_info "Checking Swift version..."
    
    if ! command -v swift &> /dev/null; then
        print_error "Swift is not installed. Please install Xcode."
        exit 1
    fi
    
    SWIFT_VERSION=$(swift --version | grep "Swift version" | cut -d' ' -f3)
    print_success "Swift $SWIFT_VERSION detected ✓"
}

# Function to check system requirements
check_system_requirements() {
    print_info "Checking system requirements..."
    echo "======================================"
    
    check_macos_version
    check_xcode_version
    check_swift_version
    
    # Check for required tools
    print_info "Checking for required tools..."
    
    local required_tools=("git" "xcrun")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_success "$tool found ✓"
        else
            print_error "$tool not found. Please install it."
            exit 1
        fi
    done
    
    echo "======================================"
    print_success "All system requirements met!"
}

# Function to clean previous builds
clean_build() {
    print_info "Cleaning previous builds..."
    
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
        print_success "Removed $BUILD_DIR directory"
    fi
    
    if [[ -d "$TEST_REPORT_DIR" ]]; then
        rm -rf "$TEST_REPORT_DIR"
        print_success "Removed $TEST_REPORT_DIR directory"
    fi
    
    # Clean Swift Package Manager cache
    swift package clean
    print_success "Cleaned Swift Package Manager cache"
}

# Function to build the application
build_app() {
    local config=$1
    print_info "Building $PROJECT_NAME in $config mode..."
    
    if [[ "$config" == "release" ]]; then
        swift build -c release --arch arm64 --arch x86_64
    else
        swift build -c debug
    fi
    
    print_success "Build completed successfully!"
}

# Function to run unit tests
run_unit_tests() {
    print_info "Running unit tests..."
    mkdir -p "$TEST_REPORT_DIR"
    
    local test_output="$TEST_REPORT_DIR/unit_tests_${TIMESTAMP}.txt"
    
    case "$TEST_SUITE" in
        "unit")
            swift test --filter "Unit" 2>&1 | tee "$test_output"
            ;;
        "integration")
            swift test --filter "Integration" 2>&1 | tee "$test_output"
            ;;
        "performance")
            swift test --filter "Performance" 2>&1 | tee "$test_output"
            ;;
        "all")
            swift test 2>&1 | tee "$test_output"
            ;;
        *)
            swift test --filter "$TEST_SUITE" 2>&1 | tee "$test_output"
            ;;
    esac
    
    print_success "Tests completed! Results saved to $test_output"
}

# Function to generate code coverage
generate_coverage() {
    print_info "Generating code coverage report..."
    
    swift test --enable-code-coverage
    
    # Find the .xcresult bundle
    local xcresult=$(find "$BUILD_DIR" -name "*.xcresult" -type d | head -n 1)
    
    if [[ -n "$xcresult" ]]; then
        xcrun xccov view --report "$xcresult" > "$TEST_REPORT_DIR/coverage_${TIMESTAMP}.txt"
        print_success "Coverage report saved to $TEST_REPORT_DIR/coverage_${TIMESTAMP}.txt"
    else
        print_warning "Could not find .xcresult bundle for coverage report"
    fi
}

# Function to create app bundle
create_app_bundle() {
    print_info "Creating macOS app bundle..."
    
    local executable_path="$BUILD_DIR/release/$PROJECT_NAME"
    local app_bundle="$PROJECT_NAME.app"
    local contents_dir="$app_bundle/Contents"
    local macos_dir="$contents_dir/MacOS"
    local resources_dir="$contents_dir/Resources"
    
    # Remove existing app bundle
    rm -rf "$app_bundle"
    
    # Create directory structure
    mkdir -p "$macos_dir"
    mkdir -p "$resources_dir"
    
    # Copy executable
    cp "$executable_path" "$macos_dir/$PROJECT_NAME"
    
    # Create Info.plist
    cat > "$contents_dir/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>WinAmp Player</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>WinAmp Player needs microphone access for visualizations</string>
</dict>
</plist>
EOF
    
    print_success "App bundle created: $app_bundle"
}

# Function to package the app for distribution
package_for_distribution() {
    print_info "Packaging app for distribution..."
    
    mkdir -p "$RELEASE_DIR"
    
    local dmg_name="${PROJECT_NAME}_${TIMESTAMP}.dmg"
    local zip_name="${PROJECT_NAME}_${TIMESTAMP}.zip"
    
    # Create ZIP archive
    zip -r "$RELEASE_DIR/$zip_name" "$PROJECT_NAME.app"
    print_success "Created ZIP archive: $RELEASE_DIR/$zip_name"
    
    # Create DMG (optional, requires create-dmg tool)
    if command -v create-dmg &> /dev/null; then
        create-dmg \
            --volname "$PROJECT_NAME" \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$PROJECT_NAME.app" 150 150 \
            --app-drop-link 450 150 \
            "$RELEASE_DIR/$dmg_name" \
            "$PROJECT_NAME.app"
        print_success "Created DMG: $RELEASE_DIR/$dmg_name"
    else
        print_warning "create-dmg not found. Skipping DMG creation."
        print_info "Install with: brew install create-dmg"
    fi
}

# Function to generate test report
generate_test_report() {
    print_info "Generating test report..."
    
    local report_file="$TEST_REPORT_DIR/test_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# WinAmpPlayer Test Report

**Date:** $(date)
**macOS Version:** $MACOS_VERSION
**Xcode Version:** $XCODE_VERSION
**Swift Version:** $SWIFT_VERSION
**Build Configuration:** $BUILD_CONFIG

## Test Summary

### Test Suite: $TEST_SUITE

$(if [[ -f "$TEST_REPORT_DIR/unit_tests_${TIMESTAMP}.txt" ]]; then
    echo "### Test Results"
    echo '```'
    tail -n 20 "$TEST_REPORT_DIR/unit_tests_${TIMESTAMP}.txt"
    echo '```'
fi)

## Build Information

- **Project:** $PROJECT_NAME
- **Bundle ID:** $BUNDLE_ID
- **Minimum macOS Version:** $MIN_MACOS_VERSION

## Files Generated

- Test Output: test_reports/unit_tests_${TIMESTAMP}.txt
$(if [[ "$GENERATE_COVERAGE" == true ]]; then
    echo "- Coverage Report: test_reports/coverage_${TIMESTAMP}.txt"
fi)
$(if [[ "$PACKAGE_APP" == true ]]; then
    echo "- Release Package: releases/${PROJECT_NAME}_${TIMESTAMP}.zip"
fi)

## Notes

- All tests run in isolated environments
- Performance tests may vary based on hardware
- Background audio tests require proper entitlements

EOF
    
    print_success "Test report generated: $report_file"
}

# Function to open in Xcode
open_in_xcode() {
    print_info "Opening project in Xcode..."
    
    # Generate Xcode project
    swift package generate-xcodeproj
    
    # Open in Xcode
    open "${PROJECT_NAME}.xcodeproj"
    
    print_success "Opened in Xcode"
}

# Function to build and run the app
build_and_run() {
    print_info "Building and running $PROJECT_NAME..."
    
    swift run
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -c, --config <debug|release>    Build configuration (default: debug)
    -t, --test-suite <suite>        Run specific test suite (default: all)
                                    Options: all, unit, integration, performance, or specific test name
    -s, --skip-tests                Skip running tests
    -x, --xcode                     Open project in Xcode
    -r, --run                       Build and run the application
    -C, --coverage                  Generate code coverage report
    -p, --package                   Package app for distribution
    -o, --clean-only                Only clean build artifacts
    -h, --help                      Display this help message

EXAMPLES:
    # Debug build with all tests
    $0

    # Release build without tests
    $0 --config release --skip-tests

    # Run only unit tests
    $0 --test-suite unit

    # Build, test, and package for distribution
    $0 --config release --package

    # Open in Xcode
    $0 --xcode

    # Build and run directly
    $0 --run

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            BUILD_CONFIG="$2"
            shift 2
            ;;
        -t|--test-suite)
            TEST_SUITE="$2"
            shift 2
            ;;
        -s|--skip-tests)
            RUN_TESTS=false
            shift
            ;;
        -x|--xcode)
            OPEN_XCODE=true
            shift
            ;;
        -r|--run)
            BUILD_AND_RUN=true
            shift
            ;;
        -C|--coverage)
            GENERATE_COVERAGE=true
            shift
            ;;
        -p|--package)
            PACKAGE_APP=true
            BUILD_CONFIG="release"
            shift
            ;;
        -o|--clean-only)
            clean_build
            print_success "Clean completed!"
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
print_info "WinAmpPlayer macOS Build and Test Script"
echo "=========================================="

# Check system requirements
check_system_requirements

# Open in Xcode if requested
if [[ "$OPEN_XCODE" == true ]]; then
    open_in_xcode
    exit 0
fi

# Clean previous builds
clean_build

# Build the application
build_app "$BUILD_CONFIG"

# Run tests if not skipped
if [[ "$RUN_TESTS" == true ]]; then
    run_unit_tests
    
    if [[ "$GENERATE_COVERAGE" == true ]]; then
        generate_coverage
    fi
fi

# Create app bundle and package if requested
if [[ "$PACKAGE_APP" == true ]]; then
    create_app_bundle
    package_for_distribution
fi

# Generate test report
generate_test_report

# Build and run if requested
if [[ "$BUILD_AND_RUN" == true ]]; then
    build_and_run
fi

print_success "All tasks completed successfully!"
echo "======================================"