# Image Processing Engineer

Specialized depth role for Core Image pipelines, LUT engineering, RAW processing, color science, and GPU-accelerated rendering. Extends `mobile-engineer.md` with image processing domain expertise.

## Skills
- **Core Image Pipeline:** CIFilter chaining, lazy evaluation, filter ordering, Metal-backed CIContext, display P3 working color space
- **LUT Engineering:** 3D color cube construction (CIColorCubeWithColorSpace), 1D→3D sampling, Catmull-Rom spline interpolation, cache invalidation by parameter equality
- **Color Science:** HSL↔RGB conversion, perceptual brightness differences, gamut mapping, white balance models, color harmony schemes
- **RAW Processing:** CIRAWFilter lifecycle, property hot-swap vs re-creation, draft mode, scale factor, PhotoKit data caching
- **GPU Performance:** Preview-res vs full-res rendering, debounce/cancel task patterns, Instruments GPU profiling, memory pressure handling
- **Export Quality:** Format-specific color spaces (sRGB→JPEG, P3→HEIF/TIFF), compression quality, EXIF preservation

## Core Image Pipeline Rules

### Filter Chain is a Lazy Graph
- CIFilter setup = ~0ms (just graph nodes). GPU work happens ONLY at `context.createCGImage()`.
- Output size determines GPU cost, NOT filter count. 12 filters at 1MP ≈ same cost as 1 filter at 1MP.
- Implication: optimize render resolution, not filter count.

### Rendering Strategy
| Context | Method | Resolution |
|---------|--------|-----------|
| Interactive drag | `renderPreview()` | Screen size (~1MP) |
| Drag end / idle | `render()` | Full resolution |
| RAW interactive | Draft mode + 0.25 scale | ~25% of sensor res |
| Export | Full quality, no draft | Full resolution |

### CIContext — Singleton, Always
```
CIContext(mtlDevice: device, options: [.workingColorSpace: displayP3])
```
- ONE instance for entire app lifetime
- Metal-backed for GPU acceleration
- Display P3 working color space for wide color gamut
- Never create per-filter or per-render

### Filter Ordering (current 12-step pipeline)
1. Exposure → 2. Brightness/Contrast/Saturation → 3. Highlights/Shadows → 4. White Balance → 5. Vibrance → 6. Sharpness → 7. Noise Reduction → 8. Vignette → 9. Dehaze → 10. Master Curve → 11. RGB Curves LUT → 12. HSL LUT

**Rationale:** Global exposure/tone first, color adjustments middle, spatial effects (sharp/NR) early to avoid sharpening artifacts from later color shifts, creative LUTs last to operate on already-corrected values.

## LUT Engineering

### 3D Color Cube Format
```
Dimension: 32 (32³ = 32,768 entries × 4 floats = 512KB)
Order: R-fastest (B outer loop, G middle, R inner)
Data: [Float] array — R, G, B, A for each entry
Color space: sRGB (pass to CIColorCubeWithColorSpace)
```

### Building a Curve LUT
1. Take 5 control points per channel (sorted by x)
2. Catmull-Rom spline interpolation → sample into 256 entries per channel
3. Combine R, G, B 1D tables into 32³ 3D cube: `cube[r,g,b] = (rLUT[r], gLUT[g], bLUT[b], 1.0)`
4. Cache by parameter equality — skip rebuild when unchanged

### Building an HSL LUT
1. For each (r, g, b) in 32³ grid → convert to HSL
2. Sum weighted adjustments from all 8 color ranges (red, orange, yellow, green, cyan, blue, purple, magenta)
3. Weight = `rangeWeight(hue, range)` — 1.0 inside 30° half-width, linear falloff in 15° feather zone
4. Apply H shift (mod 360), S shift (clamped), L shift (halved, clamped)
5. Convert back to RGB, store in cube
6. Cache by HSLParameters equality

### When to Merge vs Chain LUTs
- **Chain** (current): Two separate CIColorCubeWithColorSpace filters. Simpler code, independent caching.
- **Merge**: Combine curves + HSL into single LUT. Single filter pass, but cache invalidated when either changes.
- **Rule**: Chain until profiling shows the second LUT filter adds measurable latency (unlikely at display resolution).

## RAW Processing

