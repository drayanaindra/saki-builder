# Context: Autonomous /prd-review (option 3 — one shared loop)

**Date:** 2026-07-05
**Task:** Make `/saki-builder:prd-review` autonomous-by-default (loop-to-green: review → apply fixes → re-review). `/saki-builder:pickup` reuses the same loop instead of hand-rolling its own.

## Pinned decisions (human-approved — do not re-litigate)

1. **Autonomous is the DEFAULT** for `/prd-review` — no `--autonomous` flag. Bare `/prd-review <prd>` loops to green (`Verdict SHIP` AND `Readiness READY`) or blocked/non-convergent.
2. **`--review-only` escape hatch** preserves today's single-pass, never-edits-the-PRD behavior. The autonomous loop uses this same review core each round.
3. **Judges stay fresh.** Phase 2 launches the 3 judges as fresh Agent subagents each round — adversarial independence preserved. Only the *fix-apply* step moves into the reviewer's coordinator.
4. **`/pickup` reuses the loop** (option 3). Phase 2 stops hand-rolling the loop; it invokes autonomous `/prd-review` once, then does epic-specific terminal handling. The loop lives in exactly one place → no nesting/double-loop.

## How "autonomous" works today (the pattern to mirror)

Autonomous = a **Stop-hook keep-alive**. A skill maintains a JSON state file with a `phase` cursor; a `Stop` hook reads it and returns `{"decision":"block","reason":"…continue…"}` while the phase is "active", keeping the loop alive across turns. Two orchestrators use it:

- `/pickup` → `config/hooks/pickup-completion-gate.sh` (blocks while `phase ∈ {prd, review}`; releases on `proto-ready`/`blocked`/unknown). State: `tasks/.pickup-<slug>-state.json`.
- `/build` → `config/hooks/build-completion-gate.sh` (same pattern, build half).

Both hooks are near-identical single-purpose scripts (**precedent: two separate gates, not one generalized gate**) with: fail-safe classification, progress-aware circuit breaker (per-manifest sidecar `<state>.gate.json`, gives up after `MAX_BLOCKS` no-progress stops), session ownership (`session_id`), fail-open everywhere, SubagentStop-safe (`agent_id` → no-op), stale-run window (mtime).

## Key files (verified)

| File | Fact | Evidence |
|------|------|----------|
| `config/skills/prd-review/SKILL.md` | 473 lines. Phases 0,0.5,1,2,2.5,3,4. Single-pass; invariant "never edits the PRD". Emits `--- REVIEW COMPLETE ---` block + `<!-- review-verdict: SHIP\|REVISE\|DISCOVERY-FIRST -->`. | `SKILL.md:403` (sentinel), `:337` (comment), `:8` + Rules (invariant) |
| `config/skills/pickup/SKILL.md` | Phase 2 owns the loop-to-green (fix list + 3-round cap + BLOCKED escape). "Key design note: the review loop lives HERE… `/prd-review` stays single-pass." | `pickup/SKILL.md:114-155`, esp. `:153` |
| `config/hooks/pickup-completion-gate.sh` | Stop hook. `ACTIVE=("prd","review")` blocks; else allow. Progress score `ordinal + rounds`. Env `PICKUP_GATE_ACTIVE_MINUTES`(45)/`PICKUP_GATE_MAX_BLOCKS`(5)/`PICKUP_GATE_DISABLE`. | `pickup-completion-gate.sh:61,65-75,25-27` |
| `config/hooks/test-pickup-completion-gate.sh` | 99-line regression test locking phase behavior + ownership + breaker + stale. Run: `bash config/hooks/test-pickup-completion-gate.sh`. | file read end-to-end |
| `config/settings.json` | `Stop` array registers `build-completion-gate.sh` + `pickup-completion-gate.sh`. | `settings.json:135-149` |
| `.claude-plugin/plugin.json` | `"version": "0.7.0"`. | `plugin.json:4` |
| `CHANGELOG.md` | `## 0.7.0 — 2026-07-05` head; release convention commit `release(saki-builder): vX.Y.Z — …`. | `CHANGELOG.md:5`, git log `c4b71e9` |

## Deploy topology (verified — load-bearing for rollout)

- `~/.claude/settings.json` → **symlink** → `config/settings.json` — **LIVE**.
- `~/.claude/hooks` → **symlink** → `config/hooks` — **LIVE** (new hook script + Stop registration take effect for global sessions immediately, no release).
- `~/.claude/skills` → **NOT a symlink**. `/saki-builder:*` skills load from the **version-pinned plugin** `~/.claude/plugins/cache/saketek/saki-builder/0.7.0/…`. **SKILL edits (`prd-review`, `pickup`) need a plugin release 0.7.0→0.8.0 + reinstall** to take effect.
- Consequence: hook lands live; skills gate on the release. If hook is present but skill un-released → hook finds no state file → fail-open (harmless). Both must land; the **release is the gating dependency**.

## Design chosen

- **Dedicated `prd-review-completion-gate.sh`** (not reuse/generalize pickup's) — matches the build-vs-pickup precedent, keeps continue-reason messaging correct for a standalone run, avoids coupling two phase vocabularies in one file.
- **State file** `tasks/.prd-review-<slug>-state.json`. Phases: `reviewing` (active → BLOCK), `green` (terminal → ALLOW), `blocked` (terminal → ALLOW), unknown/empty → ALLOW. Progress score = `ordinal(reviewing=1) + review.rounds`.
- **Loop lives in `/prd-review` Phase 5 (autonomous wrapper)** around the unchanged review core (Phases 1–4). `--review-only` runs the core once and skips Phase 5.
- **`/pickup` Phase 2** invokes autonomous `/prd-review` and branches on its terminal state. Both state files/gates coexist during a pickup run and hand off cleanly (pickup gate covers the `prd` phase; prd-review gate covers `reviewing`); both fail-open.

## Invariant interaction (bias)

Moving fix-apply into the reviewer does NOT worsen the self-review bias the architecture guards against, because the **judges remain fresh Agent subagents each round**. The coordinator accumulating context across rounds mirrors what pickup's coordinator already did.
