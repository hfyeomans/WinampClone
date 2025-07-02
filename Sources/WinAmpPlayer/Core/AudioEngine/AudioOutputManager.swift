import Foundation
import AVFoundation
import Combine

/// Manages audio output devices and routing for the audio engine
public final class AudioOutputManager: NSObject {
    
    // MARK: - Types
    
    /// Represents an audio output device
    public struct AudioOutputDevice: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let uid: String
        public let portType: AVAudioSession.Port
        public let isBuiltIn: Bool
        public let channels: Int
        public let dataSources: [AVAudioSessionDataSourceDescription]?
        
        /// Human-readable description of the device type
        public var typeDescription: String {
            switch portType {
            case .builtInSpeaker:
                return "Built-in Speaker"
            case .headphones:
                return "Headphones"
            case .bluetoothA2DP:
                return "Bluetooth"
            case .bluetoothHFP:
                return "Bluetooth Handsfree"
            case .bluetoothLE:
                return "Bluetooth LE"
            case .airPlay:
                return "AirPlay"
            case .carAudio:
                return "Car Audio"
            case .HDMI:
                return "HDMI"
            case .lineOut:
                return "Line Out"
            case .AVB:
                return "AVB Device"
            case .displayPort:
                return "DisplayPort"
            case .PCI:
                return "PCI Device"
            case .thunderbolt:
                return "Thunderbolt"
            case .usbAudio:
                return "USB Audio"
            case .virtual:
                return "Virtual Device"
            default:
                return "Audio Device"
            }
        }
        
