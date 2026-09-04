#!/usr/bin/env bash
# sonar-gate-init.sh — Show live quality gate targets at session start for SonarQube projects.
# SessionStart hook (empty matcher = fires every session).
# Handles single-project repos and monorepos (scans 1 level down when none found up).
# Silently exits if no sonar-project.properties found.

# ─── Collect sonar-project.properties files ──────────────────────────────────

collect_props_files() {
  # 1. Walk UP from PWD (single-project repo launched from anywhere inside it)
  local dir="${PWD}"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/sonar-project.properties" ]; then
      echo "$dir/sonar-project.properties"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # 2. Scan 1 level DOWN (monorepo launched from workspace root)
  for f in "${PWD}"/*/sonar-project.properties; do
    [ -f "$f" ] && echo "$f"
  done
}

PROPS_LIST="$(collect_props_files)"
[ -z "$PROPS_LIST" ] && exit 0
IFS=$'\n' read -r -d '' -a PROPS_FILES <<< "$PROPS_LIST" || true
[ ${#PROPS_FILES[@]} -eq 0 ] && exit 0

# ─── Resolve SonarQube connection ────────────────────────────────────────────

STATE_FILE="$HOME/.sonar/sonarqube-cli/state.json"

# Token: env var > keychain (sonarqube-cli) > keychain (sonar-token) > file fallbacks
SONAR_TOKEN="${SONAR_TOKEN:-}"
if [ -z "$SONAR_TOKEN" ]; then
  SONAR_TOKEN="$(security find-generic-password -s "sonarqube-cli" -w 2>/dev/null || true)"
fi
if [ -z "$SONAR_TOKEN" ]; then
  SONAR_TOKEN="$(security find-generic-password -s "sonar-token" -w 2>/dev/null || true)"
fi
if [ -z "$SONAR_TOKEN" ] && [ -f "$HOME/.sonar/sonarqube-cli/user" ]; then
  SONAR_TOKEN="$(cat "$HOME/.sonar/sonarqube-cli/user" 2>/dev/null)"
fi
if [ -z "$SONAR_TOKEN" ] && [ -f "$HOME/.sonar/user" ]; then
  SONAR_TOKEN="$(cat "$HOME/.sonar/user" 2>/dev/null)"
fi

# Server URL: state.json connections > macOS keychain (sonarqube-cli account) > default
SONAR_URL="http://localhost:9000"
_URL_FROM_STATE=0
if [ -f "$STATE_FILE" ]; then
  _URL="$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    aid = d.get('auth', {}).get('activeConnectionId', '')
    for c in d.get('auth', {}).get('connections', []):
        if c.get('id') == aid:
            print(c.get('serverUrl', '').rstrip('/').replace('host.docker.internal','localhost'))
            sys.exit(0)
except: pass
" 2>/dev/null)"
  if [ -n "$_URL" ]; then SONAR_URL="$_URL"; _URL_FROM_STATE=1; fi
fi
# Fallback: read server URL from macOS keychain (account field = server hostname).
# ONLY when state.json gave no explicit active-connection URL — otherwise an explicit
# localhost connection (equal to the default literal) would be wrongly overridden here.
if [ "$_URL_FROM_STATE" = "0" ]; then
  _KCH_ACCT="$(security find-generic-password -s "sonarqube-cli" -g 2>&1 | grep '"acct"' | sed 's/.*<blob>="\(.*\)"/\1/' || true)"
  if [ -n "$_KCH_ACCT" ]; then
    # account stores the bare hostname; assume https unless it looks like localhost
    if echo "$_KCH_ACCT" | grep -qE '^(localhost|127\.)'; then
      SONAR_URL="http://${_KCH_ACCT}"
    else
      SONAR_URL="https://${_KCH_ACCT}"
    fi
  fi
fi

# ─── API helper: returns body + writes HTTP code to a temp file ───────────────

_sq_api() {
  local url="$1" code_file="$2"
  if [ -n "$SONAR_TOKEN" ]; then
    curl -s --max-time 8 -u "${SONAR_TOKEN}:" -w "%{http_code}" \
      -o "${code_file}.body" "$url" 2>/dev/null > "$code_file"
  else
    curl -s --max-time 8 -w "%{http_code}" \
      -o "${code_file}.body" "$url" 2>/dev/null > "$code_file"
  fi
}

# ─── Server reachability check ────────────────────────────────────────────────

TMP_PING="$(mktemp)"
_sq_api "${SONAR_URL}/api/system/status" "$TMP_PING"
PING_CODE="$(cat "$TMP_PING" 2>/dev/null)"
rm -f "$TMP_PING" "${TMP_PING}.body"

if [ -z "$PING_CODE" ] || [ "$PING_CODE" = "000" ]; then
  KEYS=()
  for props in "${PROPS_FILES[@]}"; do
    key="$(grep -E '^sonar\.projectKey=' "$props" | cut -d'=' -f2 | tr -d '[:space:]')"
    [ -n "$key" ] && KEYS+=("$key")
  done
  echo "[SonarQube] ${#KEYS[@]} project(s) detected ($(IFS=', '; echo "${KEYS[*]}")) — server unreachable at ${SONAR_URL}"
  exit 0
fi

# ─── Display gate for each project ───────────────────────────────────────────

FIRST=1
for props in "${PROPS_FILES[@]}"; do
  PROJECT_KEY="$(grep -E '^sonar\.projectKey=' "$props" | cut -d'=' -f2 | tr -d '[:space:]')"
  [ -z "$PROJECT_KEY" ] && continue

  TMP_STATUS="$(mktemp)"
  TMP_GATE="$(mktemp)"
  trap "rm -f ${TMP_STATUS} ${TMP_STATUS}.body ${TMP_GATE} ${TMP_GATE}.body" EXIT

  _sq_api "${SONAR_URL}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" "$TMP_STATUS"
  STATUS_CODE="$(cat "$TMP_STATUS" 2>/dev/null)"
  STATUS_BODY="${TMP_STATUS}.body"

  if [ "$STATUS_CODE" = "401" ] || [ "$STATUS_CODE" = "403" ]; then
    if [ "$FIRST" = "1" ]; then
      echo ""
      echo "──────────────────────────────────────────────────────────────"
      echo "  SonarQube: server is running but authentication is required."
      echo "  Run:  ! sonar auth login -s ${SONAR_URL}"
      echo "  Or set SONAR_TOKEN env var for headless/CI use."
      echo "──────────────────────────────────────────────────────────────"
      echo ""
      FIRST=0
    fi
    rm -f "$TMP_STATUS" "${TMP_STATUS}.body" "$TMP_GATE" "${TMP_GATE}.body"
    continue
  fi

  if [ "$STATUS_CODE" != "200" ]; then
    echo "[SonarQube] '$PROJECT_KEY': unexpected HTTP ${STATUS_CODE} from gate API"
    rm -f "$TMP_STATUS" "${TMP_STATUS}.body" "$TMP_GATE" "${TMP_GATE}.body"
    continue
  fi

  _sq_api "${SONAR_URL}/api/qualitygates/get_by_project?project=${PROJECT_KEY}" "$TMP_GATE"

  python3 - "$STATUS_BODY" "${TMP_GATE}.body" "$PROJECT_KEY" << 'PYEOF'
import json, sys

status_file, gate_file, project_key = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(status_file) as f:
        ps = json.load(f).get('projectStatus', {})
except Exception as e:
    print(f"[SonarQube] Could not parse gate status for {project_key}: {e}")
    sys.exit(0)

overall    = ps.get('status', 'UNKNOWN')
period     = ps.get('period', {})
conditions = ps.get('conditions', [])

gate_name = 'unknown'
try:
    with open(gate_file) as f:
        gate_name = json.load(f).get('qualityGate', {}).get('name', 'unknown')
except:
    pass

status_label = {"OK": "✅ PASSED", "ERROR": "❌ FAILED", "WARN": "⚠️  WARNING", "NONE": "⬜ NONE"}.get(overall, f"❓ {overall}")
cicon        = {"OK": "✅", "ERROR": "❌", "NO_VALUE": "⬜", "WARN": "⚠️ "}
# comparator is the ERROR condition; flip it to show the PASS requirement
# LT = error when metric < threshold → must be >= threshold
# GT = error when metric > threshold → must be <= threshold
op_label     = {"LT": "≥", "GT": "≤", "EQ": "=", "NE": "≠"}

W = 62
print()
print("─" * W)
print(f"  SonarQube  ·  {gate_name}  ·  {status_label}")
print(f"  Project: {project_key}")
if period:
    mode = period.get('mode', '')
    date = period.get('date', '')[:10]
    if mode:
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
    print("  /sonarqube:sonar-list-issues  — see blocking issues")
elif overall == "OK":
    print("  Gate is passing — keep these metrics green while developing.")
print()
PYEOF

  rm -f "$TMP_STATUS" "${TMP_STATUS}.body" "$TMP_GATE" "${TMP_GATE}.body"
  FIRST=0
done
