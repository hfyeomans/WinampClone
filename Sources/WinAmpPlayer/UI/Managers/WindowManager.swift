//
//  WindowManager.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02
//

import SwiftUI
import AppKit
import Combine

/// Represents different types of windows in the WinAmp player
public enum WindowType: String, CaseIterable, Codable {
    case main = "main"
    case equalizer = "equalizer"
    case playlist = "playlist"
    case library = "library"
    
    var defaultSize: CGSize {
        switch self {
        case .main:
            return CGSize(width: 275, height: 116)
        case .equalizer:
            return CGSize(width: 275, height: 116)
        case .playlist:
            return CGSize(width: 275, height: 232)
        case .library:
            return CGSize(width: 600, height: 400)
        }
    }
    
    var minSize: CGSize {
        switch self {
        case .main:
            return CGSize(width: 275, height: 14) // Shade mode height
        case .equalizer:
            return CGSize(width: 275, height: 14)
        case .playlist:
            return CGSize(width: 125, height: 100)
        case .library:
            return CGSize(width: 400, height: 300)
        }
    }
}

/// Represents the state of a window
public struct WindowState: Codable {
    var position: CGPoint
    var size: CGSize
    var isVisible: Bool
    var isShaded: Bool
    var isAlwaysOnTop: Bool
    var transparency: Double
    var screenID: Int? // For multi-monitor support
    
    init(position: CGPoint = .zero, 
         size: CGSize = .zero, 
         isVisible: Bool = false,
         isShaded: Bool = false,
         isAlwaysOnTop: Bool = false,
         transparency: Double = 1.0,
         screenID: Int? = nil) {
        self.position = position
        self.size = size
        self.isVisible = isVisible
        self.isShaded = isShaded
        self.isAlwaysOnTop = isAlwaysOnTop
        self.transparency = transparency
        self.screenID = screenID
    }
}

/// Represents a managed window
public class ManagedWindow: ObservableObject {
    let id = UUID()
    let type: WindowType
    weak var window: NSWindow?
    @Published var state: WindowState
    
    private var windowObservers: [NSKeyValueObservation] = []
    
    init(type: WindowType, window: NSWindow? = nil, state: WindowState = WindowState()) {
        self.type = type
        self.window = window
        self.state = state
        
        if let window = window {
            setupWindowObservers(window)
        }
    }
    
    func setWindow(_ window: NSWindow) {
        self.window = window
        setupWindowObservers(window)
        updateStateFromWindow()
    }
    
    private func setupWindowObservers(_ window: NSWindow) {
        // Clean up existing observers
        windowObservers.forEach { $0.invalidate() }
        windowObservers.removeAll()
        
        // Observe frame changes
        let frameObserver = window.observe(\.frame, options: [.new]) { [weak self] window, _ in
            self?.updateStateFromWindow()
        }
        windowObservers.append(frameObserver)
        
        // Observe visibility
        let visibilityObserver = window.observe(\.isVisible, options: [.new]) { [weak self] window, _ in
            self?.state.isVisible = window.isVisible
        }
        windowObservers.append(visibilityObserver)
        
        // Observe alpha value
        let alphaObserver = window.observe(\.alphaValue, options: [.new]) { [weak self] window, _ in
            self?.state.transparency = Double(window.alphaValue)
        }
        windowObservers.append(alphaObserver)
    }
    
    private func updateStateFromWindow() {
        guard let window = window else { return }
        state.position = window.frame.origin
        state.size = window.frame.size
        state.isVisible = window.isVisible
        state.transparency = Double(window.alphaValue)
        state.screenID = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int
    }
    
    deinit {
        windowObservers.forEach { $0.invalidate() }
    }
}

/// Window snapping/docking event
public struct WindowSnapEvent {
    let sourceWindow: WindowType
    let targetWindow: WindowType
    let edge: Edge
    
    enum Edge {
        case top, bottom, left, right
    }
}

/// Main window manager for the WinAmp player
public class WindowManager: ObservableObject {
    public static let shared = WindowManager()
    
    // Constants
    private let snapThreshold: CGFloat = 20
    private let userDefaultsKey = "WinAmpPlayer.WindowStates"
    
    // Published properties
    @Published public private(set) var windows: [WindowType: ManagedWindow] = [:]
    @Published public private(set) var dockedWindows: Set<WindowType> = []
    
    // Event publishers
    public let windowSnapEventPublisher = PassthroughSubject<WindowSnapEvent, Never>()
    public let windowStateChangedPublisher = PassthroughSubject<(WindowType, WindowState), Never>()
    
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.winampplayer.windowmanager", attributes: .concurrent)
    
    private init() {
        loadWindowStates()
        setupAutoSave()
    }
    
    // MARK: - Window Registration
    
