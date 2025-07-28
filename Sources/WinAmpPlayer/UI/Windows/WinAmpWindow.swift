//
//  WinAmpWindow.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02
//

import SwiftUI
import AppKit

// MARK: - WinAmp Color Scheme

public struct WinAmpColors {
    // Main window colors - matching classic WinAmp skin
    static let background = Color(red: 0.11, green: 0.11, blue: 0.11) // #1C1C1C - Dark gray
    static let backgroundDark = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D - Almost black
    static let backgroundLight = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626 - Light gray
    
    // Border colors for 3D beveled effect
    static let border = Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    static let borderHighlight = Color(red: 0.4, green: 0.4, blue: 0.4) // #666666 - Light edge
    static let borderShadow = Color(red: 0.0, green: 0.0, blue: 0.0) // #000000 - Dark edge
    static let darkBorder = Color(red: 31/255, green: 31/255, blue: 31/255) // For legacy compatibility
    static let lightBorder = Color(red: 165/255, green: 165/255, blue: 165/255) // For legacy compatibility
    
    // LCD display colors
    static let lcdBackground = Color(red: 0.0, green: 0.0, blue: 0.0) // Pure black
    static let lcdText = Color(red: 0.0, green: 1.0, blue: 0.0) // #00FF00 - Bright green
    static let lcdTextDim = Color(red: 0.0, green: 0.4, blue: 0.0) // #006600 - Dim green
    
    // Text colors
    static let text = Color(red: 0.0, green: 1.0, blue: 0.0) // #00FF00 - Classic green
    static let textDim = Color(red: 0.0, green: 0.6, blue: 0.0) // #009900
    static let textHighlight = Color(red: 0.0, green: 1.0, blue: 1.0) // #00FFFF - Cyan for current track
    static let textSelected = Color(red: 1.0, green: 1.0, blue: 0.0) // #FFFF00 - Yellow for selected
    
    // Button colors
    static let buttonFace = Color(red: 0.75, green: 0.75, blue: 0.75) // #BFBFBF - Classic button gray
    static let buttonNormal = Color(red: 0.75, green: 0.75, blue: 0.75) // Alias for buttonFace
    static let buttonHighlight = Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2 - Button highlight
    static let buttonShadow = Color(red: 0.25, green: 0.25, blue: 0.25) // #404040 - Button shadow
    static let buttonPressed = Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A - Pressed state
    static let buttonHover = Color(red: 0.2, green: 0.25, blue: 0.2) // Subtle green tint
    static let buttonActive = Color(red: 0.1, green: 0.2, blue: 0.1)
    
    // Other UI elements
    static let accent = Color(red: 0.0, green: 0.8, blue: 0.0) // #00CC00
    static let accentDark = Color(red: 0.0, green: 0.5, blue: 0.0) // #008000
    static let selection = Color(red: 0.0, green: 0.3, blue: 0.3) // #004D4D - Dark teal
    static let shadow = Color.black.opacity(0.8)
    static let button = Color(red: 0.2, green: 0.2, blue: 0.2) // #333333 - Dark button
    
    // Additional text colors
    static let textSecondary = Color(red: 0.0, green: 0.8, blue: 0.0) // #00CC00 - Secondary text
    
    // Playlist specific colors
    static let playlistBackground = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D - Dark playlist background
    static let playlistText = Color(red: 0.0, green: 1.0, blue: 0.0) // #00FF00 - Green text
    static let playlistPlaying = Color(red: 0.0, green: 1.0, blue: 1.0) // #00FFFF - Cyan for playing track
    static let playlistSelected = Color(red: 0.0, green: 0.3, blue: 0.3) // #004D4D - Dark teal for selection
}

// MARK: - Window Control Button Type

public enum WindowControlType {
    case close
    case minimize
    case shade
    
    var icon: String {
        switch self {
        case .close: return "✕"
        case .minimize: return "—"
        case .shade: return "▬"
        }
    }
    
    var hoverColor: Color {
        switch self {
        case .close: return Color.red.opacity(0.8)
        case .minimize: return WinAmpColors.accent
        case .shade: return WinAmpColors.accent
        }
    }
}

// MARK: - Window Control Button

struct WindowControlButton: View {
    let type: WindowControlType
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Text(type.icon)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(isHovered ? type.hoverColor : WinAmpColors.textDim)
            .frame(width: 18, height: 14)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPressed ? WinAmpColors.buttonActive : (isHovered ? WinAmpColors.buttonHover : WinAmpColors.backgroundLight))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(WinAmpColors.border, lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            isPressed = false
                        }
                    }
            )
    }
}

// MARK: - Custom Title Bar

