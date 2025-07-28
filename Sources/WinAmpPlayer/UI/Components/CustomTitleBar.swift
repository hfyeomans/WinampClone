//
//  CustomTitleBar.swift
//  WinAmpPlayer
//
//  Custom title bar with WinAmp styling and window controls
//

import SwiftUI
import AppKit

struct CustomTitleBar: View {
    @StateObject private var skinManager = SkinManager.shared
    @State private var isHoveringClose = false
    @State private var isHoveringMinimize = false
    @State private var isHoveringShade = false
    
    var body: some View {
        ZStack {
            // Title bar background
            if let titleBarSprite = skinManager.getSprite(.titleBarActive) {
                SpriteView(.titleBarActive)
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.3, blue: 0.3),
                        Color(red: 0.2, green: 0.2, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            
            HStack {
                // WinAmp title text
                Text("WINAMP")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.leading, 6)
                
                Spacer()
                
                // Window control buttons
                HStack(spacing: 1) {
                    // Shade button (WinAmp specific - toggles minimized mode)
                    Button(action: toggleShadeMode) {
                        if let shadeSprite = skinManager.getSprite(.shadeButton(isHoveringShade ? .pressed : .normal)) {
                            SpriteView(.shadeButton(isHoveringShade ? .pressed : .normal))
                        } else {
                            Rectangle()
                                .fill(isHoveringShade ? Color.gray : Color(NSColor.lightGray))
                                .frame(width: 9, height: 9)
                                .overlay(
                                    // Up arrow symbol
                                    Path { path in
                                        path.move(to: CGPoint(x: 4.5, y: 2))
                                        path.addLine(to: CGPoint(x: 2, y: 7))
                                        path.addLine(to: CGPoint(x: 7, y: 7))
                                        path.closeSubpath()
                                    }
                                    .stroke(Color.white, lineWidth: 0.5)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringShade = hovering
                    }
                    
                    // Minimize button
                    Button(action: minimizeWindow) {
                        if let minimizeSprite = skinManager.getSprite(.minimizeButton(isHoveringMinimize ? .pressed : .normal)) {
                            SpriteView(.minimizeButton(isHoveringMinimize ? .pressed : .normal))
                        } else {
                            Rectangle()
                                .fill(isHoveringMinimize ? Color.gray : Color(NSColor.lightGray))
                                .frame(width: 9, height: 9)
                                .overlay(
                                    // Minimize line
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 5, height: 1)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringMinimize = hovering
                    }
                    
                    // Close button
                    Button(action: closeWindow) {
                        if let closeSprite = skinManager.getSprite(.closeButton(isHoveringClose ? .pressed : .normal)) {
                            SpriteView(.closeButton(isHoveringClose ? .pressed : .normal))
                        } else {
                            Rectangle()
                                .fill(isHoveringClose ? Color.red : Color(NSColor.lightGray))
                                .frame(width: 9, height: 9)
                                .overlay(
                                    // X symbol
                                    Path { path in
                                        path.move(to: CGPoint(x: 2, y: 2))
                                        path.addLine(to: CGPoint(x: 7, y: 7))
                                        path.move(to: CGPoint(x: 7, y: 2))
                                        path.addLine(to: CGPoint(x: 2, y: 7))
                                    }
                                    .stroke(Color.white, lineWidth: 1)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringClose = hovering
                    }
                }
                .padding(.trailing, 3)
            }
        }
        .frame(height: 14)
    }
    
    private func closeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func minimizeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.miniaturize(nil)
        }
    }
    
    private func toggleShadeMode() {
        guard let window = NSApplication.shared.keyWindow else { return }
        
        let currentHeight = window.frame.height
        let newHeight: CGFloat = currentHeight > 20 ? 14 : 116 // Toggle between shaded and normal
        
        var newFrame = window.frame
        newFrame.size.height = newHeight
        newFrame.origin.y += (currentHeight - newHeight) // Keep top position fixed
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
}

#Preview {
    CustomTitleBar()
        .frame(width: 275, height: 14)
}
