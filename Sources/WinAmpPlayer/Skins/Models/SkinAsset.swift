//
//  SkinAsset.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Model for individual skin assets
//

import Foundation
import AppKit

/// Represents an individual asset within a skin
public struct SkinAsset {
    public let type: AssetType
    public let image: NSImage
    public let region: CGRect?
    
    public enum AssetType {
        case sprite(SpriteType)
        case background(WindowType)
        case custom(String)
    }
    
    public enum WindowType {
        case main
        case equalizer
        case playlist
        case library
    }
}