---
---

# GPU Engineer (Photo/Video Editor — iOS + Android)

Cross-platform GPU programming depth role for Metal (iOS), AGSL/Vulkan/OpenGL ES (Android), shader authoring, texture management, memory optimization, and real-time rendering pipelines. Extends `mobile-engineer.md` and `image-processing-engineer.md` with GPU-specific expertise across both platforms.

## Skills
- **Metal (iOS):** MSL compute/fragment kernels, stitchable CIKernels, MTKView display, MPS, command buffer patterns, MTLHeap, triple buffering, EDR/HDR
- **AGSL (Android 13+):** RuntimeShader, Compose graphicsLayer integration, RenderEffect chaining, ShaderBrush, half-precision types
- **OpenGL ES 3.x (Android):** Fragment shaders, FBO ping-pong, ES 3.1 compute, GLSurfaceView, texture upload/readback
- **Vulkan (Android NDK):** Compute pipelines, descriptor sets, push constants, AHardwareBuffer, pipeline cache
- **Shader Authoring:** Per-pixel color transforms, HSL/RGB conversion, LUT application (1D/3D), tone mapping (ACES, filmic), ASC CDL color wheels
- **Memory:** Texture pooling, tiling, GPU storage modes, zero-copy paths, bandwidth budgeting
- **Profiling:** Metal System Trace, GPU Counters, Shader Profiler, Android GPU Inspector, Systrace

## Platform Decision Tree

```
New GPU effect needed?
│
├── iOS
│   ├── Built-in CIFilter exists? → Use CIFilter (auto-tiling, lazy, stitchable)
│   ├── Per-pixel color only? → Stitchable CIColorKernel (.metal, [[stitchable]])
│   ├── Needs neighbors? → CIKernel with roiCallback
│   ├── Fast blur/histogram/resize? → MPS (hardware-optimized per device)
│   └── Full custom pipeline? → Metal compute kernel
│
├── Android
│   ├── API 33+, standard adjustment? → AGSL RuntimeShader + graphicsLayer
│   ├── API 33+, filter chain? → AGSL nested shader chaining
│   ├── Wide compat (API 21+)? → OpenGL ES 3.0 fragment + FBO ping-pong
│   ├── Compute needed (API 21+)? → GL ES 3.1 compute shader
│   ├── Max performance / batch? → Vulkan compute (NDK C++)
│   └── Simple blur/resize? → RenderScript Intrinsics Toolkit
│
└── Cross-platform shader?
    ├── Write in GLSL → compile to SPIR-V (Vulkan) + use as GL ES + adapt for AGSL
    └── Port to MSL manually or via MoltenVK (SPIR-V → MSL)
```

## iOS: Metal & Core Image

### Stitchable CIKernels (iOS 15+, Recommended)
```metal
#include <CoreImage/CoreImage.h>
using namespace metal;

[[stitchable]]
half4 myEffect(coreimage::sample_t s, float param, coreimage::destination dest) {
    // Per-pixel color transform
    return modified_color;
}
```
- **Build setting**: Other Metal Linker Flags = `-fcikernel`
- Core Image auto-concatenates stitchable kernels into single GPU pass
- No intermediate textures between stitchable kernels
- Use `coreimage::sample_t` (input pixel), `coreimage::destination` (output coord)

### MTKView Display (Zero-Copy)
```
CIImage → CIContext.startTask(toRender:to: CIRenderDestination) → MTKView
```
- Eliminates GPU→CPU→GPU roundtrip of UIImageView path (50-100ms savings on 48MP)
- Set `isPaused = true`, `enableSetNeedsDisplay = true` for on-demand redraw
- Use `.rgba16Float` pixel format for HDR/wide color
- Share `MTLCommandQueue` between CIContext and MTKView

### MPS Quick Reference
| Operation | MPS Class | When Faster Than CIFilter |
|-----------|-----------|--------------------------|
| Gaussian blur | MPSImageGaussianBlur | Large radii (2-3x faster) |
| Histogram | MPSImageHistogram | Always (outputs to MTLBuffer) |
| Resize | MPSImageLanczosScale | High-quality downsampling |
| Sharpen | MPSImageUnsharpMask | Comparable |
| Median filter | MPSImageMedian | Always |

### Metal Memory (iOS Unified Architecture)
| Storage Mode | CPU Access | GPU Access | Use For |
|-------------|-----------|-----------|---------|
| `.shared` | Yes | Yes | Param buffers, LUT data, small textures |
| `.private` | No | Yes | Intermediate render textures (faster) |
| `.memoryless` | No | Tile only | Temp render targets within single pass |

**MTLHeap**: Pool allocations, enable aliasing (`makeAliasable()`) to reuse memory across pipeline stages.

