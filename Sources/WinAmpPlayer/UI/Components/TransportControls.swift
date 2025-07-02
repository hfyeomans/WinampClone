import SwiftUI

// MARK: - Transport Button Style
struct WinAmpTransportButtonStyle: ButtonStyle {
    let isPressed: Bool
    let isHovered: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Base Transport Button
struct TransportButtonBase<Content: View>: View {
    let content: Content
    let action: () -> Void
    let width: CGFloat
    let height: CGFloat
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(width: CGFloat = 23, height: CGFloat = 18, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.width = width
        self.height = height
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.15))
                    .frame(width: width, height: height)
                
                // Border
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(white: 0.3), lineWidth: 1)
                    .frame(width: width, height: height)
                
                // Content
                content
                    .foregroundColor(isHovered ? Color(red: 0.0, green: 1.0, blue: 0.0) : Color(white: 0.7))
                
                // Hover glow effect
                if isHovered {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.3), lineWidth: 2)
                        .frame(width: width + 2, height: height + 2)
                        .blur(radius: 2)
                }
            }
            .shadow(color: isPressed ? Color.black.opacity(0.5) : Color.clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(WinAmpTransportButtonStyle(isPressed: isPressed, isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
}

// MARK: - Play/Pause Button
struct PlayPauseButton: View {
    @Binding var isPlaying: Bool
    let action: () -> Void
    
    var body: some View {
        TransportButtonBase(action: action) {
            Group {
                if isPlaying {
                    // Pause icon
                    HStack(spacing: 2) {
                        Rectangle()
                            .frame(width: 3, height: 10)
                        Rectangle()
                            .frame(width: 3, height: 10)
                    }
                } else {
                    // Play icon
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 10))
                        path.addLine(to: CGPoint(x: 8, y: 5))
                        path.closeSubpath()
                    }
                    .frame(width: 8, height: 10)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            // LED indicator
            Circle()
                .fill(isPlaying ? Color(red: 0.0, green: 1.0, blue: 0.0) : Color(white: 0.2))
                .frame(width: 4, height: 4)
                .offset(x: 2, y: -2)
                .animation(.easeInOut(duration: 0.3), value: isPlaying)
        }
    }
}

// MARK: - Stop Button
struct StopButton: View {
    let action: () -> Void
    
    var body: some View {
        TransportButtonBase(action: action) {
            Rectangle()
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Previous Button
struct PreviousButton: View {
    let action: () -> Void
    
    var body: some View {
        TransportButtonBase(action: action) {
            HStack(spacing: 1) {
                Rectangle()
                    .frame(width: 2, height: 10)
                Path { path in
                    path.move(to: CGPoint(x: 6, y: 0))
                    path.addLine(to: CGPoint(x: 6, y: 10))
                    path.addLine(to: CGPoint(x: 0, y: 5))
                    path.closeSubpath()
                }
                .frame(width: 6, height: 10)
            }
        }
    }
}

// MARK: - Next Button
struct NextButton: View {
    let action: () -> Void
    
    var body: some View {
        TransportButtonBase(action: action) {
            HStack(spacing: 1) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 10))
                    path.addLine(to: CGPoint(x: 6, y: 5))
                    path.closeSubpath()
                }
                .frame(width: 6, height: 10)
                Rectangle()
                    .frame(width: 2, height: 10)
            }
        }
    }
}

// MARK: - Eject Button
struct EjectButton: View {
    let action: () -> Void
    
    var body: some View {
        TransportButtonBase(width: 22, height: 16, action: action) {
            VStack(spacing: 1) {
                Path { path in
                    path.move(to: CGPoint(x: 5, y: 0))
                    path.addLine(to: CGPoint(x: 10, y: 5))
                    path.addLine(to: CGPoint(x: 0, y: 5))
                    path.closeSubpath()
                }
                .frame(width: 10, height: 5)
                
                Rectangle()
                    .frame(width: 10, height: 2)
            }
        }
    }
}

// MARK: - Transport Controls View
struct TransportControlsView: View {
    @Binding var isPlaying: Bool
    
    var onPlayPause: () -> Void = {}
    var onStop: () -> Void = {}
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    var onEject: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 0) {
            PreviousButton(action: onPrevious)
            
            PlayPauseButton(isPlaying: $isPlaying, action: onPlayPause)
            
            StopButton(action: onStop)
            
            NextButton(action: onNext)
            
            Spacer()
                .frame(width: 5)
            
            EjectButton(action: onEject)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Press Events Modifier
struct PressActions: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActions(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Preview
struct TransportControls_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isPlaying = false
        
        var body: some View {
            VStack(spacing: 20) {
                // Individual buttons
                VStack(alignment: .leading, spacing: 10) {
                    Text("Individual Buttons")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 10) {
                        PlayPauseButton(isPlaying: $isPlaying) {
                            isPlaying.toggle()
                        }
                        
                        StopButton {
                            isPlaying = false
                        }
                        
                        PreviousButton {
                            print("Previous")
                        }
                        
                        NextButton {
                            print("Next")
                        }
                        
                        EjectButton {
                            print("Eject")
                        }
                    }
                }
                
                // Complete transport controls
                VStack(alignment: .leading, spacing: 10) {
                    Text("Transport Controls")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TransportControlsView(
                        isPlaying: $isPlaying,
                        onPlayPause: { isPlaying.toggle() },
                        onStop: { isPlaying = false },
                        onPrevious: { print("Previous") },
                        onNext: { print("Next") },
                        onEject: { print("Eject") }
                    )
                    .frame(width: 150)
                }
            }
            .padding()
            .background(Color.black)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("WinAmp Transport Controls")
    }
}