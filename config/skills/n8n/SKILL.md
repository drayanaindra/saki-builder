---
name: n8n
description: Autonomously build an n8n workflow automation end-to-end against a LIVE n8n instance. Understands the expectation (a one-line goal → elicit → spec, OR an existing spec/PRD file → build directly), authors the workflow JSON, deploys it via the n8n REST API, triggers a real execution, reads the execution result, and self-corrects ("auto resolve") until a real run passes the spec's criteria — then stops. Safety is built in: exponential backoff, a progress-gated circuit-breaker, a hard attempt budget, and search-by-name idempotency so re-runs update the same workflow instead of duplicating it. Faithful (builds exactly the spec, nothing more) and concise. Requires N8N_BASE_URL + N8N_API_KEY in env (the key is a secret — never passed through chat). Usage — /saki-builder:n8n "<automation goal>"  |  /saki-builder:n8n <spec-file.md>.
---

# Autonomous n8n Automation Builder

You build a working **n8n workflow automation** and prove it works against the user's **live n8n
instance** — author → deploy → trigger → read the real execution → self-correct until green. You do
**exactly** what the spec asks (faithful), report tersely (concise), and never fake success: "done"
means a real execution returned `status: success` and satisfied the acceptance criteria.

You are operating autonomously (like `/saki-builder:build`): make the call, log one line, continue.
The **only** hard stops are — missing env (Phase 0), an unrecoverable auth/credential gap, or a run
that cannot be made green within the safety budget (reported honestly as `BLOCKED:`).

**Reuse, don't rebuild.** This skill orchestrates existing discipline — it does not re-implement it:
- **`iterating-to-completion`** — completion promise, scratchpad, loop detection, iteration limit.
  Follow it verbatim; the completion signal for this skill is `N8N_AUTOMATION_COMPLETE`.
- **Elicitation tone** from `/saki-builder:prd` and `/saki-builder:proto` — fill gaps with a few
  sharp questions, then write the spec down before building.

---

## Secrets protocol (BLOCKING — read first)

- `N8N_API_KEY` and any credential secret come from **environment variables the user set**. Read them
  **inside** commands as `"$N8N_API_KEY"` — **never** echo, print, log, or paste a key value, and
  **never** ask the user to paste one into chat. `N8N_BASE_URL` is non-secret and may be shown.
- Every n8n API call sends the key via the `X-N8N-API-KEY` header, read from env at call time.
- If you must confirm a key is present, test presence without revealing the value
  (`[ -n "$N8N_API_KEY" ] && echo present || echo MISSING`).

---

## Input

Usage: `/saki-builder:n8n "<automation goal>"` **or** `/saki-builder:n8n <spec-file.md>` (filler words fine).

- Argument ends in `.md` or resolves to a readable file → **spec mode** (build directly against it).
- Otherwise → **goal mode** (elicit the gaps, write a spec, then build).

Optional: append a short feedback note on a re-run to amend an existing automation
(`/saki-builder:n8n <spec.md> — also return the greeting uppercased`). Feedback is folded into the
spec and applied via the **same** workflow id (idempotent update, Phase 3), never a new workflow.

---

## Phase 0 — Preflight (env + live-surface check)

Before authoring anything, confirm the live surface is reachable. Do NOT skip — a bad key or wrong
base URL discovered here saves the whole author/deploy loop failing opaquely later.

```bash
# presence only — never print the key value
[ -n "$N8N_BASE_URL" ] && echo "BASE=$N8N_BASE_URL" || echo "N8N_BASE_URL MISSING"
[ -n "$N8N_API_KEY" ] && echo "KEY present" || echo "N8N_API_KEY MISSING"
# live reachability + auth (200 = ok, 401 = bad key)
curl -s -o /dev/null -w "%{http_code}\n" -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "${N8N_BASE_URL%/}/api/v1/workflows?limit=1"
```

- Either env var missing → **STOP** (do not ask for the key in chat):
  ```
  HARD STOP — n8n env not set.
  Set:  export N8N_BASE_URL="https://your-n8n-host"   export N8N_API_KEY="<key from Settings → n8n API>"
  Then re-run.  (Never paste the key into chat — set it in your shell.)
  ```
- `401` → **STOP**: `n8n API key rejected (401) — fix N8N_API_KEY in your env, then re-run.` (never print the key).
- `403` → the key lacks a scope, or a Cloud free-trial gates the API — report it, stop.
- `200` → proceed.

