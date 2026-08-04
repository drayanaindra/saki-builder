#!/usr/bin/env bash
# sonar-gate.sh — Block git push to main if SonarQube quality gate is not PASSED.
# Runs as PreToolUse:Bash hook.
#
# Token source:  ~/.sonar/sonarqube-cli/user
# Server source: ~/.sonar/sonarqube-cli/state.json (activeConnectionId → serverUrl)
# If SonarQube is unreachable: warns and allows push (infra failure ≠ code failure).

# ─── Read the command being run ──────────────────────────────────────────────
# PreToolUse hooks receive their payload as JSON on stdin; the Bash command lives at
# .tool_input.command. There is no CLAUDE_TOOL_INPUT_COMMAND env var — relying on one
# left COMMAND empty, so the grep below never matched and this gate allowed every push.
# `[ -t 0 ]` keeps a manual run from hanging on a terminal stdin.
STDIN_JSON=""
[ -t 0 ] || STDIN_JSON="$(cat 2>/dev/null)"

COMMAND="${CLAUDE_TOOL_INPUT_COMMAND:-}"
if [ -z "$COMMAND" ] && [ -n "$STDIN_JSON" ] && command -v python3 >/dev/null 2>&1; then
  COMMAND="$(printf '%s' "$STDIN_JSON" | python3 -c \
    'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
fi

# Only trigger on a git push that would actually update main/master. The matcher is
# shared with coverage-gate.sh so the two gates can never disagree about what counts.
_GATE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/git-push-target.sh"
if [ ! -r "$_GATE_LIB" ]; then
  echo "WARNING: sonar-gate: ${_GATE_LIB} missing — cannot identify push target, allowing." >&2
  exit 0
fi
# shellcheck source=./lib/git-push-target.sh
. "$_GATE_LIB"

command_pushes_to_default_branch "$COMMAND" || exit 0

# ─── Resolve SonarQube connection ────────────────────────────────────────────

STATE_FILE="$HOME/.sonar/sonarqube-cli/state.json"
TOKEN_FILE="$HOME/.sonar/sonarqube-cli/user"

# Token: env var > keychain (sonarqube-cli) > keychain (sonar-token) > file fallback
SONAR_TOKEN="${SONAR_TOKEN:-}"
if [ -z "$SONAR_TOKEN" ]; then
  SONAR_TOKEN="$(security find-generic-password -s "sonarqube-cli" -w 2>/dev/null || true)"
fi
if [ -z "$SONAR_TOKEN" ]; then
  SONAR_TOKEN="$(security find-generic-password -s "sonar-token" -w 2>/dev/null || true)"
fi
if [ -z "$SONAR_TOKEN" ]; then
  SONAR_TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null)"
fi

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
  # Walk up from the repo the PUSH runs in, not from the shell's cwd — otherwise
  # `cd ~/other-repo && git push origin main` is gated against whatever project the
  # shell happened to be sitting in.
  local dir="${1:-$PWD}"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/sonar-project.properties" ]; then
      echo "$dir/sonar-project.properties"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

SONAR_PROPS="$(find_sonar_props "$(push_command_cwd "$COMMAND")")"
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
    # Exit 2 is the ONLY code that blocks a PreToolUse tool call; exit 1 is a
    # non-blocking error and the push would proceed. On exit 2 stdout is discarded
    # and stderr is what gets surfaced — so the whole message goes to stderr.
    {
      echo "BLOCKED: SonarQube quality gate is ${STATUS} for project '${PROJECT_KEY}'."
      echo ""
      echo "Resolve failing conditions before pushing to main:"
      echo "  /sonarqube:sonar-quality-gate   — see gate breakdown"
      echo "  /sonarqube:sonar-list-issues    — see blocking issues"
      echo ""
      echo "After fixing: re-run analysis, verify gate is PASSED, then push."
      echo "To push without this check, run the git command manually outside Claude Code."
    } >&2
    exit 2
    ;;
esac
