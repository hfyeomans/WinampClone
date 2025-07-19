import Foundation
import Combine
import AppKit

// MARK: - Message Types

/// Base protocol for all window messages
protocol WindowMessage {
    var id: UUID { get }
    var timestamp: Date { get }
    var sourceWindowID: String? { get }
    var targetWindowID: String? { get }
}

/// Message priority levels
enum MessagePriority {
    case low
    case normal
    case high
    case critical
}

/// Base message implementation
struct BaseMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
}

// MARK: - Playback Messages

struct PlaybackStateMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let state: PlaybackState
    let position: TimeInterval?
    
    enum PlaybackState {
        case playing
        case paused
        case stopped
        case loading
    }
}

struct TrackChangeMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let track: TrackInfo
    
    struct TrackInfo {
        let title: String
        let artist: String?
        let album: String?
        let duration: TimeInterval
        let bitrate: Int?
        let sampleRate: Int?
        let fileURL: URL?
    }
}

// MARK: - Audio Messages

struct VolumeChangeMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let volume: Float // 0.0 - 1.0
    let balance: Float // -1.0 (left) to 1.0 (right)
}

struct EQSettingsMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let preamp: Float
    let bands: [Float] // 10 bands typically
    let enabled: Bool
}

struct VisualizationDataMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let leftChannel: [Float]
    let rightChannel: [Float]
    let fftData: [Float]?
    let peakLeft: Float
    let peakRight: Float
}

// MARK: - Playlist Messages

struct PlaylistUpdateMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let action: PlaylistAction
    let tracks: [TrackChangeMessage.TrackInfo]?
    let indices: [Int]?
    
    enum PlaylistAction {
        case add
        case remove
        case reorder
        case clear
        case load
    }
}

struct PlaylistSelectionMessage: WindowMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let selectedIndex: Int?
    let selectedIndices: Set<Int>?
}

// MARK: - Request/Response Messages

protocol RequestMessage: WindowMessage {
    associatedtype Response: ResponseMessage
    var responseType: Response.Type { get }
}

protocol ResponseMessage: WindowMessage {
    var requestID: UUID { get }
    var success: Bool { get }
    var error: WindowCommunicatorError? { get }
}

struct TrackInfoRequest: RequestMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let trackIndex: Int?
    var responseType: TrackInfoResponse.Type { TrackInfoResponse.self }
}

struct TrackInfoResponse: ResponseMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let requestID: UUID
    let success: Bool
    let error: WindowCommunicatorError?
    let track: TrackChangeMessage.TrackInfo?
}

struct PlaylistDataRequest: RequestMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    var responseType: PlaylistDataResponse.Type { PlaylistDataResponse.self }
}

struct PlaylistDataResponse: ResponseMessage {
    let id = UUID()
    let timestamp = Date()
    var sourceWindowID: String?
    var targetWindowID: String?
    
    let requestID: UUID
    let success: Bool
    let error: WindowCommunicatorError?
    let tracks: [TrackChangeMessage.TrackInfo]
    let currentIndex: Int?
}

// MARK: - Window Communication Error

enum WindowCommunicatorError: LocalizedError {
    case windowNotFound(String)
    case messageTimeout
    case invalidMessage
    case deliveryFailed(String)
    case responseTimeout
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .windowNotFound(let id):
            return "Window not found: \(id)"
        case .messageTimeout:
            return "Message delivery timed out"
        case .invalidMessage:
            return "Invalid message format"
        case .deliveryFailed(let reason):
            return "Message delivery failed: \(reason)"
        case .responseTimeout:
            return "Response timed out"
        case .invalidResponse:
            return "Invalid response received"
        }
    }
}

// MARK: - Message Router

protocol MessageRouter {
    func route<T: WindowMessage>(_ message: T) -> [String] // Returns target window IDs
}

class DefaultMessageRouter: MessageRouter {
    func route<T: WindowMessage>(_ message: T) -> [String] {
        // If specific target, route only there
        if let targetID = message.targetWindowID {
            return [targetID]
        }
        
        // Otherwise broadcast based on message type
        switch message {
        case is PlaybackStateMessage, is TrackChangeMessage:
            // All windows interested in playback
            return [] // Empty means broadcast to all
        case is VisualizationDataMessage:
            // Only visualization windows
            return [] // Would filter by window type in real implementation
        default:
            return []
        }
    }
}

// MARK: - Window Communicator

class WindowCommunicator: ObservableObject {
    static let shared = WindowCommunicator()
    
    // MARK: - Properties
    
    private let messageQueue = DispatchQueue(label: "com.winamp.windowcommunicator", attributes: .concurrent)
    private let responseQueue = DispatchQueue(label: "com.winamp.windowcommunicator.responses")
    
