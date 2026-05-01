# Lessons Learned

## 2026-05-01 — claude-config audit + chain refactor + commit sweep

- [CORRECTION] Recommending tests for a design whose *shape* you doubt is shape-locking — calcifies behavior. For designs in question, recommend **instrumentation** (measure phase fire/block/change-rate) before writing integration tests.
- [CORRECTION] Don't hedge recommendations. When user asks "why recommend X?", be ready to defend with evidence or retract. Hedging papers over real tensions and erodes trust.
- [DISCOVERY] `plans/` is gitignored at every nesting level in this repo (Claude Code uses it for ephemeral local plan files). Tracked plan history must use a non-colliding name — we use `config/docs/plan-history/`.
- [DISCOVERY] Reading SKILL.md files end-to-end before critiquing them yields cited evidence (line numbers, concrete contradictions). Speculating without reading yields vague claims that the user will (rightly) reject.
- [PATTERN] When two skills do similar work, the unique value usually lives in the *optional* one — promote it to the always-run path. (Phase 1.5 criteria hardening moved from optional `/rplan-review` into mandatory `/rplan` Step 6d.)
- [PATTERN] Atomic per-concern commits during repo cleanup keep each step independently reversible. The 7-commit sweep across hooks/skills/qa/settings/README/plans worked without per-commit re-confirmation because each was small and named its scope.
- [ANTI-PATTERN] Bundling shape-neutral infrastructure work with shape-locking work in the same recommendation list. Always re-stratify: which initiatives help regardless of design (commit hygiene, smoke tests, skill curation) vs. which assume the design is right (integration tests for orchestration).
- [ANTI-PATTERN] Auditing without reading. Initial chain evaluation was speculative; the real bugs (outdated model ID, ledger-overwrite by formula, Decision Tree contradicting Step 6 intent) only surfaced after reading 1,435 lines of SKILL.md.

**Promotion candidates** (flag for `/reflect` if these recur):
- The contradiction-spotting feedback (corrections #1 and #2) is global behavior guidance — promote to `memory/patterns.md` after one more recurrence.
- The "promote unique-value-from-optional-skill-to-mandatory-skill" pattern is reusable beyond `/rplan` — watch for it in other skill chains.
