//
//  TextureFilters.swift
//  WinAmpPlayer
//
//  Created on 2025-07-27.
//  Texture filtering and effects for skin generation
//

import Foundation
import CoreGraphics
import CoreImage

/// Texture filtering and effects
public class TextureFilters {
    
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    /// Apply filter to texture
    public static func applyFilter(
        to image: CGImage,
        filter: FilterType,
        parameters: FilterParameters = FilterParameters()
    ) -> CGImage? {
        
        let ciImage = CIImage(cgImage: image)
        
        let filteredImage: CIImage?
        
        switch filter {
        case .blur:
            filteredImage = applyBlur(to: ciImage, radius: parameters.radius ?? 10.0)
            
        case .sharpen:
            filteredImage = applySharpen(to: ciImage, intensity: parameters.intensity ?? 0.5)
            
        case .emboss:
            filteredImage = applyEmboss(to: ciImage, height: parameters.height ?? 2.0)
            
        case .dropShadow:
            filteredImage = applyDropShadow(
                to: ciImage,
                offset: parameters.offset ?? CGSize(width: 3, height: -3),
                radius: parameters.radius ?? 5.0,
                color: parameters.color ?? .black
            )
            
        case .glow:
            filteredImage = applyGlow(
                to: ciImage,
                radius: parameters.radius ?? 10.0,
                intensity: parameters.intensity ?? 1.0,
                color: parameters.color ?? .white
            )
            
        case .outline:
            filteredImage = applyOutline(
                to: ciImage,
                thickness: parameters.thickness ?? 2.0,
                color: parameters.color ?? .black
            )
            
        case .noise:
            filteredImage = applyNoise(
                to: ciImage,
                intensity: parameters.intensity ?? 0.1
            )
            
        case .pixelate:
            filteredImage = applyPixelate(
                to: ciImage,
                scale: parameters.scale ?? 8.0
            )
        }
        
        guard let result = filteredImage else { return nil }
        
        return ciContext.createCGImage(
            result,
            from: result.extent
        )
    }
    
    /// Filter types
    public enum FilterType {
        case blur
        case sharpen
        case emboss
        case dropShadow
        case glow
        case outline
        case noise
        case pixelate
    }
    
    /// Filter parameters
    public struct FilterParameters {
        public var radius: Double?
        public var intensity: Double?
        public var height: Double?
        public var offset: CGSize?
        public var color: CGColor?
        public var thickness: Double?
        public var scale: Double?
        
        public init(
            radius: Double? = nil,
            intensity: Double? = nil,
            height: Double? = nil,
            offset: CGSize? = nil,
            color: CGColor? = nil,
            thickness: Double? = nil,
            scale: Double? = nil
        ) {
            self.radius = radius
            self.intensity = intensity
            self.height = height
            self.offset = offset
            self.color = color
            self.thickness = thickness
            self.scale = scale
        }
    }
    
    // MARK: - Filter Implementations
    
    /// Apply Gaussian blur
    private static func applyBlur(to image: CIImage, radius: Double) -> CIImage? {
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        return filter?.outputImage
    }
    
    /// Apply sharpen filter
    private static func applySharpen(to image: CIImage, intensity: Double) -> CIImage? {
        let filter = CIFilter(name: "CISharpenLuminance")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(intensity, forKey: kCIInputSharpnessKey)
        return filter?.outputImage
    }
    
    /// Apply emboss effect
    private static func applyEmboss(to image: CIImage, height: Double) -> CIImage? {
        let filter = CIFilter(name: "CIHeightFieldFromMask")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(height, forKey: "inputRadius")
        
        // Convert height field to shaded material
        if let heightField = filter?.outputImage {
            let shadedFilter = CIFilter(name: "CIShadedMaterial")
            shadedFilter?.setValue(heightField, forKey: kCIInputImageKey)
            shadedFilter?.setValue(1.0, forKey: "inputScale")
            return shadedFilter?.outputImage
        }
        
        return nil
    }
    
