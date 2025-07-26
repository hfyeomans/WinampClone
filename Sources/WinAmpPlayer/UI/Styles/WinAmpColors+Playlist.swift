//
//  WinAmpColors+Playlist.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Additional colors for playlist window
//

import SwiftUI

extension WinAmpColors {
    // Playlist-specific colors
    static let textHighlight = Color(red: 0.0, green: 1.0, blue: 1.0) // #00FFFF - Cyan for current track
    static let textSelected = Color(red: 1.0, green: 1.0, blue: 0.0) // #FFFF00 - Yellow for selected
    static let selection = Color(red: 0.0, green: 0.3, blue: 0.3) // Dark teal background
    static let button = Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    static let buttonPressed = Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A
    static let backgroundDark = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D
}