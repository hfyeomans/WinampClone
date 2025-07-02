#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures
struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

struct Uniforms {
    float4 topColor;
    float4 bottomColor;
    float4 peakColor;
    float4 gridColor;
    float4 waveColor;
    float time;
    uint mode; // 0 = spectrum, 1 = oscilloscope
    uint elementType; // 0 = bar, 1 = peak, 2 = grid, 3 = wave
};

// MARK: - Vertex Shader
vertex VertexOut visualizationVertex(uint vertexID [[vertex_id]],
                                    constant float2 *vertices [[buffer(0)]],
                                    constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float2 position = vertices[vertexID];
    
    // Convert from normalized coordinates to clip space
    out.position = float4(position.x * 2.0 - 1.0, 1.0 - position.y * 2.0, 0.0, 1.0);
    out.texCoord = position;
    
    // Set color based on element type and position
    if (uniforms.elementType == 0) { // Spectrum bar
        // Gradient from bottom to top
        float gradient = position.y;
        out.color = mix(uniforms.bottomColor, uniforms.topColor, gradient);
    } else if (uniforms.elementType == 1) { // Peak indicator
        out.color = uniforms.peakColor;
    } else if (uniforms.elementType == 2) { // Grid
        out.color = uniforms.gridColor;
    } else if (uniforms.elementType == 3) { // Waveform
        out.color = uniforms.waveColor;
    }
    
    return out;
}

// MARK: - Fragment Shader
fragment float4 visualizationFragment(VertexOut in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(1)]]) {
    float4 color = in.color;
    
    // Add subtle effects based on element type
    if (uniforms.elementType == 0) { // Spectrum bar
        // Add slight horizontal gradient for depth
        float horizontalFade = 1.0 - abs(in.texCoord.x - 0.5) * 0.3;
        color.rgb *= horizontalFade;
        
        // Add subtle glow at the top
        float topGlow = smoothstep(0.7, 1.0, in.texCoord.y);
        color.rgb += topGlow * 0.2;
    } else if (uniforms.elementType == 1) { // Peak indicator
        // Add pulsing effect
        float pulse = sin(uniforms.time * 3.0) * 0.1 + 0.9;
        color.rgb *= pulse;
        
        // Add center highlight
        float centerDist = length(in.texCoord - 0.5);
        float highlight = 1.0 - smoothstep(0.0, 0.5, centerDist);
        color.rgb += highlight * 0.3;
    } else if (uniforms.elementType == 3) { // Waveform
        // Add slight glow effect
        float glow = 1.0 + sin(uniforms.time * 2.0) * 0.05;
        color.rgb *= glow;
    }
    
    return color;
}

// MARK: - Alternative Shaders for Better Performance

// Simple vertex shader without color calculation
vertex VertexOut simpleVertex(uint vertexID [[vertex_id]],
                             constant float2 *vertices [[buffer(0)]]) {
    VertexOut out;
    float2 position = vertices[vertexID];
    out.position = float4(position.x * 2.0 - 1.0, 1.0 - position.y * 2.0, 0.0, 1.0);
    out.texCoord = position;
    out.color = float4(1.0);
    return out;
}

// Spectrum bar fragment shader with classic WinAmp gradient
fragment float4 spectrumBarFragment(VertexOut in [[stage_in]]) {
    // Classic WinAmp green gradient
    float3 bottomColor = float3(0.0, 0.3, 0.15); // Dark green
    float3 topColor = float3(0.0, 1.0, 0.5);     // Bright green
    
    // Vertical gradient
    float gradient = in.texCoord.y;
    float3 color = mix(bottomColor, topColor, smoothstep(0.0, 1.0, gradient));
    
    // Add horizontal shading for 3D effect
    float horizontalShade = 1.0 - abs(in.texCoord.x - 0.5) * 0.4;
    color *= horizontalShade;
    
    // Add top highlight
    float topHighlight = smoothstep(0.8, 1.0, gradient);
    color += topHighlight * float3(0.0, 0.3, 0.15);
    
    return float4(color, 1.0);
}

// Peak indicator fragment shader
fragment float4 peakFragment(VertexOut in [[stage_in]]) {
    // Bright green with glow
    float3 peakColor = float3(0.0, 1.0, 0.7);
    
    // Center glow effect
    float2 center = in.texCoord - 0.5;
    float dist = length(center);
    float glow = 1.0 - smoothstep(0.0, 0.5, dist);
    
    float3 color = peakColor * (1.0 + glow * 0.5);
    
    return float4(color, 1.0);
}

// Grid line fragment shader
fragment float4 gridFragment(VertexOut in [[stage_in]]) {
    // Dark gray grid
    float3 gridColor = float3(0.2, 0.2, 0.2);
    
    // Slight fade at edges
    float alpha = 0.5;
    
    return float4(gridColor, alpha);
}

// Oscilloscope waveform fragment shader
fragment float4 waveformFragment(VertexOut in [[stage_in]]) {
    // Bright green waveform
    float3 waveColor = float3(0.0, 1.0, 0.5);
    
    // Add glow effect based on position
    float glow = 1.2;
    
    return float4(waveColor * glow, 1.0);
}

// MARK: - Compute Shaders for Advanced Effects

kernel void updateSpectrumBars(texture2d<float, access::read> input [[texture(0)]],
                              texture2d<float, access::write> output [[texture(1)]],
                              constant float *audioData [[buffer(0)]],
                              constant float &smoothing [[buffer(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
    
    // Read previous value for smoothing
    float4 previous = input.read(gid);
    
    // Get new audio value
    uint barIndex = gid.x;
    float newValue = audioData[barIndex];
    
    // Apply smoothing
    float smoothed = mix(previous.r, newValue, smoothing);
    
    // Write result
    output.write(float4(smoothed, smoothed, smoothed, 1.0), gid);
}