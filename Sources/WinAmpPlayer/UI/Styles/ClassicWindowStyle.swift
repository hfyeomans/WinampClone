//
//  ClassicWindowStyle.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Classic WinAmp window styling with beveled edges and borders
//

import SwiftUI

/// View modifier for classic WinAmp window styling
struct ClassicWindowStyle: ViewModifier {
    let raised: Bool
    let borderWidth: CGFloat
    
    init(raised: Bool = true, borderWidth: CGFloat = 1) {
        self.raised = raised
        self.borderWidth = borderWidth
    }
    
    func body(content: Content) -> some View {
        content
            .background(Color(WinAmpColors.background))
            .overlay(
                // Beveled border effect
                GeometryReader { geometry in
                    // Top and left edges (highlight or shadow)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                    }
                    .stroke(
                        raised ? Color(WinAmpColors.borderHighlight) : Color(WinAmpColors.borderShadow),
                        lineWidth: borderWidth
                    )
                    
                    // Bottom and right edges (shadow or highlight)
                    Path { path in
                        path.move(to: CGPoint(x: geometry.size.width, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    }
                    .stroke(
                        raised ? Color(WinAmpColors.borderShadow) : Color(WinAmpColors.borderHighlight),
                        lineWidth: borderWidth
                    )
                }
            )
    }
}

/// View modifier for LCD display styling
struct LCDDisplayStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(WinAmpColors.lcdBackground))
            .classicWindowStyle(raised: false)
    }
}

/// View modifier for classic button styling
struct ClassicButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color(configuration.isPressed ? WinAmpColors.buttonPressed : WinAmpColors.buttonFace)
            )
            .classicWindowStyle(raised: !configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

/// Extension to easily apply classic styling
extension View {
    func classicWindowStyle(raised: Bool = true, borderWidth: CGFloat = 1) -> some View {
        modifier(ClassicWindowStyle(raised: raised, borderWidth: borderWidth))
    }
    
    func classicLCDDisplayStyle() -> some View {
        modifier(LCDDisplayStyle())
    }
}

/// Classic WinAmp panel view
struct ClassicPanel: View {
    let raised: Bool
    let content: () -> AnyView
    
    init(raised: Bool = true, @ViewBuilder content: @escaping () -> AnyView) {
        self.raised = raised
        self.content = content
    }
    
    var body: some View {
        content()
            .classicWindowStyle(raised: raised)
    }
}

/// Classic group box style
struct ClassicGroupBox<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(WinAmpColors.text))
                    .padding(.horizontal, 4)
                    .background(Color(WinAmpColors.background))
                    .offset(x: 8, y: 6)
                    .zIndex(1)
            }
            
            content
                .padding(8)
                .padding(.top, title != nil ? 4 : 0)
                .classicWindowStyle(raised: false)
        }
    }
}

/// Classic slider track style
struct ClassicSliderTrack: View {
    let width: CGFloat
    let height: CGFloat
    let orientation: Axis
    
    var body: some View {
        Rectangle()
            .fill(Color(WinAmpColors.backgroundDark))
            .frame(
                width: orientation == .horizontal ? width : height,
                height: orientation == .horizontal ? height : width
            )
            .classicWindowStyle(raised: false)
    }
}

/// Classic slider thumb style
struct ClassicSliderThumb: View {
    let size: CGSize
    let isPressed: Bool
    let showGrips: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(isPressed ? WinAmpColors.buttonPressed : WinAmpColors.buttonFace))
                .frame(width: size.width, height: size.height)
                .classicWindowStyle(raised: !isPressed)
            
            if showGrips {
                // Grip lines
                HStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(Color(isPressed ? .white : .black))
                            .frame(width: 1, height: size.height - 6)
                    }
                }
            }
        }
    }
}