    /// Registers a window with the manager
    public func registerWindow(_ window: NSWindow, type: WindowType) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let existingWindow = self.windows[type] {
                    existingWindow.setWindow(window)
                } else {
                    let managedWindow = ManagedWindow(type: type, window: window)
                    self.windows[type] = managedWindow
                    
                    // Subscribe to state changes
                    managedWindow.$state
                        .sink { [weak self] state in
                            self?.windowStateChangedPublisher.send((type, state))
                            self?.checkForSnapping(windowType: type)
                        }
                        .store(in: &self.cancellables)
                }
                
                // Apply saved state if available
                if let savedState = self.loadWindowState(for: type) {
                    self.applyState(savedState, to: window, type: type)
                }
                
                // Set up window delegate for additional control
                window.delegate = WindowDelegate(manager: self, type: type)
            }
        }
    }
    
    /// Unregisters a window
    public func unregisterWindow(type: WindowType) {
        queue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.windows.removeValue(forKey: type)
                self?.dockedWindows.remove(type)
            }
        }
    }
    
    // MARK: - Window Operations
    
    /// Shows a window
    public func showWindow(_ type: WindowType) {
        DispatchQueue.main.async { [weak self] in
            guard let managedWindow = self?.windows[type],
                  let window = managedWindow.window else { return }
            
            window.makeKeyAndOrderFront(nil)
            managedWindow.state.isVisible = true
        }
    }
    
    /// Hides a window
    public func hideWindow(_ type: WindowType) {
        DispatchQueue.main.async { [weak self] in
            guard let managedWindow = self?.windows[type],
                  let window = managedWindow.window else { return }
            
            window.orderOut(nil)
            managedWindow.state.isVisible = false
        }
    }
    
    /// Toggles window visibility
    public func toggleWindow(_ type: WindowType) {
        if let managedWindow = windows[type], managedWindow.state.isVisible {
            hideWindow(type)
        } else {
            showWindow(type)
        }
    }
    
    /// Sets window shade mode
    public func setShadeMode(_ isShaded: Bool, for type: WindowType) {
        DispatchQueue.main.async { [weak self] in
            guard let managedWindow = self?.windows[type],
                  let window = managedWindow.window else { return }
            
            let currentFrame = window.frame
            let newHeight = isShaded ? type.minSize.height : type.defaultSize.height
            let newFrame = CGRect(x: currentFrame.origin.x,
                                  y: currentFrame.origin.y + currentFrame.height - newHeight,
                                  width: currentFrame.width,
                                  height: newHeight)
            
            window.setFrame(newFrame, display: true, animate: true)
            managedWindow.state.isShaded = isShaded
            managedWindow.state.size = newFrame.size
        }
    }
    
    /// Sets always on top for a window
    public func setAlwaysOnTop(_ alwaysOnTop: Bool, for type: WindowType) {
        DispatchQueue.main.async { [weak self] in
            guard let managedWindow = self?.windows[type],
                  let window = managedWindow.window else { return }
            
            window.level = alwaysOnTop ? .floating : .normal
            managedWindow.state.isAlwaysOnTop = alwaysOnTop
        }
    }
    
    /// Sets window transparency
    public func setTransparency(_ transparency: Double, for type: WindowType) {
        DispatchQueue.main.async { [weak self] in
            guard let managedWindow = self?.windows[type],
                  let window = managedWindow.window else { return }
            
            window.alphaValue = CGFloat(transparency)
            managedWindow.state.transparency = transparency
        }
    }
    
    // MARK: - Window Snapping/Docking
    
    internal func checkForSnapping(windowType: WindowType) {
        guard let sourceWindow = windows[windowType],
              let sourceNSWindow = sourceWindow.window else { return }
        
        let sourceFrame = sourceNSWindow.frame
        
        // Check against all other windows
        for (targetType, targetWindow) in windows where targetType != windowType {
            guard let targetNSWindow = targetWindow.window,
                  targetNSWindow.isVisible else { continue }
            
            let targetFrame = targetNSWindow.frame
            
            // Check horizontal snapping
            if abs(sourceFrame.minX - targetFrame.maxX) < snapThreshold {
                snapWindow(sourceNSWindow, to: targetFrame.maxX, axis: .horizontal)
                windowSnapEventPublisher.send(WindowSnapEvent(sourceWindow: windowType, targetWindow: targetType, edge: .left))
            } else if abs(sourceFrame.maxX - targetFrame.minX) < snapThreshold {
                snapWindow(sourceNSWindow, to: targetFrame.minX - sourceFrame.width, axis: .horizontal)
                windowSnapEventPublisher.send(WindowSnapEvent(sourceWindow: windowType, targetWindow: targetType, edge: .right))
            }
            
            // Check vertical snapping
            if abs(sourceFrame.minY - targetFrame.maxY) < snapThreshold {
                snapWindow(sourceNSWindow, to: targetFrame.maxY, axis: .vertical)
                windowSnapEventPublisher.send(WindowSnapEvent(sourceWindow: windowType, targetWindow: targetType, edge: .bottom))
            } else if abs(sourceFrame.maxY - targetFrame.minY) < snapThreshold {
                snapWindow(sourceNSWindow, to: targetFrame.minY - sourceFrame.height, axis: .vertical)
                windowSnapEventPublisher.send(WindowSnapEvent(sourceWindow: windowType, targetWindow: targetType, edge: .top))
            }
        }
    }
    
    private func snapWindow(_ window: NSWindow, to position: CGFloat, axis: Axis) {
        var frame = window.frame
        switch axis {
        case .horizontal:
            frame.origin.x = position
        case .vertical:
            frame.origin.y = position
        }
        window.setFrame(frame, display: true)
    }
    
    private enum Axis {
        case horizontal, vertical
    }
    
    // MARK: - Layout Management
    
    /// Saves the current window layout
    public func saveLayout(name: String? = nil) {
        let states = windows.mapValues { $0.state }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(states)
            
            let key = name.map { "WinAmpPlayer.Layout.\($0)" } ?? userDefaultsKey
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save window layout: \(error)")
        }
    }
    
    /// Restores a saved window layout
    public func restoreLayout(name: String? = nil) {
        let key = name.map { "WinAmpPlayer.Layout.\($0)" } ?? userDefaultsKey
        
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        
        do {
            let decoder = JSONDecoder()
            let states = try decoder.decode([WindowType: WindowState].self, from: data)
            
            for (type, state) in states {
                if let window = windows[type]?.window {
                    applyState(state, to: window, type: type)
                }
            }
        } catch {
            print("Failed to restore window layout: \(error)")
        }
    }
    
    /// Gets list of saved layouts
    public func getSavedLayouts() -> [String] {
        let prefix = "WinAmpPlayer.Layout."
        return UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }
    
    // MARK: - Multi-Monitor Support
    
    /// Moves window to specific screen
    public func moveWindow(_ type: WindowType, toScreen screenID: Int) {
        guard let managedWindow = windows[type],
              let window = managedWindow.window,
              let screen = NSScreen.screens.first(where: { 
                  $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int == screenID 
              }) else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        // Center on new screen
        let newOrigin = CGPoint(
            x: screenFrame.midX - windowFrame.width / 2,
            y: screenFrame.midY - windowFrame.height / 2
        )
        
        window.setFrameOrigin(newOrigin)
        managedWindow.state.screenID = screenID
    }
    
    /// Gets current screen for window
    public func getScreen(for type: WindowType) -> NSScreen? {
        return windows[type]?.window?.screen
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSave() {
        // Auto-save window states every 5 seconds if there were changes
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.saveWindowStates()
            }
            .store(in: &cancellables)
    }
    
    private func loadWindowStates() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            let states = try decoder.decode([WindowType: WindowState].self, from: data)
            
            for (type, state) in states {
                windows[type] = ManagedWindow(type: type, state: state)
            }
        } catch {
            print("Failed to load window states: \(error)")
        }
    }
    
    private func saveWindowStates() {
        let states = windows.mapValues { $0.state }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(states)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save window states: \(error)")
        }
    }
    
    private func loadWindowState(for type: WindowType) -> WindowState? {
        return windows[type]?.state
    }
    
    private func applyState(_ state: WindowState, to window: NSWindow, type: WindowType) {
        // Apply position and size
        let frame = CGRect(origin: state.position, size: state.size)
        window.setFrame(frame, display: false)
        
        // Apply visibility
        if state.isVisible {
            window.makeKeyAndOrderFront(nil)
        }
        
        // Apply transparency
        window.alphaValue = CGFloat(state.transparency)
        
        // Apply always on top
        window.level = state.isAlwaysOnTop ? .floating : .normal
        
        // Update managed window state
        windows[type]?.state = state
    }
}

// MARK: - Window Delegate

private class WindowDelegate: NSObject, NSWindowDelegate {
    weak var manager: WindowManager?
    let type: WindowType
    
    init(manager: WindowManager, type: WindowType) {
        self.manager = manager
        self.type = type
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        manager?.hideWindow(type)
    }
    
    func windowDidMove(_ notification: Notification) {
        manager?.checkForSnapping(windowType: type)
    }
    
    func windowDidResize(_ notification: Notification) {
        // Update size in managed window state
        if let window = notification.object as? NSWindow,
           let managedWindow = manager?.windows[type] {
            managedWindow.state.size = window.frame.size
        }
    }
    
    func windowDidChangeScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow,
           let managedWindow = manager?.windows[type],
           let screenID = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int {
            managedWindow.state.screenID = screenID
        }
    }
}

// MARK: - Extensions

extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

extension CGSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}