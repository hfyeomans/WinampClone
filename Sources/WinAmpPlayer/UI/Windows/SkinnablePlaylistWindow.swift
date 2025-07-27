//
//  SkinnablePlaylistWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Skinnable playlist editor window
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Skinnable playlist row
struct SkinnablePlaylistRow: View {
    let track: Track
    let index: Int
    let isSelected: Bool
    let isCurrent: Bool
    @StateObject private var skinManager = SkinManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            // Track number
            Text("\(index + 1).")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 30, alignment: .trailing)
            
            // Track info
            VStack(alignment: .leading, spacing: 0) {
                Text(track.displayTitle)
                    .font(.system(size: 11, weight: isCurrent ? .bold : .regular, design: .monospaced))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                if !track.displayArtist.isEmpty {
                    Text(track.displayArtist)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(backgroundColor)
    }
    
    private var textColor: Color {
        if let config = skinManager.playlistConfig {
            if isCurrent {
                return Color(config.currentText)
            } else {
                return Color(config.normalText)
            }
        } else {
            // Fallback colors
            if isCurrent {
                return WinAmpColors.textHighlight
            } else {
                return WinAmpColors.text
            }
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
            if let config = skinManager.playlistConfig {
                return Color(config.normalBackground)
            } else {
                return Color.clear
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Skinnable playlist window
struct SkinnablePlaylistWindow: View {
    @ObservedObject var playlistController: PlaylistController
    @StateObject private var skinManager = SkinManager.shared
    @State private var selectedTracks: Set<Track.ID> = []
    @State private var searchText = ""
    @State private var sortField: PlaylistSortField = .title
    @State private var sortAscending = true
    
    private let windowSize = CGSize(width: 275, height: 232)
    
    var body: some View {
        ZStack {
            // Background
            if let bgSprite = skinManager.getSprite(.playlistBackground) {
                Image(nsImage: bgSprite)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: windowSize.width, height: windowSize.height)
            } else {
                // Fallback background
                WinAmpWindow(
                    configuration: WinAmpWindowConfiguration(
                        title: "Playlist Editor",
                        windowType: .playlist,
                        showTitleBar: true,
                        resizable: true,
                        minSize: CGSize(width: 275, height: 116),
                        maxSize: CGSize(width: 550, height: 464)
                    )
                ) {
                    fallbackContent
                }
            }
            
            // Content overlay
            VStack(spacing: 0) {
                // Title bar area (built into sprite)
                Color.clear
                    .frame(height: 14)
                
                // Toolbar buttons
                HStack(spacing: 2) {
                    // Add button
                    SkinnableButton(
                        normal: .playlistAddButton(.normal),
                        pressed: .playlistAddButton(.pressed),
                        action: addFiles
                    )
                    .frame(width: 25, height: 18)
                    
                    // Remove button
                    SkinnableButton(
                        normal: .playlistRemoveButton(.normal),
                        pressed: .playlistRemoveButton(.pressed),
                        action: removeSelected
                    )
                    .frame(width: 25, height: 18)
                    
                    // Select button
                    SkinnableButton(
                        normal: .playlistSelectButton(.normal),
                        pressed: .playlistSelectButton(.pressed),
                        action: selectAll
                    )
                    .frame(width: 25, height: 18)
                    
                    // Misc button
                    SkinnableButton(
                        normal: .playlistMiscButton(.normal),
                        pressed: .playlistMiscButton(.pressed),
                        action: { /* Show misc menu */ }
                    )
                    .frame(width: 25, height: 18)
                    
                    // List button
                    SkinnableButton(
                        normal: .playlistListButton(.normal),
                        pressed: .playlistListButton(.pressed),
                        action: { /* Show list menu */ }
                    )
                    .frame(width: 25, height: 18)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                
                // Search bar
                PlaylistSearchField(text: $searchText)
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                
                // Playlist content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayedTracks.enumerated()), id: \.element.id) { index, track in
                            SkinnablePlaylistRow(
                                track: track,
                                index: index,
                                isSelected: selectedTracks.contains(track.id),
                                isCurrent: playlistController.currentTrack?.id == track.id
                            )
                            .onTapGesture {
                                toggleSelection(track)
                            }
                            .onTapGesture(count: 2) {
                                playTrack(track)
                            }
                            .contextMenu {
                                playlistContextMenu(for: track)
                            }
                        }
                    }
                }
                .background(playlistBackgroundColor)
                
                // Status bar
                PlaylistStatusBar(
                    trackCount: displayedTracks.count,
                    totalDuration: totalDuration,
                    selectedCount: selectedTracks.count
                )
                .frame(height: 20)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .onAppear {
            WindowCommunicator.shared.registerWindow("playlist")
        }
        .onReceive(playlistController.$currentTrack) { _ in
            // Refresh view when current track changes
        }
    }
    
    private var fallbackContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            PlaylistToolbar(
                onAdd: addFiles,
                onRemove: removeSelected,
                onClear: clearPlaylist,
                onSort: { field in
                    if sortField == field {
                        sortAscending.toggle()
                    } else {
                        sortField = field
                        sortAscending = true
                    }
                },
                sortField: sortField,
                sortAscending: sortAscending
            )
            .frame(height: 30)
            
            // Search bar
            PlaylistSearchField(text: $searchText)
                .frame(height: 20)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            // Playlist content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayedTracks.enumerated()), id: \.element.id) { index, track in
                        PlaylistRowView(
                            track: track,
                            index: index,
                            isSelected: selectedTracks.contains(track.id),
                            isCurrent: playlistController.currentTrack?.id == track.id,
                            onSelect: { toggleSelection(track) },
                            onPlay: { playTrack(track) }
                        )
                        .contextMenu {
                            playlistContextMenu(for: track)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .background(WinAmpColors.background)
            
            // Status bar
            PlaylistStatusBar(
                trackCount: displayedTracks.count,
                totalDuration: totalDuration,
                selectedCount: selectedTracks.count
            )
            .frame(height: 20)
        }
    }
    
    private var playlistBackgroundColor: Color {
        if let config = skinManager.playlistConfig {
            return Color(config.normalBackground)
        } else {
            return WinAmpColors.background
        }
    }
    
    private var displayedTracks: [Track] {
        guard let playlist = playlistController.currentPlaylist else { return [] }
        
        var tracks = playlist.tracks
        
        // Apply search filter
        if !searchText.isEmpty {
            tracks = tracks.filter { track in
                track.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                track.displayArtist.localizedCaseInsensitiveContains(searchText) ||
                (track.album ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch sortField {
        case .title:
            tracks.sort { sortAscending ? $0.displayTitle < $1.displayTitle : $0.displayTitle > $1.displayTitle }
        case .artist:
            tracks.sort { sortAscending ? $0.displayArtist < $1.displayArtist : $0.displayArtist > $1.displayArtist }
        case .album:
            tracks.sort { 
                let album0 = $0.album ?? ""
                let album1 = $1.album ?? ""
                return sortAscending ? album0 < album1 : album0 > album1
            }
        case .duration:
            tracks.sort { sortAscending ? $0.duration < $1.duration : $0.duration > $1.duration }
        case .none:
            break
        }
        
        return tracks
    }
    
    private var totalDuration: TimeInterval {
        displayedTracks.reduce(0) { $0 + $1.duration }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ track: Track) {
        if selectedTracks.contains(track.id) {
            selectedTracks.remove(track.id)
        } else {
            selectedTracks.insert(track.id)
        }
    }
    
    private func playTrack(_ track: Track) {
        Task {
            try? await playlistController.playTrack(track)
        }
    }
    
    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = Track.supportedExtensions
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        
        if panel.runModal() == .OK {
            Task {
                for url in panel.urls {
                    if let track = Track(from: url) {
                        playlistController.currentPlaylist?.addTrack(track)
                    }
                }
            }
        }
    }
    
    private func removeSelected() {
        guard let playlist = playlistController.currentPlaylist else { return }
        
        let tracksToRemove = playlist.tracks.enumerated()
            .filter { selectedTracks.contains($0.element.id) }
            .map { $0.offset }
            .reversed() // Remove from end to avoid index shifting
        
        for index in tracksToRemove {
            playlist.removeTrack(at: index)
        }
        selectedTracks.removeAll()
    }
    
    private func clearPlaylist() {
        playlistController.currentPlaylist?.clear()
        selectedTracks.removeAll()
    }
    
    private func selectAll() {
        guard let playlist = playlistController.currentPlaylist else { return }
        selectedTracks = Set(playlist.tracks.map { $0.id })
    }
    
    @ViewBuilder
    private func playlistContextMenu(for track: Track) -> some View {
        Button("Play") {
            playTrack(track)
        }
        
        Button("Remove") {
            if let playlist = playlistController.currentPlaylist,
               let index = playlist.tracks.firstIndex(where: { $0.id == track.id }) {
                playlist.removeTrack(at: index)
            }
        }
        
        Divider()
        
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(track.fileURL.path, inFileViewerRootedAtPath: "")
        }
    }
}