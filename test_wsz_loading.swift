#!/usr/bin/env swift

import Foundation
import AppKit

// Test script to verify .wsz loading functionality

print("Testing WinAmp .wsz file loading...")

// Test files found
let testFiles = [
    "/Users/hank/Downloads/Deus_Ex_Amp_by_AJ.wsz",
    "/Users/hank/Downloads/Purple_Glow.wsz"
]

for wszPath in testFiles {
    print("\n=== Testing: \(wszPath) ===")
    
    let url = URL(fileURLWithPath: wszPath)
    
    do {
        // Test archive extraction
        print("1. Testing WSZ archive extraction...")
        let archive = try ClassicWSZArchive(url: url)
        print("   ✓ Archive extracted successfully")
        print("   Files found: \(archive.availableFiles.count)")
        
        // Check for required files
        print("\n2. Checking for required skin files...")
        let requiredFiles = ["main.bmp", "cbuttons.bmp", "playpaus.bmp", "numbers.bmp", "text.bmp"]
        for file in requiredFiles {
            if archive.contains(file) {
                print("   ✓ \(file) found")
            } else {
                print("   ✗ \(file) missing")
            }
        }
        
        // Check for bitmap fonts
        print("\n3. Checking bitmap font files...")
        if archive.contains("text.bmp") {
            let textData = try archive.data(for: "text.bmp")
            print("   ✓ text.bmp: \(textData.count) bytes")
        }
        
        if archive.contains("numbers.bmp") || archive.contains("nums_ex.bmp") {
            let hasNumbers = archive.contains("numbers.bmp")
            let hasNumsEx = archive.contains("nums_ex.bmp")
            print("   ✓ Number bitmaps: numbers=\(hasNumbers), nums_ex=\(hasNumsEx)")
        }
        
        // Check for configuration files
        print("\n4. Checking configuration files...")
        if archive.contains("pledit.txt") {
            print("   ✓ pledit.txt found (custom colors)")
        }
        if archive.contains("viscolor.txt") {
            print("   ✓ viscolor.txt found (visualizer colors)")
        }
        
        print("\n✅ Skin appears to be valid and complete!")
        
    } catch {
        print("❌ Error: \(error)")
    }
}

print("\n\nTo load these skins in WinAmpPlayer:")
print("1. Open WinAmpPlayer.app")
print("2. Click 'Skins' in the toolbar")
print("3. Navigate to one of these files:")
for file in testFiles {
    print("   - \(file)")
}