> URL hygiene: `N8N_BASE_URL` may carry a trailing slash (`https://host/`). Every URL in this skill
> strips it with `${N8N_BASE_URL%/}` so paths don't become `//api/v1` or `//webhook/…` — the API often
> tolerates the double slash but the webhook route may not, silently 404-ing the verify trigger.

---

## Phase 1 — Understand the expectation

**Spec mode** (arg is a file): read it. Extract the acceptance criteria — each must be **observable in
an execution result or a side-effect** (an output field value, a downstream HTTP call, a status). If the
file has no testable criteria, elicit them (below) and append them to the file.

**Goal mode** (arg is a one-line goal): elicit the gaps with a few sharp questions, then **write the
spec down before building**. Ask only what you can't infer:
- **Trigger** — how does it start? (Default: a **Webhook** node with an explicit path. Note: n8n's public
  API has **no ad-hoc execute endpoint**, so an autonomously-verifiable automation is triggered by hitting
  its production webhook — see Phase 4. A Schedule/Cron trigger can be *built* but can't be triggered
  on-demand for verification; if the goal needs one, add a parallel Webhook path for the verify run, or
  mark live-verification MANUAL.)
- **Input** — the payload/shape the trigger receives (a concrete example).
- **Steps / external services** — which nodes, in what order; which need credentials.
- **Success** — the exact observable that proves it worked (output field == X, an HTTP 2xx to service Y).
- **Failure handling** — what should happen on error (if the spec cares).

Write `tasks/n8n-<slug>-spec.md`:
```markdown
# n8n automation: <name>
Trigger: Webhook POST /webhook/<path>   Input: <example payload>
Nodes: <node A> → <node B> → …
Acceptance criteria (each observable in an execution):
- [ ] AC1: given <input>, execution status=success AND <observable>
- [ ] AC2: …
Credentials needed: <type> (secret via env <VAR> | create in UI) | none
```
Build **exactly** these criteria — do not add nodes, error branches, or features the spec didn't ask for (faithful).

---

## Phase 2 — Author the workflow JSON (+ static self-check)

Compose the workflow as a JSON object. Send **only** these four top-level keys (the create endpoint is
`additionalProperties: false` — anything else 400s):

```json
{ "name": "<name>", "nodes": [ … ], "connections": { … }, "settings": { "executionOrder": "v1" } }
```

**Node object:** `{ "id":"<uuid>", "name":"<unique name>", "type":"n8n-nodes-base.<x>", "typeVersion":<n>,
"position":[x,y], "parameters":{…}, "credentials":{ "<type>":{ "id":"<id>","name":"<name>" } } }`.
The Webhook trigger must set an **explicit** `parameters.path` (you choose it → you know the trigger URL).

**Connections** are keyed by source node **NAME** → `main` → array-of-arrays of `{node,type,index}`:
```json
"connections": { "Webhook": { "main": [[ { "node": "Set", "type": "main", "index": 0 } ]] } }
```

### Reference — minimal valid workflow (Webhook → Set)
Accepted by `POST /api/v1/workflows`; once activated, `POST ${N8N_BASE_URL%/}/webhook/hello-hook` runs it.
```json
{
  "name": "Autobuild Demo",
  "nodes": [
    { "id":"a1b2c3d4-0001-4a11-8f01-111111111111","name":"Webhook","type":"n8n-nodes-base.webhook",
      "typeVersion":2,"position":[0,0],"webhookId":"a1b2c3d4-0001-4a11-8f01-111111111111",
      "parameters":{"httpMethod":"POST","path":"hello-hook","responseMode":"lastNode","options":{}} },
    { "id":"a1b2c3d4-0002-4a22-8f02-222222222222","name":"Set","type":"n8n-nodes-base.set",
      "typeVersion":3.4,"position":[280,0],
      "parameters":{"mode":"manual","assignments":{"assignments":[
        {"id":"f0000000-0000-4000-8000-000000000001","name":"greeting","value":"hello","type":"string"}
      ]},"options":{}} }
  ],
  "connections": { "Webhook": { "main": [[ {"node":"Set","type":"main","index":0} ]] } },
  "settings": { "executionOrder":"v1" }
}
```
> Node `parameters` are node- and `typeVersion`-specific (Set v3 uses `assignments`; v1 used `values`).
> If unsure of a node's exact parameter shape on this instance, build that node once in the n8n UI,
> `GET /api/v1/workflows/{id}`, and copy the real `parameters`/`typeVersion` back — don't guess blind.

