import SwiftUI
import Combine

// MARK: - VU Meter Constants

private enum VUMeterConstants {
    static let updateInterval: TimeInterval = 1.0 / 60.0 // 60 FPS
    static let peakHoldDuration: TimeInterval = 1.0
    static let decayTime: TimeInterval = 0.3
    static let gridLineSpacing: CGFloat = 4
    static let ledSpacing: CGFloat = 2
    
    // Level thresholds
    static let yellowThreshold: Float = 0.7
    static let redThreshold: Float = 0.9
    
    // Colors
    static let backgroundColor = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let gridColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let greenGradient = LinearGradient(
        colors: [Color(hex: "00FF00"), Color(hex: "00CC00")],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let yellowColor = Color(hex: "FFFF00")
    static let redColor = Color(hex: "FF0000")
    static let peakIndicatorColor = Color(hex: "FFFFFF")
}

// MARK: - VU Meter Bar (Single Channel)

struct VUMeterBar: View {
    let level: Float
    let peakLevel: Float
    let orientation: Axis
    let showGrid: Bool
    
    @State private var animatedLevel: CGFloat = 0
    @State private var animatedPeak: CGFloat = 0
    @State private var peakHoldTime: Date = Date()
    
    private let timer = Timer.publish(every: VUMeterConstants.updateInterval, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(VUMeterConstants.backgroundColor)
                
                // Grid lines
                if showGrid {
                    GridOverlay(size: geometry.size, orientation: orientation)
                }
                
                // Level bar
                LevelBar(
                    level: animatedLevel,
                    size: geometry.size,
                    orientation: orientation
                )
                
                // Peak indicator
                PeakLine(
                    peakLevel: animatedPeak,
                    size: geometry.size,
                    orientation: orientation
                )
            }
            .onReceive(timer) { _ in
                updateLevels()
            }
        }
    }
    
    private func updateLevels() {
        // Apply logarithmic scaling
        let scaledLevel = logarithmicScale(level)
        
        // Smooth animation for level
        withAnimation(.linear(duration: VUMeterConstants.updateInterval)) {
            animatedLevel = CGFloat(scaledLevel)
        }
        
        // Peak hold logic
        let scaledPeak = logarithmicScale(peakLevel)
        if scaledPeak > Float(animatedPeak) {
            animatedPeak = CGFloat(scaledPeak)
            peakHoldTime = Date()
        } else if Date().timeIntervalSince(peakHoldTime) > VUMeterConstants.peakHoldDuration {
            // Decay after hold time
            let decayRate = Float(VUMeterConstants.updateInterval / VUMeterConstants.decayTime)
            animatedPeak = max(0, animatedPeak - CGFloat(decayRate))
        }
    }
    
    private func logarithmicScale(_ linearValue: Float) -> Float {
        guard linearValue > 0 else { return 0 }
        
        // Convert to dB (-60 to 0)
        let db = 20.0 * log10(linearValue)
        let normalizedDB = (db + 60.0) / 60.0 // Normalize to 0-1 range
        return max(0, min(1, normalizedDB))
    }
}

// MARK: - Level Bar Component

private struct LevelBar: View {
    let level: CGFloat
    let size: CGSize
    let orientation: Axis
    
