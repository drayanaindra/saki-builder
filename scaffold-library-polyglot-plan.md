# EXECUTION PLAN: scaffold-library polyglot extension (Go · Python · Rust · Node · TypeScript · Ruby)

**Date:** 2026-07-09
**Blocking items:** 0 (see Evidence Ledger)
**Risk Score:** LOW
**Unknown Count:** 2 / 2 max
**Behavior Spec:** N/A — backend-only (skill-authoring: one Markdown instruction file, no UI, no endpoint a user hits through an app)
**Source PRD:** N/A (standalone `/saki-builder:rplan`)
**Appetite:** ~5 agent tasks (single-file parity refactor; sits well within a "small" band)
**Kill-if:** N/A (no product metric)

## Problem Statement

When a developer runs `/saki-builder:scaffold-library` in a Go, Rust, Python, or Ruby project (or a greenfield dir for one), I want the skill to scaffold a language-appropriate library instead of assuming Node/TypeScript, so I can use the same single entry point across all six languages the plugin already targets in its sibling scaffolds.

---

## Concrete Example Output

The deliverable is the transformed `config/skills/scaffold-library/SKILL.md`. "Done" is deterministic parity with `scaffold-cli`/`scaffold-tui`'s detection pattern, extended to libraries + Ruby. Two representative before/after behaviors:

**Today (Node/TS only):** the `## Script` block branches solely on `package.json` (`npm init`, `tsup`, `vitest`). In a dir containing `Cargo.toml` or `*.gemspec`, the skill produces a Node package — wrong.

**After — Rust (existing-pattern language):**
```
$ /saki-builder:scaffold-library mylib   # cwd has Cargo.toml
Detected: Rust (Cargo.toml)
→ src/lib.rs           (pub fn + #[cfg(test)] mod tests)
→ Cargo.toml           ([lib] section, crate name)
Validation: cargo build && cargo test
```

**After — Ruby (net-new, canonical Bundler skeleton):**
```
$ /saki-builder:scaffold-library mygem   # cwd has mygem.gemspec or Gemfile
Detected: Ruby (gemspec/Gemfile)
→ lib/mygem.rb         (module Mygem — public API surface)
→ lib/mygem/version.rb (VERSION constant)
→ mygem.gemspec        (spec, if greenfield)
→ spec/mygem_spec.rb   (RSpec)
Validation: bundle install && bundle exec rspec
```

Definition of done = all six languages have a named manifest, build tool, test framework, source layout, and public-API convention in `## Instructions`, plus a detection branch in `## Script` and a language-agnostic `## Validation`.

---

## Steps

All five steps edit the single file `config/skills/scaffold-library/SKILL.md`. The file is only valid as a whole, so steps 1–5 land as **one atomic commit** (step 5 completes it). Likely implemented as one `Write` of the full file; listed as sections for review clarity.

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 1 | Rewrite frontmatter `inputs`: add `language` input (enum `go\|python\|rust\|node\|typescript\|ruby`, optional, default `auto` = detect-from-manifest-else-ask); scope existing `runtime` + `format` inputs to "Node/TypeScript only — ignored for other languages" via their `description`. Keep `name` required. Update top-line `description` + `project_types` unchanged. | `config/skills/scaffold-library/SKILL.md` frontmatter (L1–25) | LOW | `grep -A40 '^inputs:' … \| grep -q 'name: language'` | No → completed by step 5 (same file) |
| 2 | Rewrite `## Context` to be language-parametrized: state the detected/selected `{{input.language}}`, mirror scaffold-cli's "Read AGENTS.md; read existing files to understand patterns" line, drop the Node-only runtime/format framing to a Node/TS aside. | same file, `## Context` | LOW | manual read: no npm-only assumption remains | No → step 5 |
| 3 | Rewrite `## Instructions`: prepend step "0. Detect language / analyze existing manifest" (mirror scaffold-cli Instructions step 1, L30–36). Then replace the 8 Node-specific steps with **per-language branches** covering, for each of Go/Python/Rust/Node/TypeScript/Ruby: manifest file, build/package tool, source layout, public-API convention, test framework, linter/formatter, README stub, CI. Use the Instructions-branch style of scaffold-cli L38–42 / scaffold-tui L38–43 (a bulleted "Lang (tool): path" list per concern). | same file, `## Instructions` | LOW | `for l in Go Python Rust Node TypeScript Ruby; do grep -q "$l" … \|\| echo MISSING $l; done` → empty | No → step 5 |
| 4 | Rewrite `## Script`: language-detection branch mirroring scaffold-cli L82–107 — `if [ -f go.mod ] … elif [ -f Cargo.toml ] … elif [ -f pyproject.toml ]/[ -f setup.py ] … elif [ -f package.json ] (disambiguate TypeScript via `[ -f tsconfig.json ]` + `grep typescript`) … elif ls *.gemspec >/dev/null 2>&1 \|\| [ -f Gemfile ]` (Ruby, net-new)`. Each branch echoes detected lang + install/init command (e.g. Rust `cargo init --lib`, Python `python -m build` deps, Ruby `bundle gem`/`gem build`, Node/TS existing `npm i -D typescript tsup vitest`). Keep the block POSIX-sh, `bash -n`-clean. | same file, `## Script` | LOW | extract fenced block → `bash -n` exits 0; `for m in go.mod Cargo.toml pyproject.toml package.json gemspec; do grep -q "$m" … \|\| echo MISSING; done` empty | No → step 5 |
| 5 | Rewrite `## Validation`: replace npm-specific checklist items with language-agnostic outcomes — build succeeds, tests pass, package/crate/gem artifact produced, public API importable/`use`-able/`require`-able, lint passes — with the per-language command named parenthetically (`go test ./...`, `cargo test`, `pytest`, `vitest`, `bundle exec rspec`). This checkbox completes the file → atomic commit of steps 1–5. | same file, `## Validation` | LOW | manual read: no bare `npm run …` as sole validation; generic wording present | Yes (completes file; commit steps 1–5 together) |

