//
//  TextureEngine.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Procedural texture generation engine
//

import Foundation
import CoreGraphics
import CoreImage
import Accelerate

/// Procedural texture generation engine
public class TextureEngine {
    
    /// Texture generation context
    public struct Context {
        public let width: Int
        public let height: Int
        public let scale: CGFloat
        public let seed: UInt32
        
        public init(width: Int, height: Int, scale: CGFloat = 1.0, seed: UInt32 = UInt32.random(in: 0...UInt32.max)) {
            self.width = width
            self.height = height
            self.scale = scale
            self.seed = seed
        }
    }
    
    /// Generate texture based on configuration
    public static func generateTexture(
        type: TextureType,
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig? = nil
    ) -> CGImage? {
        
        switch type {
        case .solid:
            return generateSolidTexture(context: context, color: colors.primaryColor)
            
        case .gradient:
            return generateGradientTexture(context: context, colors: colors)
            
        case .noise:
            return generateNoiseTexture(context: context, colors: colors, config: config)
            
        case .circuit:
            return generateCircuitTexture(context: context, colors: colors, config: config)
            
        case .dots:
            return generateDotsTexture(context: context, colors: colors, config: config)
            
        case .lines:
            return generateLinesTexture(context: context, colors: colors, config: config)
            
        case .waves:
            return generateWavesTexture(context: context, colors: colors, config: config)
            
        case .voronoi:
            return generateVoronoiTexture(context: context, colors: colors, config: config)
            
        case .checkerboard:
            return generateCheckerboardTexture(context: context, colors: colors, config: config)
        }
    }
    
    // MARK: - Texture Generators
    
