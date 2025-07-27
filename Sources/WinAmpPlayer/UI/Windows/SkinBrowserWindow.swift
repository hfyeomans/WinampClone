//
//  SkinBrowserWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Skin browser and manager window
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Skin item view for the browser
struct SkinItemView: View {
    let skin: Skin
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    
    private func exportSkin(_ skin: Skin) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "wsz")!, UTType.zip].compactMap { $0 }
        panel.nameFieldStringValue = "\(skin.name).wsz"
        panel.prompt = "Export"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try SkinManager.shared.exportSkin(skin, to: url)
            } catch {
                print("Failed to export skin: \(error)")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            thumbnailView
            skinInfoView
        }
        .padding(8)
        .background(backgroundView)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            contextMenuContent
        }
        .task {
            await loadThumbnailIfNeeded()
        }
    }
    
    private var thumbnailView: some View {
        ZStack {
            thumbnailContent
            selectionOverlay
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
    
    private var thumbnailContent: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 137.5, height: 58)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(WinAmpColors.backgroundLight)
                    .frame(width: 137.5, height: 58)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .stroke(WinAmpColors.accent, lineWidth: 2)
        }
    }
    
    private var skinInfoView: some View {
        VStack(spacing: 2) {
            Text(skin.name)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? WinAmpColors.textHighlight : WinAmpColors.text)
                .lineLimit(1)
                .frame(width: 137.5)
            
            if let author = skin.author {
                Text(author)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(WinAmpColors.textDim)
                    .lineLimit(1)
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isHovered ? WinAmpColors.backgroundLight : Color.clear)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Apply Skin") {
            onSelect()
        }
        
        if !skin.isDefault {
            Divider()
            
            Button("Export Skin...") {
                exportSkin(skin)
            }
            
            Button("Delete Skin") {
                onDelete()
            }
            .foregroundColor(.red)
        }
    }
    
    private func loadThumbnailIfNeeded() async {
        if thumbnail == nil {
            thumbnail = await SkinManager.shared.createThumbnail(for: skin)
        }
    }
}