> Each Action names the exact section + line anchors and the concrete change. No vague verbs.

---

## User Role Coverage

Single actor — this is developer-tooling, not an app feature. Matrix filled honestly; other rows N/A.

| Role | Can Do | Cannot Do | Auth Guard | UI Entry Point |
|------|--------|-----------|------------|----------------|
| Developer (skill invoker) | Run `/saki-builder:scaffold-library <name>` and get a language-correct library scaffold for any of the 6 languages | Cannot scaffold a language outside the 6 (falls back to ask/Node) | N/A (local CLI skill, no auth surface) | `/saki-builder:scaffold-library` slash command |
| Customer / Admin / Merchant / Warehouse | N/A — no product surface | — | — | — |

---

## Plan Wiring

Not an HTTP call chain — this is a skill file. The load-bearing "flow" is invocation → consumption:

### Flow 1: Developer scaffolds a library
```
/saki-builder:scaffold-library <name>            (slash command)
  → plugin auto-discovers config/skills/scaffold-library/SKILL.md
       (plugin.json: "skills": ["./config/skills"] — no per-skill registration)
  → LLM runs ## Script detection block → detects language from manifest
       (go.mod | Cargo.toml | pyproject.toml/setup.py | tsconfig.json→TS | package.json→Node | *.gemspec/Gemfile→Ruby)
  → LLM follows ## Instructions branch for the detected language
       (manifest · build tool · source layout · public API · tests · lint · README · CI)
  → LLM runs ## Validation checklist for that language
       (build succeeds · tests pass · artifact produced · public API importable)
```

### Flow 2: Greenfield (empty dir, no manifest)
```
No manifest detected → skill uses {{input.language}} if provided, else asks which of the 6
  → same Instructions/Validation branch as Flow 1
```

---

## Migration Checklist

N/A — no database, no schema, no data migration. This task edits one Markdown instruction file.

- [x] No DB change → no migration rows required (explicitly N/A)

---

## Branch Points (pre-declared)

- Step 3: If any language's canonical library convention is genuinely ambiguous while writing → default to that ecosystem's most standard tool (documented in Unknowns) and note the assumption inline in the SKILL.md; do not block.
- Step 4: If a POSIX-sh detection idiom for Ruby gemspec globbing is non-portable → fall back to `[ -f Gemfile ]` as the primary Ruby signal (gemspec glob as secondary). Auto-handle.

---

## Unknowns (must be <= 2)

1. [LOW] Exact Ruby gem skeleton layout → resolution: use the canonical Bundler `bundle gem <name>` structure — `lib/<name>.rb`, `lib/<name>/version.rb`, `<name>.gemspec`, `spec/<name>_spec.rb` (RSpec), `Rakefile`. This is a long-stable Bundler convention; stated as known, not spiked.
2. [LOW] Node-vs-TypeScript disambiguation heuristic → resolution: presence of `tsconfig.json` (and/or `typescript` in `package.json`) selects the TypeScript branch; otherwise plain Node. Mirrors the skill's current TS-default bias; the existing tsup/vitest path becomes the TS branch verbatim.

---

## No-Gos