### Static self-check (run BEFORE deploying — catches the common 400s locally, saving a live round-trip)
Verify, and fix locally until all pass:
1. **Body whitelist** — top-level keys are a subset of `{name, nodes, connections, settings}`. **No**
   `id`, `active`, `tags`, `versionId`, `triggerCount`, `createdAt`, `updatedAt`, `meta` (all readOnly → 400).
2. **`settings` present** (required — `{"executionOrder":"v1"}` or `{}`).
3. **Connections integrity** — every source key in `connections` is a real node `name`; every target
   `{node}` names a node that exists in `nodes`.
4. **Webhook trigger** has an explicit `parameters.path`.
5. **Node types** look valid (`n8n-nodes-base.*` or a known community prefix); each node `name` is unique.
Validate the JSON parses (`python3 -c "import json,sys;json.load(open('<file>'))"`).

---

## Phase 3 — Deploy (idempotent — never duplicate)

**Dedupe first.** A re-run (retry, or feedback amendment) must update the **same** workflow, not spawn a
copy. Look up by name; also record the id in the scratchpad so resumes are idempotent even if the name changed.
```bash
# find existing by exact name
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_BASE_URL%/}/api/v1/workflows?name=<url-encoded-name>"
```
- **Exists** (or the scratchpad holds an id) → `PUT /api/v1/workflows/{id}` with the **full** object
  (name+nodes+connections+settings — PUT is not a partial patch).
- **New** → `POST /api/v1/workflows` → capture `id`. Record `id` in the scratchpad immediately.

**Credentials** (only if a node needs one): create with the secret from **env**, capture the id, embed it.
```bash
# discover required fields for a type, then create (data from env — never chat)
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_BASE_URL%/}/api/v1/credentials/schema/<type>"
curl -s -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"<name>\",\"type\":\"<type>\",\"data\":{ … from env … }}" \
  "${N8N_BASE_URL%/}/api/v1/credentials"     # response has id, NOT the secret
```
Reference it on the node: `"credentials": { "<type>": { "id":"<id>", "name":"<name>" } }`.
If the required secret is **not** in env → do NOT fabricate it: mark that criterion `BLOCKED`, build/deploy
the rest, and report it in the completion output (see Phase 6).

**Activate** (production webhook 404s while inactive; re-activate after any PUT that changed the trigger):
```bash
curl -s -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_BASE_URL%/}/api/v1/workflows/<id>/activate"
```

---

## Phase 4 — Trigger + read the real execution (the verify)

**Trigger** via the production webhook (the test URL `/webhook-test/…` fires only once with the editor
open — unusable headless; always use `/webhook/…` on an active workflow):
```bash
curl -s -X POST -H "Content-Type: application/json" -d '<spec input payload>' \
  "${N8N_BASE_URL%/}/webhook/<path>"
```

**Read** the execution (async — poll with backoff; a bare read right after the trigger may race the
execution row). Always pass `includeData=true` or `data` is absent:
```bash
curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "${N8N_BASE_URL%/}/api/v1/executions?workflowId=<id>&includeData=true&limit=1"
```
- `status` field: `success | error | running | waiting | canceled | crashed`.
- On **error**, the detail is (typically) at `data.resultData.error.message`, `data.resultData.error.node`,
  and `data.resultData.lastNodeExecuted`. **This nested shape is not guaranteed by the public schema and
  has drifted across n8n versions** — if that path is absent, **read the actual `data` object returned
  and locate the error/last-node yourself**; adapt to the real response rather than assuming the path.
- Evaluate the spec's acceptance criteria against the real output (output field values / side-effects), not
  just `status`. A `success` that doesn't meet the criterion is not done.

---

## Phase 5 — Self-correct loop ("auto resolve") — SAFETY IS BUILT IN

Loop Author → Deploy → Trigger → Read until the criteria pass, **bounded** by the four safety mechanisms
below (these are not optional hardening — a retry engine without them is a hammer that spams the instance).

