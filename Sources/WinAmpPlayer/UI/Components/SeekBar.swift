import SwiftUI

struct WinAmpSeekBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var hoverLocation: CGPoint = .zero
    @State private var dragLocation: Double = 0
    
    private let trackHeight: CGFloat = 10
    private let thumbWidth: CGFloat = 4
    private let thumbHeight: CGFloat = 10
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return isDragging ? dragLocation : (currentTime / duration)
    }
    
    private var displayTime: Double {
        isDragging ? (dragLocation * duration) : currentTime
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.1, green: 0.1, blue: 0.1),
                                Color(red: 0.05, green: 0.05, blue: 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: trackHeight)
                    .overlay(
                        // Inner shadow effect
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black.opacity(0.5), lineWidth: 1)
                            .blur(radius: 1)
                            .offset(y: 1)
                    )
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.2),
                                Color(red: 0.1, green: 0.6, blue: 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: trackHeight)
                    .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.2).opacity(isHovering ? 0.6 : 0.3), radius: 3)
                    .animation(.linear(duration: isDragging ? 0 : 0.1), value: progress)
                
                // Thumb
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.9, green: 0.9, blue: 0.9),
                                Color(red: 0.7, green: 0.7, blue: 0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: thumbWidth, height: thumbHeight)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .scaleEffect(isDragging ? 1.2 : (isHovering ? 1.1 : 1.0))
                    .offset(x: max(0, min(geometry.size.width - thumbWidth, geometry.size.width * CGFloat(progress) - thumbWidth / 2)))
                    .animation(.easeOut(duration: 0.1), value: isDragging)
                    .animation(.easeOut(duration: 0.1), value: isHovering)
                
                // Time tooltip
                if isHovering || isDragging {
                    TimeTooltip(time: displayTime)
                        .position(x: hoverLocation.x, y: -15)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.15), value: isHovering || isDragging)
                }
            }
            .frame(height: thumbHeight)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        dragLocation = Double(progress)
                        hoverLocation = CGPoint(x: value.location.x, y: value.location.y)
                    }
                    .onEnded { value in
                        isDragging = false
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        onSeek(Double(progress) * duration)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverLocation = location
                case .ended:
                    break
                }
            }
            .focusable()
            .onKeyPress { press in
                switch press.key {
                case .leftArrow:
                    onSeek(max(0, currentTime - 5))
                    return .handled
                case .rightArrow:
                    onSeek(min(duration, currentTime + 5))
                    return .handled
                default:
                    return .ignored
                }
            }
        }
        .frame(height: thumbHeight)
    }
}

struct TimeTooltip: View {
    let time: Double
    
    private var formattedTime: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Text(formattedTime)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
}

// Preview
struct WinAmpSeekBar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var currentTime: Double = 45
        let duration: Double = 180
        
        var body: some View {
            VStack(spacing: 30) {
                WinAmpSeekBar(
                    currentTime: $currentTime,
                    duration: duration,
                    onSeek: { time in
                        currentTime = time
                    }
                )
                .frame(width: 300)
                
                HStack {
                    Text("Current: \(Int(currentTime))s")
                    Spacer()
                    Text("Duration: \(Int(duration))s")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 300)
            }
            .padding(40)
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .preferredColorScheme(.dark)
    }
}