- Will NOT create new skills or split into per-language skills — single `scaffold-library` entry point preserved (plugin auto-discovers `config/skills/`; keep the directory name).
- Will NOT edit `plugin.json` or otherwise register the skill — it is auto-discovered via `"skills": ["./config/skills"]`.
- Will NOT remove the `runtime`/`format` inputs — scope them to Node/TypeScript (preserves existing behavior; avoids a breaking input-contract change).
- Will NOT bump the plugin version or cut a release in this task — the edit lands in the repo only. Activation in the live `/saki-builder:scaffold-library` requires a separate release (version bump + push + reinstall), per the version-pinned-snapshot model. Verification here is against the repo file content, not by re-invoking the live skill.
- Will NOT invent non-standard tooling — use each ecosystem's canonical build/test tools (go test, cargo, hatchling/pytest, tsup/vitest, Bundler/RSpec).

---

## Implementation Completeness Checklist

**User Coverage**
- [x] Every role that touches this feature is in the Role Coverage matrix (single Developer role; others N/A)
- [x] Each role has full call chain in Plan Wiring (Flows 1–2)
- [x] Permission/auth check listed for each role (N/A — local skill, no auth surface; stated)
- [x] Edge cases per role documented (greenfield / unsupported language → Flow 2 + Branch Points)

**Database & Migrations**
- [x] N/A — no schema change (explicitly noted in Migration Checklist)

**API Layer**
- [x] N/A — no HTTP API (skill file). Noted.

**Service / Business Logic**
- [x] Every section modified is named with file path + line anchors (Steps 1–5)
- [x] Side effects listed (none beyond writing the SKILL.md; scaffold output is the skill's own runtime behavior, unchanged in kind)
- [x] Error/fallback paths documented (greenfield + unsupported-language fallback — Branch Points, Unknowns)

**Frontend**
- [x] N/A — no UI. Noted in header (Behavior Spec: backend-only).

**Plan Wiring**
- [x] Invocation→consumption chain written out (Flows 1–2)
- [x] No step uses vague verbs without exact file + section + line anchor
- [x] No "update X" without naming the section and the concrete change

---

## Evidence Ledger

Readiness is a boolean: presentable when the **Blocking** table is empty.

### Blocking (must be empty to present)

| # | Step | Blocking predicate (unresolved) | Evidence |
|---|------|---------------------------------|----------|
| — | — | (none) | — |

### Advisory (visible, never gates)

| Step | Note | Evidence |
|------|------|----------|
| 4 | Ruby detection portability across shells is a minor risk (net-new branch) | mitigated by Branch Point (Gemfile as primary signal) |
| 5 | Live `/saki-builder:scaffold-library` won't reflect the change until a saki-builder release | memory `project_saki_symlink_shadows_plugin`; captured as No-Go |
| — | All anchors verified, all targets have creating steps, no unchecked items on state-changing steps, no unknowns above LOW | self-audit |

**Anchors verified:**
- `config/skills/scaffold-library/SKILL.md` exists (read; 2.2K, Node/TS-only) — the edit target
- `config/skills/scaffold-cli/SKILL.md` L38–42 (Instructions branch) + L82–107 (Script detection) — pattern source (read)
- `config/skills/scaffold-tui/SKILL.md` L38–43 + L88–119 — pattern source (read)
- `.claude-plugin/plugin.json` `"skills": ["./config/skills"]` — auto-discovery, no manifest edit needed (read)
- Old input schema has no live coupling — `grep -rn scaffold-library config/` returns only `config/docs/plan-history/*` (historical)
- No project-local override — `find … -path "*/.claude/skills/scaffold-library*"` → none

**Blocking: 0 → READY.**

---

## Success Criteria

Run from repo root `/Users/indrayana/claude-config`.

- [x] **Language input present** — `grep -A40 '^inputs:' … | grep -q 'name: language'` exits 0. ✓ PASS
- [x] **All 6 languages in Instructions** — Go/Python/Rust/Node/TypeScript/Ruby loop prints nothing. ✓ PASS
- [x] **All 6 manifests in Script detection** — go.mod/Cargo.toml/pyproject.toml/package.json/gemspec loop prints nothing. ✓ PASS
- [x] **Script block is valid sh** — extracted `## Script` block → `bash -n` exits 0. ✓ PASS
- [x] **Validation is language-agnostic** — names cargo/go test/pytest/rspec (not only npm). ✓ PASS
- [x] **Ruby path uses canonical Bundler layout** — `lib/` + `rspec`/`gemspec` present. ✓ PASS
- [x] **Single entry point preserved** — `git status --porcelain config/skills/` shows only `scaffold-library/SKILL.md` modified. ✓ PASS

---

## Annotation Space

> Human: add notes, corrections, constraints here.

---
Status: [ ] Draft  [ ] Annotated  [x] Approved  [ ] In Progress  [x] Complete
Readiness Gate: [x] Evidence Ledger present and every blocking item cited  [x] Blocking Set empty  [x] Unknowns <= 2
