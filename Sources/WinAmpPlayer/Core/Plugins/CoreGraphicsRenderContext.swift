import Foundation
import CoreGraphics
import AppKit

/// Core Graphics implementation of the visualization render context
public final class CoreGraphicsRenderContext: VisualizationRenderContext {
    private let cgContext: CGContext
    public let size: CGSize
    public let scale: CGFloat
    
    public init(cgContext: CGContext, size: CGSize, scale: CGFloat = 1.0) {
        self.cgContext = cgContext
        self.size = size
        self.scale = scale
        
        // Setup initial context state
        setupContext()
    }
    
    private func setupContext() {
        // Flip coordinate system to match standard top-left origin
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        
        // Apply scale factor for Retina displays
        if scale != 1.0 {
            cgContext.scaleBy(x: scale, y: scale)
        }
        
        // Set default line cap and join
        cgContext.setLineCap(.round)
        cgContext.setLineJoin(.round)
        
        // Enable antialiasing
        cgContext.setAllowsAntialiasing(true)
        cgContext.setShouldAntialias(true)
    }
    
    // MARK: - VisualizationRenderContext Implementation
    
    public func drawPath(_ path: CGPath, color: CGColor, lineWidth: CGFloat) {
        cgContext.saveGState()
        cgContext.setStrokeColor(color)
        cgContext.setLineWidth(lineWidth)
        cgContext.addPath(path)
        cgContext.strokePath()
        cgContext.restoreGState()
    }
    
    public func fillPath(_ path: CGPath, color: CGColor) {
        cgContext.saveGState()
        cgContext.setFillColor(color)
        cgContext.addPath(path)
        cgContext.fillPath()
        cgContext.restoreGState()
    }
    
    public func drawText(_ text: String, at point: CGPoint, attributes: [NSAttributedString.Key: Any]) {
        cgContext.saveGState()
        
        // Temporarily flip back for text rendering
        cgContext.scaleBy(x: 1.0, y: -1.0)
        cgContext.translateBy(x: 0, y: -size.height)
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Adjust position for flipped coordinates
        cgContext.textPosition = CGPoint(x: point.x, y: size.height - point.y)
        CTLineDraw(line, cgContext)
        
        cgContext.restoreGState()
    }
    
    public func drawImage(_ image: CGImage, in rect: CGRect) {
        cgContext.saveGState()
        cgContext.draw(image, in: rect)
        cgContext.restoreGState()
    }
    
    public func setBackgroundColor(_ color: CGColor) {
        cgContext.saveGState()
        cgContext.setFillColor(color)
        cgContext.fill(CGRect(origin: .zero, size: size))
        cgContext.restoreGState()
    }
    
    public func pushState() {
        cgContext.saveGState()
    }
    
    public func popState() {
        cgContext.restoreGState()
    }
    
    public func applyTransform(_ transform: CGAffineTransform) {
        cgContext.concatenate(transform)
    }
}

/// Extension to create a render context from an NSView
public extension NSView {
    func createVisualizationRenderContext() -> VisualizationRenderContext? {
        guard let context = NSGraphicsContext.current?.cgContext else { return nil }
        return CoreGraphicsRenderContext(
            cgContext: context,
            size: bounds.size,
            scale: window?.backingScaleFactor ?? 1.0
        )
    }
}

/// Visualization view that hosts plugins
public class VisualizationView: NSView {
    private var displayLink: CVDisplayLink?
    private var audioDataBuffer: VisualizationAudioData?
    private let dataQueue = DispatchQueue(label: "com.winamp.visualization.data", qos: .userInteractive)
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDisplayLink()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDisplayLink()
    }
    
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    private func setupDisplayLink() {
        // Create display link for smooth animation
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let displayLink = displayLink else { return }
        
        // Set callback
        CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, context) -> CVReturn in
            let view = Unmanaged<VisualizationView>.fromOpaque(context!).takeUnretainedValue()
            
            DispatchQueue.main.async {
                view.setNeedsDisplay(view.bounds)
            }
            
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        
        // Start display link
        CVDisplayLinkStart(displayLink)
    }
    
    /// Update audio data for visualization
    public func updateAudioData(_ audioData: VisualizationAudioData) {
        dataQueue.async { [weak self] in
            self?.audioDataBuffer = audioData
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = createVisualizationRenderContext() else { return }
        
        // Get current audio data
        let audioData = dataQueue.sync { audioDataBuffer } ?? VisualizationAudioData(
            samples: [],
            frequencyData: nil,
            sampleRate: 44100,
            channelCount: 2,
            timestamp: CACurrentMediaTime(),
            beatInfo: nil
        )
        
        // Process visualization
        VisualizationPluginManager.shared.processAudioData(audioData, context: context)
    }
    
    public override var isOpaque: Bool {
        return true
    }
    
    public override var wantsDefaultClipping: Bool {
        return false
    }
}

/// Helper to create audio data from an audio buffer
public extension VisualizationAudioData {
    init(from buffer: AVAudioPCMBuffer, fft: [Float]? = nil, beatInfo: BeatInfo? = nil) {
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        self.init(
            samples: samples,
            frequencyData: fft,
            sampleRate: buffer.format.sampleRate,
            channelCount: Int(buffer.format.channelCount),
            timestamp: CACurrentMediaTime(),
            beatInfo: beatInfo
        )
    }
}