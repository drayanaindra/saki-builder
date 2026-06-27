# AI / LLM / Voice Patterns

Stack-specific patterns for LLM integration, prompt engineering, and voice/audio AI (Whisper). Loaded on-demand via `@import` in project CLAUDE.md files that use AI features.

---

## AI / LLM Integration

- **Named semantic presets > raw LLM-generated numerical arrays**: When an LLM needs to output precise numerical values (curve control points, coordinates, timing offsets), define a small set of named presets in the prompt and map them to exact values in code. LLMs describe semantics reliably; they generate inaccurate precise floats. Examples: curve presets ("s_curve", "film_fade"), animation easing ("ease_in", "spring"), layout modes. (confidence: MED, source: iOS photo editing app — AI color grading feature, date: 2026-03-12)
- **Domain vocabulary in system prompts improves AI output calibration**: Include professional terminology (film stock names, design pattern names, grading technique names) in system prompts. LLMs reason better when they can anchor to named concepts they were trained on vs. purely numerical ranges. Example: "Kodak Portra: lifted blacks, warm shadows" produces more accurate color grading output than "slightly brighter shadows". (confidence: MED, source: iOS photo editing app — AI color grading feature, date: 2026-03-12)
- **Calibration tables prevent LLM value extremism**: LLMs default to dramatic values when asked to replicate visual styles. Add a "subtle/moderate/strong" table for each parameter type (e.g. HSL saturation: ±0.1 subtle, ±0.25 moderate, ±0.5 strong) and an "interaction rules" section (don't stack contrast slider + s_curve). This makes AI output conservative and stackable rather than over-processed. (confidence: MED, source: iOS photo editing app — AI prompt enhancement, date: 2026-03-12)
- **Keep prompt JSON schema in sync with parser**: When an LLM is asked to return structured JSON, every field in the schema must have a corresponding parser entry. Fields in the prompt but not in the parser are silently discarded — no error, no warning. Mitigation: write the parser and the prompt schema at the same time; grep the schema keys against the parser when reviewing. (confidence: MED, source: iOS photo editing app — AI color grading feature, date: 2026-03-12)

---

## Audio / Voice / Whisper

- **OpenAI hosted whisper-1 has no tunable server params**: `vad_filter`, `condition_on_previous_text`, `compression_ratio_threshold`, `no_speech_threshold` are only available in self-hosted Whisper/faster-whisper. When using the OpenAI API, all anti-hallucination defense must be client-side. (confidence: HIGH, source: deep research + implementation, date: 2026-03-09)
- **Never use Whisper `initial_prompt` for continuous voice chat**: Research (OpenAI community + GitHub issues) shows `initial_prompt` causes ~80% fully-hallucinated looping output in continuous contexts. Use hallucination blocklist + VAD + echo cancellation instead. (confidence: HIGH, source: research + external sources, date: 2026-03-09)
- **7-layer client-side anti-hallucination stack for Whisper**: (1) VAD (Silero/@ricky0123/vad-web), (2) echoCancellation+noiseSuppression on getUserMedia, (3) speechDetected RMS threshold flag, (4) hallucination string blocklist (60+ strings, 12+ languages), (5) repetition/loop detector (word count + unique ratio), (6) min cumulative speech duration, (7) consecutive-silence bail-out (3 strikes → pause). First two give the highest ROI. (confidence: HIGH, source: research + implementation, date: 2026-03-09)
