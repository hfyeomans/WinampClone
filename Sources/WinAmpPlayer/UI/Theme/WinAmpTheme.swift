//
//  WinAmpTheme.swift
//  WinAmpPlayer
//
//  Classic WinAmp 2.x theme colors and styling
//

import SwiftUI

// MARK: - Color Scheme

struct LegacyWinAmpColors {
    // Classic WinAmp 2.x colors
    static let background = Color(red: 58/255, green: 58/255, blue: 58/255)
    static let backgroundLight = Color(red: 74/255, green: 74/255, blue: 74/255)
    static let darkBorder = Color(red: 31/255, green: 31/255, blue: 31/255)
    static let lightBorder = Color(red: 165/255, green: 165/255, blue: 165/255)
    static let midTone = Color(red: 99/255, green: 99/255, blue: 99/255)
    static let border = Color(red: 0.3, green: 0.3, blue: 0.3)
    static let text = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let textSecondary = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let accent = Color(red: 0.2, green: 0.8, blue: 0.2)
    static let highlight = Color(red: 0.3, green: 0.5, blue: 0.8)
    
    // LCD specific colors
    static let lcdBackground = Color.black
    static let lcdText = Color(red: 0, green: 1, blue: 0)
    static let lcdDim = Color(red: 0, green: 0.31, blue: 0)
    
    // Playlist colors
    static let playlistBackground = Color.black
    static let playlistText = Color(red: 0, green: 1, blue: 0)
    static let playlistSelected = Color(red: 0, green: 0, blue: 0.66)
    static let playlistPlaying = Color.white
    
    // Button states
    static let buttonNormal = Color(red: 74/255, green: 74/255, blue: 74/255)
    static let buttonPressed = Color(red: 58/255, green: 58/255, blue: 58/255)
    static let buttonHover = Color(red: 82/255, green: 82/255, blue: 82/255)
}

// MARK: - Button Styles

struct ClassicWinAmpButtonStyle: ButtonStyle {
    @State private var isPressed = false
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(configuration.isPressed ? LegacyWinAmpColors.buttonPressed : 
                          (isHovered ? LegacyWinAmpColors.buttonHover : LegacyWinAmpColors.buttonNormal))
            )
            .overlay(
                BeveledBorder(raised: !configuration.isPressed)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Beveled Border

struct BeveledBorder: View {
    let raised: Bool
    let lineWidth: CGFloat = 1
    
    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            
            // Top and left edges
            Path { path in
                path.move(to: CGPoint(x: 0, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: 0))
            }
            .stroke(raised ? LegacyWinAmpColors.lightBorder : LegacyWinAmpColors.darkBorder, lineWidth: lineWidth)
            
            // Bottom and right edges
            Path { path in
                path.move(to: CGPoint(x: rect.width, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: rect.height))
            }
            .stroke(raised ? LegacyWinAmpColors.darkBorder : LegacyWinAmpColors.lightBorder, lineWidth: lineWidth)
        }
    }
}

// MARK: - LCD Display Style

struct ThemeLCDDisplayStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LegacyWinAmpColors.lcdBackground)
            .foregroundColor(LegacyWinAmpColors.lcdText)
            .overlay(BeveledBorder(raised: false))
    }
}

extension View {
    func lcdDisplayStyle() -> some View {
        modifier(ThemeLCDDisplayStyle())
    }
}

// MARK: - Classic Window Style

struct ThemeClassicWindowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LegacyWinAmpColors.background)
            .overlay(BeveledBorder(raised: true))
    }
}

extension View {
    func classicWindowStyle() -> some View {
        modifier(ThemeClassicWindowStyle())
    }
}