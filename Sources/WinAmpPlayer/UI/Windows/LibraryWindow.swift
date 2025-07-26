//
//  LibraryWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Media library browser window implementation
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Library view mode
enum LibraryViewMode: String, CaseIterable {
    case folders = "Folders"
    case artists = "Artists"
    case albums = "Albums"
    case genres = "Genres"
    
    var icon: String {
        switch self {
        case .folders: return "folder"
        case .artists: return "person.2"
        case .albums: return "square.stack"
        case .genres: return "guitars"
        }
    }
}

/// Library item for tree view
struct LibraryItem: Identifiable {
    let id = UUID()
    let name: String
    let type: ItemType
    let url: URL?
    var children: [LibraryItem]?
    var tracks: [Track]?
    
    enum ItemType {
        case folder
        case artist
        case album
        case genre
        case track
    }
    
    var icon: String {
        switch type {
        case .folder: return "folder"
        case .artist: return "person"
        case .album: return "square.stack"
        case .genre: return "guitars"
        case .track: return "music.note"
        }
    }
    
    var isExpandable: Bool {
        return children != nil && !children!.isEmpty
    }
}

/// Classic WinAmp-style media library window
struct LibraryWindow: View {
    @StateObject private var libraryController: LibraryController
    @ObservedObject var playlistController: PlaylistController
    @State private var selectedViewMode: LibraryViewMode = .folders
    @State private var searchText = ""
    @State private var selectedItems: Set<LibraryItem.ID> = []
    @State private var expandedItems: Set<LibraryItem.ID> = []
    
    private let configuration = WinAmpWindowConfiguration(
        title: "Media Library",
        windowType: .library,
        showTitleBar: true,
        resizable: true,
        minSize: CGSize(width: 400, height: 300),
        maxSize: CGSize(width: 800, height: 600)
    )
    
    init(playlistController: PlaylistController) {
        self.playlistController = playlistController
        _libraryController = StateObject(wrappedValue: LibraryController())
    }
    
    var body: some View {
        WinAmpWindow(
            configuration: configuration
        ) {
            VStack(spacing: 0) {
                // Toolbar
                LibraryToolbar(
                    viewMode: $selectedViewMode,
                    searchText: $searchText,
                    onScan: scanLibrary,
                    onRefresh: refreshLibrary
                )
                .frame(height: 30)
                
                // Content area
                HSplitView {
                    // Tree view
                    ScrollView {
                        LibraryTreeView(
                            items: filteredItems,
                            selectedItems: $selectedItems,
                            expandedItems: $expandedItems,
                            onDoubleClick: handleDoubleClick
                        )
                        .padding(4)
                    }
                    .frame(minWidth: 200)
                    .background(WinAmpColors.background)
                    
                    // Detail view
                    LibraryDetailView(
                        selectedItems: selectedItemsData,
                        playlistController: playlistController
                    )
                    .frame(minWidth: 200)
                    .background(WinAmpColors.backgroundLight)
                }
                
                // Status bar
                LibraryStatusBar(
                    totalTracks: libraryController.totalTracks,
                    totalSize: libraryController.totalSize,
                    selectedCount: selectedItems.count
                )
                .frame(height: 20)
            }
        }
        .onAppear {
            WindowCommunicator.shared.registerWindow("library")
            libraryController.loadLibrary()
        }
    }
    
    private var filteredItems: [LibraryItem] {
        if searchText.isEmpty {
            return libraryController.rootItems(for: selectedViewMode)
        } else {
            return libraryController.searchItems(searchText, in: selectedViewMode)
        }
    }
    
    private var selectedItemsData: [LibraryItem] {
        libraryController.allItems.filter { selectedItems.contains($0.id) }
    }
    
    private func handleDoubleClick(_ item: LibraryItem) {
        switch item.type {
        case .track:
            if let url = item.url, let track = Track(from: url) {
                playlistController.currentPlaylist?.addTrack(track)
                Task {
                    try? await playlistController.playTrack(track)
                }
            }
        case .folder, .artist, .album, .genre:
            // Toggle expansion
            if expandedItems.contains(item.id) {
                expandedItems.remove(item.id)
            } else {
                expandedItems.insert(item.id)
            }
        }
    }
    
