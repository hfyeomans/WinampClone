//
//  PluginProtocol.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Base protocol for all WinAmp plugins
//

import Foundation
import SwiftUI
import Combine

// MARK: - Plugin Types

/// Types of plugins supported by WinAmp Player
public enum PluginType: String, CaseIterable {
    case visualization = "Visualization"
    case dsp = "DSP"
    case general = "General"
    case input = "Input"
    case output = "Output"
}

// MARK: - Plugin State

/// Current state of a plugin
public enum PluginState {
    case unloaded
    case loading
    case loaded
    case active
    case error(Error)
}

// MARK: - Plugin Metadata

/// Metadata describing any WinAmp plugin
public struct PluginMetadata: Codable {
    public let identifier: String
    public let name: String
    public let type: PluginType
    public let version: String
    public let apiVersion: String
    public let author: String
    public let description: String
    public let website: URL?
    public let iconName: String?
    public let minimumHostVersion: String
    public let requiredCapabilities: [String]
    
    public init(
        identifier: String,
        name: String,
        type: PluginType,
        version: String,
        apiVersion: String = "1.0",
        author: String,
        description: String,
        website: URL? = nil,
        iconName: String? = nil,
        minimumHostVersion: String = "1.0.0",
        requiredCapabilities: [String] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.type = type
        self.version = version
        self.apiVersion = apiVersion
        self.author = author
        self.description = description
        self.website = website
        self.iconName = iconName
        self.minimumHostVersion = minimumHostVersion
        self.requiredCapabilities = requiredCapabilities
    }
}

// MARK: - Plugin Host

/// Interface provided by the host application to plugins
public protocol PluginHost: AnyObject {
    /// Current version of the host application
    var hostVersion: String { get }
    
    /// Available capabilities of the host
    var capabilities: Set<String> { get }
    
    /// Logger for plugin messages
    func log(_ message: String, level: LogLevel, from plugin: String)
    
    /// Request a capability from the host
    func requestCapability(_ capability: String) -> Bool
    
    /// Get a service from the host
    func getService<T>(_ serviceType: T.Type) -> T?
    
    /// Send a message to other plugins
    func sendMessage(_ message: PluginMessage, to recipient: String?)
    
    /// Subscribe to messages
    func subscribeToMessages(from sender: String?, handler: @escaping (PluginMessage) -> Void) -> AnyCancellable
}

/// Log levels for plugin messages
public enum LogLevel: String {
    case debug
    case info
    case warning
    case error
}

// MARK: - Plugin Messages

/// Message that can be sent between plugins
public struct PluginMessage {
    public let id: UUID
    public let sender: String
    public let type: String
    public let payload: Any?
    public let timestamp: Date
    
    public init(sender: String, type: String, payload: Any? = nil) {
        self.id = UUID()
        self.sender = sender
        self.type = type
        self.payload = payload
        self.timestamp = Date()
    }
}

// MARK: - Base Plugin Protocol

/// Base protocol that all plugins must implement
public protocol WAPlugin: AnyObject {
    /// Plugin metadata
    var metadata: PluginMetadata { get }
    
    /// Current state of the plugin
    var state: PluginState { get }
    
    /// State change publisher
    var statePublisher: AnyPublisher<PluginState, Never> { get }
    
    /// Initialize the plugin with a host
    func initialize(host: PluginHost) async throws
    
    /// Activate the plugin
    func activate() async throws
    
    /// Deactivate the plugin
    func deactivate() async throws
    
    /// Shutdown the plugin
    func shutdown() async
    
    /// Get configuration view
    func configurationView() -> AnyView?
    
    /// Export current settings
    func exportSettings() -> Data?
    
    /// Import settings
    func importSettings(_ data: Data) throws
    
    /// Handle a message from another plugin
    func handleMessage(_ message: PluginMessage)
}

// MARK: - Plugin Bundle

/// Information about a plugin bundle
public struct PluginBundle {
    public let url: URL
    public let metadata: PluginMetadata
    public let bundleIdentifier: String
    public let executableURL: URL
    public let resourcesURL: URL
    public let isBuiltIn: Bool
    
    /// Load the plugin from this bundle
    public func loadPlugin() throws -> WAPlugin {
        // This would dynamically load the plugin
        // For now, throw an error as a placeholder
        throw PluginError.loadingFailed("Dynamic loading not yet implemented")
    }
}

// MARK: - Plugin Errors

/// Errors that can occur with plugins
public enum PluginError: LocalizedError {
    case incompatibleVersion(required: String, actual: String)
    case missingCapability(String)
    case loadingFailed(String)
    case initializationFailed(String)
    case invalidConfiguration
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let required, let actual):
            return "Incompatible version. Required: \(required), Actual: \(actual)"
        case .missingCapability(let capability):
            return "Missing required capability: \(capability)"
        case .loadingFailed(let reason):
            return "Failed to load plugin: \(reason)"
        case .initializationFailed(let reason):
            return "Failed to initialize plugin: \(reason)"
        case .invalidConfiguration:
            return "Invalid plugin configuration"
        case .unauthorized:
            return "Plugin is not authorized"
        }
    }
}

// MARK: - Plugin Services

/// Service that can be provided by the host to plugins
public protocol PluginService {
    static var identifier: String { get }
}

/// Audio service for plugins
public protocol AudioService: PluginService {
    var sampleRate: Double { get }
    var bufferSize: Int { get }
    var isPlaying: Bool { get }
    
    func getCurrentTime() -> TimeInterval
    func getCurrentTrack() -> Track?
}

/// UI service for plugins
public protocol UIService: PluginService {
    func showWindow(content: AnyView, title: String, size: CGSize?)
    func showAlert(title: String, message: String)
    func requestUserInput(prompt: String, defaultValue: String?) async -> String?
}

/// File service for plugins
public protocol FileService: PluginService {
    func readFile(at url: URL) async throws -> Data
    func writeFile(_ data: Data, to url: URL) async throws
    func getPluginDataDirectory() -> URL
}

/// Network service for plugins
public protocol NetworkService: PluginService {
    func fetch(from url: URL) async throws -> Data
    func post(_ data: Data, to url: URL) async throws -> Data
}