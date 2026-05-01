#!/usr/bin/env bash
# SessionStart hook: emits a tight <repo-context> block with high-signal
# repo state the Claude Code harness env-block doesn't already provide.
#
# Adds: top-level tree, branch ahead/behind vs upstream, stash count,
# top-level *-plan.md files. Deliberately omits cwd / branch / git status /
# recent commits — the harness already injects those.
#
# Always exits 0 so it never blocks session start.
# Hard output cap: 2000 chars.

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null)
SOURCE=$(jq -r '.source // "startup"' <<<"$INPUT" 2>/dev/null)

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
	exit 0
fi
case "$CWD" in
"$HOME" | "/" | "") exit 0 ;;
esac

cd "$CWD" 2>/dev/null || exit 0

# Top-level listing: non-hidden entries, dirs marked with /, capped at 20.
top=""
total=0
while IFS= read -r e; do
	total=$((total + 1))
	if [ "$total" -le 20 ]; then
		name="${e##*/}"
		[ -d "$e" ] && name="$name/"
		top="$top$name "
	fi
done < <(find . -maxdepth 1 -mindepth 1 ! -name '.*' 2>/dev/null | sort)
top="${top% }"
if [ "$total" -gt 20 ]; then
	top="$top (+$((total - 20)) more)"
fi

# Git info: branch tracking + stash. Only emit non-zero values (else it's noise).
remote_line=""
stash_line=""
if git rev-parse --git-dir >/dev/null 2>&1; then
	branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
	if [ -n "$branch" ]; then
		upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
		if [ -n "$upstream" ]; then
			ahead=$(git rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)
			behind=$(git rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)
			if [ "$ahead" != "0" ] || [ "$behind" != "0" ]; then
				remote_line="$branch → $upstream (↑$ahead ↓$behind)"
			fi
		fi
	fi
	stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
	if [ -n "$stash_count" ] && [ "$stash_count" -gt 0 ]; then
		stash_line="$stash_count"
	fi
fi

# Active plan files: top-level *-plan.md only (aligns with /rplan workflow).
plans_line=""
plans=$(find . -maxdepth 1 -name '*-plan.md' -type f 2>/dev/null | sort | sed 's|^\./||')
if [ -n "$plans" ]; then
	plans_line=$(echo "$plans" | paste -sd ',' - | sed 's/,/, /g')
fi

# Bail silently if there's nothing useful to say.
if [ -z "$top" ] && [ -z "$remote_line" ] && [ -z "$stash_line" ] && [ -z "$plans_line" ]; then
	exit 0
fi

# Build output.
output="<repo-context source=\"$SOURCE\">"
[ -n "$top" ] && output="$output"$'\n'"top: $top"
[ -n "$remote_line" ] && output="$output"$'\n'"remote: $remote_line"
[ -n "$stash_line" ] && output="$output"$'\n'"stash: $stash_line"
[ -n "$plans_line" ] && output="$output"$'\n'"plans: $plans_line"
output="$output"$'\n'"</repo-context>"

# Hard cap: truncate gracefully if somehow over 2000 chars.
if [ "${#output}" -gt 2000 ]; then
	output="${output:0:1980}…
</repo-context>"
fi

printf '%s\n' "$output"
exit 0
