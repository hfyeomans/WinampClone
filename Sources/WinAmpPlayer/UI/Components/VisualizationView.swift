import SwiftUI
import MetalKit
import Accelerate

// MARK: - Visualization Mode
enum VisualizationMode: String, CaseIterable {
    case spectrum = "Spectrum Analyzer"
    case oscilloscope = "Oscilloscope"
}

// MARK: - VisualizationView
struct VisualizationView: View {
    @State private var mode: VisualizationMode = .spectrum
    @ObservedObject var audioEngine: AudioEngine
    
    var body: some View {
        VStack(spacing: 0) {
            // Visualization display
            MetalVisualizationView(mode: mode, audioEngine: audioEngine)
                .frame(height: 100)
                .background(Color.black)
                .border(Color(white: 0.2), width: 1)
            
            // Mode selector
            HStack(spacing: 4) {
                ForEach(VisualizationMode.allCases, id: \.self) { vizMode in
                    Button(action: {
                        mode = vizMode
                    }) {
                        Text(vizMode.rawValue)
                            .font(.system(size: 9))
                            .foregroundColor(mode == vizMode ? .black : Color(white: 0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .background(mode == vizMode ? Color(red: 0, green: 1, blue: 0.5) : Color(white: 0.2))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(2)
            .background(Color(white: 0.1))
        }
    }
}

// MARK: - Metal Visualization View
struct MetalVisualizationView: NSViewRepresentable {
    let mode: VisualizationMode
    @ObservedObject var audioEngine: AudioEngine
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        context.coordinator.renderer = VisualizationRenderer(
            metalView: mtkView,
            audioEngine: audioEngine
        )
        
        mtkView.delegate = context.coordinator
        
        return mtkView
    }
    
    func updateNSView(_ mtkView: MTKView, context: Context) {
        context.coordinator.renderer?.mode = mode
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: VisualizationRenderer?
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }
        
        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}

// MARK: - Uniforms Structure
struct Uniforms {
    var topColor: SIMD4<Float>
    var bottomColor: SIMD4<Float>
    var peakColor: SIMD4<Float>
    var gridColor: SIMD4<Float>
    var waveColor: SIMD4<Float>
    var time: Float
    var mode: UInt32
    var elementType: UInt32
}

// MARK: - Visualization Renderer
class VisualizationRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStates: [String: MTLRenderPipelineState] = [:]
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    
    private weak var audioEngine: AudioEngine?
    var mode: VisualizationMode = .spectrum
    
    // Spectrum analyzer properties
    private var spectrumBars: [Float] = Array(repeating: 0, count: 32)
    private var peakValues: [Float] = Array(repeating: 0, count: 32)
    private var peakDecay: [Float] = Array(repeating: 0, count: 32)
    private let peakDecayRate: Float = 0.05
    private let barCount = 32
    
    // Oscilloscope properties
    private var waveformBuffer: [Float] = Array(repeating: 0, count: 512)
    
    // Time for animation
    private var time: Float = 0
    
    // Colors (classic WinAmp style)
    private let barTopColor = SIMD4<Float>(0, 1, 0.5, 1)      // Bright green
    private let barBottomColor = SIMD4<Float>(0, 0.3, 0.15, 1) // Dark green
    private let peakColor = SIMD4<Float>(0, 1, 0.7, 1)        // Bright green peak
    private let gridColor = SIMD4<Float>(0.2, 0.2, 0.2, 0.5)  // Dark gray with transparency
    private let waveColor = SIMD4<Float>(0, 1, 0.5, 1)        // Bright green
    
    init?(metalView: MTKView, audioEngine: AudioEngine) {
        guard let device = metalView.device,
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.audioEngine = audioEngine
        
        super.init()
        
        setupPipeline()
        setupBuffers()
    }
    
    private func setupPipeline() {
        // Load the Metal shader library
        guard let library = loadMetalLibrary() else {
            print("Failed to load Metal library")
            return
        }
        
        // Create pipeline states for different shader combinations
        let shaderPairs = [
            ("main", "simpleVertex", "spectrumBarFragment"),
            ("peak", "simpleVertex", "peakFragment"),
            ("grid", "simpleVertex", "gridFragment"),
            ("wave", "simpleVertex", "waveformFragment")
        ]
        
        for (name, vertexName, fragmentName) in shaderPairs {
            guard let vertexFunction = library.makeFunction(name: vertexName),
                  let fragmentFunction = library.makeFunction(name: fragmentName) else {
                print("Failed to load shader functions: \(vertexName), \(fragmentName)")
                continue
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            // Enable blending for smooth visuals
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            do {
                pipelineStates[name] = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state for \(name): \(error)")
            }
        }
    }
    
    private func loadMetalLibrary() -> MTLLibrary? {
        // First try to load from the default library
        if let library = device.makeDefaultLibrary() {
            return library
        }
        
        // Try to load from the Shaders directory
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "Visualization", withExtension: "metal", subdirectory: "Shaders") {
            do {
                let source = try String(contentsOf: url)
                return try device.makeLibrary(source: source, options: nil)
            } catch {
                print("Failed to load shader source: \(error)")
            }
        }
        
        // Fallback: compile shader source inline
        do {
            return try device.makeLibrary(source: VisualizationRenderer.metalShaderSource, options: nil)
        } catch {
            print("Failed to compile inline shaders: \(error)")
            return nil
        }
    }
    
    private func setupBuffers() {
        // Create vertex buffer with enough space for all visualization elements
        let maxVertices = 1024 * 6 // 6 vertices per quad, plenty of quads
        vertexBuffer = device.makeBuffer(length: maxVertices * MemoryLayout<SIMD2<Float>>.stride,
                                        options: .storageModeShared)
        
        // Uniform buffer for colors and other parameters
        uniformBuffer = device.makeBuffer(length: 256,
                                        options: .storageModeShared)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view resize if needed
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        // Update time for animations
        time += 1.0 / 60.0
        
        // Update audio data
        updateAudioData()
        
        // Clear background
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        switch mode {
        case .spectrum:
            drawSpectrum(encoder: encoder, viewSize: view.drawableSize)
        case .oscilloscope:
            drawOscilloscope(encoder: encoder, viewSize: view.drawableSize)
        }
        
        encoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    private func updateAudioData() {
        guard let audioEngine = audioEngine else { return }
        
        // Get frequency data for spectrum analyzer
        let frequencies = audioEngine.getFrequencyData()
        if !frequencies.isEmpty {
            // Group frequencies into bars
            let freqPerBar = frequencies.count / barCount
            for i in 0..<barCount {
                let startIdx = i * freqPerBar
                let endIdx = min((i + 1) * freqPerBar, frequencies.count)
                
                // Average the frequencies for this bar
                var sum: Float = 0
                for j in startIdx..<endIdx {
                    sum += frequencies[j]
                }
                let avg = sum / Float(endIdx - startIdx)
                
                // Apply logarithmic scaling and smoothing
                let scaled = log10(1 + avg * 9) // log scale for better visualization
                spectrumBars[i] = spectrumBars[i] * 0.7 + scaled * 0.3 // Smooth transitions
                
                // Update peaks
                if spectrumBars[i] > peakValues[i] {
                    peakValues[i] = spectrumBars[i]
                    peakDecay[i] = 0
                } else {
                    peakDecay[i] += peakDecayRate
                    peakValues[i] = max(0, peakValues[i] - peakDecay[i] * 0.02)
                }
            }
        }
        
        // Get waveform data for oscilloscope
        let waveform = audioEngine.getWaveformData()
        if !waveform.isEmpty {
            let samples = min(waveform.count, waveformBuffer.count)
            for i in 0..<samples {
                waveformBuffer[i] = waveform[i]
            }
        }
    }
    
    private func drawSpectrum(encoder: MTLRenderCommandEncoder, viewSize: CGSize) {
        guard let vertexBuffer = vertexBuffer else { return }
        
        let barWidth = Float(viewSize.width) / Float(barCount + 1) * 0.8
        let barSpacing = Float(viewSize.width) / Float(barCount + 1)
        let maxHeight = Float(viewSize.height) * 0.9
        
        // Draw grid lines first
        if let gridPipeline = pipelineStates["grid"] {
            var gridVertices: [SIMD2<Float>] = []
            
            // Horizontal grid lines
            for i in 0...4 {
                let y = 0.05 + Float(i) * 0.9 / 4.0
                gridVertices.append(contentsOf: createLineQuad(
                    from: SIMD2<Float>(0, y),
                    to: SIMD2<Float>(1, y),
                    thickness: 0.002
                ))
            }
            
            // Vertical grid lines
            for i in 0...barCount {
                let x = Float(i) / Float(barCount)
                gridVertices.append(contentsOf: createLineQuad(
                    from: SIMD2<Float>(x, 0.05),
                    to: SIMD2<Float>(x, 0.95),
                    thickness: 0.001
                ))
            }
            
            updateVertexBuffer(vertices: gridVertices)
            encoder.setRenderPipelineState(gridPipeline)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: gridVertices.count)
        }
        
        // Draw spectrum bars
        if let barPipeline = pipelineStates["main"] {
            var barVertices: [SIMD2<Float>] = []
            
            for i in 0..<barCount {
                let x = Float(i) * barSpacing + barSpacing * 0.5
                let height = spectrumBars[i] * maxHeight
                let normalizedX = x / Float(viewSize.width)
                let normalizedHeight = height / Float(viewSize.height)
                
                // Bar quad
                let left = normalizedX - barWidth / Float(viewSize.width) * 0.5
                let right = normalizedX + barWidth / Float(viewSize.width) * 0.5
                let bottom: Float = 0.05
                let top = bottom + normalizedHeight
                
                barVertices.append(contentsOf: [
                    SIMD2<Float>(left, bottom),
                    SIMD2<Float>(right, bottom),
                    SIMD2<Float>(left, top),
                    SIMD2<Float>(right, bottom),
                    SIMD2<Float>(right, top),
                    SIMD2<Float>(left, top)
                ])
            }
            
            updateVertexBuffer(vertices: barVertices)
            encoder.setRenderPipelineState(barPipeline)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: barVertices.count)
        }
        
        // Draw peak indicators
        if let peakPipeline = pipelineStates["peak"] {
            var peakVertices: [SIMD2<Float>] = []
            
            for i in 0..<barCount {
                if peakValues[i] > 0.01 {
                    let x = Float(i) * barSpacing + barSpacing * 0.5
                    let normalizedX = x / Float(viewSize.width)
                    let peakY = 0.05 + peakValues[i] * maxHeight / Float(viewSize.height)
                    let peakHeight: Float = 0.015
                    
                    let left = normalizedX - barWidth / Float(viewSize.width) * 0.5
                    let right = normalizedX + barWidth / Float(viewSize.width) * 0.5
                    
                    peakVertices.append(contentsOf: [
                        SIMD2<Float>(left, peakY),
                        SIMD2<Float>(right, peakY),
                        SIMD2<Float>(left, peakY + peakHeight),
                        SIMD2<Float>(right, peakY),
                        SIMD2<Float>(right, peakY + peakHeight),
                        SIMD2<Float>(left, peakY + peakHeight)
                    ])
                }
            }
            
            if !peakVertices.isEmpty {
                updateVertexBuffer(vertices: peakVertices)
                encoder.setRenderPipelineState(peakPipeline)
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: peakVertices.count)
            }
        }
    }
    
    private func drawOscilloscope(encoder: MTLRenderCommandEncoder, viewSize: CGSize) {
        guard let vertexBuffer = vertexBuffer else { return }
        
        // Draw grid first
        if let gridPipeline = pipelineStates["grid"] {
            var gridVertices: [SIMD2<Float>] = []
            
            // Horizontal grid lines
            for i in 0...4 {
                let y = 0.05 + Float(i) * 0.9 / 4.0
                gridVertices.append(contentsOf: createLineQuad(
                    from: SIMD2<Float>(0.05, y),
                    to: SIMD2<Float>(0.95, y),
                    thickness: 0.002
                ))
            }
            
            // Vertical grid lines
            for i in 0...8 {
                let x = 0.05 + Float(i) * 0.9 / 8.0
                gridVertices.append(contentsOf: createLineQuad(
                    from: SIMD2<Float>(x, 0.05),
                    to: SIMD2<Float>(x, 0.95),
                    thickness: 0.002
                ))
            }
            
            updateVertexBuffer(vertices: gridVertices)
            encoder.setRenderPipelineState(gridPipeline)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: gridVertices.count)
        }
        
        // Draw waveform
        if let wavePipeline = pipelineStates["wave"] {
            var waveVertices: [SIMD2<Float>] = []
            
            let sampleCount = waveformBuffer.count
            for i in 0..<(sampleCount - 1) {
                let x1 = 0.05 + Float(i) / Float(sampleCount - 1) * 0.9
                let x2 = 0.05 + Float(i + 1) / Float(sampleCount - 1) * 0.9
                let y1 = 0.5 + waveformBuffer[i] * 0.4 // Center at 0.5, scale to fit
                let y2 = 0.5 + waveformBuffer[i + 1] * 0.4
                
                waveVertices.append(contentsOf: createLineQuad(
                    from: SIMD2<Float>(x1, y1),
                    to: SIMD2<Float>(x2, y2),
                    thickness: 0.003
                ))
            }
            
            if !waveVertices.isEmpty {
                updateVertexBuffer(vertices: waveVertices)
                encoder.setRenderPipelineState(wavePipeline)
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: waveVertices.count)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLineQuad(from start: SIMD2<Float>, to end: SIMD2<Float>, thickness: Float) -> [SIMD2<Float>] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = sqrt(dx * dx + dy * dy)
        
        guard len > 0 else { return [] }
        
        let nx = -dy / len * thickness
        let ny = dx / len * thickness
        
        return [
            SIMD2<Float>(start.x - nx, start.y - ny),
            SIMD2<Float>(start.x + nx, start.y + ny),
            SIMD2<Float>(end.x - nx, end.y - ny),
            SIMD2<Float>(start.x + nx, start.y + ny),
            SIMD2<Float>(end.x + nx, end.y + ny),
            SIMD2<Float>(end.x - nx, end.y - ny)
        ]
    }
    
    private func updateVertexBuffer(vertices: [SIMD2<Float>]) {
        guard let vertexBuffer = vertexBuffer else { return }
        
        let vertexData = vertexBuffer.contents()
        vertices.withUnsafeBufferPointer { buffer in
            vertexData.copyMemory(from: buffer.baseAddress!,
                                byteCount: buffer.count * MemoryLayout<SIMD2<Float>>.stride)
        }
    }
}

// MARK: - Metal Shaders
extension VisualizationRenderer {
    static let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

// Simple vertex shader
vertex VertexOut simpleVertex(uint vertexID [[vertex_id]],
                             constant float2 *vertices [[buffer(0)]]) {
    VertexOut out;
    float2 position = vertices[vertexID];
    out.position = float4(position.x * 2.0 - 1.0, 1.0 - position.y * 2.0, 0.0, 1.0);
    out.texCoord = position;
    out.color = float4(1.0);
    return out;
}

// Spectrum bar fragment shader
fragment float4 spectrumBarFragment(VertexOut in [[stage_in]]) {
    float3 bottomColor = float3(0.0, 0.3, 0.15);
    float3 topColor = float3(0.0, 1.0, 0.5);
    
    float gradient = in.texCoord.y;
    float3 color = mix(bottomColor, topColor, smoothstep(0.0, 1.0, gradient));
    
    float horizontalShade = 1.0 - abs(in.texCoord.x - 0.5) * 0.4;
    color *= horizontalShade;
    
    float topHighlight = smoothstep(0.8, 1.0, gradient);
    color += topHighlight * float3(0.0, 0.3, 0.15);
    
    return float4(color, 1.0);
}

// Peak indicator fragment shader
fragment float4 peakFragment(VertexOut in [[stage_in]]) {
    float3 peakColor = float3(0.0, 1.0, 0.7);
    
    float2 center = in.texCoord - 0.5;
    float dist = length(center);
    float glow = 1.0 - smoothstep(0.0, 0.5, dist);
    
    float3 color = peakColor * (1.0 + glow * 0.5);
    
    return float4(color, 1.0);
}

// Grid line fragment shader
fragment float4 gridFragment(VertexOut in [[stage_in]]) {
    float3 gridColor = float3(0.2, 0.2, 0.2);
    float alpha = 0.5;
    
    return float4(gridColor, alpha);
}

// Waveform fragment shader
fragment float4 waveformFragment(VertexOut in [[stage_in]]) {
    float3 waveColor = float3(0.0, 1.0, 0.5);
    float glow = 1.2;
    
    return float4(waveColor * glow, 1.0);
}
"""
}