### Metal Compute Dispatch
```swift
let w = pipeline.threadExecutionWidth        // typically 32
let h = pipeline.maxTotalThreadsPerThreadgroup / w
let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
// A11+: dispatchThreads (handles edges automatically)
encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerGroup)
```

### HDR / EDR (iPhone 12+)
- `.rgba16Float` pixel format — stores linear light, values > 1.0 for HDR
- `CAMetalLayer.wantsExtendedDynamicRangeContent = true`
- `colorspace = CGColorSpace.extendedLinearDisplayP3`
- Tone mapping: ACES or filmic in shader, or system via `CAEDRMetadata`

## Android: AGSL / Vulkan / OpenGL ES

### AGSL RuntimeShader (API 33+, Recommended for Compose)
```glsl
uniform shader inputImage;
uniform float exposure;
uniform float contrast;

half4 main(float2 coord) {
    half4 c = inputImage.eval(coord);
    c.rgb *= half3(1.0 + exposure);
    c.rgb = half3(0.5) + half3(1.0 + contrast) * (c.rgb - half3(0.5));
    return half4(clamp(c.rgb, half3(0.0), half3(1.0)), c.a);
}
```

**Key AGSL differences from GLSL:**
| Aspect | GLSL | AGSL |
|--------|------|------|
| Entry | `void main()` + `gl_FragColor` | `half4 main(float2 coord)` returns color |
| Origin | Bottom-left | Top-left (matches Canvas) |
| Texture | `texture2D(sampler, uv)` | `inputShader.eval(coord)` |
| Preprocessor | `#define`, `#ifdef` | Not supported — use `const` |
| Color uniform | Manual | `layout(color) uniform half4` (auto color space) |

**Compose integration:**
```kotlin
Image(bitmap = imageBitmap, modifier = Modifier.graphicsLayer {
    shader.setFloatUniform("exposure", exposure)
    renderEffect = RenderEffect.createRuntimeShaderEffect(shader, "inputImage")
        .asComposeRenderEffect()
})
```

**Chaining AGSL shaders:**
```kotlin
shader1.setInputShader("inputImage", BitmapShader(bitmap, ...))
shader2.setInputShader("previousPass", shader1)  // nested chain
```

### OpenGL ES FBO Ping-Pong (Wide Compatibility)
```
Source texture → Filter 1 → FBO A → Filter 2 → FBO B → ... → Screen
```
- Create 2 FBOs + 2 textures, alternate read/write per filter pass
- Use `glTexStorage2D` (immutable textures) for faster uploads
- Use `RENDERMODE_WHEN_DIRTY` on GLSurfaceView for photo editing
- `glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)` between compute passes

### 3D LUT on Android (No Native Support)
Android has no `CIColorCubeWithColorSpace` equivalent. Two approaches:
1. **2D texture atlas**: Pack 32 slices of 32×32 into 256×32 texture, trilinear interpolate in shader
2. **3D texture** (GL ES 3.0+): `GL_TEXTURE_3D` with `glTexImage3D` — direct hardware trilinear

```glsl
// AGSL 3D LUT via 2D atlas
uniform shader lutAtlas;
uniform float lutSize;  // e.g., 32.0

half4 applyLUT(half4 color, float2 atlasSize) {
    float blueSlice = color.b * (lutSize - 1.0);
    float slice0 = floor(blueSlice);
    float slice1 = ceil(blueSlice);
    float blend = fract(blueSlice);
    // ... sample two slices, interpolate
}
```

### Vulkan Compute (NDK, Max Performance)
- Use for: RAW batch processing, export-quality rendering, heavy compute
- Shaders in GLSL, compile to SPIR-V via `glslc` (NDK-bundled)
- Push constants for small params (≤128 bytes), UBO for larger structs
- Pipeline cache: serialize with `vkGetPipelineCacheData` → 2x startup speedup
- AHardwareBuffer extension for zero-copy Bitmap↔Vulkan

### Android Memory
| Strategy | API | Purpose |
|----------|-----|---------|
| `Bitmap.Config.HARDWARE` | 26+ | GPU-only bitmap, halves memory |
| `HardwareBuffer` | 26+ | Zero-copy GPU/CPU/cross-API sharing |
| `inSampleSize` | All | Decode thumbnails at reduced resolution |
| `BitmapRegionDecoder` | All | Decode visible region only (tiling) |
| `glTexStorage2D` | ES 3.0+ | Immutable textures, faster upload |
| Texture pooling | All | Reuse textures by dimension, avoid alloc churn |
| PBO readback | ES 3.0+ | Async GPU→CPU (10-100x faster than glReadPixels) |

**Max texture size**: Query `GL_MAX_TEXTURE_SIZE` (typically 4096 or 8192). Tile images exceeding this.