        /// Check if this is a wireless device
        public var isWireless: Bool {
            return portType == .bluetoothA2DP ||
                   portType == .bluetoothHFP ||
                   portType == .bluetoothLE ||
                   portType == .airPlay
        }
    }
    
    /// Audio output configuration
    public struct OutputConfiguration {
        public let primaryDevice: AudioOutputDevice
        public let additionalDevices: [AudioOutputDevice]
        public let isMirroring: Bool // If true, same audio to all devices
        
        public init(
            primaryDevice: AudioOutputDevice,
            additionalDevices: [AudioOutputDevice] = [],
            isMirroring: Bool = true
        ) {
            self.primaryDevice = primaryDevice
            self.additionalDevices = additionalDevices
            self.isMirroring = isMirroring
        }
    }
    
    // MARK: - Properties
    
    /// Singleton instance
    public static let shared = AudioOutputManager()
    
    /// Publisher for available output devices
    @Published public private(set) var availableOutputDevices: [AudioOutputDevice] = []
    
    /// Publisher for current output configuration
    @Published public private(set) var currentConfiguration: OutputConfiguration?
    
    /// Publisher for device connection events
    public let deviceConnectionPublisher = PassthroughSubject<(device: AudioOutputDevice, connected: Bool), Never>()
    
    /// Publisher for route change events
    public let routeChangePublisher = PassthroughSubject<AVAudioSession.RouteChangeReason, Never>()
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var routeChangeObserver: NSObjectProtocol?
    private var deviceChangeObserver: NSObjectProtocol?
    private let updateQueue = DispatchQueue(label: "com.winamp.audiooutputmanager", qos: .userInitiated)
    
    /// Track if we support multi-route (iOS 14+)
    private var supportsMultiRoute: Bool {
        if #available(iOS 14.0, macOS 11.0, *) {
            return audioSession.routeSharingPolicy == .independent
        }
        return false
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupObservers()
        updateAvailableDevices()
        updateCurrentConfiguration()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Public Methods
    
    /// Get the current default output device
    public var currentOutputDevice: AudioOutputDevice? {
        return currentConfiguration?.primaryDevice
    }
    
    /// Switch to a specific output device
    @discardableResult
    public func switchToDevice(_ device: AudioOutputDevice) -> Bool {
        do {
            // For built-in speaker, we need to override the port
            if device.portType == .builtInSpeaker {
                try audioSession.overrideOutputAudioPort(.speaker)
            } else {
                // For other devices, we need to set the preferred output
                if #available(iOS 14.0, macOS 11.0, *) {
                    // Find the actual port description
                    if let portDescription = findPortDescription(for: device) {
                        try audioSession.setPreferredOutput(portDescription)
                    }
                } else {
                    // For older iOS versions, we can only suggest route changes
                    // The system will handle the actual routing
                    try audioSession.overrideOutputAudioPort(.none)
                }
            }
            
            updateCurrentConfiguration()
            return true
        } catch {
            print("Failed to switch audio output device: \(error)")
            return false
        }
    }
    
    /// Enable simultaneous output to multiple devices (if supported)
    @discardableResult
    public func enableMultiOutput(devices: [AudioOutputDevice], mirroring: Bool = true) -> Bool {
        guard supportsMultiRoute else {
            print("Multi-route audio not supported on this platform")
            return false
        }
        
        if #available(iOS 14.0, macOS 11.0, *) {
            do {
                // Set route sharing policy for independent routing
                try audioSession.setRouteSharingPolicy(.independent)
                
                // Configure multi-route
                // Note: This is simplified - actual implementation would need
                // to configure AVAudioEngine with multiple output nodes
                if let primary = devices.first {
                    currentConfiguration = OutputConfiguration(
                        primaryDevice: primary,
                        additionalDevices: Array(devices.dropFirst()),
                        isMirroring: mirroring
                    )
                }
                
                return true
            } catch {
                print("Failed to enable multi-output: \(error)")
                return false
            }
        }
        
        return false
    }
    
    /// Disable multi-output and revert to single device
    public func disableMultiOutput() {
        if #available(iOS 14.0, macOS 11.0, *) {
            do {
                try audioSession.setRouteSharingPolicy(.default)
                updateCurrentConfiguration()
            } catch {
                print("Failed to disable multi-output: \(error)")
            }
        }
    }
    
    /// Check if a specific device is currently connected
    public func isDeviceConnected(_ device: AudioOutputDevice) -> Bool {
        return availableOutputDevices.contains(device)
    }
    
    /// Get available AirPlay devices
    public var airPlayDevices: [AudioOutputDevice] {
        return availableOutputDevices.filter { $0.portType == .airPlay }
    }
    
    /// Get available Bluetooth devices
    public var bluetoothDevices: [AudioOutputDevice] {
        return availableOutputDevices.filter { device in
            return device.portType == .bluetoothA2DP ||
                   device.portType == .bluetoothHFP ||
                   device.portType == .bluetoothLE
        }
    }
    
    /// Get available wired devices (headphones, line out, etc.)
    public var wiredDevices: [AudioOutputDevice] {
        return availableOutputDevices.filter { device in
            return device.portType == .headphones ||
                   device.portType == .lineOut ||
                   device.portType == .usbAudio ||
                   device.portType == .HDMI ||
                   device.portType == .displayPort ||
                   device.portType == .thunderbolt
        }
    }
    
    /// Force refresh of available devices
    public func refreshDevices() {
        updateQueue.async { [weak self] in
            self?.updateAvailableDevices()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        let notificationCenter = NotificationCenter.default
        
        // Route change observer
        routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        
        // iOS 14+ device change observer
        if #available(iOS 14.0, macOS 11.0, *) {
            deviceChangeObserver = notificationCenter.addObserver(
                forName: AVAudioSession.availableOutputsDidChangeNotification,
                object: audioSession,
                queue: .main
            ) { [weak self] _ in
                self?.updateAvailableDevices()
            }
        }
    }
    
    private func removeObservers() {
        let notificationCenter = NotificationCenter.default
        
        if let observer = routeChangeObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = deviceChangeObserver {
            notificationCenter.removeObserver(observer)
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Update available devices and configuration
        updateAvailableDevices()
        updateCurrentConfiguration()
        
        // Publish route change event
        routeChangePublisher.send(reason)
        
        // Handle specific reasons
        switch reason {
        case .oldDeviceUnavailable:
            // A device was disconnected
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs {
                    if let device = createDevice(from: output) {
                        deviceConnectionPublisher.send((device: device, connected: false))
                    }
                }
            }
            
        case .newDeviceAvailable:
            // A new device was connected
            let currentRoute = audioSession.currentRoute
            for output in currentRoute.outputs {
                if let device = createDevice(from: output) {
                    deviceConnectionPublisher.send((device: device, connected: true))
                }
            }
            
        default:
            break
        }
    }
    
    private func updateAvailableDevices() {
        var devices: [AudioOutputDevice] = []
        
        // Get current route outputs
        let currentRoute = audioSession.currentRoute
        for output in currentRoute.outputs {
            if let device = createDevice(from: output) {
                devices.append(device)
            }
        }
        
        // Always include built-in speaker as an option
        if !devices.contains(where: { $0.portType == .builtInSpeaker }) {
            let speakerDevice = AudioOutputDevice(
                id: AVAudioSession.Port.builtInSpeaker.rawValue,
                name: "Speaker",
                uid: AVAudioSession.Port.builtInSpeaker.rawValue,
                portType: .builtInSpeaker,
                isBuiltIn: true,
                channels: 2,
                dataSources: nil
            )
            devices.append(speakerDevice)
        }
        
        // Get available outputs (iOS 14+)
        if #available(iOS 14.0, macOS 11.0, *) {
            let availableOutputs = audioSession.availableOutputs ?? []
            for output in availableOutputs {
                if let device = createDevice(from: output),
                   !devices.contains(where: { $0.uid == device.uid }) {
                    devices.append(device)
                }
            }
        }
        
        // Update on main queue
        DispatchQueue.main.async { [weak self] in
            self?.availableOutputDevices = devices
        }
    }
    
    private func updateCurrentConfiguration() {
        let currentRoute = audioSession.currentRoute
        
        guard let primaryOutput = currentRoute.outputs.first,
              let primaryDevice = createDevice(from: primaryOutput) else {
            currentConfiguration = nil
            return
        }
        
        var additionalDevices: [AudioOutputDevice] = []
        for (index, output) in currentRoute.outputs.enumerated() where index > 0 {
            if let device = createDevice(from: output) {
                additionalDevices.append(device)
            }
        }
        
        currentConfiguration = OutputConfiguration(
            primaryDevice: primaryDevice,
            additionalDevices: additionalDevices,
            isMirroring: true // Assume mirroring for now
        )
    }
    
    private func createDevice(from portDescription: AVAudioSessionPortDescription) -> AudioOutputDevice? {
        return AudioOutputDevice(
            id: portDescription.uid,
            name: portDescription.portName,
            uid: portDescription.uid,
            portType: portDescription.portType,
            isBuiltIn: portDescription.portType == .builtInSpeaker || portDescription.portType == .builtInReceiver,
            channels: portDescription.channels?.count ?? 2,
            dataSources: portDescription.dataSources
        )
    }
    
    private func findPortDescription(for device: AudioOutputDevice) -> AVAudioSessionPortDescription? {
        // Check current route
        let currentRoute = audioSession.currentRoute
        for output in currentRoute.outputs {
            if output.uid == device.uid {
                return output
            }
        }
        
        // Check available outputs (iOS 14+)
        if #available(iOS 14.0, macOS 11.0, *) {
            let availableOutputs = audioSession.availableOutputs ?? []
            for output in availableOutputs {
                if output.uid == device.uid {
                    return output
                }
            }
        }
        
        return nil
    }
}

