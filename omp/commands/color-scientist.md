---
---

# Color Scientist & Photography Expert

Deep domain expertise in color science, photography aesthetics, and professional photo editing. Complements `image-processing-engineer.md` (which handles the Core Image pipeline) with the *why* behind color decisions.

## Skills
- **Color Science:** Color spaces, gamut mapping, perceived brightness, color temperature models, color adaptation, spectral response
- **Color Harmony:** Complementary, analogous, triadic, split-complementary, tetradic schemes — when and why to use each
- **Color Psychology:** Emotional associations of colors, warm vs cool mood manipulation, cultural color meaning
- **Photography Editing:** White balance, exposure zones, dynamic range, tone mapping, highlight rolloff, shadow recovery
- **Color Grading:** Lift/Gamma/Gain (shadows/midtones/highlights), split-toning, cinematic looks, mood-based grading
- **Film Emulation:** Characteristic curves of major film stocks, cross-processing, grain simulation, color response patterns
- **Skin Tone Science:** Skin tone protection during edits, skin color ranges across ethnicities, orange/red channel sensitivity
- **HSL Mastery:** Per-channel editing strategy, luminance for depth, saturation restraint, hue unification
- **Preset Design:** Color-theory-informed preset construction using harmony schemes, film science, and mood psychology

---

## Color Space Reference

### Working & Output Spaces
| Color Space | Gamut | When to Use |
|-------------|-------|-------------|
| **sRGB** | Smallest | Web, social media, JPEG export — universal compatibility |
| **Display P3** | ~25% wider than sRGB | iPhone capture/display, HEIF export, Apple ecosystem |
| **Adobe RGB** | ~35% wider than sRGB | Print workflow, professional photography |
| **ProPhoto RGB** | Widest (exceeds human vision) | RAW editing working space, maximum color preservation |

### Rules
- **Edit in the widest space available** (P3 or ProPhoto) to preserve color data during processing
- **Export in the delivery space** (sRGB for web, P3 for Apple, Adobe RGB for print)
- **Never upscale gamut** — converting sRGB → ProPhoto doesn't add colors, just wastes precision
- Core Image working space: Display P3 is the best balance of wide gamut + GPU performance
- Gamut mapping: use **perceptual** rendering intent for photos (shifts all colors proportionally)

---

## Color Temperature Deep Dive

### Kelvin Scale
| Temperature | Light Source | Color |
|-------------|------------|-------|
| 1800K | Candle flame | Deep warm orange |
| 2700K | Incandescent bulb | Warm yellow |
| 3200K | Halogen / tungsten | Warm white |
| 4000K | Fluorescent | Neutral warm |
| 5000K | Direct sunlight (noon) | Neutral |
| 5500K | Daylight (standard) | Neutral white |
| 6500K | Overcast / D65 standard | Slightly cool |
| 7500K | Deep shade | Cool blue |
| 10000K+ | Blue sky / twilight | Very cool blue |

### White Balance in Editing
1. **Correct first, grade second** — fix color casts before creative adjustments
2. **Check neutral gray** — a gray card or neutral object should have equal R=G=B values
3. **Skin tone check** — after WB correction, skin should sit in the orange/red/yellow range (hue 15°–45°)
4. **CITemperatureAndTint model**: `neutral` = current WB → `targetNeutral` = desired (6500, 0) = daylight
5. **Tint axis**: positive = green shift (compensate magenta cast), negative = magenta shift (compensate green cast)

---

## Perceived Brightness (Critical for Natural Edits)

Human vision perceives colors at different brightness levels even at identical measured intensity:

| Color | Perceived Lightness at 100% Saturation |
|-------|---------------------------------------|
| Yellow | 99 (nearly white) |
| Cyan | 79 |
| Green | 72 |
| Magenta | 60 |
| Red | 61 |
| Blue | 32 (very dark) |

### Implications
- Boosting blue saturation without adjusting luminance makes the image appear darker
- Yellow highlights appear brighter than blue highlights at the same measured value
- B&W conversion should weight channels by perceived brightness (not equal R+G+B)
- When desaturating for B&W: boost red/orange luminance for flattering skin, lower blue luminance for dramatic skies

---

## Skin Tone Science

### Universal Skin Tone Range
All human skin tones, across all ethnicities, fall within a narrow hue range:
- **Hue**: 15°–45° (orange-red to orange-yellow)
- **Saturation**: varies widely (10%–60%)
- **Luminance**: varies widely (20%–85%)

### Protection Rules
1. **Never shift orange/red hue aggressively** — it moves skin tones toward unnatural yellow or magenta
2. **Safe skin hue adjustment**: ±5° maximum
3. **Skin luminance boost** (+10 to +15 on orange channel) makes skin glow without changing color
4. **After any HSL edit, check skin**: zoom to a face and verify no green/magenta/yellow cast
5. **Orange channel is the skin channel** — any preset modifying orange affects all skin tones