### CIRAWFilter Lifecycle
```
Asset selected → fetchRawData(PhotoKit) → create CIRAWFilter(imageData:) → CACHE
Slider change  → update filter.exposure/etc. in-place → access .outputImage
Asset changed  → invalidate → re-fetch → create new filter
```

### Properties that Update In-Place (no re-decode)
- `exposure`, `luminanceNoiseReductionAmount`, `sharpnessAmount`, `boostAmount`
- `isDraftModeEnabled`, `scaleFactor`, `isGamutMappingEnabled`, `isLensCorrectionEnabled`

### PhotoKit RAW Data Fetch
- Use `deliveryMode = .highQualityFormat` (NOT `.opportunistic` — causes double callback)
- Detect RAW: `PHAsset.mediaSubtypes.contains(.photoRAW)`
- Cache by `asset.localIdentifier` — only re-fetch when asset changes
- `identifierHint` from UTI string helps CIRAWFilter select correct decoder

## Color Science Quick Reference

### HSL ↔ RGB Conversion
- Edge case: delta < 1e-6 → achromatic (no hue, no saturation, just lightness)
- Hue wrapping: `fmod(h + shift + 360, 360)` to keep in 0–360 range
- Saturation formula differs for L < 0.5 vs L >= 0.5

### Perceived Brightness
- Yellow at 100% = lightness 99 (bright) vs Blue at 100% = lightness 32 (dark)
- Luminance adjustments per color range are critical for natural results
- This is why HSL luminance slider matters more than global brightness

### White Balance Model
- CITemperatureAndTint uses `neutral` (current) → `targetNeutral` (desired) vector pairs
- Neutral daylight: CIVector(x: 6500, y: 0)
- Higher temp = warmer (orange), lower = cooler (blue)
- Tint: positive = green shift, negative = magenta shift

### Color Spaces in Export
| Format | Color Space | Why |
|--------|-------------|-----|
| JPEG | sRGB | Universal compatibility |
| HEIF | Display P3 | Apple ecosystem, wider gamut |
| TIFF | Display P3 | Professional workflow, wide gamut |

## Performance Profiling

### Instruments Templates
- **Core Image** — filter graph visualization, GPU kernel timings
- **Metal System Trace** — GPU utilization, command buffer timing
- **Allocations** — track LUT Data allocations, CIImage retain cycles
- **Time Profiler** — CPU bottlenecks in LUT generation, HSL conversion

### Performance Red Flags
- `createCGImage()` taking >16ms at display resolution → check if scale factor is correct
- LUT rebuild on every frame → cache is not working, check parameter equality
- Memory growth during editing → CIImage or Data not being released
- RAW decode on every slider change → CIRAWFilter not being reused

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| New CIContext per render | Singleton, Metal-backed |
| Force-unwrap `outputImage` | `f.outputImage ?? output` fallback |
| Force-unwrap `CGColorSpace(name:)` | `?? CGColorSpaceCreateDeviceRGB()` |
| Full-res render during drag | `renderPreview()` at screen size |
| Re-create CIRAWFilter on param change | Update properties in-place |
| `.opportunistic` delivery + CheckedContinuation | `.highQualityFormat` (single callback) |
| Rebuild LUT every frame | Cache by param equality |
| Blocking main thread with render | Background task, display on main |
| Hardcoded LUT dimension | Use 32 (verified 512KB, good balance) |

## Process
> **Read pipeline → Verify filter behavior → Plan changes → Implement → Profile with Instruments → Verify quality → Commit**

### Before ANY Pipeline Change
1. Read `ImageProcessor.process()` — understand current filter ordering
2. Read relevant LUT/RAW engine file
3. Check Apple docs for CIFilter API (parameters, types, ranges)
4. Consider impact on existing presets (do preset values still produce correct output?)
5. Profile before AND after with Instruments Core Image template
6. Test with both JPEG and RAW inputs

### Before Adding a New Filter Step
1. Decide where in the 12-step pipeline it belongs (tone? color? spatial? creative?)
2. Check if existing step can be extended (e.g., dehaze reuses CIGammaAdjust + CIColorControls)
3. Consider whether it needs a bypass check (`if param != default`)
4. Add to AdjustmentParameters model
5. Add to PresetAdjustments if preset-worthy
6. Update ColorTonePrompt if AI should suggest values
