import SwiftUI

struct Clutterbar: View {
    // Toggle states
    @Binding var isAlwaysOnTop: Bool
    @Binding var isDoubleSize: Bool
    @Binding var showVisualization: Bool
    @Binding var showFileInfo: Bool
    @Binding var timeDisplayMode: TimeDisplayMode
    
    // Callbacks
    var onOptions: () -> Void
    var onMinimize: () -> Void
    var onClose: () -> Void
    
    // Colors
    private let activeColor = Color(red: 0.0, green: 1.0, blue: 0.0) // Bright green
    private let inactiveColor = Color(red: 0.0, green: 0.5, blue: 0.0) // Darker green
    private let backgroundColor = Color(red: 0.1, green: 0.1, blue: 0.1) // Dark background
    
    var body: some View {
        HStack(spacing: 2) {
            // Options button
            ClutterbarButton(
                text: "O",
                isToggle: false,
                isActive: false,
                action: onOptions
            )
            .help("Options")
            
            // Always on top toggle
            ClutterbarButton(
                text: "A",
                isToggle: true,
                isActive: isAlwaysOnTop,
                action: { isAlwaysOnTop.toggle() }
            )
            .help("Always on Top")
            
            // File info toggle
            ClutterbarButton(
                text: "I",
                isToggle: true,
                isActive: showFileInfo,
                action: { showFileInfo.toggle() }
            )
            .help("File Info")
            
            // Double size toggle
            ClutterbarButton(
                text: "D",
                isToggle: true,
                isActive: isDoubleSize,
                action: { isDoubleSize.toggle() }
            )
            .help("Double Size")
            
            // Visualization toggle
            ClutterbarButton(
                text: "V",
                isToggle: true,
                isActive: showVisualization,
                action: { showVisualization.toggle() }
            )
            .help("Visualization")
            
            Spacer()
            
            // Time display mode toggle
            ClutterbarButton(
                text: timeDisplayMode == .elapsed ? "TIME" : "REM",
                isToggle: false,
                isActive: false,
                action: { 
                    timeDisplayMode = timeDisplayMode == .elapsed ? .remaining : .elapsed
                }
            )
            .help(timeDisplayMode == .elapsed ? "Show Remaining Time" : "Show Elapsed Time")
            
            Spacer()
            
            // Minimize button
            ClutterbarButton(
                text: "_",
                isToggle: false,
                isActive: false,
                action: onMinimize
            )
            .help("Minimize")
            
            // Close button
            ClutterbarButton(
                text: "X",
                isToggle: false,
                isActive: false,
                action: onClose
            )
            .help("Close")
        }
        .padding(.horizontal, 4)
        .frame(height: 14)
        .background(backgroundColor)
    }
}

// Individual button component
struct ClutterbarButton: View {
    let text: String
    let isToggle: Bool
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var textColor: Color {
        if isToggle && isActive {
            return Color(red: 0.0, green: 1.0, blue: 0.0) // Bright green when active
        } else if isHovered {
            return Color(red: 0.0, green: 0.8, blue: 0.0) // Slightly brighter on hover
        } else {
            return Color(red: 0.0, green: 0.5, blue: 0.0) // Dark green default
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.custom("Monaco", size: 8))
                .foregroundColor(textColor)
                .frame(minWidth: text.count > 1 ? 24 : 12, minHeight: 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Time display mode enum
enum TimeDisplayMode {
    case elapsed
    case remaining
}

// Preview
struct Clutterbar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isAlwaysOnTop = false
        @State private var isDoubleSize = false
        @State private var showVisualization = true
        @State private var showFileInfo = false
        @State private var timeDisplayMode = TimeDisplayMode.elapsed
        
        var body: some View {
            VStack(spacing: 20) {
                // Normal state
                Clutterbar(
                    isAlwaysOnTop: $isAlwaysOnTop,
                    isDoubleSize: $isDoubleSize,
                    showVisualization: $showVisualization,
                    showFileInfo: $showFileInfo,
                    timeDisplayMode: $timeDisplayMode,
                    onOptions: { print("Options clicked") },
                    onMinimize: { print("Minimize clicked") },
                    onClose: { print("Close clicked") }
                )
                .frame(width: 275)
                
                // With some toggles active
                Clutterbar(
                    isAlwaysOnTop: .constant(true),
                    isDoubleSize: .constant(true),
                    showVisualization: .constant(true),
                    showFileInfo: .constant(true),
                    timeDisplayMode: .constant(.remaining),
                    onOptions: { print("Options clicked") },
                    onMinimize: { print("Minimize clicked") },
                    onClose: { print("Close clicked") }
                )
                .frame(width: 275)
            }
            .padding()
            .background(Color.black)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}