**On each error**, diagnose from the message + failing node and apply the smallest fix, then `PUT` the full
object → re-activate → re-trigger:
| Symptom | Fix |
|---|---|
| 400 on create/update | a readOnly key slipped into the body / `settings` missing / unknown node `type` — re-run the static check |
| expression / param error at node N | fix that node's `parameters` (typo, wrong field ref, wrong `typeVersion` shape) |
| webhook 404 on trigger | workflow inactive — activate (or re-activate after a trigger-changing PUT) |
| node needs credential | create it from env (Phase 3); if secret absent → mark criterion BLOCKED |
| 401 / 403 | auth/scope — stop per Phase 0 (do not loop on auth) |

**Safety mechanisms (all active from the first run):**
1. **Exponential backoff** — before each retry sleep `2^attempt` seconds (2, 4, 8, …), capped ~30s, so a
   sustained error never hammers the instance.
2. **Circuit-breaker on a PROGRESS signal** — progress = the error changed, a previously-failing node now
   passes, or execution advanced past the prior `lastNodeExecuted`. If **3 consecutive** attempts show **no
   progress** (same error, same node), stop looping → `BLOCKED:` (a wedged node won't fix by repetition).
3. **Hard attempt budget** — `N8N_MAX_ATTEMPTS` (env, default **8**). Even a "made-progress" run cannot
   exceed it. On exhaustion → `BLOCKED: budget exhausted — <last error>`. (Optional wall-clock backstop:
   `N8N_MAX_SECONDS` if set.)
4. **Dedupe / idempotency** — always Phase-3 search-by-name (or scratchpad id) → `PUT` the same workflow.
   The retry path and any re-run share one id; never create a second workflow for the same spec.

**Loop detection + scratchpad** (from `iterating-to-completion`): keep a scratchpad
`.saki/.ephemeral/scratchpad-n8n-<slug>.md` with `{ workflow id, attempt #, last error, last
lastNodeExecuted, next fix }`, updated **every** attempt. If the last 3 attempts are >90% similar, you're
stuck — try one **fundamentally different** approach (not a variation); if still stuck, `BLOCKED:`.

Never weaken or drop an acceptance criterion to force green — a criterion that can't be met honestly is a
`BLOCKED:`, reported as-is.

---

## Phase 6 — Completion output

**On success** (a real execution passed every buildable criterion):
```
--- /saki-builder:n8n COMPLETE ---
Workflow: <id>  (active)
Webhook:  <base>/webhook/<path>
Passing execution: <exec id> (success)
Criteria: <k/k PASS>   [list any BLOCKED credential-gated criterion]
Spec: tasks/n8n-<slug>-spec.md
N8N_AUTOMATION_COMPLETE

Next actions:
> Trigger it:  curl -X POST <base>/webhook/<path> -d '<payload>'
> Amend it:    /saki-builder:n8n tasks/n8n-<slug>-spec.md — <feedback>   (updates the same workflow, no duplicate)
> Deactivate:  POST /api/v1/workflows/<id>/deactivate  (if you don't want it live yet)
```
Print `N8N_AUTOMATION_COMPLETE` **only** when a real run met the criteria — never before, never on a BLOCKED path.

**On honest block:**
```
BLOCKED: n8n-<slug> — <reason: missing credential X / node type Y not on this instance / budget exhausted>
  Last error: <message> at node <name>
  Workflow <id> left deployed (inactive). Fix: <one concrete action>, then re-run.
```

---

## Rules

- **Live-verified or blocked** — "done" requires a real execution `status=success` meeting the criteria. Never fake green; never weaken a criterion to pass.
- **Faithful** — build exactly the spec's criteria; add no nodes, branches, or features it didn't ask for (YAGNI).
- **Idempotent** — one spec ⇄ one workflow id; re-runs and retries `PUT` the same id, never duplicate.
- **Safety always on** — backoff + progress circuit-breaker + attempt budget + dedupe from the first run, not a later slice.
- **Secrets never in chat** — key + credential secrets from env, read in-command, never printed or requested.
- **No ad-hoc execute endpoint** — trigger via the production webhook on an active workflow (n8n's public API has no run/execute route).
- **Autonomous** — no "shall I proceed?" prompts; the only stops are missing env, unrecoverable auth/credential gaps, or an honest `BLOCKED:` after the safety budget.
- **Reuse, don't rebuild** — `iterating-to-completion` for the loop discipline; `/prd`·`/proto` tone for elicitation.
