//
//  PlaylistControlsView.swift
//  WinAmpPlayer
//
//  Playlist control buttons with classic WinAmp styling
//

import SwiftUI
import UniformTypeIdentifiers

struct PlaylistControlsView: View {
    @ObservedObject var playlist: Playlist
    @State private var showingFilePicker = false
    @State private var showingSaveDialog = false
    @State private var showingLoadDialog = false
    @State private var sortMenuVisible = false
    
    // Classic WinAmp colors
    private let backgroundColor = Color(red: 0.11, green: 0.11, blue: 0.11)
    private let buttonColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    private let buttonHighlight = Color(red: 0.3, green: 0.3, blue: 0.3)
    private let textColor = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let pressedColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    var body: some View {
        HStack(spacing: 2) {
            // File operations
            Group {
                WinAmpButton(
                    label: "ADD",
                    action: { showingFilePicker = true },
                    textColor: textColor
                )
                
                WinAmpButton(
                    label: "REM",
                    action: removeSelected,
                    textColor: textColor
                )
                
                WinAmpButton(
                    label: "SEL",
                    action: selectAll,
                    textColor: textColor
                )
            }
            
            Divider()
                .frame(width: 1, height: 20)
                .background(buttonColor)
            
            // Sort operations
            WinAmpButton(
                label: "SORT",
                action: { sortMenuVisible.toggle() },
                textColor: textColor
            )
            .popover(isPresented: $sortMenuVisible) {
                sortMenu
            }
            
            Divider()
                .frame(width: 1, height: 20)
                .background(buttonColor)
            
            // Playlist operations
            Group {
                WinAmpButton(
                    label: "LOAD",
                    action: { showingLoadDialog = true },
                    textColor: textColor
                )
                
                WinAmpButton(
                    label: "SAVE",
                    action: { showingSaveDialog = true },
                    textColor: textColor
                )
            }
            
            Spacer()
            
            // Playback modes
            Group {
                WinAmpToggleButton(
                    label: "REP",
                    isOn: playlist.repeatMode != .off,
                    action: toggleRepeat,
                    textColor: textColor
                )
                
                WinAmpToggleButton(
                    label: "SHUF",
                    isOn: playlist.shuffleMode != .off,
                    action: toggleShuffle,
                    textColor: textColor
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .fileExporter(
            isPresented: $showingSaveDialog,
            document: PlaylistDocument(playlist: playlist),
            contentType: .m3uPlaylist,
            defaultFilename: "\(playlist.name).m3u"
        ) { result in
            handleFileSave(result)
        }
        .fileImporter(
            isPresented: $showingLoadDialog,
            allowedContentTypes: [.m3uPlaylist, .plsPlaylist],
            allowsMultipleSelection: false
        ) { result in
            handlePlaylistLoad(result)
        }
    }
    
    private var sortMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            sortMenuItem("Title") {
                playlist.sort(by: \.title)
            }
            
            sortMenuItem("Artist") {
                playlist.sort(by: \.displayArtist)
            }
            
            sortMenuItem("Album") {
                if let firstTrack = playlist.tracks.first(where: { $0.album != nil }) {
                    // Sort by album, handling nil values
                    playlist.tracks.sort { track1, track2 in
                        let album1 = track1.album ?? ""
                        let album2 = track2.album ?? ""
                        return album1 < album2
                    }
                }
            }
            
            sortMenuItem("Duration") {
                playlist.sort(by: \.duration)
            }
            
            Divider()
                .background(buttonColor)
            
            sortMenuItem("Reverse") {
                playlist.tracks.reverse()
            }
            
            sortMenuItem("Randomize") {
                playlist.tracks.shuffle()
            }
        }
        .background(backgroundColor)
        .border(buttonColor, width: 1)
        .frame(width: 120)
    }
    
    private func sortMenuItem(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            sortMenuVisible = false
        }) {
            Text(label)
                .font(.custom("Monaco", size: 10))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
        .onHover { hovering in
            // Handle hover state
        }
    }
    