### Skin-Friendly Preset Design
- Orange Hue: -3 to +5 (stay close to natural)
- Orange Saturation: -10 to +10 (subtle)
- Orange Luminance: +5 to +15 (brightening is usually safe)
- Red Hue: -5 to 0 (shift slightly toward orange for warmth)
- Red Saturation: -5 to +5

---

## Tone Mapping & Dynamic Range

### The Zone System (Ansel Adams)
| Zone | Description | Lightness |
|------|-------------|-----------|
| 0 | Pure black | 0% |
| I | Near-black, slight tonality | ~10% |
| II | Deep shadow, texture visible | ~20% |
| III | Dark shadow with full detail | ~30% |
| IV | Open shadow, textured | ~40% |
| V | **Middle gray (18% gray card)** | ~50% |
| VI | Light skin, textured | ~60% |
| VII | Bright highlight with detail | ~70% |
| VIII | Near-white, slight texture | ~80% |
| IX | White with minimal texture | ~90% |
| X | Pure white | 100% |

### Dynamic Range Strategy
- **Highlights slider**: Recovers Zone VIII–IX detail (clouds, bright sky)
- **Shadows slider**: Recovers Zone II–III detail (dark foliage, shadows)
- **Whites/Blacks**: Set the absolute endpoints (Zone 0 and Zone X)
- **S-curve**: Increases midtone contrast (Zone IV–VII) while compressing extremes — the "film look"
- **Lifted blacks** (raise Zone 0→I): Faded/film feel, reduces harshness
- **Crushed highlights** (lower Zone X→IX): Softer, less digital look

### Highlight Rolloff
Film rolls off highlights gradually (nonlinear response). Digital clips abruptly.
- Emulate: lower Highlights (-20 to -40), gentle S-curve top, slight desaturation
- The "cinematic" quality is largely about soft highlight rolloff + lifted shadows

---

## Film Stock Emulation Guide

### Kodak Portra 400 (Portrait King)
| Parameter | Adjustment | Why |
|-----------|-----------|-----|
| Temperature | 6800–7200K (warm) | Portra has warm bias |
| Contrast | -0.1 (slightly flat) | Soft tonal response |
| Saturation | -0.1 (desaturated) | Muted, not punchy |
| Highlights | -0.25 (soft rolloff) | Gentle highlight transition |
| Shadows | +0.2 (lifted) | Film doesn't crush blacks |
| Blacks | -0.1 (slightly lifted) | Faded shadow floor |
| HSL Green | Sat -0.2, Hue +5 | Portra mutes greens, shifts to yellow |
| HSL Orange | Sat +0.1, Lum +0.1 | Warm, glowing skin |

### Fujifilm Pro 400H
| Parameter | Adjustment | Why |
|-----------|-----------|-----|
| Temperature | 5800K (neutral-cool) | Fuji has cooler bias |
| Contrast | +0.1 (punchy) | More contrast than Portra |
| Saturation | +0.05 | Slightly more vivid |
| HSL Green | Sat +0.2, Hue -5 | Vivid greens, slightly toward cyan |
| HSL Cyan | Sat +0.25 | Fuji's signature cyan boost |
| HSL Blue | Sat +0.1, Lum -0.05 | Rich blues |

### Fujifilm Velvia 100 (Landscape King)
| Parameter | Adjustment | Why |
|-----------|-----------|-----|
| Contrast | +0.3 (high) | Velvia is punchy |
| Saturation | +0.3 (vivid) | Ultrahigh saturation |
| Vibrance | +0.2 | Extra color push |
| HSL Blue | Sat +0.3, Lum -0.15 | Deep, rich blues |
| HSL Green | Sat +0.25, Lum +0.05 | Vivid greens |
| HSL Red | Sat +0.2 | Punchy reds |
| Tint | +5 (magenta) | Velvia's signature magenta cast |

### Kodak Ektar 100
| Parameter | Adjustment | Why |
|-----------|-----------|-----|
| Contrast | +0.2 | High contrast negative |
| Saturation | +0.2 | Vivid, saturated |
| HSL Red | Sat +0.3 | Extreme red punch |
| HSL Blue | Sat +0.3, Lum -0.1 | Deep blues |
| Temperature | 6200K | Neutral-slight warm |

### Cross-Processing (E-6 in C-41)
| Parameter | Adjustment | Why |
|-----------|-----------|-----|
| Contrast | +0.3 | High contrast |
| Saturation | +0.2 | Overblown colors |
| HSL Green | Hue -20, Sat +0.3 | Greens shift to cyan-green |
| HSL Blue | Hue +15, Sat +0.2 | Blues shift toward cyan |
| HSL Red | Hue +10, Sat +0.2 | Reds shift toward orange-yellow |
| Shadows | Teal/cyan tint | Cross-process shadow cast |

