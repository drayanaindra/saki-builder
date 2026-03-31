# Senior Mobile Engineer (iOS & Android)

## Skills
- **iOS Native:** Swift, SwiftUI, UIKit, Core Image, Metal, AVFoundation, PhotoKit, Core ML, Combine, async/await
- **Android Native:** Kotlin, Jetpack Compose, Material Design 3, CameraX, RenderScript/Vulkan, MediaCodec, ML Kit
- **Image/Video Processing:** GPU-accelerated pipelines, CIFilter chains, color science, RAW processing, LUT application, real-time preview
- **App Architecture:** MVVM, Clean Architecture, @Observable (iOS), ViewModel (Android), dependency injection
- **Performance:** 60fps UI, GPU profiling (Instruments/GPU Debugger), memory management, lazy loading, thumbnail caching

## iOS Specifics

### SwiftUI Best Practices
- Use `@Observable` (iOS 17+) over `@ObservableObject` — simpler, no `@Published` needed
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `.task {}` for async work, not `.onAppear` with Task {}
- Keep views small, extract subviews for reusability
- Use `PHPickerViewController` (no permission needed) over `PHPhotoLibrary` when possible

### Core Image Pipeline
- Always reuse `CIContext` — creating one is expensive
- Use Metal-backed `CIContext` for GPU acceleration: `CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!)`
- Chain CIFilters by connecting `.outputImage` → next filter's `.inputImage`
- For RAW: use `CIRAWFilter` (iOS 15+) — handles 500+ camera models
- RAW-specific controls: `exposure`, `temperature`, `tint`, `noiseReductionAmount`, `luminanceNoiseReductionAmount`, `sharpnessAmount`, `localToneMapAmount`
- Never force-unwrap CIImage outputs in production

### Common CIFilters for Photo Editing
| Adjustment | CIFilter |
|-----------|----------|
| Exposure | CIExposureAdjust |
| Contrast/Brightness | CIColorControls |
| Saturation | CIColorControls |
| Highlights/Shadows | CIHighlightShadowAdjust |
| Temperature/Tint | CITemperatureAndTint |
| Vibrance | CIVibrance |
| Sharpness | CISharpenLuminance / CIUnsharpMask |
| Curves | CIToneCurve |
| Vignette | CIVignette |
| Noise Reduction | CINoiseReduction |
| LUT | CIColorCubeWithColorSpace |
| Crop | CICrop |

### PhotoKit Access
- `PHPickerViewController` — no permission prompt, limited access
- `PHPhotoLibrary` — needs `NSPhotoLibraryUsageDescription` in Info.plist
- RAW files: check `PHAsset.mediaSubtypes.contains(.photoRAW)`
- Request full-size: `PHImageManager.requestImageDataAndOrientation`

### Export Pipeline
- JPEG: `CGImageDestination` with `kCGImageDestinationLossyCompressionQuality`
- HEIF: `CIContext.writeHEIFRepresentation` or `CGImageDestination` with `public.heic` UTI
- TIFF: `CGImageDestination` with `public.tiff` UTI (16-bit for RAW exports)
- Preserve EXIF: copy `CGImageProperties` from source to destination

## Android Specifics (for future reference)

### Jetpack Compose
- Use `ViewModel` with `StateFlow` for state management
- `LazyVerticalGrid` for photo grids
- `Modifier.pointerInput` for gesture handling
- Material Design 3 theming

### Image Processing (Android)
- RenderScript deprecated → use Vulkan compute or OpenGL ES shaders
- `android.graphics.ColorMatrix` for basic adjustments
- `BitmapFactory.Options.inSampleSize` for efficient loading
- DNG RAW: `DngCreator` / third-party libraries
- Consider GPUImage library for filter pipeline

## Process
> **Read → Verify → Plan → Implement → Preview/Simulator → Device Test → Commit**

### Before ANY Mobile Change
1. Read related views, models, and engine files
2. Check Apple/Google docs for API availability and deprecation
3. Verify minimum OS version supports the API
4. Test on simulator first, then device for GPU/camera features
5. Profile with Instruments (iOS) or Profiler (Android) for performance

### Anti-Patterns
| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Force-unwrapping optionals | Use guard let / if let |
| Blocking main thread with image processing | Use background queue, display on main |
| Creating new CIContext per filter | Reuse single CIContext |
| Loading full-resolution images in grid | Use thumbnails with PHCachingImageManager |
| Ignoring memory warnings | Implement didReceiveMemoryWarning, release caches |
