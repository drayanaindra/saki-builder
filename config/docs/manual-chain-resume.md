# Manual-Chain Resume Manifest

The manual chain — `/saki-builder:rplan → /saki-builder:rplan-review → /saki-builder:approved → /saki-builder:qa → /saki-builder:reviewer → (/security-review) → /saki-builder:wrap`,
run by hand rather than orchestrated by `/saki-builder:build` — has no built-in resume state. This doc defines a
small on-disk manifest that lets it **survive a context clear / interruption**: after a `/clear` you (or
Claude) read one file to know what's done and what's next, instead of re-deriving it from plan checkboxes
and git.

It is the manual-chain analog of `/saki-builder:build`'s `tasks/.build-<prd-slug>-state.json`, adapted to a **single
task** (no slices). Load this doc **on demand** — only when a manual-chain skill reaches its manifest
touch-point, never eagerly.

---

## Non-negotiable rules

1. **Best-effort, never a gate.** Every read/write is wrapped so a failure is silent (`|| true`). A skill
   MUST behave exactly as it does today when the manifest is absent, unreadable, or stale. A standalone
   one-off `/saki-builder:qa` (or any skill) with no manifest runs unchanged. The manifest is *additive orientation*,
   not a new precondition.
2. **The human drives — this is orientation, not auto-loop.** Unlike `/saki-builder:build`, nothing auto-advances. The
   manifest's job is to answer *"where was I, what's next"* after an interruption. Skills stamp their step
   on completion; the reader protocol (below) reports the next uncompleted step.
3. **Redo-over-skip.** When in doubt, redo. A skill trusts a prior step as done only if the manifest says
   so AND its artifact verifies (plan file exists / commit resolves). The non-committed gates (`qa`,
   `reviewer`, `security`) are cheap to re-run and should be, rather than trusted blindly.
4. **Never clobber `/saki-builder:build`'s manifest.** `/saki-builder:build` owns `tasks/.build-<prd-slug>-state.json` (schema has a
   top-level `slices` array). Manual-chain manifests are `tasks/.<slug>-state.json` (schema has a top-level
   `steps` object, no `slices`). Readers that glob must disambiguate on that.

---

## File

- **Path:** `tasks/.<slug>-state.json`, a hidden dotfile beside the plan, where
  `<slug>` = the plan filename minus `-plan.md` (so `tasks/foo-plan.md` → `tasks/.foo-state.json`).
- **Owner:** created by `/saki-builder:rplan` (Step 7, when it writes the plan); each later skill stamps its own step.

## Schema

```json
{
  "task":   "<slug>",
  "plan":   "tasks/<slug>-plan.md",
  "branch": "<git branch at rplan time>",
  "item":   "I<n> | B<n> | null",
  "steps": {
    "rplan":        { "status": "done",             "artifact": "tasks/<slug>-plan.md" },
    "rplan-review": { "status": "done | not-ready" },
    "approved":     { "status": "in-progress | done", "lastCommit": "<sha>" },
    "qa":           { "status": "done | red" },
    "reviewer":     { "status": "done | changes-requested" },
    "security":     { "status": "done | n/a" },
    "wrap":         { "status": "done" }
  },
  "updated": "<YYYY-MM-DD>"
}
```

**Status vocabulary.** A step key that is **absent** means *not-reached* (for the optional steps
`rplan-review` / `security`, absent = *skipped / n/a*). `in-progress` marks a step that started but did
not finish (e.g. a crash mid-`/saki-builder:approved`). The terminal-fail states (`not-ready`, `red`,
`changes-requested`) record that the step ran and did not pass — resume re-enters there.

**Step order** (canonical, for the reader): `rplan → rplan-review → approved → qa → reviewer → security → wrap`.
`rplan-review` and `security` are optional; treat an absent optional step as satisfied when computing the
next step.

---

## Snippets

Both are best-effort: they no-op silently on any error and never fail the calling skill.

### Init (create or refresh) — used by `/saki-builder:rplan`

```bash
# PLAN_FILE = the plan path /saki-builder:rplan just wrote. ITEM = "I3"/"B7" or "" if none.
SLUG="$(basename "$PLAN_FILE" -plan.md)"
STATE="$(dirname "$PLAN_FILE")/.${SLUG}-state.json"
STATE="$STATE" SLUG="$SLUG" PLAN="$PLAN_FILE" \
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" ITEM="${ITEM:-}" TODAY="$(date +%F)" \
python3 - <<'PY' 2>/dev/null || true
import json, os
p=os.environ["STATE"]
try: d=json.load(open(p)) if os.path.exists(p) else {}
except Exception: d={}
d.update(task=os.environ["SLUG"], plan=os.environ["PLAN"],
         branch=os.environ.get("BRANCH") or None,
         item=os.environ.get("ITEM") or None, updated=os.environ["TODAY"])
d.setdefault("steps", {})
d["steps"]["rplan"]={"status":"done","artifact":os.environ["PLAN"]}
json.dump(d, open(p,"w"), indent=2)
PY
```

### Stamp one step — used by every later skill

