#!/usr/bin/env swift

//
//  run_tests.swift
//  WinAmpPlayer Test Executor
//
//  Command-line script to execute comprehensive tests
//

import Foundation

print("WinAmp Player - Test Execution Script")
print("=====================================")
print("")

// Build the project first
print("Building project...")
let buildProcess = Process()
buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
buildProcess.arguments = ["build", "--configuration", "debug"]
buildProcess.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

do {
    try buildProcess.run()
    buildProcess.waitUntilExit()
    
    if buildProcess.terminationStatus != 0 {
        print("❌ Build failed with exit code: \(buildProcess.terminationStatus)")
        exit(1)
    }
    
    print("✅ Build succeeded")
    print("")
    
    // Run tests
    print("Running tests...")
    let testProcess = Process()
    testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    testProcess.arguments = ["test", "--parallel"]
    testProcess.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    try testProcess.run()
    testProcess.waitUntilExit()
    
    if testProcess.terminationStatus == 0 {
        print("")
        print("✅ All tests passed!")
    } else {
        print("")
        print("❌ Some tests failed. Exit code: \(testProcess.terminationStatus)")
        exit(1)
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}