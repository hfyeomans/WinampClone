//
//  PlaylistWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Playlist editor window implementation
//

import SwiftUI
import AppKit

/// Classic WinAmp-style playlist editor window
struct PlaylistWindow: View {
    @ObservedObject var playlistController: PlaylistController
    @State private var selectedTracks: Set<Track.ID> = []
    @State private var searchText = ""
    @State private var isShaded = false
    
    private let configuration = WinAmpWindowConfiguration(
        title: "Playlist Editor",
        windowType: .playlist,
        showTitleBar: true,
        resizable: true,
        minSize: CGSize(width: 275, height: 100),
        maxSize: CGSize(width: 600, height: 800)
    )
    
    var body: some View {
        WinAmpWindow(
            configuration: configuration
        ) {
            VStack(spacing: 0) {
                    // Playlist controls bar
                    PlaylistControlBar(
                        playlistController: playlistController,
                        selectedTracks: $selectedTracks,
                        searchText: $searchText
                    )
                    .frame(height: 20)
                    
                    // Track list
                    PlaylistTrackList(
                        tracks: filteredTracks,
                        currentTrack: playlistController.currentTrack,
                        selectedTracks: $selectedTracks,
                        onDoubleClick: { track in
                            Task {
                                try? await playlistController.playTrack(track)
                            }
                        }
                    )
                    
                    // Status bar
                    PlaylistStatusBar(
                        totalTracks: playlistController.currentPlaylist?.tracks.count ?? 0,
                        totalDuration: calculateTotalDuration(),
                        selectedCount: selectedTracks.count
                    )
                    .frame(height: 20)
                }
        }
        .onAppear {
            WindowCommunicator.shared.registerWindow("playlist")
        }
    }
    
    private var playlistTitle: String {
        playlistController.currentPlaylist?.name ?? "Playlist Editor"
    }
    
    private var filteredTracks: [Track] {
        guard let playlist = playlistController.currentPlaylist else { return [] }
        
        if searchText.isEmpty {
            return playlist.tracks
        } else {
            return playlist.tracks.filter { track in
                track.matchesSearch(searchText)
            }
        }
    }
    
    private func calculateTotalDuration() -> TimeInterval {
        playlistController.currentPlaylist?.tracks
            .compactMap { $0.duration }
            .reduce(0, +) ?? 0
    }
}

/// Shaded mode view for playlist window
struct ShadedPlaylistView: View {
    let currentTrack: Track?
    let trackCount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(trackCount) tracks")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(WinAmpColors.text)
            
            Spacer()
            
            if let track = currentTrack {
                Text(track.displayTitle)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(WinAmpColors.textHighlight)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Control bar for playlist operations
struct PlaylistControlBar: View {
    @ObservedObject var playlistController: PlaylistController
    @Binding var selectedTracks: Set<Track.ID>
    @Binding var searchText: String
    @State private var showingAddMenu = false
    @State private var showingSortMenu = false
    
    var body: some View {
        HStack(spacing: 2) {
            // Add button
            PlaylistButton(icon: "+", action: { showingAddMenu.toggle() })
                .popover(isPresented: $showingAddMenu) {
                    AddTracksMenu(playlistController: playlistController)
                }
            
            // Remove button
            PlaylistButton(icon: "-", action: removeTracks)
                .disabled(selectedTracks.isEmpty)
            
            // Select all button
            PlaylistButton(icon: "□", action: selectAll)
            
            // Sort button
            PlaylistButton(icon: "↕", action: { showingSortMenu.toggle() })
                .popover(isPresented: $showingSortMenu) {
                    SortMenu(playlistController: playlistController)
                }
            
            Spacer()
            
            // Search field
            PlaylistSearchField(text: $searchText)
                .frame(width: 100)
        }
        .padding(.horizontal, 4)
        .background(WinAmpColors.backgroundDark)
    }
    
    private func removeTracks() {
        guard let playlist = playlistController.currentPlaylist else { return }
        let tracksToRemove = playlist.tracks.filter { selectedTracks.contains($0.id) }
        
        for track in tracksToRemove {
            if let index = playlist.tracks.firstIndex(of: track) {
                playlist.removeTrack(at: index)
            }
        }
        selectedTracks.removeAll()
    }
    
    private func selectAll() {
        if let playlist = playlistController.currentPlaylist {
            selectedTracks = Set(playlist.tracks.map { $0.id })
        }
    }
}

/// Custom button style for playlist controls
struct PlaylistButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isPressed ? WinAmpColors.textDim : WinAmpColors.text)
                .frame(width: 20, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isPressed ? WinAmpColors.buttonPressed : WinAmpColors.button)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(WinAmpColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            isPressed = pressing
        } perform: {}
    }
}