    // Publishers for different message types
    private let playbackStateSubject = PassthroughSubject<PlaybackStateMessage, Never>()
    private let trackChangeSubject = PassthroughSubject<TrackChangeMessage, Never>()
    private let volumeChangeSubject = PassthroughSubject<VolumeChangeMessage, Never>()
    private let eqSettingsSubject = PassthroughSubject<EQSettingsMessage, Never>()
    private let visualizationDataSubject = PassthroughSubject<VisualizationDataMessage, Never>()
    private let playlistUpdateSubject = PassthroughSubject<PlaylistUpdateMessage, Never>()
    private let playlistSelectionSubject = PassthroughSubject<PlaylistSelectionMessage, Never>()
    
    // Generic message subject for custom messages
    private let genericMessageSubject = PassthroughSubject<WindowMessage, Never>()
    
    // Response handling
    private var pendingResponses = [UUID: (ResponseMessage) -> Void]()
    private var responseTimeouts = [UUID: Timer]()
    
    // Message history for debugging
    private var messageHistory = [WindowMessage]()
    private let maxHistorySize = 1000
    private let historyLock = NSLock()
    
    // Window registry
    private var registeredWindows = Set<String>()
    private let windowsLock = NSLock()
    
    // Router
    private let router: MessageRouter
    
    // MARK: - Publishers
    
    var playbackStatePublisher: AnyPublisher<PlaybackStateMessage, Never> {
        playbackStateSubject.eraseToAnyPublisher()
    }
    
    var trackChangePublisher: AnyPublisher<TrackChangeMessage, Never> {
        trackChangeSubject.eraseToAnyPublisher()
    }
    
    var volumeChangePublisher: AnyPublisher<VolumeChangeMessage, Never> {
        volumeChangeSubject.eraseToAnyPublisher()
    }
    
    var eqSettingsPublisher: AnyPublisher<EQSettingsMessage, Never> {
        eqSettingsSubject.eraseToAnyPublisher()
    }
    
    var visualizationDataPublisher: AnyPublisher<VisualizationDataMessage, Never> {
        visualizationDataSubject.eraseToAnyPublisher()
    }
    
    var playlistUpdatePublisher: AnyPublisher<PlaylistUpdateMessage, Never> {
        playlistUpdateSubject.eraseToAnyPublisher()
    }
    
    var playlistSelectionPublisher: AnyPublisher<PlaylistSelectionMessage, Never> {
        playlistSelectionSubject.eraseToAnyPublisher()
    }
    
    var genericMessagePublisher: AnyPublisher<WindowMessage, Never> {
        genericMessageSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(router: MessageRouter = DefaultMessageRouter()) {
        self.router = router
    }
    
    // MARK: - Window Registration
    
    func registerWindow(_ windowID: String) {
        windowsLock.lock()
        defer { windowsLock.unlock() }
        registeredWindows.insert(windowID)
    }
    
    func unregisterWindow(_ windowID: String) {
        windowsLock.lock()
        defer { windowsLock.unlock() }
        registeredWindows.remove(windowID)
    }
    
    func isWindowRegistered(_ windowID: String) -> Bool {
        windowsLock.lock()
        defer { windowsLock.unlock() }
        return registeredWindows.contains(windowID)
    }
    
    // MARK: - Message Sending
    
    /// Send a message asynchronously
    func send<T: WindowMessage>(_ message: T, priority: MessagePriority = .normal) {
        messageQueue.async(qos: priority.qos) { [weak self] in
            self?.processMessage(message)
        }
    }
    
    /// Send a message synchronously
    func sendSync<T: WindowMessage>(_ message: T) throws {
        try messageQueue.sync {
            try processMessageSync(message)
        }
    }
    
    /// Send a request and wait for response
    func request<T: RequestMessage>(_ request: T, timeout: TimeInterval = 5.0) async throws -> T.Response {
        return try await withCheckedThrowingContinuation { continuation in
            responseQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WindowCommunicatorError.deliveryFailed("Communicator deallocated"))
                    return
                }
                
                // Store the response handler
                self.pendingResponses[request.id] = { response in
                    if let typedResponse = response as? T.Response {
                        continuation.resume(returning: typedResponse)
                    } else {
                        continuation.resume(throwing: WindowCommunicatorError.invalidResponse)
                    }
                }
                
                // Set timeout
                let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                    self.responseQueue.async {
                        if self.pendingResponses[request.id] != nil {
                            self.pendingResponses.removeValue(forKey: request.id)
                            self.responseTimeouts.removeValue(forKey: request.id)
                            continuation.resume(throwing: WindowCommunicatorError.responseTimeout)
                        }
                    }
                }
                self.responseTimeouts[request.id] = timer
                