    private func scanLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Select Music Folders"
        
        if panel.runModal() == .OK {
            libraryController.scanFolders(panel.urls)
        }
    }
    
    private func refreshLibrary() {
        libraryController.refreshLibrary()
    }
}

/// Library toolbar
struct LibraryToolbar: View {
    @Binding var viewMode: LibraryViewMode
    @Binding var searchText: String
    let onScan: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // View mode selector
            Picker("View", selection: $viewMode) {
                ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
            
            Spacer()
            
            // Search field
            PlaylistSearchField(text: $searchText)
                .frame(width: 150)
            
            // Action buttons
            LibraryToolbarButton(icon: "arrow.clockwise", action: onRefresh)
            LibraryToolbarButton(icon: "folder.badge.plus", action: onScan)
        }
        .padding(.horizontal, 8)
        .background(WinAmpColors.backgroundDark)
    }
}

/// Library toolbar button
struct LibraryToolbarButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? WinAmpColors.text : WinAmpColors.textDim)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Library tree view
struct LibraryTreeView: View {
    let items: [LibraryItem]
    @Binding var selectedItems: Set<LibraryItem.ID>
    @Binding var expandedItems: Set<LibraryItem.ID>
    let onDoubleClick: (LibraryItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                LibraryTreeNode(
                    item: item,
                    level: 0,
                    selectedItems: $selectedItems,
                    expandedItems: $expandedItems,
                    onDoubleClick: onDoubleClick
                )
            }
        }
    }
}

/// Individual tree node
struct LibraryTreeNode: View {
    let item: LibraryItem
    let level: Int
    @Binding var selectedItems: Set<LibraryItem.ID>
    @Binding var expandedItems: Set<LibraryItem.ID>
    let onDoubleClick: (LibraryItem) -> Void
    
    private var isExpanded: Bool {
        expandedItems.contains(item.id)
    }
    
    private var isSelected: Bool {
        selectedItems.contains(item.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<level, id: \.self) { _ in
                    Spacer()
                        .frame(width: 20)
                }
                
                // Expand/collapse button
                if item.isExpandable {
                    Button(action: toggleExpansion) {
                        Text(isExpanded ? "▼" : "▶")
                            .font(.system(size: 8))
                            .foregroundColor(WinAmpColors.textDim)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer()
                        .frame(width: 12)
                }
                
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? WinAmpColors.textHighlight : WinAmpColors.text)
                
                // Name
                Text(item.name)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(isSelected ? WinAmpColors.textHighlight : WinAmpColors.text)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isSelected ? WinAmpColors.selection.opacity(0.3) : Color.clear)
            .onTapGesture {
                toggleSelection()
            }
            .onTapGesture(count: 2) {
                onDoubleClick(item)
            }
            
            // Children (if expanded)
            if isExpanded, let children = item.children {
                ForEach(children) { child in
                    LibraryTreeNode(
                        item: child,
                        level: level + 1,
                        selectedItems: $selectedItems,
                        expandedItems: $expandedItems,
                        onDoubleClick: onDoubleClick
                    )
                }
            }
        }
    }
    
    private func toggleExpansion() {
        if isExpanded {
            expandedItems.remove(item.id)
        } else {
            expandedItems.insert(item.id)
        }
    }
    
    private func toggleSelection() {
        if isSelected {
            selectedItems.remove(item.id)
        } else {
            selectedItems = [item.id] // Single selection for now
        }
    }
}

/// Library detail view
struct LibraryDetailView: View {
    let selectedItems: [LibraryItem]
    @ObservedObject var playlistController: PlaylistController
    
