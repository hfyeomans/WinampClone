import Foundation
import AppKit

/// Protocol for parsed skin data to enable interoperability between different parsing approaches
public protocol ParsedSkinProtocol {
    var name: String { get }
    var bitmaps: [String: NSImage] { get }
    var configurations: [String: String] { get }
}

/// Extension to provide default implementations
extension ParsedSkinProtocol {
    /// Get URL if this is a file-based skin
    public var url: URL? {
        return nil
    }
    
    /// Get author if available in configurations
    public var author: String {
        return configurations["author"] ?? "Unknown"
    }
    
    /// Get version if available in configurations
    public var version: String {
        return configurations["version"] ?? "1.0"
    }
}
