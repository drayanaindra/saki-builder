---
name: resume
description: Read-only "where was I" reader for the manual chain. Runs the orientation protocol from config/docs/manual-chain-resume.md against a task's resume manifest (tasks/.<slug>-state.json) and reports each step's status plus the next skill to run. Never writes — pure orientation after a context clear. Usage — /saki-builder:resume [<slug>|<plan-path>].
type: analysis
trigger: "resume, where was I, what's next, continue task, pick up where, what step am I on, manual chain status"
user-invocable: true
---

# Resume — manual-chain orientation

Thin, **read-only** reader for the manual chain (`/saki-builder:rplan → /saki-builder:rplan-review → /saki-builder:approved → /saki-builder:qa → /saki-builder:reviewer →
/saki-builder:wrap`). After a `/clear` or an interruption it answers *"where was I, what's next"* from the resume manifest
that those skills stamp — see `${CLAUDE_PLUGIN_ROOT}/config/docs/manual-chain-resume.md` for the schema and
the canonical protocol this skill runs. It **never stamps or writes** anything.

## What it does

1. **Resolve the manifest.** With an argument (a `<slug>`, a `tasks/<slug>-plan.md` path, or a
   `.<slug>-state.json` path) → `tasks/.<slug>-state.json`. With no argument → the **newest** manual-chain
   manifest (top-level `steps`, not `/saki-builder:build`'s `.build-*` with `slices`).
2. **Run the orientation protocol** → print each step's status in canonical order and compute the next
   uncompleted step (absent optional `rplan-review`/`security` count as satisfied; a `red` / `not-ready` /
   `changes-requested` / `in-progress` step is re-entered).
3. **Recommend the exact command** to resume with.

## Run

```bash
ARG="${1:-}"   # optional: a slug, a plan path, or a manifest path
python3 - "$ARG" <<'PY' 2>/dev/null || echo "resume: no readable manual-chain manifest — start with /saki-builder:rplan"
import json, glob, os, sys
arg=(sys.argv[1] if len(sys.argv)>1 else "").strip()
order=["rplan","rplan-review","approved","qa","reviewer","security","wrap"]
optional={"rplan-review","security"}
fail={"not-ready","red","changes-requested","in-progress"}
cmd={"rplan":"/saki-builder:rplan","rplan-review":"/saki-builder:rplan-review",
     "approved":"/saki-builder:approved","qa":"/saki-builder:qa","reviewer":"/saki-builder:reviewer",
     "security":"/security-review","wrap":"/saki-builder:wrap"}

def manual(f):
    try: d=json.load(open(f))
    except Exception: return None
    return d if ("steps" in d and "slices" not in d) else None

if arg:
    slug=os.path.basename(arg)
    for suf in ("-plan.md","-state.json"):
        if slug.endswith(suf): slug=slug[:-len(suf)]; break
    slug=slug.lstrip(".")
    p=f"tasks/.{slug}-state.json"
    cands=[p] if manual(p) else []
    miss=f" (looked for tasks/.{slug}-state.json)"
else:
    cands=sorted([f for f in glob.glob("tasks/.*-state.json")
                  if not os.path.basename(f).startswith(".build-") and manual(f)],
                 key=os.path.getmtime, reverse=True)
    miss=""

if not cands:
    print("no manual-chain manifest found."+miss)
    print("NEXT: /saki-builder:rplan  — start the chain")
    raise SystemExit

path=cands[0]; d=manual(path); steps=d.get("steps",{})
nxt=None
for s in order:
    st=steps.get(s,{}).get("status")
    if st in fail: nxt=s; break
    if st is None and s not in optional: nxt=s; break
print(f"task={d.get('task')}  branch={d.get('branch')}  updated={d.get('updated')}  ({path})")
for s in order:
    print(f"  {s:13} {steps.get(s,{}).get('status','—')}")
if len(cands)>1:
    print("other manuals: "+", ".join(os.path.basename(c) for c in cands[1:])+"  (pass a <slug> to pick one)")
if nxt:
    tag="  (re-enter — it did not pass)" if steps.get(nxt,{}).get("status") in fail else ""
    print(f"NEXT: {cmd[nxt]}  — resume at '{nxt}'{tag}")
else:
    print("NEXT: done — nothing outstanding (task fully wrapped)")
PY
```

Then relay the table + the `NEXT:` line to the user. Per the manifest doc's rule 3, prefer to **redo** a
`qa` / `reviewer` / `security` step even if it shows `done` — those gates are cheap and not commit-backed.

## Rules

- **Read-only.** Never stamp, edit, or create a manifest — that is the chain skills' job. `/saki-builder:resume` only reports.
- **Best-effort.** No manifest (or unreadable) → say so and point at `/saki-builder:rplan`; never error out.
- **`config/docs/manual-chain-resume.md` is the source of truth** for the schema, step order, and protocol —
  this skill just runs it on demand and maps the next step to its command.
- Ignores `/saki-builder:build`'s `.build-*-state.json` (that's the autonomous chain; it resumes via its own
  Gate 2, not here).