/// Search field for filtering playlist
struct PlaylistSearchField: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = "Search..."
        searchField.font = .systemFont(ofSize: 10)
        searchField.delegate = context.coordinator
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: PlaylistSearchField
        
        init(_ parent: PlaylistSearchField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let searchField = obj.object as? NSSearchField {
                parent.text = searchField.stringValue
            }
        }
    }
}

/// Track list view
struct PlaylistTrackList: View {
    let tracks: [Track]
    let currentTrack: Track?
    @Binding var selectedTracks: Set<Track.ID>
    let onDoubleClick: (Track) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    PlaylistTrackRow(
                        index: index + 1,
                        track: track,
                        isCurrent: track.id == currentTrack?.id,
                        isSelected: selectedTracks.contains(track.id),
                        onSelect: { toggleSelection(track) },
                        onDoubleClick: { onDoubleClick(track) }
                    )
                }
            }
        }
        .background(WinAmpColors.background)
    }
    
    private func toggleSelection(_ track: Track) {
        if selectedTracks.contains(track.id) {
            selectedTracks.remove(track.id)
        } else {
            selectedTracks.insert(track.id)
        }
    }
}

/// Individual track row in playlist
struct PlaylistTrackRow: View {
    let index: Int
    let track: Track
    let isCurrent: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            // Track number
            Text(String(format: "%3d.", index))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 30, alignment: .trailing)
            
            // Track info
            VStack(alignment: .leading, spacing: 0) {
                Text(track.displayTitle)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let artist = track.artist {
                    Text(artist)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture {
            onSelect()
        }
    }
    
    private var textColor: Color {
        if isCurrent {
            return WinAmpColors.textHighlight
        } else if isSelected {
            return WinAmpColors.textSelected
        } else {
            return WinAmpColors.text
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return WinAmpColors.selection
        } else {
            return Color.clear
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Status bar showing playlist statistics
struct PlaylistStatusBar: View {
    let totalTracks: Int
    let totalDuration: TimeInterval
    let selectedCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(totalTracks) items")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
            
            if totalDuration > 0 {
                Text("•")
                Text(formatTotalDuration(totalDuration))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
            }
            
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
    
    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

/// Menu for adding tracks
struct AddTracksMenu: View {
    @ObservedObject var playlistController: PlaylistController
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuButton(title: "Add Files...", action: addFiles)
            MenuButton(title: "Add Folder...", action: addFolder)
            MenuButton(title: "Add URL...", action: addURL)
        }
        .padding(8)
        .frame(width: 150)
    }
    
    private func addFiles() {
        dismiss()
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Track.supportedContentTypes
        
        if panel.runModal() == .OK {
            let tracks = panel.urls.compactMap { url in
                Track(from: url)
            }
            
            if let playlist = playlistController.currentPlaylist {
                for track in tracks {
                    playlist.addTrack(track)
                }
            }
        }
    }
    
    private func addFolder() {
        dismiss()
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            // TODO: Implement folder scanning
        }
    }
    
    private func addURL() {
        dismiss()
        // TODO: Implement URL input dialog
    }
}

/// Menu for sorting options
struct SortMenu: View {
    @ObservedObject var playlistController: PlaylistController
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuButton(title: "Sort by Title", action: { sortBy(.title) })
            MenuButton(title: "Sort by Artist", action: { sortBy(.artist) })
            MenuButton(title: "Sort by Album", action: { sortBy(.album) })
            MenuButton(title: "Sort by Duration", action: { sortBy(.duration) })
            MenuButton(title: "Randomize", action: randomize)
            MenuButton(title: "Reverse", action: reverse)
        }
        .padding(8)
        .frame(width: 150)
    }
    
    private func sortBy(_ field: PlaylistSortField) {
        dismiss()
        playlistController.currentPlaylist?.sortTracks(by: field, ascending: true)
    }
    
    private func randomize() {
        dismiss()
        playlistController.currentPlaylist?.shuffleTracks()
    }
    
    private func reverse() {
        dismiss()
        playlistController.currentPlaylist?.tracks.reverse()
    }
}


/// Simple menu button component
struct MenuButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(isHovered ? .white : WinAmpColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(isHovered ? WinAmpColors.selection : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Extensions

extension Track {
    /// Check if track matches search query
    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        
        if title.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        if let artist = artist, artist.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        if let album = album, album.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        return false
    }
    
    /// Get supported content types for file selection
    static var supportedContentTypes: [UTType] {
        [.mp3, .mpeg4Audio, .wav, .aiff]
    }
}

// Add UTType import
import UniformTypeIdentifiers