    var body: some View {
        if selectedItems.isEmpty {
            Text("Select an item to view details")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(WinAmpColors.textDim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedItems.count == 1, let item = selectedItems.first {
            ItemDetailView(item: item, playlistController: playlistController)
        } else {
            MultiSelectionView(items: selectedItems, playlistController: playlistController)
        }
    }
}

/// Single item detail view
struct ItemDetailView: View {
    let item: LibraryItem
    @ObservedObject var playlistController: PlaylistController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item info
            Text(item.name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(WinAmpColors.text)
            
            Text(item.type.description)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(WinAmpColors.textDim)
            
            Divider()
                .background(WinAmpColors.border)
            
            // Actions
            VStack(alignment: .leading, spacing: 4) {
                DetailActionButton(title: "Add to Playlist", icon: "plus") {
                    addToPlaylist(item)
                }
                
                DetailActionButton(title: "Play", icon: "play") {
                    playItem(item)
                }
                
                if item.type == .folder {
                    DetailActionButton(title: "Scan Folder", icon: "arrow.clockwise") {
                        // TODO: Implement folder scanning
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func addToPlaylist(_ item: LibraryItem) {
        guard let playlist = playlistController.currentPlaylist else { return }
        
        if let tracks = item.tracks {
            for track in tracks {
                playlist.addTrack(track)
            }
        } else if let url = item.url, item.type == .track {
            if let track = Track(from: url) {
                playlist.addTrack(track)
            }
        }
    }
    
    private func playItem(_ item: LibraryItem) {
        if let tracks = item.tracks, let firstTrack = tracks.first {
            Task {
                try? await playlistController.playTrack(firstTrack)
            }
        } else if let url = item.url, item.type == .track {
            if let track = Track(from: url) {
                Task {
                    try? await playlistController.playTrack(track)
                }
            }
        }
    }
}

/// Multi-selection view
struct MultiSelectionView: View {
    let items: [LibraryItem]
    @ObservedObject var playlistController: PlaylistController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(items.count) items selected")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(WinAmpColors.text)
            
            Divider()
                .background(WinAmpColors.border)
            
            DetailActionButton(title: "Add All to Playlist", icon: "plus") {
                addAllToPlaylist()
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func addAllToPlaylist() {
        guard let playlist = playlistController.currentPlaylist else { return }
        
        for item in items {
            if let tracks = item.tracks {
                for track in tracks {
                    playlist.addTrack(track)
                }
            } else if let url = item.url, item.type == .track {
                if let track = Track(from: url) {
                    playlist.addTrack(track)
                }
            }
        }
    }
}

/// Detail action button
struct DetailActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
            .foregroundColor(isHovered ? WinAmpColors.text : WinAmpColors.textDim)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Library status bar
struct LibraryStatusBar: View {
    let totalTracks: Int
    let totalSize: Int64
    let selectedCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(totalTracks) tracks")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
            
            Text("•")
            
            Text(formatFileSize(totalSize))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
            
            Spacer()
            
            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
            }
        }
        .foregroundColor(WinAmpColors.textDim)
        .padding(.horizontal, 8)
        .background(WinAmpColors.backgroundDark)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Extensions

extension LibraryItem.ItemType {
    var description: String {
        switch self {
        case .folder: return "Folder"
        case .artist: return "Artist"
        case .album: return "Album"
        case .genre: return "Genre"
        case .track: return "Track"
        }
    }
}

/// Library controller managing the media library
class LibraryController: ObservableObject {
    @Published var allItems: [LibraryItem] = []
    @Published var totalTracks = 0
    @Published var totalSize: Int64 = 0
    
    private var folderItems: [LibraryItem] = []
    private var artistItems: [LibraryItem] = []
    private var albumItems: [LibraryItem] = []
    private var genreItems: [LibraryItem] = []
    
    func loadLibrary() {
        // TODO: Load from persistent storage
        // For now, start with empty library
    }
    
    func scanFolders(_ urls: [URL]) {
        // TODO: Implement folder scanning
        // This would recursively scan folders for audio files
        // and build the library structure
    }
    
    func refreshLibrary() {
        // TODO: Re-scan all tracked folders
    }
    
    func rootItems(for mode: LibraryViewMode) -> [LibraryItem] {
        switch mode {
        case .folders: return folderItems
        case .artists: return artistItems
        case .albums: return albumItems
        case .genres: return genreItems
        }
    }
    
    func searchItems(_ query: String, in mode: LibraryViewMode) -> [LibraryItem] {
        // TODO: Implement search functionality
        return []
    }
}