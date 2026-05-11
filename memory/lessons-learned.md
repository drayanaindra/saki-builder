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

## 2026-05-07 — Slate slice 3 watchlist (single-source; awaiting one more recurrence)

Six new lessons captured in the Slate project's `.claude/memory/lessons-learned.md`. None met the 3+/multi-project promotion bar yet. Flag for `/reflect` next time any recur:

- [DISCOVERY] **modernc/sqlite default settings cause `SQLITE_BUSY` storms under concurrent writes** — fix: `?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)` in the DSN. HIGH-impact stack-portable Go+SQLite truth. Promote to `patterns.md → Go` on first recurrence; consider early promotion given fix universality. (Status 2026-05-10: still 1×, hold; user opted to keep Slate-Go entries project-local for now.)
- [DISCOVERY] **`go run` does not propagate SIGINT to the compiled subprocess** — smoke-test process lifecycle against `go build && bin/x`, not `go run`. Promote to `patterns.md → Go` on first recurrence. (Status 2026-05-10: still 1×, hold.)
- [DISCOVERY] **`go vet`'s `httpresponse` analyzer catches resp-before-err** on `resp, _ := http.Get(...); defer resp.Body.Close()`. Adjacent to line-106 pattern. Promote on first recurrence. (Status 2026-05-10: still 1×, hold.)
- [PATTERN] **TDD RED can be 1/N if happy-path GREEN already added defensive error handling** — lock in the assertions anyway, the partially-RED test list still validates the gap. Promote to `patterns.md → Workflow` on first recurrence. (Status 2026-05-10: still 1×, hold.)
- [ANTI-PATTERN] **Bash variable round-trip mangles byte-level verification** — for HTTP escape-behavior assertions, pipe `curl` directly to `xxd`/file, never via `RESP=$(curl); echo "$RESP" | xxd`. Promote to `patterns.md → Tools & Commands` on first recurrence. (Status 2026-05-10: still 1×, hold.)
- [ANTI-PATTERN] **Harness parallel stdout: write to file from each subshell, don't pipe through `tee`** — `for ...; do (cmd) & done | tee` is fragile under harness auto-backgrounding. Adjacent to line-143 "Background Bash tasks need `bash -c`". Promote to `patterns.md → Tools & Commands` on first recurrence. (Status 2026-05-10: still 1×, hold.)

## 2026-05-10 — /reflect cycle: 7 patterns promoted from Slate (slices 4, 9, 25, mock parity)

Promoted to `~/.claude/memory/patterns.md`:

- [Code Quality] **`getComputedStyle` > screenshots for visual-parity verification** (2× on Slate — explicitly flagged for /reflect at slice 25)
- [MCP Playwright] **`browser_evaluate` runs as plain JavaScript, not TypeScript** (slice 4 BoardCard parity)
- [MCP Playwright] **Chrome user-data-dir lock recovery via `pgrep -lf mcp-chrome` + `pkill`** (2× on Slate — slice 4 + mock parity)
- [MCP Playwright] **`browser_navigate` is a hard reload — wipes in-memory state** (mock parity slice)
- [MCP Playwright] **`window.fetch` counter > network log for "fired exactly once" assertions** (card delete confirmation slice)
- [Vite] **Vite dev module graph can serve a stale source file even after `npm run build`** — `?_t=cachebust` hard-nav fix (mock parity slice; mirrors Turbopack stale-chunk pattern)
- [React Patterns] **React Context value-identity trap: `useSyncExternalStore` for external mutable stores** (DeepMind store slice)
- [React Patterns] **Destructive-action confirmation: never morph the trigger into Confirm at the same screen coords** (card delete safety probe — caught CRITICAL bypass via mouse double-click)

Slate Go/embed/SQLite patterns kept project-local in the Slate repo's `.claude/memory/lessons-learned.md` per user preference.
