//
//  Skin.swift
//  WinAmpPlayer
//
//  Created on 2025-07-26.
//  Skin model representing a loaded WinAmp skin
//

import Foundation
import AppKit

/// Represents a WinAmp skin
public struct Skin: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let url: URL?
    public let isDefault: Bool
    public let thumbnailImage: NSImage?
    public let author: String?
    public let version: String?
    public let description: String?
    
    /// Create a skin instance
    public init(
        name: String,
        url: URL? = nil,
        isDefault: Bool = false,
        thumbnailImage: NSImage? = nil,
        author: String? = nil,
        version: String? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.url = url
        self.isDefault = isDefault
        self.thumbnailImage = thumbnailImage
        self.author = author
        self.version = version
        self.description = description
    }
    
    /// Default skin instance
    public static let defaultSkin = Skin(
        name: "Classic WinAmp",
        isDefault: true,
        author: "WinAmp",
        version: "1.0",
        description: "The classic WinAmp look"
    )
}