    private func removeSelected() {
        // Remove selected tracks logic would go here
        // For now, remove current track if any
        if let index = playlist.currentTrackIndex {
            playlist.removeTrack(at: index)
        }
    }
    
    private func selectAll() {
        // Select all tracks logic would go here
    }
    
    private func toggleRepeat() {
        switch playlist.repeatMode {
        case .off:
            playlist.repeatMode = .all
        case .all:
            playlist.repeatMode = .one
        case .one:
            playlist.repeatMode = .off
        case .abLoop:
            playlist.repeatMode = .off
        }
    }
    
    private func toggleShuffle() {
        switch playlist.shuffleMode {
        case .off:
            playlist.setShuffleMode(.random)
        default:
            playlist.setShuffleMode(.off)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let tracks = urls.compactMap { Track(from: $0) }
            playlist.addTracks(tracks)
        case .failure(let error):
            print("Error importing files: \(error)")
        }
    }
    
    private func handleFileSave(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try playlist.saveAsM3U(to: url)
            } catch {
                print("Error saving playlist: \(error)")
            }
        case .failure(let error):
            print("Error saving: \(error)")
        }
    }
    
    private func handlePlaylistLoad(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                do {
                    let loadedPlaylist = try Playlist.loadFromM3U(url: url)
                    playlist.clear()
                    playlist.addTracks(loadedPlaylist.tracks)
                    playlist.name = loadedPlaylist.name
                } catch {
                    print("Error loading playlist: \(error)")
                }
            }
        case .failure(let error):
            print("Error loading: \(error)")
        }
    }
}

// MARK: - Custom Button Styles

struct WinAmpButton: View {
    let label: String
    let action: () -> Void
    let textColor: Color
    @State private var isPressed = false
    
    private let buttonColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    private let buttonHighlight = Color(red: 0.3, green: 0.3, blue: 0.3)
    private let pressedColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Monaco", size: 9))
                .foregroundColor(textColor)
                .frame(minWidth: 35, minHeight: 18)
                .background(
                    ZStack {
                        Rectangle()
                            .fill(isPressed ? pressedColor : buttonColor)
                        
                        if !isPressed {
                            // 3D bevel effect
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(buttonHighlight)
                                    .frame(height: 1)
                                Spacer()
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(height: 1)
                            }
                            
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(buttonHighlight)
                                    .frame(width: 1)
                                Spacer()
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 1)
                            }
                        }
                    }
                )
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}

struct WinAmpToggleButton: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    let textColor: Color
    
    private let buttonColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    private let activeColor = Color(red: 0.0, green: 0.3, blue: 0.0)
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Monaco", size: 9))
                .foregroundColor(isOn ? Color.white : textColor)
                .frame(minWidth: 35, minHeight: 18)
                .background(
                    ZStack {
                        Rectangle()
                            .fill(isOn ? activeColor : buttonColor)
                        
                        Rectangle()
                            .stroke(Color.black, lineWidth: 1)
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Playlist Document

struct PlaylistDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.m3uPlaylist, .plsPlaylist] }
    
    let playlist: Playlist
    
    init(playlist: Playlist) {
        self.playlist = playlist
    }
    
    init(configuration: ReadConfiguration) throws {
        playlist = Playlist()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var content = "#EXTM3U\n"
        
        for track in playlist.tracks {
            if let fileURL = track.fileURL {
                content += "#EXTINF:\(Int(track.duration)),\(track.artist ?? "") - \(track.title)\n"
                content += "\(fileURL.path)\n"
            }
        }
        
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Content Type Extensions

extension UTType {
    static let m3uPlaylist = UTType(filenameExtension: "m3u")!
    static let plsPlaylist = UTType(filenameExtension: "pls")!
}

// MARK: - Preview

struct PlaylistControlsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistControlsView(playlist: Playlist(name: "My Playlist"))
            .frame(height: 30)
            .preferredColorScheme(.dark)
    }
}