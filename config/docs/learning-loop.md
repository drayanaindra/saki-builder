# The saki-builder learning loop (split model)

Two layers, so a whole team can learn without ever conflicting on one file.

| Layer | Path | Who writes | Who reads | Governance |
| ----- | ---- | ---------- | --------- | ---------- |
| **Team baseline** | repo `memory/patterns.md` + `patterns-<topic>.md` (shipped read-only in the installed plugin) | maintainers, via **MR** | everyone (on-demand: skills read `${CLAUDE_PLUGIN_ROOT}/memory/…`) | PR/MR review |
| **Personal overlay** | `~/.claude/memory/patterns-personal.md` (each machine) | you, freely | you (injected every session by `inject-core.js`) | none — private |

## How it flows

- `/saki-builder:reflect` promotes a lesson by **audience**: yours/experimental/project-local/< 3× → **personal overlay** (instant); cross-person + confirmed + portable → **team baseline** (opens an MR).
- `/saki-builder:sync` shares team-baseline edits via a **branch + MR** — never a direct push to `main`. Personal-overlay writes are never synced (they aren't in the repo).
- `/saki-builder:reviewer` and other pattern-consuming skills read **both** layers.

## Why split

The old model auto-loaded one big `patterns.md` for everyone and pushed it from every machine —
at team scale that means merge conflicts and one person's raw notes polluting the shared standard.
The split fixes both: the shared layer is small, curated, and review-gated; personal noise stays
personal and never leaves your machine.

## Setup (each teammate, optional)

Create your overlay whenever you have a personal note worth keeping around:

```bash
mkdir -p ~/.claude/memory
$EDITOR ~/.claude/memory/patterns-personal.md
```

It's picked up automatically next session. Absent = no-op (the core injection still works).
