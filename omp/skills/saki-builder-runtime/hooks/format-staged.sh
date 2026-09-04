#!/usr/bin/env bash
# format-staged.sh — PreToolUse(Bash) hook. Just before `git commit`, format the STAGED
# code files in place and re-stage them, so commits (and the push-time SonarQube gate) see
# consistently-formatted code.
#
# Why not format-on-every-edit (PostToolUse:Write|Edit)? An adversarial pressure-test showed
# that reformatting a file right after the model writes it desyncs the model's view of the file,
# so the next Edit's exact-match old_string fails — during the edit-heavy /build flow. Formatting
# at commit time (after edits are done) avoids that entirely.
#
# Safety (best-effort; NEVER blocks the commit — always exit 0):
#   - acts only on `git commit`;
#   - canonical formatters (gofmt/rustfmt) always; opinionated ones (prettier/black/ruff) ONLY
#     when a project config is found — so it never imposes a style a project didn't opt into;
#   - code files only (no md/json/yaml → no doc/fixture/snapshot churn);
#   - re-stages only the files it actually changed (compared by git hash-object);
#   - FORMAT_STAGED_DISABLE=1 to turn off.
set -u
[ "${FORMAT_STAGED_DISABLE:-0}" = "1" ] && exit 0

STDIN_JSON="$(cat 2>/dev/null)"
COMMAND="${CLAUDE_TOOL_INPUT_COMMAND:-}"
if [ -z "$COMMAND" ] && [ -n "$STDIN_JSON" ] && command -v python3 >/dev/null 2>&1; then
	COMMAND="$(printf '%s' "$STDIN_JSON" | python3 -c \
		'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
fi
echo "$COMMAND" | grep -qE '\bgit\b.*\bcommit\b' || exit 0 # only on git commit

command -v git >/dev/null 2>&1 || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0
STAGED="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)"
[ -z "$STAGED" ] && exit 0

has() { command -v "$1" >/dev/null 2>&1; }
changed=0
while IFS= read -r f; do
	[ -z "$f" ] && continue
	[ -f "$f" ] || continue
	before="$(git hash-object -- "$f" 2>/dev/null)"
	case "${f##*.}" in
	js | jsx | ts | tsx | mjs | cjs | css | scss | less)
		if has prettier && [ -n "$(prettier --find-config-path "$f" 2>/dev/null)" ]; then
			prettier --write -- "$f" >/dev/null 2>&1
		fi
		;;
	py)
		if has ruff && { [ -e pyproject.toml ] || [ -e ruff.toml ] || [ -e .ruff.toml ]; }; then
			ruff format -- "$f" >/dev/null 2>&1
		elif has black && { [ -e pyproject.toml ] || [ -e setup.cfg ]; }; then
			black -q -- "$f" >/dev/null 2>&1
		fi
		;;
	go) has gofmt && gofmt -w "$f" >/dev/null 2>&1 ;;
	rs) has rustfmt && rustfmt "$f" >/dev/null 2>&1 ;;
	esac
	after="$(git hash-object -- "$f" 2>/dev/null)"
	if [ -n "$before" ] && [ "$before" != "$after" ]; then
		git add -- "$f" >/dev/null 2>&1 && changed=$((changed + 1))
	fi
done <<EOF
$STAGED
EOF
[ "$changed" -gt 0 ] && echo "format-staged: reformatted & re-staged $changed file(s) before commit." >&2
exit 0
