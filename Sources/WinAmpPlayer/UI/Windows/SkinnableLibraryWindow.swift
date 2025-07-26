//
//  SkinnableLibraryWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Skinnable media library browser window
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Skinnable library window
struct SkinnableLibraryWindow: View {
    @StateObject private var libraryController: LibraryController
    @StateObject private var skinManager = SkinManager.shared
    @ObservedObject var playlistController: PlaylistController
    @State private var selectedViewMode: LibraryViewMode = .folders
    @State private var searchText = ""
    @State private var selectedItems: Set<LibraryItem.ID> = []
    @State private var expandedItems: Set<LibraryItem.ID> = []
    
    private let windowSize = CGSize(width: 400, height: 300)
    
    init(playlistController: PlaylistController) {
        self.playlistController = playlistController
        _libraryController = StateObject(wrappedValue: LibraryController())
    }
    
    var body: some View {
        // Library window doesn't have a specific sprite in classic skins
        // So we'll use a styled window that matches the skin theme
        WinAmpWindow(
            configuration: WinAmpWindowConfiguration(
                title: "Media Library",
                windowType: .library,
                showTitleBar: true,
                resizable: true,
                minSize: CGSize(width: 400, height: 300),
                maxSize: CGSize(width: 800, height: 600)
            )
        ) {
            VStack(spacing: 0) {
                // Toolbar with skin-aware styling
                LibraryToolbar(
                    viewMode: $selectedViewMode,
                    searchText: $searchText,
                    onScan: scanLibrary,
                    onRefresh: refreshLibrary
                )
                .frame(height: 30)
                .background(backgroundColor)
                
                // Content area
                HSplitView {
                    // Tree view with skin colors
                    ScrollView {
                        SkinnableLibraryTreeView(
                            items: filteredItems,
                            selectedItems: $selectedItems,
                            expandedItems: $expandedItems,
                            onDoubleClick: handleDoubleClick
                        )
                        .padding(4)
                    }
                    .frame(minWidth: 200)
                    .background(backgroundColor)
                    
                    // Detail view with skin colors
                    SkinnableLibraryDetailView(
                        selectedItems: selectedItemsData,
                        playlistController: playlistController
                    )
                    .frame(minWidth: 200)
                    .background(secondaryBackgroundColor)
                }
                
                // Status bar
                LibraryStatusBar(
                    totalTracks: libraryController.totalTracks,
                    totalSize: libraryController.totalSize,
                    selectedCount: selectedItems.count
                )
                .frame(height: 20)
                .background(statusBarColor)
                .foregroundColor(textColor)
            }
        }
        .onAppear {
            WindowCommunicator.shared.registerWindow("library")
            libraryController.loadLibrary()
        }
    }
    
    // MARK: - Skin Colors
    
    private var backgroundColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalBackground)
        } else {
            return WinAmpColors.background
        }
    }
    
    private var secondaryBackgroundColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalBackground).opacity(0.9)
        } else {
            return WinAmpColors.backgroundLight
        }
    }
    
    private var statusBarColor: Color {
        return WinAmpColors.backgroundDark
    }
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalText)
        } else {
            return WinAmpColors.text
        }
    }
    
    // MARK: - Data
    
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
    
    // MARK: - Actions
    
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

/// Skinnable library tree view
struct SkinnableLibraryTreeView: View {
    let items: [LibraryItem]
    @Binding var selectedItems: Set<LibraryItem.ID>
    @Binding var expandedItems: Set<LibraryItem.ID>
    let onDoubleClick: (LibraryItem) -> Void
    @StateObject private var skinManager = SkinManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                SkinnableLibraryTreeNode(
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

/// Skinnable tree node
struct SkinnableLibraryTreeNode: View {
    let item: LibraryItem
    let level: Int
    @Binding var selectedItems: Set<LibraryItem.ID>
    @Binding var expandedItems: Set<LibraryItem.ID>
    let onDoubleClick: (LibraryItem) -> Void
    @StateObject private var skinManager = SkinManager.shared
    
    private var isExpanded: Bool {
        expandedItems.contains(item.id)
    }
    
    private var isSelected: Bool {
        selectedItems.contains(item.id)
    }
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            return isSelected ? Color(config.currentText) : Color(config.normalText)
        } else {
            return isSelected ? WinAmpColors.textHighlight : WinAmpColors.text
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            if let config = skinManager.playlistConfig {
                return Color(config.selectedBackground)
            } else {
                return WinAmpColors.selection.opacity(0.3)
            }
        } else {
            return Color.clear
        }
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
                            .foregroundColor(textColor.opacity(0.6))
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
                    .foregroundColor(textColor)
                
                // Name
                Text(item.name)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(backgroundColor)
            .onTapGesture {
                toggleSelection()
            }
            .onTapGesture(count: 2) {
                onDoubleClick(item)
            }
            
            // Children (if expanded)
            if isExpanded, let children = item.children {
                ForEach(children) { child in
                    SkinnableLibraryTreeNode(
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

/// Skinnable library detail view
struct SkinnableLibraryDetailView: View {
    let selectedItems: [LibraryItem]
    @ObservedObject var playlistController: PlaylistController
    @StateObject private var skinManager = SkinManager.shared
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalText)
        } else {
            return WinAmpColors.text
        }
    }
    
    private var dimTextColor: Color {
        textColor.opacity(0.7)
    }
    
    var body: some View {
        if selectedItems.isEmpty {
            Text("Select an item to view details")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(dimTextColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedItems.count == 1, let item = selectedItems.first {
            SkinnableItemDetailView(item: item, playlistController: playlistController)
        } else {
            SkinnableMultiSelectionView(items: selectedItems, playlistController: playlistController)
        }
    }
}

/// Skinnable single item detail view
struct SkinnableItemDetailView: View {
    let item: LibraryItem
    @ObservedObject var playlistController: PlaylistController
    @StateObject private var skinManager = SkinManager.shared
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalText)
        } else {
            return WinAmpColors.text
        }
    }
    
    private var dimTextColor: Color {
        textColor.opacity(0.7)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item info
            Text(item.name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(textColor)
            
            Text(item.type.description)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(dimTextColor)
            
            Divider()
                .background(WinAmpColors.border)
            
            // Actions
            VStack(alignment: .leading, spacing: 4) {
                SkinnableDetailActionButton(title: "Add to Playlist", icon: "plus") {
                    addToPlaylist(item)
                }
                
                SkinnableDetailActionButton(title: "Play", icon: "play") {
                    playItem(item)
                }
                
                if item.type == .folder {
                    SkinnableDetailActionButton(title: "Scan Folder", icon: "arrow.clockwise") {
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

/// Skinnable multi-selection view
struct SkinnableMultiSelectionView: View {
    let items: [LibraryItem]
    @ObservedObject var playlistController: PlaylistController
    @StateObject private var skinManager = SkinManager.shared
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalText)
        } else {
            return WinAmpColors.text
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(items.count) items selected")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(textColor)
            
            Divider()
                .background(WinAmpColors.border)
            
            SkinnableDetailActionButton(title: "Add All to Playlist", icon: "plus") {
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

/// Skinnable detail action button
struct SkinnableDetailActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    @StateObject private var skinManager = SkinManager.shared
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            return isHovered ? Color(config.currentText) : Color(config.normalText)
        } else {
            return isHovered ? WinAmpColors.text : WinAmpColors.textDim
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
            .foregroundColor(textColor)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}