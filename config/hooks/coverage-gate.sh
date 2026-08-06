#!/usr/bin/env bash
# coverage-gate.sh — Block git push to main if test coverage is below the floor.
# Runs as PreToolUse:Bash hook. Sibling of sonar-gate.sh (local backstop; works
# offline and before any SonarQube analysis has run).
#
# It READS the most recent coverage report an earlier test run / `/qa` produced —
# it never runs the test suite itself (too slow for a synchronous pre-push hook).
# Supported reports (first found, walking up from PWD, wins):
#   1. coverage/coverage-summary.json  — Jest/Vitest json-summary  (.total.lines.pct)
#   2. coverage.xml                    — Cobertura (pytest-cov, …)  (line-rate × 100)
#   3. coverage/lcov.info              — lcov (sum LH / sum LF × 100)
#   4. coverage.out                    — Go coverprofile (go tool cover -func total)
#
# Threshold: COVERAGE_MIN (default 80) — pass only when coverage > COVERAGE_MIN
#   (strict: exactly 80.0% blocks). Enforces the "test coverage must be > 80%" rule.
# COVERAGE_STRICT=1 → also block when NO report is found (can't prove ≥ floor).
#   Default (0) warns and allows, so repos without coverage tooling aren't bricked
#   (same "no signal ≠ code failure" stance as sonar-gate.sh).
#
# To push past this check intentionally, run the git command manually outside Claude Code.

# ─── Pure, testable helpers ──────────────────────────────────────────────────

# Shared push-target matcher (also used by sonar-gate.sh) — see lib/git-push-target.sh
# for why grepping the raw command string was wrong in both directions.
_COVERAGE_GATE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/git-push-target.sh"
if [ -r "$_COVERAGE_GATE_LIB" ]; then
	# shellcheck source=./lib/git-push-target.sh
	. "$_COVERAGE_GATE_LIB"
else
	echo "WARNING: coverage-gate: ${_COVERAGE_GATE_LIB} missing — cannot identify push target, allowing." >&2
	command_pushes_to_default_branch() { return 1; }
fi

# is_push_to_main COMMAND → 0 if the command would push to the default branch.
is_push_to_main() {
	command_pushes_to_default_branch "${1:-}"
}

# compare_gt ACTUAL MIN → 0 if ACTUAL > MIN (float-safe, strict), else 1.
compare_gt() {
	awk -v a="$1" -v m="$2" 'BEGIN { exit (a + 0 > m + 0) ? 0 : 1 }'
}

# parse_json_summary FILE → prints .total.lines.pct from a Jest/Vitest json-summary.
parse_json_summary() {
	python3 -c "
import json, sys
try:
    with open('$1') as f:
        d = json.load(f)
    print(d['total']['lines']['pct'])
except Exception:
    pass
" 2>/dev/null
}

# parse_cobertura FILE → prints the root line-rate as a percentage (0.857 → 85.70).
parse_cobertura() {
	local rate
	rate="$(grep -oE 'line-rate="[0-9.]+"' "$1" 2>/dev/null | head -1 | grep -oE '[0-9.]+')"
	[ -n "$rate" ] && awk -v r="$rate" 'BEGIN { printf "%.2f", r * 100 }'
}

# parse_lcov FILE → prints sum(LH)/sum(LF)*100 across all records.
parse_lcov() {
	awk -F: '
		/^LF:/ { f += $2 }
		/^LH:/ { h += $2 }
		END { if (f > 0) printf "%.2f", h / f * 100 }
	' "$1" 2>/dev/null
}

# parse_go_out FILE → prints the total statement coverage from a Go coverprofile.
# Uses `go tool cover -func` (instant — reads the profile, runs no tests).
parse_go_out() {
	command -v go >/dev/null 2>&1 || return 0
	go tool cover -func="$1" 2>/dev/null \
		| awk '/^total:/ { gsub(/%/, "", $NF); print $NF }'
}

