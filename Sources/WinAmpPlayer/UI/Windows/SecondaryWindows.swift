//
//  SecondaryWindows.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Secondary window management and presentation
//

import SwiftUI
import AppKit

/// Window type enumeration for secondary windows
enum SecondaryWindowType: String, CaseIterable {
    case playlist = "playlist"
    case equalizer = "equalizer"
    case library = "library"
    
    var title: String {
        switch self {
        case .playlist: return "Playlist Editor"
        case .equalizer: return "Equalizer"
        case .library: return "Media Library"
        }
    }
    
    var defaultSize: CGSize {
        switch self {
        case .playlist: return CGSize(width: 275, height: 232)
        case .equalizer: return CGSize(width: 275, height: 116)
        case .library: return CGSize(width: 400, height: 300)
        }
    }
}

/// Manager for secondary windows
class SecondaryWindowManager: ObservableObject {
    static let shared = SecondaryWindowManager()
    
    private var windows: [SecondaryWindowType: NSWindow] = [:]
    
    private init() {}
    
    /// Open or focus a secondary window
    func openWindow(_ type: SecondaryWindowType, playlistController: PlaylistController? = nil, audioEngine: AudioEngine? = nil) {
        if let existingWindow = windows[type] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: type.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = type.title
        window.center()
        window.isReleasedWhenClosed = false
        
        // Set up content based on window type
        switch type {
        case .playlist:
            if let controller = playlistController {
                let contentView = PlaylistWindow(playlistController: controller)
                window.contentView = NSHostingView(rootView: contentView)
            }
        case .equalizer:
            if let engine = audioEngine {
                let contentView = EqualizerWindow(audioEngine: engine)
                window.contentView = NSHostingView(rootView: contentView)
            }
        case .library:
            if let controller = playlistController {
                let contentView = LibraryWindow(playlistController: controller)
                window.contentView = NSHostingView(rootView: contentView)
            }
        }
        
        window.makeKeyAndOrderFront(nil)
        windows[type] = window
    }
    
    /// Close a secondary window
    func closeWindow(_ type: SecondaryWindowType) {
        windows[type]?.close()
        windows[type] = nil
    }
    
    /// Toggle window visibility
    func toggleWindow(_ type: SecondaryWindowType, playlistController: PlaylistController? = nil, audioEngine: AudioEngine? = nil) {
        if let window = windows[type], window.isVisible {
            window.close()
        } else {
            openWindow(type, playlistController: playlistController, audioEngine: audioEngine)
        }
    }
    
    /// Check if window is open
    func isWindowOpen(_ type: SecondaryWindowType) -> Bool {
        return windows[type]?.isVisible ?? false
    }
}

