#!/usr/bin/env bash
# test-recut-markdown.sh — grep-based verification that the Cluster 2 (senior-pm contract) and
# Cluster 4 (recut state-machine, redesigned) markdown behaviors are present in the skill/agent files.
# These are Test-After checks (the behavior is model-driven prose); the greps lock the load-bearing
# instructions so a future edit can't silently drop them. Run: bash config/hooks/test-recut-markdown.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PM="$ROOT/config/agents/senior-pm.md"
PICKUP="$ROOT/config/skills/pickup/SKILL.md"
ADD="$ROOT/config/skills/add/SKILL.md"
PGATE="$ROOT/config/hooks/pickup-completion-gate.sh"
RGATE="$ROOT/config/hooks/prd-review-completion-gate.sh"
PASS=0
FAIL=0

has() { # has <name> <file> <pattern>
	if grep -qE "$3" "$2" 2>/dev/null; then PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
	else FAIL=$((FAIL + 1)); printf '  FAIL %s  (pattern: %s)\n' "$1" "$3"; fi
}
absent() { # absent <name> <file> <pattern>  — must NOT match
	if grep -qE "$3" "$2" 2>/dev/null; then FAIL=$((FAIL + 1)); printf '  FAIL %s  (should be absent: %s)\n' "$1" "$3"
	else PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; fi
}

echo "recut markdown-contract tests"

# ── Cluster 2 — senior-pm MVP-Phasing Decision contract ────────────────────────
has "senior-pm: recut artifact-selector row" "$PM" 'Recut initiative into MVP \+ phases.*MVP-Phasing Decision'
has "senior-pm: MVP-Phasing Decision template" "$PM" '## MVP-Phasing Decision'
has "senior-pm: 5-field — Title" "$PM" '\*\*Title:\*\*'
has "senior-pm: 5-field — Goal (outcome)" "$PM" '\*\*Goal \(outcome\):\*\*'
has "senior-pm: 5-field — Target user & Job" "$PM" '\*\*Target user & Job'
has "senior-pm: 5-field — User flow" "$PM" '\*\*User flow'
has "senior-pm: 5-field — Success signal" "$PM" '\*\*Success signal:\*\*'
has "senior-pm: objective trigger required" "$PM" 'objective trigger'
has "senior-pm: decide-not-ask" "$PM" 'DECISION, not a discovery|Do NOT ask'
has "senior-pm: return inline" "$PM" 'INLINE in your final message'
has "senior-pm: never invent scope" "$PM" 'never invent new scope'

# ── Cluster 2/4 — pickup Phase 2b + GATE 0 ─────────────────────────────────────
has "pickup: /add --autonomous in Step 3" "$PICKUP" 'add --feature --autonomous'
has "pickup: one /add per turn MUST" "$PICKUP" 'one .{0,25}add.{0,20} per turn'
has "pickup: fan-out cap ≤5" "$PICKUP" 'Cap the fan-out at .* 5'
has "pickup: embed template verbatim in spawn" "$PICKUP" 'embed the exact output template verbatim'
has "pickup: corrective re-prompt" "$PICKUP" 're-prompt the senior-pm once, CORRECTIVELY'
has "pickup: once-guard compares active_slug" "$PICKUP" 'state\["slug"\].{0,10}recut.active_slug'
has "pickup: GATE 0 branches on recut.stage" "$PICKUP" 'recut.stage. == .phasing'
has "pickup: driving resumes CHILD from persisted seed" "$PICKUP" 'Resume the CHILD from the PERSISTED state seed'
has "pickup: no-recut ⇒ never a recut" "$PICKUP" 'no .recut. block is NEVER treated as a recut|absence . never a recut'
has "pickup: preserve slug on resume" "$PICKUP" 'PRESERVE the existing .slug'
has "pickup: sidecar-delete not rename" "$PICKUP" 'deleting the .gate.json sidecar in place|delete the sidecar in place|rm -f tasks/.pickup'
has "pickup: file never renamed" "$PICKUP" 'NEVER renamed|is never renamed'
has "pickup: recut.phases dedup" "$PICKUP" 'recut.phases\[\]'
has "pickup: no manual review.rounds bump" "$PICKUP" 'hand-bump .{0,15}rounds'

# ── Cluster 4 — add --autonomous + sanitize ────────────────────────────────────
has "add: --autonomous flag documented" "$ADD" 'autonomous'
has "add: strip bold markers (\\* removal)" "$ADD" 'replace..\*'
has "add: collapse whitespace" "$ADD" 'collapse ALL whitespace'
has "add: length cap" "$ADD" 'v\[:200\]|cap length'
has "add: Planned-only preserved" "$ADD" 'ALWAYS written.*Planned|status always .Planned'

# ── Cluster 1.5 — cross-hook CONTRACT note (both sides) ─────────────────────────
has "pickup-gate: CONTRACT note (reader)" "$PGATE" 'CONTRACT'
has "prd-review-gate: CONTRACT note (writer)" "$RGATE" 'CONTRACT'

echo "─────────────────────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