    var body: some View {
        let barSize = orientation == .horizontal
            ? CGSize(width: size.width * level, height: size.height)
            : CGSize(width: size.width, height: size.height * level)
        
        Rectangle()
            .fill(gradient(for: level))
            .frame(width: barSize.width, height: barSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
    
    private var alignment: Alignment {
        orientation == .horizontal ? .leading : .bottom
    }
    
    private func gradient(for level: CGFloat) -> some ShapeStyle {
        if level > CGFloat(VUMeterConstants.redThreshold) {
            return LinearGradient(
                colors: [VUMeterConstants.redColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if level > CGFloat(VUMeterConstants.yellowThreshold) {
            return LinearGradient(
                colors: [VUMeterConstants.yellowColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return VUMeterConstants.greenGradient
        }
    }
}

// MARK: - Peak Line Indicator

private struct PeakLine: View {
    let peakLevel: CGFloat
    let size: CGSize
    let orientation: Axis
    
    var body: some View {
        if peakLevel > 0 {
            Rectangle()
                .fill(VUMeterConstants.peakIndicatorColor)
                .frame(
                    width: orientation == .horizontal ? 2 : size.width,
                    height: orientation == .horizontal ? size.height : 2
                )
                .offset(
                    x: orientation == .horizontal ? size.width * peakLevel - 1 : 0,
                    y: orientation == .horizontal ? 0 : size.height * (1 - peakLevel) - 1
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Grid Overlay

private struct GridOverlay: View {
    let size: CGSize
    let orientation: Axis
    
    var body: some View {
        Canvas { context, _ in
            let spacing = VUMeterConstants.gridLineSpacing
            
            if orientation == .horizontal {
                // Vertical grid lines
                var x: CGFloat = spacing
                while x < size.width {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(VUMeterConstants.gridColor),
                        lineWidth: 0.5
                    )
                    x += spacing
                }
            } else {
                // Horizontal grid lines
                var y: CGFloat = spacing
                while y < size.height {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        },
                        with: .color(VUMeterConstants.gridColor),
                        lineWidth: 0.5
                    )
                    y += spacing
                }
            }
        }
    }
}

// MARK: - Stereo VU Meter

public struct StereoVUMeter: View {
    @ObservedObject var volumeController: VolumeBalanceController
    let orientation: Axis
    let showGrid: Bool
    let spacing: CGFloat
    
    public init(
        volumeController: VolumeBalanceController,
        orientation: Axis = .horizontal,
        showGrid: Bool = true,
        spacing: CGFloat = 4
    ) {
        self.volumeController = volumeController
        self.orientation = orientation
        self.showGrid = showGrid
        self.spacing = spacing
    }
    
    public var body: some View {
        HStack(spacing: spacing) {
            // Left channel
            VStack(spacing: 2) {
                Text("L")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                
                VUMeterBar(
                    level: volumeController.leftPeakLevel,
                    peakLevel: volumeController.leftPeakLevel,
                    orientation: orientation,
                    showGrid: showGrid
                )
            }
            
            // Right channel
            VStack(spacing: 2) {
                Text("R")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                
                VUMeterBar(
                    level: volumeController.rightPeakLevel,
                    peakLevel: volumeController.rightPeakLevel,
                    orientation: orientation,
                    showGrid: showGrid
                )
            }
        }
    }
}

// MARK: - Peak Indicator (LED Style)

public struct PeakIndicator: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat
    
    public init(
        isActive: Bool,
        color: Color = .red,
        size: CGFloat = 8
    ) {
        self.isActive = isActive
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Circle()
            .fill(isActive ? color : Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(
                color: isActive ? color.opacity(0.8) : .clear,
                radius: isActive ? 3 : 0
            )
    }
}

// MARK: - LED VU Meter (Alternative Style)

public struct LEDVUMeter: View {
    let level: Float
    let orientation: Axis
    let ledCount: Int
    
    public init(
        level: Float,
        orientation: Axis = .horizontal,
        ledCount: Int = 20
    ) {
        self.level = level
        self.orientation = orientation
        self.ledCount = ledCount
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let activeLeds = Int(Float(ledCount) * logarithmicScale(level))
            
            if orientation == .horizontal {
                HStack(spacing: VUMeterConstants.ledSpacing) {
                    ForEach(0..<ledCount, id: \.self) { index in
                        LEDSegment(
                            isActive: index < activeLeds,
                            index: index,
                            totalCount: ledCount
                        )
                    }
                }
            } else {
                VStack(spacing: VUMeterConstants.ledSpacing) {
                    ForEach((0..<ledCount).reversed(), id: \.self) { index in
                        LEDSegment(
                            isActive: index < activeLeds,
                            index: index,
                            totalCount: ledCount
                        )
                    }
                }
            }
        }
    }
    
    private func logarithmicScale(_ linearValue: Float) -> Float {
        guard linearValue > 0 else { return 0 }
        let db = 20.0 * log10(linearValue)
        let normalizedDB = (db + 60.0) / 60.0
        return max(0, min(1, normalizedDB))
    }
}

// MARK: - LED Segment

private struct LEDSegment: View {
    let isActive: Bool
    let index: Int
    let totalCount: Int
    
    var body: some View {
        Rectangle()
            .fill(segmentColor)
            .overlay(
                Rectangle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
            )
    }
    
    private var segmentColor: Color {
        let position = Float(index) / Float(totalCount)
        
        if !isActive {
            return Color.gray.opacity(0.2)
        }
        
        if position > VUMeterConstants.redThreshold {
            return VUMeterConstants.redColor
        } else if position > VUMeterConstants.yellowThreshold {
            return VUMeterConstants.yellowColor
        } else {
            return Color(hex: "00FF00")
        }
    }
}

// MARK: - Helper Extensions

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#if DEBUG
struct VUMeter_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Horizontal VU meters
            VUMeterBar(
                level: 0.7,
                peakLevel: 0.85,
                orientation: .horizontal,
                showGrid: true
            )
            .frame(height: 20)
            
            // LED style meter
            LEDVUMeter(
                level: 0.6,
                orientation: .horizontal,
                ledCount: 25
            )
            .frame(height: 10)
            
            // Peak indicators
            HStack(spacing: 10) {
                PeakIndicator(isActive: true)
                PeakIndicator(isActive: false)
            }
        }
        .padding()
        .background(Color.black)
    }
}
#endif