```bash
# PLAN_FILE = the plan this skill is acting on. STEP/STATUS per the schema.
# EXTRA (optional) = a JSON object of extra fields to merge, e.g. '{"lastCommit":"abc123"}'.
SLUG="$(basename "$PLAN_FILE" -plan.md)"
STATE="$(dirname "$PLAN_FILE")/.${SLUG}-state.json"
STATE="$STATE" STEP="<step>" STATUS="<status>" EXTRA="${EXTRA:-}" TODAY="$(date +%F)" \
python3 - <<'PY' 2>/dev/null || true
import json, os
p=os.environ["STATE"]
try: d=json.load(open(p)) if os.path.exists(p) else {}
except Exception: d={}
d.setdefault("steps", {}); s=d["steps"].setdefault(os.environ["STEP"], {})
s["status"]=os.environ["STATUS"]
ex=os.environ.get("EXTRA","").strip()
if ex:
    try:
        for k,v in json.loads(ex).items(): s[k]=v
    except Exception: pass
d["updated"]=os.environ["TODAY"]
json.dump(d, open(p,"w"), indent=2)
PY
```

`/saki-builder:wrap` has no plan handle, so it resolves the manifest by newest instead — see its touch-point below.

---

## Per-skill touch-points

Each skill does a tiny amount. Read this doc, run the matching snippet, move on.

| Skill | Where | Action |
|-------|-------|--------|
| `/saki-builder:rplan` | Step 7 (Output), after writing the plan | **Init** the manifest; stamps `rplan=done` (+ `item` if seeded from a roadmap item in Step 0.6). |
| `/saki-builder:rplan-review` | Final Verdict | Stamp `rplan-review=done` on APPROVED, `rplan-review=not-ready` otherwise. (Skipped for LOW/MED plans → key stays absent = n/a.) |
| `/saki-builder:approved` | Step 3 (begin) / Completion | Stamp `approved=in-progress` at start; `approved=done` with `EXTRA='{"lastCommit":"<final sha>"}'` at completion. |
| `/saki-builder:qa` | Step 6 (Report) | Stamp `qa=done` when the verdict is ALL PASS, else `qa=red`. |
| `/saki-builder:reviewer` | Step 4 (Act on verdict) | Stamp `reviewer=done` on APPROVE, `reviewer=changes-requested` on REQUEST CHANGES. |
| `/saki-builder:wrap` | Phase 6 (Final report) | Stamp `wrap=done` on the newest manual-chain manifest (glob below). Terminal marker. |

`/security-review` is a global/plugin skill outside this repo, so it is **not** instrumented. The manual
chain leaves `security` absent (= n/a); stamp it by hand only if you track it.

### `/saki-builder:wrap` manifest resolution (no plan handle)

```bash
# Newest tasks/.*-state.json that is a manual-chain manifest (top-level "steps", not "slices").
STATE="$(python3 - <<'PY' 2>/dev/null || true
import json, glob, os
best=None; bt=-1
for f in glob.glob("tasks/.*-state.json"):
    if os.path.basename(f).startswith(".build-"): continue
    try: d=json.load(open(f))
    except Exception: continue
    if "steps" in d and "slices" not in d and os.path.getmtime(f)>bt:
        best, bt = f, os.path.getmtime(f)
print(best or "")
PY
)"
[ -n "$STATE" ] && STATE="$STATE" STEP="wrap" STATUS="done" TODAY="$(date +%F)" python3 - <<'PY' 2>/dev/null || true
import json, os
p=os.environ["STATE"]
try: d=json.load(open(p))
except Exception: d={"steps":{}}
d.setdefault("steps",{})["wrap"]={"status":os.environ["STATUS"]}
d["updated"]=os.environ["TODAY"]
json.dump(d, open(p,"w"), indent=2)
PY
```

---

## Reader / orientation protocol (resume entry point)

The **`/saki-builder:resume`** skill runs this on demand — `/saki-builder:resume [<slug>|<plan-path>]` — and
maps the next step to its command; reach for it first. The raw protocol below is what it executes.

After a `/clear`, to answer *"where was I on task `<slug>`, what's next":*

```bash
STATE="tasks/.<slug>-state.json"   # or the /saki-builder:wrap glob above if the slug is unknown
STATE="$STATE" python3 - <<'PY' 2>/dev/null || true
import json, os
order=["rplan","rplan-review","approved","qa","reviewer","security","wrap"]
optional={"rplan-review","security"}
fail={"not-ready","red","changes-requested","in-progress"}
try: d=json.load(open(os.environ["STATE"]))
except Exception:
    print("no manifest — start fresh (or run /saki-builder:rplan)"); raise SystemExit
steps=d.get("steps",{})
nxt=None
for s in order:
    st=steps.get(s,{}).get("status")
    if st in fail: nxt=s; break            # re-enter a failed/in-progress step
    if st is None and s not in optional: nxt=s; break
print(f"task={d.get('task')} branch={d.get('branch')} updated={d.get('updated')}")
for s in order:
    print(f"  {s:13} {steps.get(s,{}).get('status','—')}")
print("NEXT:", nxt or "done — nothing outstanding")
PY
```

Then re-run the reported NEXT skill by hand. Prefer redo on any `qa` / `reviewer` / `security` step even
if marked done — they are cheap and not commit-backed (rule 3).