# read_hook_command → prints the Bash command from the PreToolUse payload.
# The payload is JSON on stdin, with the command at .tool_input.command. There is no
# CLAUDE_TOOL_INPUT_COMMAND env var — relying on one left the command empty, so
# is_push_to_main never matched and this gate allowed every push. The env var is kept
# only as a fallback. `[ -t 0 ]` keeps a manual run from hanging on a terminal stdin.
read_hook_command() {
	if [ -n "${CLAUDE_TOOL_INPUT_COMMAND:-}" ]; then
		printf '%s' "$CLAUDE_TOOL_INPUT_COMMAND"
		return 0
	fi
	[ -t 0 ] && return 0
	command -v python3 >/dev/null 2>&1 || return 0
	python3 -c \
		'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' \
		2>/dev/null
}

# find_up REL_SUBPATH [START_DIR] → prints the first REL_SUBPATH found walking
# START_DIR (default PWD) → /. START_DIR is the repo the push runs in, not the shell's
# cwd, so `cd ~/other-repo && git push` reads that repo's coverage report.
find_up() {
	local rel="$1" dir="${2:-$PWD}"
	while [ "$dir" != "/" ]; do
		if [ -f "$dir/$rel" ]; then
			echo "$dir/$rel"
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	[ -f "/$rel" ] && { echo "/$rel"; return 0; }
	return 1
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
	local command
	command="$(read_hook_command)"
	is_push_to_main "$command" || return 0

	local min="${COVERAGE_MIN:-80}"
	local strict="${COVERAGE_STRICT:-0}"

	local repo
	repo="$(push_command_cwd "$command")"

	local file="" pct="" desc=""
	if file="$(find_up coverage/coverage-summary.json "$repo")"; then
		pct="$(parse_json_summary "$file")"; desc="coverage-summary.json"
	elif file="$(find_up coverage.xml "$repo")"; then
		pct="$(parse_cobertura "$file")"; desc="coverage.xml (Cobertura)"
	elif file="$(find_up coverage/lcov.info "$repo")"; then
		pct="$(parse_lcov "$file")"; desc="lcov.info"
	elif file="$(find_up coverage.out "$repo")"; then
		pct="$(parse_go_out "$file")"; desc="coverage.out (Go)"
	else
		file=""
	fi

	# No report found.
	if [ -z "$file" ]; then
		if [ "$strict" = "1" ]; then
			{
				echo "BLOCKED: no test-coverage report found and COVERAGE_STRICT=1."
				echo "Generate coverage (e.g. /saki-builder:qa, or your test runner with coverage on),"
				echo "then push. Looked for: coverage/coverage-summary.json, coverage.xml,"
				echo "coverage/lcov.info, coverage.out (from $PWD, walking up then down)."
			} >&2
			return 2
		fi
		echo "coverage-gate: no coverage report found — skipping (run /saki-builder:qa to generate one; set COVERAGE_STRICT=1 to require it)."
		return 0
	fi

	# Found a report but couldn't read a number — don't block on a parse failure.
	if [ -z "$pct" ]; then
		echo "WARNING: coverage-gate found $desc at $file but could not parse a percentage — skipping."
		return 0
	fi

	if compare_gt "$pct" "$min"; then
		printf 'coverage-gate: %s%% > %s%% (%s) — OK to push.\n' "$pct" "$min" "$desc"
		return 0
	fi

	# Exit 2 is the ONLY code that blocks a PreToolUse tool call (exit 1 is a
	# non-blocking error and the push proceeds), and on exit 2 stdout is discarded
	# while stderr is surfaced — so the whole message goes to stderr.
	{
		echo "BLOCKED: test coverage ${pct}% is not above the ${min}% floor (source: ${desc})."
		echo "  report: ${file}"
		echo ""
		echo "Raise coverage above ${min}% before pushing to main:"
		echo "  /saki-builder:qa            — add tests, re-run, and re-check the floor"
		echo ""
		echo "Threshold is COVERAGE_MIN (default 80). To push without this check,"
		echo "run the git command manually outside Claude Code."
	} >&2
	return 2
}

# Only run main when executed directly, so tests can `source` and unit-test the helpers.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	main "$@"
	exit $?
fi