                // Send the request
                self.messageQueue.async {
                    self.processMessage(request)
                }
            }
        }
    }
    
    // MARK: - Message Processing
    
    private func processMessage<T: WindowMessage>(_ message: T) {
        // Add to history
        addToHistory(message)
        
        // Route message
        let targetIDs = router.route(message)
        
        // Publish to appropriate subjects
        switch message {
        case let msg as PlaybackStateMessage:
            playbackStateSubject.send(msg)
        case let msg as TrackChangeMessage:
            trackChangeSubject.send(msg)
        case let msg as VolumeChangeMessage:
            volumeChangeSubject.send(msg)
        case let msg as EQSettingsMessage:
            eqSettingsSubject.send(msg)
        case let msg as VisualizationDataMessage:
            visualizationDataSubject.send(msg)
        case let msg as PlaylistUpdateMessage:
            playlistUpdateSubject.send(msg)
        case let msg as PlaylistSelectionMessage:
            playlistSelectionSubject.send(msg)
        case let msg as ResponseMessage:
            handleResponse(msg)
        default:
            genericMessageSubject.send(message)
        }
    }
    
    private func processMessageSync<T: WindowMessage>(_ message: T) throws {
        // Validate target windows if specified
        if let targetID = message.targetWindowID {
            guard isWindowRegistered(targetID) else {
                throw WindowCommunicatorError.windowNotFound(targetID)
            }
        }
        
        processMessage(message)
    }
    
    private func handleResponse(_ response: ResponseMessage) {
        responseQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let handler = self.pendingResponses.removeValue(forKey: response.requestID) {
                handler(response)
                self.responseTimeouts[response.requestID]?.invalidate()
                self.responseTimeouts.removeValue(forKey: response.requestID)
            }
        }
    }
    
    // MARK: - Message History
    
    private func addToHistory(_ message: WindowMessage) {
        historyLock.lock()
        defer { historyLock.unlock() }
        
        messageHistory.append(message)
        
        // Trim history if needed
        if messageHistory.count > maxHistorySize {
            messageHistory.removeFirst(messageHistory.count - maxHistorySize)
        }
    }
    
    func getMessageHistory(limit: Int? = nil) -> [WindowMessage] {
        historyLock.lock()
        defer { historyLock.unlock() }
        
        if let limit = limit {
            return Array(messageHistory.suffix(limit))
        }
        return messageHistory
    }
    
    func clearMessageHistory() {
        historyLock.lock()
        defer { historyLock.unlock() }
        messageHistory.removeAll()
    }
    
    // MARK: - Debugging
    
    func printDebugInfo() {
        windowsLock.lock()
        let windowCount = registeredWindows.count
        let windows = registeredWindows
        windowsLock.unlock()
        
        historyLock.lock()
        let historyCount = messageHistory.count
        historyLock.unlock()
        
        responseQueue.async { [weak self] in
            let pendingCount = self?.pendingResponses.count ?? 0
            
            print("""
            WindowCommunicator Debug Info:
            - Registered Windows: \(windowCount)
            - Window IDs: \(windows)
            - Message History: \(historyCount) messages
            - Pending Responses: \(pendingCount)
            """)
        }
    }
}

// MARK: - Extensions

extension MessagePriority {
    var qos: DispatchQoS {
        switch self {
        case .low:
            return .utility
        case .normal:
            return .default
        case .high:
            return .userInitiated
        case .critical:
            return .userInteractive
        }
    }
}

// MARK: - Convenience Methods

extension WindowCommunicator {
    func broadcastPlaybackState(_ state: PlaybackStateMessage.PlaybackState, position: TimeInterval? = nil, from windowID: String? = nil) {
        let message = PlaybackStateMessage(
            sourceWindowID: windowID,
            targetWindowID: nil,
            state: state,
            position: position
        )
        send(message)
    }
    
    func broadcastTrackChange(_ track: TrackChangeMessage.TrackInfo, from windowID: String? = nil) {
        let message = TrackChangeMessage(
            sourceWindowID: windowID,
            targetWindowID: nil,
            track: track
        )
        send(message, priority: .high)
    }
    
    func broadcastVolumeChange(volume: Float, balance: Float, from windowID: String? = nil) {
        let message = VolumeChangeMessage(
            sourceWindowID: windowID,
            targetWindowID: nil,
            volume: volume,
            balance: balance
        )
        send(message)
    }
    
    func sendVisualizationData(left: [Float], right: [Float], fft: [Float]? = nil, peakLeft: Float, peakRight: Float, from windowID: String? = nil) {
        let message = VisualizationDataMessage(
            sourceWindowID: windowID,
            targetWindowID: nil,
            leftChannel: left,
            rightChannel: right,
            fftData: fft,
            peakLeft: peakLeft,
            peakRight: peakRight
        )
        send(message, priority: .high)
    }
}