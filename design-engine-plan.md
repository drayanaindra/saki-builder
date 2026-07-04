# Plan: selectable design engine (figma | native) for `/init-env` + `/proto`

**Status:** approved by choice → implementing
**Risk tier:** MED (new hook + init-env step + edits to the delicate 1157-line proto skill; all additive)
**Confidence:** 92%

## Decisions (locked by user)
- **Figma role:** selectable engine — **detect + route** (read-from-Figma when write is blocked, native otherwise).
- **Placement:** an `/init-env` step records the project's engine + verifies Figma MCP/seat; `/proto` reads the record and routes.

## Architectural constraint (drives the split)
A **bash hook cannot check the Figma MCP** — the MCP server is in-process to Claude, no CLI. So:
- **bash script** owns the *record file* (`.claude/design-engine.json`) + the statically-checkable bits (recorded choice, does the repo have a frontend for native render).
- **Claude (in the skill)** owns *live Figma verification* — calls the Figma MCP `whoami` tool to read connection + seat, then persists the result via the script's `record` mode.

Live finding on this machine: Figma MCP connected as *M Asep Indrayana*, **seat = View (read-only)** → capability `read`. Write-to-canvas export (Step 6c) will be blocked here; design-to-code READ works.

## Record file — `.claude/design-engine.json`
```json
{
  "engine": "figma" | "native",
  "figma": { "source": "<figma file url>", "seat": "view", "capability": "read"|"write", "handle": "…" } | null,
  "recordedBy": "design-engine-setup.sh",
  "recordedAt": "<iso8601>"
}
```
Seat→capability map: `view`,`dev` → **read**; `edit`,`editor`,`full`,`design` → **write**; unknown → **read** (conservative). Best-effort; the real test is attempting the op.

## Artifacts

### 1. `config/hooks/design-engine-setup.sh` (NEW)
- `detect [--path DIR]` → reads the record + `frontend: yes|no` (grep package.json for a FE framework); prints a `<design-engine>` block. Read-only, exit 0.
- `record --engine native|figma [--path DIR] [--seat S] [--capability C] [--source URL] [--handle NAME]` → validates engine, writes the record atomically (temp+mv), JSON-escaped. Non-zero only on bad `--engine`.
- jq for reads if present, grep fallback. Helpers keep each fn ≤40 LOC / complexity ≤15. `main "$@"` guarded by `BASH_SOURCE` for testability.

### 2. `config/hooks/test-design-engine-setup.sh` (NEW)
Round-trip: record native → detect shows native + figma null; record figma w/ source/seat/capability → detect echoes them; bad engine → non-zero; empty dir → `NONE`; package.json w/ react → `frontend: yes`, empty → `no`.

### 3. `config/skills/init-env/SKILL.md` (EDIT) — new **Step 1c** (interactive only; headless SKIP)
1. `~/.claude/hooks/design-engine-setup.sh detect`
2. Ask **figma | native** (default **native** — always available, canonical).
3. If **figma**: call Figma MCP `whoami` → connection + seat → derive capability; ask for the Figma source file URL (design-to-code); `record --engine figma --seat … --capability … --source … --handle …`. If MCP not connected: tell the user how to connect (Figma desktop MCP / plugin) or fall back to native.
4. If **native**: `record --engine native`.
5. Add Step 1c to the headless **SKIP** list.

### 4. `config/skills/proto/SKILL.md` (EDIT) — **Step 0 — Design engine (read + route)**, inserted between Input and GATE 1
Routing contract (native stays canonical; build never reads Figma — honesty rail preserved):

| recorded engine | live check | behavior |
|---|---|---|
| `native` / no record | — | current behavior exactly (native render → gallery; 6c export stays optional-when-connected) |
| `figma` | `whoami` fails (not reachable here) | **fall back to native**, note it + suggest `--figma-only` on a Figma-connected machine |
| `figma` | connected, capability `read` + `source` set | **design-to-code reference**: Step 5 pulls `get_design_context`/`get_screenshot` per manifested screen to guide the native render; gallery canonical; skip 6c write-export (note seat) |
| `figma` | connected, capability `write` | read-reference (if source) **and** run 6c export |

Minimal hooks: Step 5 gains a short "if figma-source mode, pull Figma reference for this screen" note; Step 6c gates its write on `capability=write`. No rewrite of the big sections.

## Out of scope (this pass)
- Auto-registering the Figma MCP in install.sh (it's already enabled via the figma plugin; connection is per-machine/interactive).
- Full pixel-diff between Figma source and native render (design-to-code stays reference-guided, not a pixel gate).
- A standalone `/design-engine` command (script is re-runnable already).

## Verification
- `bash config/hooks/test-design-engine-setup.sh` → all asserts pass.
- Live: `design-engine-setup.sh detect` in a scratch repo → `NONE`; after `record` → echoes engine/source/seat/capability.
- Re-read proto Step 0 table for internal consistency with Steps 5/6c after edit.
