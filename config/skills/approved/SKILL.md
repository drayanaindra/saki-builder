---
name: approved
description: Approve the current plan and switch model to Sonnet. Use after reviewing a /plan output to begin implementation.
---

# Plan Approved — Switch to Sonnet

The user has reviewed and approved the current plan. Do the following in order:

## Step 1: Switch model to Sonnet

Run this bash command to update the model in settings:

```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude' / 'settings.json'
s = json.loads(p.read_text())
s['model'] = 'claude-sonnet-4-6'
p.write_text(json.dumps(s, indent=2))
print('Model set to claude-sonnet-4-6')
"
```

## Step 2: Confirm and proceed

After running the command, respond with:

```
Model: SONNET | Status: Approved — proceeding with implementation

Plan approved. Switching to Sonnet for implementation.
```

Then immediately begin executing the first uncompleted step from the active plan file (look for `[task]-plan.md` in the project root, or the most recently discussed plan).

## Rules

- Do NOT ask for further confirmation — the user has already approved
- Do NOT re-summarize the plan — just start step 1 of implementation
- If no active plan is found, ask: "Which plan should I implement?"
