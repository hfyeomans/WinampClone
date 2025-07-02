//
//  PlaylistView.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Playlist view with WinAmp-style aesthetics.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @ObservedObject var controller: PlaylistController
    @ObservedObject var playlist: Playlist
    
    @State private var selectedTrackIDs: Set<UUID> = []
    @State private var isEditingName = false
    @State private var editedName = ""
    
    private let rowHeight: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            PlaylistHeaderView(
                playlist: playlist,
                isEditingName: $isEditingName,
                editedName: $editedName,
                onShuffle: { controller.toggleShuffle() },
                onRepeat: { controller.cycleRepeatMode() }
            )
            
            // Track list
            ScrollViewReader { proxy in
                List(selection: $selectedTrackIDs) {
                    ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                        PlaylistRowView(
                            track: track,
                            index: index + 1,
                            isCurrentTrack: playlist.currentTrackIndex == index,
                            isPlaying: controller.isPlaying && playlist.currentTrackIndex == index
                        )
                        .tag(track.id)
                        .id(track.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .onTapGesture(count: 2) {
                            // Double-click to play
                            Task {
                                try? await controller.playTrack(track)
                            }
                        }
                        .contextMenu {
                            PlaylistContextMenu(
                                track: track,
                                controller: controller,
                                playlist: playlist
                            )
                        }
                    }
                    .onMove { source, destination in
                        playlist.moveTracks(from: source, to: destination)
                    }
                    .onDelete { indices in
                        playlist.removeTracks(at: indices)
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackground(.hidden)
                .onChange(of: playlist.currentTrackIndex) { newIndex in
                    // Auto-scroll to current track
                    if let index = newIndex,
                       let track = playlist.tracks[safe: index] {
                        withAnimation {
                            proxy.scrollTo(track.id, anchor: .center)
                        }
                    }
                }
            }
            
            // Footer with stats
            PlaylistFooterView(playlist: playlist)
        }
        .frame(width: 275, height: 232)
        .background(Color.black)
        .border(Color.gray.opacity(0.3), width: 1)
    }
}

// MARK: - Header View

struct PlaylistHeaderView: View {
    @ObservedObject var playlist: Playlist
    @Binding var isEditingName: Bool
    @Binding var editedName: String
    let onShuffle: () -> Void
    let onRepeat: () -> Void
    
    var body: some View {
        HStack {
            if isEditingName {
                TextField("Playlist Name", text: $editedName, onCommit: {
                    playlist.name = editedName
                    isEditingName = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            } else {
                Text(playlist.name)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .onTapGesture(count: 2) {
                        editedName = playlist.name
                        isEditingName = true
                    }
            }
            
            Spacer()
            
            // Shuffle button
            Button(action: onShuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 10))
                    .foregroundColor(playlist.shuffleMode != .off ? .green : .gray)
            }
            .buttonStyle(.plain)
            .help("Shuffle: \(playlist.shuffleMode != .off ? "On" : "Off")")
            
            // Repeat button
            Button(action: onRepeat) {
                Image(systemName: repeatModeIcon)
                    .font(.system(size: 10))
                    .foregroundColor(playlist.repeatMode != .off ? .green : .gray)
            }
            .buttonStyle(.plain)
            .help("Repeat: \(repeatModeText)")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.2))
    }
    
    private var repeatModeIcon: String {
        switch playlist.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        case .abLoop:
            return "repeat"
        }
    }
    
    private var repeatModeText: String {
        switch playlist.repeatMode {
        case .off:
            return "Off"
        case .all:
            return "All"
        case .one:
            return "One"
        case .abLoop:
            return "A-B Loop"
        }
    }
}

// MARK: - Row View

struct PlaylistRowView: View {
    let track: Track
    let index: Int
    let isCurrentTrack: Bool
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            // Track number / Playing indicator
            Text(isPlaying ? "▶" : String(format: "%02d", index))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isCurrentTrack ? .green : .green.opacity(0.6))
                .frame(width: 20, alignment: .trailing)
            
            // Track info
            VStack(alignment: .leading, spacing: 0) {
                Text(track.displayTitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isCurrentTrack ? .green : .green.opacity(0.8))
                    .lineLimit(1)
                
                if track.artist != nil {
                    Text(track.displayArtist)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(isCurrentTrack ? .green.opacity(0.8) : .green.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            Text(track.formattedDuration)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(isCurrentTrack ? .green : .green.opacity(0.6))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isCurrentTrack ? Color.green.opacity(0.1) : Color.clear)
    }
}

// MARK: - Footer View

struct PlaylistFooterView: View {
    @ObservedObject var playlist: Playlist
    
    var body: some View {
        HStack {
            Text("\(playlist.tracks.count) tracks")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.green.opacity(0.8))
            
            Spacer()
            
            Text(playlist.formattedTotalDuration)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.green.opacity(0.8))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.2))
    }
}

// MARK: - Context Menu

struct PlaylistContextMenu: View {
    let track: Track
    let controller: PlaylistController
    let playlist: Playlist
    
    var body: some View {
        Group {
            Button("Play") {
                Task {
                    try? await controller.playTrack(track)
                }
            }
            
            Button("Add to Queue") {
                controller.addToQueue(track)
            }
            
            Divider()
            
            if let index = playlist.tracks.firstIndex(where: { $0.id == track.id }) {
                Button("Remove from Playlist") {
                    playlist.removeTrack(at: index)
                }
            }
            
            Divider()
            
            Menu("Rating") {
                ForEach(0...5, id: \.self) { rating in
                    Button(rating == 0 ? "No Rating" : String(repeating: "★", count: rating)) {
                        playlist.setRating(rating == 0 ? nil : rating, for: track)
                    }
                }
            }
            
            Divider()
            
            Button("Show in Finder") {
                if let url = track.fileURL {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }
        }
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}