/// Skin browser window
public struct SkinBrowserWindow: View {
    @StateObject private var skinManager = SkinManager.shared
    @State private var selectedSkin: Skin?
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var skinToDelete: Skin?
    @State private var isDraggingOver = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    public var body: some View {
        WinAmpWindow(
            configuration: WinAmpWindowConfiguration(
                title: "Skin Browser",
                windowType: .library,
                showTitleBar: true,
                resizable: true,
                minSize: CGSize(width: 400, height: 300),
                maxSize: CGSize(width: 800, height: 600)
            )
        ) {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 16) {
                    // Search field
                    PlaylistSearchField(text: $searchText)
                        .frame(width: 200)
                    
                    Spacer()
                    
                    // Add skin button
                    Button(action: addSkin) {
                        Label("Add Skin", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Export all button
                    Button(action: exportAllSkins) {
                        Label("Export All", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(skinManager.availableSkins.filter { !$0.isDefault }.isEmpty)
                    
                    // Refresh button
                    Button(action: refreshSkins) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(12)
                .background(WinAmpColors.backgroundDark)
                
                // Skin grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredSkins) { skin in
                            SkinItemView(
                                skin: skin,
                                isSelected: skinManager.currentSkin.id == skin.id,
                                onSelect: {
                                    applySkin(skin)
                                },
                                onDelete: {
                                    skinToDelete = skin
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding()
                }
                .background(WinAmpColors.background)
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    handleDrop(providers: providers)
                }
                .overlay(
                    Group {
                        if isDraggingOver {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(WinAmpColors.accent, lineWidth: 2)
                                .background(
                                    WinAmpColors.accent.opacity(0.1)
                                )
                                .padding(4)
                                .allowsHitTesting(false)
                        }
                    }
                )
                
                // Status bar
                HStack {
                    Text("\(filteredSkins.count) skins")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(WinAmpColors.textDim)
                    
                    Spacer()
                    
                    Text("Current: \(skinManager.currentSkin.name)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(WinAmpColors.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(WinAmpColors.backgroundDark)
            }
        }
        .alert("Delete Skin", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let skin = skinToDelete {
                    deleteSkin(skin)
                }
            }
        } message: {
            if let skin = skinToDelete {
                Text("Are you sure you want to delete \"\(skin.name)\"? This action cannot be undone.")
            }
        }
        .onAppear {
            selectedSkin = skinManager.currentSkin
            refreshSkins()
        }
    }
    
    private var filteredSkins: [Skin] {
        if searchText.isEmpty {
            return skinManager.availableSkins
        } else {
            return skinManager.availableSkins.filter { skin in
                skin.name.localizedCaseInsensitiveContains(searchText) ||
                (skin.author ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func applySkin(_ skin: Skin) {
        Task {
            do {
                try await skinManager.applySkin(skin)
                selectedSkin = skin
            } catch {
                // Show error alert
                print("Failed to apply skin: \(error)")
            }
        }
    }
    
    private func addSkin() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "wsz")!, UTType.zip].compactMap { $0 }
        panel.allowsMultipleSelection = true
        panel.prompt = "Add Skin"
        panel.message = "Select skin files (.wsz) or skin packs (.zip)"
        
        if panel.runModal() == .OK {
            Task {
                var totalInstalled = 0
                var firstSkin: Skin?
                
                for url in panel.urls {
                    do {
                        // Check if it's a pack
                        let skins = try await skinManager.installSkinPack(from: url)
                        if !skins.isEmpty {
                            // It was a pack
                            totalInstalled += skins.count
                            if firstSkin == nil {
                                firstSkin = skins.first
                            }
                            
                            // Show pack installation result
                            await MainActor.run {
                                let alert = NSAlert()
                                alert.messageText = "Skin Pack Installed"
                                alert.informativeText = "Installed \(skins.count) skins from \(url.lastPathComponent)"
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }
                        } else {
                            // Single skin
                            let skin = try await skinManager.installSkin(from: url)
                            totalInstalled += 1
                            if firstSkin == nil {
                                firstSkin = skin
                            }
                        }
                    } catch {
                        print("Failed to install skin from \(url): \(error)")
                    }
                }
                
                // Apply the first skin if any were installed
                if let skin = firstSkin {
                    try? await skinManager.applySkin(skin)
                }
            }
        }
    }
    
    private func deleteSkin(_ skin: Skin) {
        do {
            try skinManager.deleteSkin(skin)
            if selectedSkin?.id == skin.id {
                selectedSkin = nil
            }
        } catch {
            print("Failed to delete skin: \(error)")
        }
    }
    
    private func refreshSkins() {
        skinManager.loadAvailableSkins()
    }
    
    private func exportAllSkins() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["zip"]
        panel.nameFieldStringValue = "WinAmp_Skins_Pack.zip"
        panel.prompt = "Export Pack"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    let skinsToExport = skinManager.availableSkins.filter { !$0.isDefault }
                    try await skinManager.exportSkinPack(skinsToExport, to: url)
                    
                    // Show success alert
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Export Successful"
                        alert.informativeText = "Exported \(skinsToExport.count) skins to \(url.lastPathComponent)"
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                } catch {
                    // Show error alert
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    guard let url = url else { return }
                    
                    // Check if it's a skin file
                    let ext = url.pathExtension.lowercased()
                    if ext == "wsz" || ext == "zip" {
                        Task {
                            do {
                                let skin = try await skinManager.installSkin(from: url)
                                try await skinManager.applySkin(skin)
                            } catch {
                                print("Failed to install dropped skin: \(error)")
                            }
                        }
                    }
                }
            }
        }
        return true
    }
}

/// Skin browser presented as a sheet
public struct SkinBrowserSheet: View {
    @Binding var isPresented: Bool
    
    public var body: some View {
        SkinBrowserWindow()
            .frame(width: 600, height: 400)
    }
}