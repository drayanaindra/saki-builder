#!/usr/bin/env bash
# sonar-gate.sh — Block git push to main if SonarQube quality gate is not PASSED.
# Runs as PreToolUse:Bash hook.
#
# Token source:  ~/.sonar/sonarqube-cli/user
# Server source: ~/.sonar/sonarqube-cli/state.json (activeConnectionId → serverUrl)
# If SonarQube is unreachable: warns and allows push (infra failure ≠ code failure).

COMMAND="${CLAUDE_TOOL_INPUT_COMMAND:-}"

# Only trigger on git push targeting main/master
if ! echo "$COMMAND" | grep -qE 'git\s+push\b'; then
  exit 0
fi
if ! echo "$COMMAND" | grep -qE '\b(main|master)\b'; then
  exit 0
fi

# ─── Resolve SonarQube connection ────────────────────────────────────────────

STATE_FILE="$HOME/.sonar/sonarqube-cli/state.json"
TOKEN_FILE="$HOME/.sonar/sonarqube-cli/user"

SONAR_TOKEN="${SONAR_TOKEN:-$(cat "$TOKEN_FILE" 2>/dev/null)}"

# Read serverUrl for the active connection from state.json
if [ -f "$STATE_FILE" ] && [ -n "$(which python3 2>/dev/null)" ]; then
  SONAR_URL="$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    active_id = d.get('auth', {}).get('activeConnectionId', '')
    for conn in d.get('auth', {}).get('connections', []):
        if conn.get('id') == active_id:
            url = conn.get('serverUrl', '').rstrip('/')
            # Hook runs on host, not in Docker — remap host.docker.internal → localhost
            print(url.replace('host.docker.internal', 'localhost'))
            sys.exit(0)
    print('http://localhost:9000')
except Exception:
    print('http://localhost:9000')
" 2>/dev/null)"
fi
SONAR_URL="${SONAR_URL:-http://localhost:9000}"

# ─── Find project key ────────────────────────────────────────────────────────

find_sonar_props() {
  local dir="${PWD}"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/sonar-project.properties" ]; then
      echo "$dir/sonar-project.properties"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

SONAR_PROPS="$(find_sonar_props)"
if [ -z "$SONAR_PROPS" ]; then
  exit 0  # Not a SonarQube project — skip gate
fi

PROJECT_KEY="$(grep -E '^sonar\.projectKey=' "$SONAR_PROPS" | cut -d'=' -f2 | tr -d '[:space:]')"
if [ -z "$PROJECT_KEY" ]; then
  exit 0
fi

# ─── Call quality gate API ───────────────────────────────────────────────────

API_URL="${SONAR_URL}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}"

if [ -n "$SONAR_TOKEN" ]; then
  RESPONSE="$(curl -sf --max-time 10 -u "${SONAR_TOKEN}:" "$API_URL" 2>/dev/null)"
else
  RESPONSE="$(curl -sf --max-time 10 "$API_URL" 2>/dev/null)"
fi

if [ -z "$RESPONSE" ]; then
  echo "WARNING: SonarQube unreachable at ${SONAR_URL} — quality gate check skipped."
  exit 0
fi

STATUS="$(echo "$RESPONSE" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('projectStatus', {}).get('status', 'UNKNOWN'))
except Exception:
    print('UNKNOWN')
" 2>/dev/null)"

case "$STATUS" in
  OK)
    echo "SonarQube quality gate: PASSED for '${PROJECT_KEY}'"
    exit 0
    ;;
  NONE)
    echo "SonarQube quality gate: no gate configured for '${PROJECT_KEY}' — allowing push."
    exit 0
    ;;
  UNKNOWN)
    echo "WARNING: Could not parse SonarQube response — quality gate check skipped."
    exit 0
    ;;
  *)
    echo "BLOCKED: SonarQube quality gate is ${STATUS} for project '${PROJECT_KEY}'."
    echo ""
    echo "Resolve failing conditions before pushing to main:"
    echo "  /sonarqube:sonar-quality-gate   — see gate breakdown"
    echo "  /sonarqube:sonar-list-issues    — see blocking issues"
    echo ""
    echo "After fixing: re-run analysis, verify gate is PASSED, then push."
    echo "To push without this check, run the git command manually outside Claude Code."
    exit 1
    ;;
esac
