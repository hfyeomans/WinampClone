//
//  macOSAudioDeviceManager.swift
//  WinAmpPlayer
//
//  Created on 2025-07-19.
//  macOS-specific audio device management using CoreAudio
//

import Foundation
import CoreAudio
import AVFoundation
import Combine

/// Manages audio output devices on macOS using CoreAudio APIs
final class macOSAudioDeviceManager: ObservableObject {
    
    // MARK: - Types
    
    /// Represents an audio device on macOS
    struct AudioDevice: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
        let uid: String
        let isInput: Bool
        let isOutput: Bool
        let manufacturer: String?
        let sampleRate: Double
        let bufferSize: UInt32
        
        /// Human-readable description
        var description: String {
            return "\(name) (\(manufacturer ?? "Unknown"))"
        }
    }
    
    /// Audio device configuration
    struct DeviceConfiguration {
        let device: AudioDevice
        let sampleRate: Double
        let bufferSize: UInt32
    }
    
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = macOSAudioDeviceManager()
    
    /// Available output devices
    @Published private(set) var availableDevices: [AudioDevice] = []
    
    /// Currently selected output device
    @Published private(set) var currentDevice: AudioDevice?
    
    /// Device connection/disconnection events
    let deviceChangePublisher = PassthroughSubject<(device: AudioDevice, connected: Bool), Never>()
    
    private var deviceListenerID: AudioObjectPropertyListenerProc?
    
    // MARK: - Initialization
    
    init() {
        setupDeviceChangeListener()
        updateAvailableDevices()
        selectDefaultDevice()
    }
    
    deinit {
        removeDeviceChangeListener()
    }
    
    // MARK: - Public Methods
    
    /// Set the output device for an AVAudioEngine
    func setOutputDevice(_ device: AudioDevice, for engine: AVAudioEngine) throws {
        guard device.isOutput else {
            throw AudioDeviceError.notAnOutputDevice
        }
        
        // Get the AVAudioUnit for the output node
        guard let outputUnit = engine.outputNode.audioUnit else {
            throw AudioDeviceError.noOutputUnit
        }
        
        // Set the device ID on the audio unit
        var deviceID = device.id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let result = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            size
        )
        
        if result != noErr {
            throw AudioDeviceError.failedToSetDevice(OSStatus: result)
        }
        
        currentDevice = device
    }
    
    /// Get the default system output device
    func getDefaultOutputDevice() -> AudioDevice? {
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        guard result == noErr else { return nil }
        
        return createDevice(from: deviceID)
    }
    
    // MARK: - Private Methods
    
    @objc private func handleDeviceListChanged() {
        updateAvailableDevices()
    }
    
    private func setupDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Note: Property listener requires C callback without capturing context
        // Using notification center instead for device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceListChanged),
            name: NSNotification.Name("AudioDevicesChanged"),
            object: nil
        )
        
        // For now, poll for changes periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAvailableDevices()
        }
    }
    
    private func removeDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if let listener = deviceListenerID {
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                listener,
                nil
            )
        }
    }
    
    private func updateAvailableDevices() {
        let deviceIDs = getAllAudioDeviceIDs()
        var devices: [AudioDevice] = []
        
        for deviceID in deviceIDs {
            if let device = createDevice(from: deviceID), device.isOutput {
                devices.append(device)
            }
        }
        
        // Check for changes
        let oldDeviceIDs = Set(availableDevices.map { $0.id })
        let newDeviceIDs = Set(devices.map { $0.id })
        
        // Notify about disconnected devices
        for device in availableDevices {
            if !newDeviceIDs.contains(device.id) {
                deviceChangePublisher.send((device: device, connected: false))
            }
        }
        
        // Notify about connected devices
        for device in devices {
            if !oldDeviceIDs.contains(device.id) {
                deviceChangePublisher.send((device: device, connected: true))
            }
        }
        
        availableDevices = devices
    }
    
    private func getAllAudioDeviceIDs() -> [AudioDeviceID] {
        var size: UInt32 = 0
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get size
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        )
        
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        // Get device IDs
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceIDs
        )
        
        return deviceIDs
    }
    
    private func createDevice(from deviceID: AudioDeviceID) -> AudioDevice? {
        guard let name = getDeviceProperty(deviceID: deviceID, selector: kAudioObjectPropertyName) as String? else {
            return nil
        }
        
        let uid = getDeviceProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceUID) as String? ?? ""
        let manufacturer = getDeviceProperty(deviceID: deviceID, selector: kAudioObjectPropertyManufacturer) as String?
        
        // Check if device has input/output streams
        let isInput = hasStreams(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)
        let isOutput = hasStreams(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
        
        // Get sample rate
        var sampleRate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &sampleRate)
        
        // Get buffer size
        var bufferSize: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyBufferFrameSize
        
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &bufferSize)
        
        return AudioDevice(
            id: deviceID,
            name: name,
            uid: uid,
            isInput: isInput,
            isOutput: isOutput,
            manufacturer: manufacturer,
            sampleRate: sampleRate,
            bufferSize: bufferSize
        )
    }
    
    private func getDeviceProperty<T>(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        
        var result: T?
        
        if T.self == String.self {
            var name: CFString = "" as CFString
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
            result = name as String as? T
        } else {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &result)
        }
        
        return result
    }
    
    private func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var size: UInt32 = 0
        let result = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        
        return result == noErr && size > 0
    }
    
    private func selectDefaultDevice() {
        currentDevice = getDefaultOutputDevice()
    }
}

// MARK: - Errors

enum AudioDeviceError: LocalizedError {
    case notAnOutputDevice
    case noOutputUnit
    case failedToSetDevice(OSStatus: OSStatus)
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAnOutputDevice:
            return "Selected device is not an output device"
        case .noOutputUnit:
            return "Audio engine has no output unit"
        case .failedToSetDevice(let status):
            return "Failed to set audio device (error: \(status))"
        case .deviceNotFound:
            return "Audio device not found"
        }
    }
}