    /// Apply drop shadow
    private static func applyDropShadow(
        to image: CIImage,
        offset: CGSize,
        radius: Double,
        color: CGColor
    ) -> CIImage? {
        // Create shadow
        let shadowFilter = CIFilter(name: "CIGaussianBlur")
        shadowFilter?.setValue(image, forKey: kCIInputImageKey)
        shadowFilter?.setValue(radius, forKey: kCIInputRadiusKey)
        
        guard var shadow = shadowFilter?.outputImage else { return nil }
        
        // Colorize shadow
        let colorFilter = CIFilter(name: "CIColorMatrix")
        colorFilter?.setValue(shadow, forKey: kCIInputImageKey)
        
        if let components = color.components, components.count >= 3 {
            let r = components[0]
            let g = components[1]
            let b = components[2]
            let a = components.count > 3 ? components[3] : 1.0
            
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
            colorFilter?.setValue(CIVector(x: r, y: g, z: b, w: a), forKey: "inputBiasVector")
        }
        
        shadow = colorFilter?.outputImage ?? shadow
        
        // Offset shadow
        shadow = shadow.transformed(by: CGAffineTransform(
            translationX: offset.width,
            y: offset.height
        ))
        
        // Composite shadow under original
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")
        compositeFilter?.setValue(image, forKey: kCIInputImageKey)
        compositeFilter?.setValue(shadow, forKey: kCIInputBackgroundImageKey)
        
        return compositeFilter?.outputImage
    }
    
    /// Apply glow effect
    private static func applyGlow(
        to image: CIImage,
        radius: Double,
        intensity: Double,
        color: CGColor
    ) -> CIImage? {
        // Create glow
        let glowFilter = CIFilter(name: "CIGaussianBlur")
        glowFilter?.setValue(image, forKey: kCIInputImageKey)
        glowFilter?.setValue(radius, forKey: kCIInputRadiusKey)
        
        guard var glow = glowFilter?.outputImage else { return nil }
        
        // Colorize glow
        let colorFilter = CIFilter(name: "CIColorMatrix")
        colorFilter?.setValue(glow, forKey: kCIInputImageKey)
        
        if let components = color.components, components.count >= 3 {
            let r = components[0] * intensity
            let g = components[1] * intensity
            let b = components[2] * intensity
            
            colorFilter?.setValue(CIVector(x: CGFloat(r), y: 0, z: 0, w: 0), forKey: "inputRVector")
            colorFilter?.setValue(CIVector(x: 0, y: CGFloat(g), z: 0, w: 0), forKey: "inputGVector")
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: CGFloat(b), w: 0), forKey: "inputBVector")
        }
        
        glow = colorFilter?.outputImage ?? glow
        
        // Composite glow over original
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")
        compositeFilter?.setValue(glow, forKey: kCIInputBackgroundImageKey)
        compositeFilter?.setValue(image, forKey: kCIInputImageKey)
        
        return compositeFilter?.outputImage
    }
    
    /// Apply outline effect
    private static func applyOutline(
        to image: CIImage,
        thickness: Double,
        color: CGColor
    ) -> CIImage? {
        // Edge detection
        let edgeFilter = CIFilter(name: "CIEdges")
        edgeFilter?.setValue(image, forKey: kCIInputImageKey)
        edgeFilter?.setValue(thickness, forKey: kCIInputIntensityKey)
        
        guard var edges = edgeFilter?.outputImage else { return nil }
        
        // Colorize edges
        let colorFilter = CIFilter(name: "CIColorMatrix")
        colorFilter?.setValue(edges, forKey: kCIInputImageKey)
        
        if let components = color.components, components.count >= 3 {
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
            colorFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
            colorFilter?.setValue(CIVector(x: components[0], y: components[1], z: components[2], w: 1), forKey: "inputBiasVector")
        }
        
        edges = colorFilter?.outputImage ?? edges
        
        // Composite edges over original
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")
        compositeFilter?.setValue(edges, forKey: kCIInputImageKey)
        compositeFilter?.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return compositeFilter?.outputImage
    }
    
    /// Apply noise
    private static func applyNoise(to image: CIImage, intensity: Double) -> CIImage? {
        let noiseFilter = CIFilter(name: "CIRandomGenerator")
        guard let noise = noiseFilter?.outputImage else { return nil }
        
        // Crop noise to image size
        let croppedNoise = noise.cropped(to: image.extent)
        
        // Blend noise with image
        let blendFilter = CIFilter(name: "CIColorDodgeBlendMode")
        blendFilter?.setValue(image, forKey: kCIInputImageKey)
        blendFilter?.setValue(croppedNoise, forKey: kCIInputBackgroundImageKey)
        
        guard let blended = blendFilter?.outputImage else { return nil }
        
        // Mix based on intensity
        let mixFilter = CIFilter(name: "CIColorMatrix")
        mixFilter?.setValue(blended, forKey: kCIInputImageKey)
        
        let factor = CGFloat(1.0 - intensity)
        mixFilter?.setValue(CIVector(x: factor, y: 0, z: 0, w: 0), forKey: "inputRVector")
        mixFilter?.setValue(CIVector(x: 0, y: factor, z: 0, w: 0), forKey: "inputGVector")
        mixFilter?.setValue(CIVector(x: 0, y: 0, z: factor, w: 0), forKey: "inputBVector")
        mixFilter?.setValue(CIVector(x: CGFloat(intensity), y: CGFloat(intensity), z: CGFloat(intensity), w: 1), forKey: "inputBiasVector")
        
        return mixFilter?.outputImage
    }
    
    /// Apply pixelation
    private static func applyPixelate(to image: CIImage, scale: Double) -> CIImage? {
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        return filter?.outputImage
    }
}