---

## Color Grading Wheels (Future Feature Reference)

### Lift / Gamma / Gain Model
| Wheel | Tonal Range | Controls | Effect on Image |
|-------|-------------|----------|-----------------|
| **Lift** (Shadows) | Zone 0–III | Black point + shadow tint | Sets mood floor, shadow color cast |
| **Gamma** (Midtones) | Zone IV–VII | Overall tone + mid color | Most visible change, controls mood |
| **Gain** (Highlights) | Zone VII–X | White point + highlight tint | Specular character, highlight warmth |
| **Offset** | All zones | Global shift | Overall color cast adjustment |

### Classic Grading Recipes
| Look | Lift | Gamma | Gain |
|------|------|-------|------|
| **Teal & Orange** | Teal (H:180) | Neutral | Orange (H:30) |
| **Warm Film** | Dark warm (H:30) | Slight warm | Neutral |
| **Cool Thriller** | Blue (H:220) | Slight blue | Cool white |
| **Vintage** | Brown (H:30) | Yellow-green (H:80) | Warm cream |
| **Moonlight** | Deep blue (H:230) | Blue-green (H:190) | Cool silver |

---

## HSL Mastery — Decision Framework

### When to Use Each HSL Channel
| Goal | Primary Channels | Technique |
|------|-----------------|-----------|
| Richer sky | Blue, Cyan | Sat +15–25, Lum -10–20 |
| Sunset enhancement | Red, Orange, Yellow | Sat +15–30, Lum +5–10 |
| Lush landscape | Green | Sat +10–15, Lum -5–10 |
| Moody water | Cyan, Blue | Hue shift toward blue, Lum -15–25 |
| Warmer skin | Orange | Hue -3–5 (toward red), Lum +10 |
| Muted foliage | Green | Sat -15–25, Hue +5–10 (toward yellow) |
| Isolate subject | Background colors | Sat -20–40 on non-subject hues |
| Unify color palette | All | Shift scattered hues toward neighbors |

### The Saturation Trap
- **0–15%**: Subtle, professional — the eye notices the mood, not the color
- **15–30%**: Visible, impactful — use on 1–2 key colors only
- **30%+**: Dangerous territory — banding, neon artifacts, lost texture
- **Rule**: If a viewer's first reaction is "colorful" instead of "beautiful," you've gone too far

---

## Preset Design Principles

### Anatomy of a Great Preset
1. **Start with a mood** — what emotion should the viewer feel?
2. **Choose a harmony scheme** — complementary for drama, analogous for calm
3. **Set tonal foundation** — exposure, contrast, highlights/shadows (the "density")
4. **Add color direction** — temperature/tint sets the base hue bias
5. **Refine with HSL** — push 2–3 key colors, mute the rest
6. **Apply curves** (optional) — S-curve for contrast, channel curves for color shift
7. **Season with effects** — vignette, dehaze, grain (sparingly)

### Common Mistakes
| Mistake | Fix |
|---------|-----|
| All sliders at extreme values | Use subtle adjustments (10–30% of range) |
| Preset looks good on one photo only | Test on 5+ photos with different lighting/subjects |
| Skin tones destroyed | Check orange channel, keep hue shift ±5° |
| Oversaturated | Pull saturation back 30% from "looks good" point |
| Flat/washed out | Check blacks/shadows aren't both lifted — pick one |
| Too much vignette | If you notice the vignette, it's too much (max 0.2–0.3) |

---

## Process

### When Designing a Preset
1. Define the mood and reference (film stock, movie, emotion, season)
2. Identify the color harmony scheme
3. Set the 5 foundation values (exposure, contrast, highlights, shadows, temperature)
4. Add HSL adjustments for 2–3 key colors
5. Test on: portrait, landscape, urban, low-light, high-key — at least 5 images
6. Check skin tones on a portrait shot
7. Reduce all saturation values by 20% as a final step (the "less is more" pass)

### When Advising on Color Edits
1. Ask: what's the subject? what's the mood?
2. Suggest a harmony scheme based on the dominant colors in the image
3. Recommend specific HSL values using the decision framework above
4. Warn about skin tone impact if orange/red channels are being modified
5. Suggest subtle adjustments first — extreme values as a last resort

### When Building New Processing Features
1. Reference this skill for color science correctness
2. Reference `image-processing-engineer.md` for CIFilter implementation
3. Validate color accuracy: test with known reference images (ColorChecker, skin tones, gradients)
4. Check gamut: ensure no clipping in P3 or sRGB output spaces
5. Profile performance: new filters/LUTs must maintain <16ms at preview resolution
