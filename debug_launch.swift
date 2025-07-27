import Foundation

print("🚀 Starting WinAmpPlayer debug launch...")

// Set environment variables for debugging
setenv("CFNETWORK_DIAGNOSTICS", "3", 1)
setenv("OS_ACTIVITY_MODE", "debug", 1)

// Launch the app
let task = Process()
task.executableURL = URL(fileURLWithPath: ".build/release/WinAmpPlayer")
task.standardOutput = FileHandle.standardOutput
task.standardError = FileHandle.standardError

do {
    print("📍 Launching from: \(task.executableURL!.path)")
    print("📂 Current directory: \(FileManager.default.currentDirectoryPath)")
    
    try task.run()
    print("✅ Process started with PID: \(task.processIdentifier)")
    
    // Wait a bit to see if there's any output
    Thread.sleep(forTimeInterval: 2.0)
    
    if task.isRunning {
        print("⏳ App is still running after 2 seconds...")
        print("⚠️  The app might be waiting for UI events or hanging during initialization")
        print("💡 Try checking Activity Monitor for the WinAmpPlayer process")
        
        // Force terminate after 5 seconds
        Thread.sleep(forTimeInterval: 3.0)
        task.terminate()
        print("🛑 Process terminated")
    } else {
        print("❌ App exited with code: \(task.terminationStatus)")
    }
} catch {
    print("❌ Failed to launch: \(error)")
}