#!/usr/bin/env bash
# sonar-gate-init.sh — Show live quality gate targets at session start for SonarQube projects.
# SessionStart hook (empty matcher = fires every session).
# Silently exits if no sonar-project.properties found (not a SonarQube project).

find_sonar_props() {
  local dir="${PWD}"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/sonar-project.properties" ] && echo "$dir/sonar-project.properties" && return 0
    dir="$(dirname "$dir")"
  done
  return 1
}

SONAR_PROPS="$(find_sonar_props)"
[ -z "$SONAR_PROPS" ] && exit 0

PROJECT_KEY="$(grep -E '^sonar\.projectKey=' "$SONAR_PROPS" | cut -d'=' -f2 | tr -d '[:space:]')"
[ -z "$PROJECT_KEY" ] && exit 0

# ─── Resolve SonarQube connection (same logic as sonar-gate.sh) ──────────────
STATE_FILE="$HOME/.sonar/sonarqube-cli/state.json"
TOKEN_FILE="$HOME/.sonar/sonarqube-cli/user"
SONAR_TOKEN="${SONAR_TOKEN:-$(cat "$TOKEN_FILE" 2>/dev/null)}"

if [ -f "$STATE_FILE" ]; then
  SONAR_URL="$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    aid = d.get('auth', {}).get('activeConnectionId', '')
    for c in d.get('auth', {}).get('connections', []):
        if c.get('id') == aid:
            print(c.get('serverUrl', 'http://localhost:9000').rstrip('/').replace('host.docker.internal','localhost'))
            sys.exit(0)
except: pass
print('http://localhost:9000')
" 2>/dev/null)"
fi
SONAR_URL="${SONAR_URL:-http://localhost:9000}"

# ─── Fetch gate data ──────────────────────────────────────────────────────────
_sq_curl() {
  if [ -n "$SONAR_TOKEN" ]; then
    curl -sf --max-time 8 -u "${SONAR_TOKEN}:" "$1" 2>/dev/null
  else
    curl -sf --max-time 8 "$1" 2>/dev/null
  fi
}

TMP_STATUS="$(mktemp)"
TMP_GATE="$(mktemp)"
trap "rm -f $TMP_STATUS $TMP_GATE" EXIT

_sq_curl "${SONAR_URL}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" > "$TMP_STATUS"

if [ ! -s "$TMP_STATUS" ]; then
  echo "[SonarQube] '$PROJECT_KEY' detected — server unreachable at ${SONAR_URL} (gate check skipped)"
  exit 0
fi

_sq_curl "${SONAR_URL}/api/qualitygates/get_by_project?project=${PROJECT_KEY}" > "$TMP_GATE"

# ─── Display ──────────────────────────────────────────────────────────────────
python3 - "$TMP_STATUS" "$TMP_GATE" "$PROJECT_KEY" << 'PYEOF'
import json, sys

status_file, gate_file, project_key = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(status_file) as f:
        ps = json.load(f).get('projectStatus', {})
except Exception as e:
    print(f"[SonarQube] Could not parse gate status: {e}")
    sys.exit(0)

overall   = ps.get('status', 'UNKNOWN')
period    = ps.get('period', {})
conditions = ps.get('conditions', [])

gate_name = 'unknown'
try:
    with open(gate_file) as f:
        gate_name = json.load(f).get('qualityGate', {}).get('name', 'unknown')
except:
    pass

status_icon = {"OK": "✅ PASSED", "ERROR": "❌ FAILED", "WARN": "⚠️  WARNING", "NONE": "⬜ NONE"}.get(overall, f"❓ {overall}")
cicon       = {"OK": "✅", "ERROR": "❌", "NO_VALUE": "⬜", "WARN": "⚠️ "}
op_label    = {"LT": "<", "GT": ">", "EQ": "=", "NE": "≠"}

W = 62
print()
print("─" * W)
print(f"  SonarQube  ·  {gate_name}  ·  {status_icon}")
print(f"  Project: {project_key}")
if period:
    mode = period.get('mode', '')
    date = period.get('date', '')[:10]
    print(f"  New-code period: {mode}  {date}")
print("─" * W)

if not conditions:
    print("  No conditions configured on this gate.")
else:
    for c in conditions:
        metric    = c.get('metricKey', '').replace('_', ' ').title()
        op        = op_label.get(c.get('comparator', ''), c.get('comparator', '?'))
        threshold = c.get('errorThreshold', '?')
        actual    = c.get('actualValue', 'N/A')
        cstatus   = c.get('status', '?')
        icon      = cicon.get(cstatus, '❓')
        print(f"  {icon}  {metric:<36}  {actual:>8}  (must be {op} {threshold})")

print("─" * W)
if overall == "ERROR":
    print("  Fix failing conditions before pushing to main.")
    print("  Run /sonarqube:sonar-list-issues to see blocking issues.")
elif overall == "OK":
    print("  Gate is passing — keep these metrics green.")
print()
PYEOF