// MARK: - Convenience Extensions

extension AudioOutputManager {
    
    /// Check if headphones are currently connected
    public var areHeadphonesConnected: Bool {
        return availableOutputDevices.contains { $0.portType == .headphones }
    }
    
    /// Check if any Bluetooth audio device is connected
    public var isBluetoothConnected: Bool {
        return availableOutputDevices.contains { device in
            return device.portType == .bluetoothA2DP ||
                   device.portType == .bluetoothHFP ||
                   device.portType == .bluetoothLE
        }
    }
    
    /// Check if AirPlay is available
    public var isAirPlayAvailable: Bool {
        return availableOutputDevices.contains { $0.portType == .airPlay }
    }
    
    /// Get the preferred output device based on priority
    /// Priority: Headphones > Bluetooth > AirPlay > External > Built-in
    public var preferredOutputDevice: AudioOutputDevice? {
        // First check for wired headphones
        if let headphones = availableOutputDevices.first(where: { $0.portType == .headphones }) {
            return headphones
        }
        
        // Then Bluetooth
        if let bluetooth = availableOutputDevices.first(where: { 
            $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP 
        }) {
            return bluetooth
        }
        
        // Then AirPlay
        if let airplay = availableOutputDevices.first(where: { $0.portType == .airPlay }) {
            return airplay
        }
        
        // Then any external device
        if let external = availableOutputDevices.first(where: { !$0.isBuiltIn && !$0.isWireless }) {
            return external
        }
        
        // Finally built-in
        return availableOutputDevices.first(where: { $0.isBuiltIn })
    }
}