struct WinAmpTitleBar: View {
    let title: String
    let windowType: WindowType
    @Binding var isShaded: Bool
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onStartDrag: () -> Void
    let menuContent: AnyView?
    
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Window controls
            HStack(spacing: 2) {
                WindowControlButton(type: .close, action: onClose)
                
                WindowControlButton(type: .minimize, action: onMinimize)
                
                WindowControlButton(type: .shade, action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShaded.toggle()
                        WindowManager.shared.setShadeMode(isShaded, for: windowType)
                    }
                })
            }
            .padding(.leading, 6)
            
            // Title area (draggable)
            HStack {
                BitmapFontText(title.uppercased(), spacing: -1)
                    .scaleEffect(0.8)
                    .shadow(color: WinAmpColors.shadow, radius: 1, x: 1, y: 1)
                
                Spacer()
                
                // Menu area if provided
                if let menuContent = menuContent {
                    menuContent
                        .padding(.trailing, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        if !isDragging {
                            isDragging = true
                            onStartDrag()
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .padding(.horizontal, 4)
        }
        .frame(height: 20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    WinAmpColors.backgroundLight,
                    WinAmpColors.background
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .stroke(WinAmpColors.borderHighlight, lineWidth: 1)
                .opacity(0.3)
        )
    }
}

// MARK: - WinAmp Window Configuration

public struct WinAmpWindowConfiguration {
    let title: String
    let windowType: WindowType
    let showTitleBar: Bool
    let resizable: Bool
    let minSize: CGSize?
    let maxSize: CGSize?
    let borderWidth: CGFloat
    let showBorder: Bool
    
    public init(
        title: String,
        windowType: WindowType,
        showTitleBar: Bool = true,
        resizable: Bool = false,
        minSize: CGSize? = nil,
        maxSize: CGSize? = nil,
        borderWidth: CGFloat = 2,
        showBorder: Bool = true
    ) {
        self.title = title
        self.windowType = windowType
        self.showTitleBar = showTitleBar
        self.resizable = resizable
        self.minSize = minSize
        self.maxSize = maxSize
        self.borderWidth = borderWidth
        self.showBorder = showBorder
    }
}

// MARK: - WinAmp Window View

public struct WinAmpWindow<Content: View, MenuContent: View>: View {
    let configuration: WinAmpWindowConfiguration
    let content: Content
    let menuContent: MenuContent?
    
    @State private var isShaded = false
    @State private var window: NSWindow?
    @Environment(\.scenePhase) private var scenePhase
    
    public init(
        configuration: WinAmpWindowConfiguration,
        @ViewBuilder content: () -> Content,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.configuration = configuration
        self.content = content()
        self.menuContent = menuContent()
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if configuration.showTitleBar {
                WinAmpTitleBar(
                    title: configuration.title,
                    windowType: configuration.windowType,
                    isShaded: $isShaded,
                    onClose: {
                        WindowManager.shared.hideWindow(configuration.windowType)
                    },
                    onMinimize: {
                        window?.miniaturize(nil)
                    },
                    onStartDrag: {
                        window?.performDrag(with: NSEvent())
                    },
                    menuContent: menuContent.map { AnyView($0) }
                )
            }
            
            if !isShaded {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WinAmpColors.background)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .background(WinAmpColors.background)
        .if(configuration.showBorder) { view in
            view.overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WinAmpColors.borderHighlight,
                                WinAmpColors.border
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: configuration.borderWidth
                    )
            )
        }
        .shadow(color: WinAmpColors.shadow, radius: 8, x: 2, y: 2)
        .background(WindowAccessor { newWindow in
            self.window = newWindow
            configureWindow(newWindow)
        })
        .onChange(of: scenePhase) { _, _ in
            if let window = window {
                WindowManager.shared.registerWindow(window, type: configuration.windowType)
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        // Remove default title bar
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        
        // Configure window properties
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        
        // Set resizing constraints
        if !configuration.resizable {
            window.styleMask.remove(.resizable)
        }
        
        if let minSize = configuration.minSize {
            window.minSize = minSize
        }
        
        if let maxSize = configuration.maxSize {
            window.maxSize = maxSize
        }
        
        // Register with WindowManager
        WindowManager.shared.registerWindow(window, type: configuration.windowType)
    }
}

// MARK: - Convenience Initializer for No Menu

extension WinAmpWindow where MenuContent == EmptyView {
    public init(
        configuration: WinAmpWindowConfiguration,
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.content = content()
        self.menuContent = nil
    }
}

// MARK: - Window Style Modifier

public struct WinAmpWindowStyle: ViewModifier {
    let configuration: WinAmpWindowConfiguration
    
    public func body(content: Content) -> some View {
        WinAmpWindow(configuration: configuration) {
            content
        }
    }
}

extension View {
    public func winAmpWindow(configuration: WinAmpWindowConfiguration) -> some View {
        modifier(WinAmpWindowStyle(configuration: configuration))
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    let onWindowFound: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.onWindowFound(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                self.onWindowFound(window)
            }
        }
    }
}

// MARK: - Helper Extensions

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WinAmpWindow_Previews: PreviewProvider {
    static var previews: some View {
        WinAmpWindow(
            configuration: WinAmpWindowConfiguration(
                title: "WinAmp Player",
                windowType: .main,
                resizable: false
            )
        ) {
            VStack {
                Text("WINAMP 5.0")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(WinAmpColors.text)
                    .padding()
                
                Spacer()
            }
            .frame(width: 275, height: 116)
        }
        .preferredColorScheme(.dark)
    }
}
#endif