    /// Generate solid color texture
    private static func generateSolidTexture(context: Context, color: CGColor) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        cgContext.setFillColor(color)
        cgContext.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        
        return cgContext.makeImage()
    }
    
    /// Generate gradient texture
    private static func generateGradientTexture(context: Context, colors: GeneratedPalette) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        let gradientColors = [
            colors.primary.tone(30),
            colors.primary.tone(50),
            colors.primary.tone(70)
        ] as CFArray
        
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: gradientColors,
            locations: locations
        ) else { return nil }
        
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: context.width, y: context.height)
        
        cgContext.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        
        return cgContext.makeImage()
    }
    
    /// Generate noise texture
    private static func generateNoiseTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let octaves = config?.octaves ?? 4
        let persistence = config?.persistence ?? 0.5
        let scale = config?.scale ?? 1.0
        
        // Create noise data
        var noiseData = [Float](repeating: 0, count: context.width * context.height)
        let perlin = PerlinNoise(seed: context.seed)
        
        for y in 0..<context.height {
            for x in 0..<context.width {
                let nx = Double(x) / Double(context.width) * scale
                let ny = Double(y) / Double(context.height) * scale
                
                let noise = perlin.fractalNoise(
                    x: nx,
                    y: ny,
                    octaves: octaves,
                    persistence: persistence
                )
                
                noiseData[y * context.width + x] = Float(noise)
            }
        }
        
        // Convert to image
        return noiseToImage(
            data: noiseData,
            width: context.width,
            height: context.height,
            colors: colors
        )
    }
    
    /// Generate circuit texture
    private static func generateCircuitTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let scale = config?.scale ?? 2.0
        let density = 0.3
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Background
        cgContext.setFillColor(colors.neutral.tone(10))
        cgContext.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        
        // Circuit lines
        let gridSize = Int(20.0 * scale)
        var rng = SeededRandomGenerator(seed: context.seed)
        
        cgContext.setStrokeColor(colors.primary.tone(60))
        cgContext.setLineWidth(1.5)
        
        // Draw circuit paths
        for y in stride(from: 0, to: context.height, by: gridSize) {
            for x in stride(from: 0, to: context.width, by: gridSize) {
                if rng.random() < density {
                    drawCircuitNode(
                        at: CGPoint(x: x, y: y),
                        in: cgContext,
                        gridSize: gridSize,
                        rng: &rng,
                        colors: colors
                    )
                }
            }
        }
        
        return cgContext.makeImage()
    }
    
    /// Generate dots texture
    private static func generateDotsTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let scale = config?.scale ?? 1.0
        let dotSize = 4.0 * scale
        let spacing = 12.0 * scale
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Background
        cgContext.setFillColor(colors.surface)
        cgContext.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        
        // Dots
        cgContext.setFillColor(colors.primary.tone(40))
        
        for y in stride(from: spacing/2, to: CGFloat(context.height), by: spacing) {
            for x in stride(from: spacing/2, to: CGFloat(context.width), by: spacing) {
                let rect = CGRect(
                    x: x - dotSize/2,
                    y: y - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                cgContext.fillEllipse(in: rect)
            }
        }
        
        return cgContext.makeImage()
    }
    
    /// Generate lines texture
    private static func generateLinesTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let scale = config?.scale ?? 1.0
        let lineWidth = 2.0 * scale
        let spacing = 8.0 * scale
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Background
        cgContext.setFillColor(colors.background)
        cgContext.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        
        // Diagonal lines
        cgContext.setStrokeColor(colors.primary.tone(30))
        cgContext.setLineWidth(lineWidth)
        
        let diagonal = sqrt(Double(context.width * context.width + context.height * context.height))
        
        for offset in stride(from: -diagonal, to: diagonal, by: Double(spacing)) {
            cgContext.move(to: CGPoint(x: offset, y: 0))
            cgContext.addLine(to: CGPoint(x: offset + Double(context.height), y: Double(context.height)))
        }
        
        cgContext.strokePath()
        
        return cgContext.makeImage()
    }
    
    /// Generate waves texture
    private static func generateWavesTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let scale = config?.scale ?? 3.0
        let amplitude = 20.0
        let frequency = scale
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Background gradient
        let locations: [CGFloat] = [0.0, 1.0]
        let gradientColors = [
            colors.secondary.tone(70),
            colors.secondary.tone(40)
        ] as CFArray
        
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: gradientColors,
            locations: locations
        ) {
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: context.height),
                options: []
            )
        }
        
        // Wave lines
        cgContext.setStrokeColor(colors.primary.tone(60).copy(alpha: 0.6)!)
        cgContext.setLineWidth(2.0)
        
        for waveY in stride(from: 0, to: context.height, by: Int(amplitude * 2)) {
            cgContext.beginPath()
            
            for x in 0...context.width {
                let y = CGFloat(waveY) + amplitude * sin(Double(x) / Double(context.width) * .pi * 2 * frequency)
                
                if x == 0 {
                    cgContext.move(to: CGPoint(x: CGFloat(x), y: y))
                } else {
                    cgContext.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
            }
            
            cgContext.strokePath()
        }
        
        return cgContext.makeImage()
    }
    
    /// Generate Voronoi texture
    private static func generateVoronoiTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let scale = config?.scale ?? 1.0
        let cellCount = Int(10.0 / scale)
        
        // Generate random cell centers
        var rng = SeededRandomGenerator(seed: context.seed)
        var cellCenters: [CGPoint] = []
        
        for _ in 0..<cellCount {
            let x = CGFloat(rng.random()) * CGFloat(context.width)
            let y = CGFloat(rng.random()) * CGFloat(context.height)
            cellCenters.append(CGPoint(x: x, y: y))
        }
        
        // Create pixel data
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * context.width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * context.height)
        
        // Generate Voronoi diagram
        for y in 0..<context.height {
            for x in 0..<context.width {
                let point = CGPoint(x: x, y: y)
                
                // Find closest cell center
                var minDistance = CGFloat.infinity
                var closestIndex = 0
                
                for (index, center) in cellCenters.enumerated() {
                    let dx = point.x - center.x
                    let dy = point.y - center.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    if distance < minDistance {
                        minDistance = distance
                        closestIndex = index
                    }
                }
                
                // Assign color based on cell
                let tone = 30 + (closestIndex * 40 / cellCount)
                let color = colors.primary.tone(tone)
                
                if let components = color.components, components.count >= 3 {
                    let offset = (y * context.width + x) * bytesPerPixel
                    pixelData[offset] = UInt8(components[0] * 255)
                    pixelData[offset + 1] = UInt8(components[1] * 255)
                    pixelData[offset + 2] = UInt8(components[2] * 255)
                    pixelData[offset + 3] = 255
                }
            }
        }
        
        return createImage(from: pixelData, width: context.width, height: context.height)
    }
    
    /// Generate checkerboard texture
    private static func generateCheckerboardTexture(
        context: Context,
        colors: GeneratedPalette,
        config: TextureConfig?
    ) -> CGImage? {
        let scale = config?.scale ?? 0.1
        let checkSize = Int(max(8.0, Double(context.width) * scale))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: context.width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let color1 = colors.neutral.tone(20)
        let color2 = colors.neutral.tone(30)
        
        for y in stride(from: 0, to: context.height, by: checkSize) {
            for x in stride(from: 0, to: context.width, by: checkSize) {
                let isEven = ((x / checkSize) + (y / checkSize)) % 2 == 0
                cgContext.setFillColor(isEven ? color1 : color2)
                cgContext.fill(CGRect(x: x, y: y, width: checkSize, height: checkSize))
            }
        }
        
        return cgContext.makeImage()
    }
    
    // MARK: - Helper Functions
    
    /// Draw circuit node
    private static func drawCircuitNode(
        at point: CGPoint,
        in context: CGContext,
        gridSize: Int,
        rng: inout SeededRandomGenerator,
        colors: GeneratedPalette
    ) {
        // Draw connection lines
        let directions = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        
        for (dx, dy) in directions {
            if rng.random() < 0.5 {
                let endPoint = CGPoint(
                    x: point.x + CGFloat(dx * gridSize),
                    y: point.y + CGFloat(dy * gridSize)
                )
                
                context.move(to: point)
                context.addLine(to: endPoint)
            }
        }
        
        context.strokePath()
        
        // Draw node
        if rng.random() < 0.3 {
            context.setFillColor(colors.primary.tone(80))
            let nodeRect = CGRect(
                x: point.x - 3,
                y: point.y - 3,
                width: 6,
                height: 6
            )
            context.fillEllipse(in: nodeRect)
        }
    }
    
    /// Convert noise data to image
    private static func noiseToImage(
        data: [Float],
        width: Int,
        height: Int,
        colors: GeneratedPalette
    ) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        
        // Normalize noise values
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let range = maxValue - minValue
        
        for i in 0..<data.count {
            let normalized = (data[i] - minValue) / range
            let tone = Int(normalized * 100)
            let color = colors.neutral.tone(tone)
            
            if let components = color.components, components.count >= 3 {
                let offset = i * bytesPerPixel
                pixelData[offset] = UInt8(components[0] * 255)
                pixelData[offset + 1] = UInt8(components[1] * 255)
                pixelData[offset + 2] = UInt8(components[2] * 255)
                pixelData[offset + 3] = 255
            }
        }
        
        return createImage(from: pixelData, width: width, height: height)
    }
    
    /// Create CGImage from pixel data
    private static func createImage(from pixelData: [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let provider = CGDataProvider(data: NSData(bytes: pixelData, length: pixelData.count)) else {
            return nil
        }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

// MARK: - Noise Generators

/// Perlin noise generator
private class PerlinNoise {
    private let permutation: [Int]
    
    init(seed: UInt32) {
        var rng = SeededRandomGenerator(seed: seed)
        var perm = Array(0..<256)
        perm.shuffle(using: &rng)
        self.permutation = perm + perm // Duplicate for wrapping
    }
    
    func noise(x: Double, y: Double) -> Double {
        // Find unit square
        let X = Int(floor(x)) & 255
        let Y = Int(floor(y)) & 255
        
        // Find relative x,y in square
        let xf = x - floor(x)
        let yf = y - floor(y)
        
        // Fade curves
        let u = fade(xf)
        let v = fade(yf)
        
        // Hash coordinates of square corners
        let a = permutation[X] + Y
        let aa = permutation[a]
        let ab = permutation[a + 1]
        let b = permutation[X + 1] + Y
        let ba = permutation[b]
        let bb = permutation[b + 1]
        
        // Blend results from corners
        let res = lerp(
            v,
            lerp(u, grad(permutation[aa], xf, yf), grad(permutation[ba], xf - 1, yf)),
            lerp(u, grad(permutation[ab], xf, yf - 1), grad(permutation[bb], xf - 1, yf - 1))
        )
        
        return (res + 1.0) / 2.0 // Map to 0...1
    }
    
    func fractalNoise(x: Double, y: Double, octaves: Int, persistence: Double) -> Double {
        var total = 0.0
        var frequency = 1.0
        var amplitude = 1.0
        var maxValue = 0.0
        
        for _ in 0..<octaves {
            total += noise(x: x * frequency, y: y * frequency) * amplitude
            maxValue += amplitude
            amplitude *= persistence
            frequency *= 2
        }
        
        return total / maxValue
    }
    
    private func fade(_ t: Double) -> Double {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(_ t: Double, _ a: Double, _ b: Double) -> Double {
        return a + t * (b - a)
    }
    
    private func grad(_ hash: Int, _ x: Double, _ y: Double) -> Double {
        let h = hash & 3
        let u = h < 2 ? x : y
        let v = h < 2 ? y : x
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}

/// Random number generator with seed
private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt32) {
        self.state = UInt64(seed)
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    mutating func random() -> Double {
        return Double(next() >> 32) / Double(UInt32.max)
    }
}

// MARK: - Texture Blending

extension TextureEngine {
    
    /// Blend two textures together
    public static func blendTextures(
        _ texture1: CGImage,
        _ texture2: CGImage,
        mode: BlendMode,
        opacity: Double = 1.0
    ) -> CGImage? {
        let width = texture1.width
        let height = texture1.height
        
        guard texture2.width == width && texture2.height == height else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Draw base texture
        context.draw(texture1, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Apply blend mode and draw second texture
        context.setAlpha(CGFloat(opacity))
        context.setBlendMode(mode.cgBlendMode)
        context.draw(texture2, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    /// Supported blend modes
    public enum BlendMode {
        case normal
        case multiply
        case screen
        case overlay
        case softLight
        case hardLight
        
        var cgBlendMode: CGBlendMode {
            switch self {
            case .normal: return .normal
            case .multiply: return .multiply
            case .screen: return .screen
            case .overlay: return .overlay
            case .softLight: return .softLight
            case .hardLight: return .hardLight
            }
        }
    }
}