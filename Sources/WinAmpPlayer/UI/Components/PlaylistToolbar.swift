import SwiftUI

struct PlaylistToolbar: View {
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onClear: () -> Void
    let onSort: (PlaylistSortField) -> Void
    let sortField: PlaylistSortField
    let sortAscending: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Action buttons
            ToolbarButton(icon: "plus", action: onAdd, tooltip: "Add files")
            ToolbarButton(icon: "minus", action: onRemove, tooltip: "Remove selected")
            ToolbarButton(icon: "trash", action: onClear, tooltip: "Clear playlist")
            
            Spacer()
            
            // Sort controls
            Menu {
                ForEach([PlaylistSortField.title, PlaylistSortField.artist, PlaylistSortField.album, PlaylistSortField.duration], id: \.self) { field in
                    Button(action: { onSort(field) }) {
                        HStack {
                            Text(field.displayName)
                            if sortField == field {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Sort: \(sortField.displayName)")
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(WinAmpColors.backgroundDark)
    }
}

private struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
    }
}

// Extension to provide display names for sort fields
private extension PlaylistSortField {
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .artist: return "Artist"
        case .album: return "Album"
        case .duration: return "Duration"
        default: return "Unknown"
        }
    }
}