// MARK: - Seamless Tiling

extension TextureFilters {
    
    /// Make texture seamlessly tileable
    public static func makeSeamless(
        _ image: CGImage,
        blendWidth: Int = 50
    ) -> CGImage? {
        let width = image.width
        let height = image.height
        
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
        
        // Draw original image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Blend edges
        blendEdges(in: context, width: width, height: height, blendWidth: blendWidth)
        
        return context.makeImage()
    }
    
    private static func blendEdges(
        in context: CGContext,
        width: Int,
        height: Int,
        blendWidth: Int
    ) {
        guard let image = context.makeImage() else { return }
        
        // Horizontal blending
        for x in 0..<blendWidth {
            let alpha = CGFloat(x) / CGFloat(blendWidth)
            
            // Top edge
            let topRect = CGRect(x: 0, y: 0, width: width, height: 1)
            let bottomSourceRect = CGRect(x: 0, y: height - 1, width: width, height: 1)
            
            context.saveGState()
            context.setAlpha(1.0 - alpha)
            context.draw(image.cropping(to: bottomSourceRect)!, in: topRect)
            context.restoreGState()
            
            // Bottom edge
            let bottomRect = CGRect(x: 0, y: height - 1, width: width, height: 1)
            let topSourceRect = CGRect(x: 0, y: 0, width: width, height: 1)
            
            context.saveGState()
            context.setAlpha(1.0 - alpha)
            context.draw(image.cropping(to: topSourceRect)!, in: bottomRect)
            context.restoreGState()
        }
        
        // Vertical blending
        for y in 0..<blendWidth {
            let alpha = CGFloat(y) / CGFloat(blendWidth)
            
            // Left edge
            let leftRect = CGRect(x: 0, y: 0, width: 1, height: height)
            let rightSourceRect = CGRect(x: width - 1, y: 0, width: 1, height: height)
            
            context.saveGState()
            context.setAlpha(1.0 - alpha)
            context.draw(image.cropping(to: rightSourceRect)!, in: leftRect)
            context.restoreGState()
            
            // Right edge
            let rightRect = CGRect(x: width - 1, y: 0, width: 1, height: height)
            let leftSourceRect = CGRect(x: 0, y: 0, width: 1, height: height)
            
            context.saveGState()
            context.setAlpha(1.0 - alpha)
            context.draw(image.cropping(to: leftSourceRect)!, in: rightRect)
            context.restoreGState()
        }
    }
}

// MARK: - Texture Operations

extension TextureFilters {
    
    /// Apply color mapping to texture
    public static func applyColorMap(
        to image: CGImage,
        palette: GeneratedPalette,
        mapping: ColorMapping = .brightness
    ) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        
        // Convert to grayscale if needed
        let grayscale: CIImage
        if mapping == .brightness {
            let filter = CIFilter(name: "CIColorMonochrome")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(CIColor.gray, forKey: "inputColor")
            filter?.setValue(1.0, forKey: "inputIntensity")
            grayscale = filter?.outputImage ?? ciImage
        } else {
            grayscale = ciImage
        }
        
        // Map to palette colors
        let colorFilter = CIFilter(name: "CIFalseColor")
        colorFilter?.setValue(grayscale, forKey: kCIInputImageKey)
        colorFilter?.setValue(CIColor(cgColor: palette.primary.tone(0)), forKey: "inputColor0")
        colorFilter?.setValue(CIColor(cgColor: palette.primary.tone(100)), forKey: "inputColor1")
        
        guard let result = colorFilter?.outputImage else { return nil }
        
        return ciContext.createCGImage(result, from: result.extent)
    }
    
    /// Color mapping modes
    public enum ColorMapping {
        case brightness
        case hue
        case saturation
    }
}