### RAW on Android
1. **Capture**: CameraX 1.5+ `OUTPUT_FORMAT_RAW` or Camera2 `RAW_SENSOR`
2. **Demosaic**: LibRaw (NDK C++) — CPU-bound, produces linear RGB
3. **Upload**: Linear RGB → GPU texture → all adjustments on GPU
4. **No CIRAWFilter equivalent** — demosaicing is always a separate CPU step

## Shared Shader Patterns

### Exposure, Contrast, Saturation (All Platforms)
```glsl
// GLSL/AGSL (identical math)
color.rgb *= vec3(1.0 + exposure);
color.rgb = vec3(0.5) + vec3(1.0 + contrast) * (color.rgb - vec3(0.5));
vec3 lum = vec3(dot(color.rgb, vec3(0.2126, 0.7152, 0.0722)));
color.rgb = mix(lum, color.rgb, 1.0 + saturation);
```

### ASC CDL Color Wheels (Lift/Gamma/Gain)
```glsl
// Shadow/midtone/highlight color grading
vec3 lgg(vec3 color, vec3 lift, vec3 gamma, vec3 gain) {
    return pow(max(vec3(0.0), color * gain + lift), vec3(1.0) / gamma);
}
```

### Film Grain
```glsl
float noise = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
noise = (noise - 0.5) * intensity;
color.rgb += vec3(noise);
```

### Tone Mapping
```glsl
// ACES (industry standard)
vec3 aces(vec3 x) {
    float a=2.51, b=0.03, c=2.43, d=0.59, e=0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}
```

### sRGB ↔ Linear Conversion
```glsl
float srgbToLinear(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}
float linearToSrgb(float c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0/2.4) - 0.055;
}
```

## Performance Rules

### Both Platforms
1. **Optimize output resolution, not filter count** — GPU cost scales with pixels rendered, not pipeline complexity
2. **Render at display size during interaction**, full-res on finger lift / export
3. **Pool and reuse textures** — allocation is expensive on both Metal and GL
4. **Cache shader compilation** — Metal binary archives, GL program binaries, Vulkan pipeline cache
5. **Cancel previous render on new slider value** — only latest value matters
6. **Never block main thread** — render on background queue, display result on main

### iOS-Specific
- Use `half4` in Metal shaders — Apple GPUs have 2x throughput for half vs float
- Use `.private` storage mode for intermediate textures
- Use `CIRenderDestination` (async) over `createCGImage` (sync) where possible
- Create all `MTLComputePipelineState` at app launch, not during editing

### Android-Specific
- Use `Bitmap.Config.HARDWARE` for display-only bitmaps (halves memory)
- Use `glTexStorage2D` for immutable textures (avoids deferred copy)
- Use PBO for async GPU readback (10-100x faster than `glReadPixels`)
- Target bandwidth < 1 GB/s average; use mipmaps to reduce bandwidth
- AGSL uses Skia's internal batching — generally efficient without manual optimization

## Anti-Patterns

| Anti-Pattern | iOS Fix | Android Fix |
|--------------|---------|-------------|
| GPU→CPU→GPU roundtrip for display | MTKView + CIRenderDestination | AGSL graphicsLayer / GLSurfaceView |
| Full-res render during drag | renderPreview() at screen size | Reduced FBO / inSampleSize |
| New shader compilation during editing | Pre-compile at launch | Cache program binaries / pipeline cache |
| Texture alloc per frame | MTLHeap pooling | TexturePool + glTexStorage |
| Sync GPU readback | CIRenderDestination async | PBO or HardwareBuffer |
| Forgetting memory barrier (compute) | N/A (Metal handles) | `glMemoryBarrier()` / `vkCmdPipelineBarrier` |
| Large image without tiling | CIFilter auto-tiles | Manual tiling for > GL_MAX_TEXTURE_SIZE |
| float when half suffices | Use `half4` in MSL | Use `half4` in AGSL, `mediump` in GLSL |

## Process
> **Read pipeline → Check platform API → Plan shader → Implement → Profile GPU → Verify quality → Commit**

### Before ANY GPU Change
1. Read existing pipeline code (ImageProcessor.swift / Renderer class)
2. Identify target platform(s) and minimum API level
3. Check if built-in API exists (CIFilter / RenderEffect / MPS) before writing custom shader
4. For custom shader: prototype in GLSL (most portable), then adapt to MSL/AGSL
5. Profile before AND after with platform GPU profiler
6. Test on real device — simulator/emulator GPU behavior differs significantly
7. Check memory impact with `device.currentAllocatedSize` (Metal) or AGI (Android)

### Before Adding Custom Shader Effect
1. Decide: CIColorKernel (per-pixel) vs CIKernel (needs neighbors) vs compute (full control)
2. On Android: AGSL first (simplest), GL compute if AGSL insufficient, Vulkan for max perf
3. Write unit test: known input color → expected output color
4. Verify on both SDR and HDR content if applicable
5. Cache compiled pipeline state / program binary
