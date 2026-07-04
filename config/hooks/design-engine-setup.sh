#!/usr/bin/env bash
# design-engine-setup.sh — record + report a project's DESIGN ENGINE for
# /saki-builder:proto: "native" (render the real design system → HTML gallery,
# the canonical path /saki-builder:build reads) or "figma" (use a connected
# Figma design as a SOURCE via the Figma MCP, routed by seat capability).
#
# This script owns the RECORD FILE (.claude/design-engine.json) and reports the
# statically-checkable bits (the recorded choice + whether the repo even has a
# frontend to render natively). It CANNOT check the Figma MCP — that server is
# in-process to Claude with no CLI — so live Figma connection + seat verification
# is done by Claude calling the Figma MCP `whoami` tool inside /init-env; this
# script only stores what that check found.
#
# `detect` is READ-ONLY and always exits 0. `record` writes ONLY
# .claude/design-engine.json and exits non-zero only on an invalid --engine.
#
# Usage:
#   design-engine-setup.sh detect [--path DIR]
#   design-engine-setup.sh record --engine native|figma [--path DIR]
#            [--seat S] [--capability read|write] [--source URL] [--handle NAME]

set -u

FE_FRAMEWORKS='react|next|vue|nuxt|svelte|@angular|solid-js|astro|preact|remix'

# Escape a string for embedding in a JSON double-quoted value (\ and " only —
# Figma URLs / handles never contain control chars).
json_escape() {
	local s="$1"
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	printf '%s' "$s"
}

# yes if the repo has a frontend framework in package.json (native render needs one).
detect_frontend() {
	local pkg="$1/package.json"
	[ -f "$pkg" ] && grep -qE "\"($FE_FRAMEWORKS)" "$pkg" 2>/dev/null && printf 'yes' || printf 'no'
}

# Read one field from the record: jq when available, grep fallback otherwise.
read_field() {
	local file="$1" jq_filter="$2" grep_key="$3"
	[ -f "$file" ] || return 0
	if command -v jq >/dev/null 2>&1; then
		jq -r "$jq_filter // empty" "$file" 2>/dev/null
		return 0
	fi
	grep -oE "\"$grep_key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null |
		head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/'
}

emit_detect() {
	local status="$1" engine="$2" source="$3" seat="$4" cap="$5" frontend="$6" record="$7" note="$8"
	printf '<design-engine>\n'
	printf 'status: %s\n' "$status"
	printf 'engine: %s\n' "${engine:--}"
	printf 'figma_source: %s\n' "${source:--}"
	printf 'figma_seat: %s\n' "${seat:--}"
	printf 'figma_capability: %s\n' "${cap:--}"
	printf 'frontend: %s\n' "$frontend"
	printf 'record: %s\n' "$record"
	printf 'note: %s\n' "$note"
	printf '</design-engine>\n'
}

cmd_detect() {
	local path="${1:-.}"
	local record="$path/.claude/design-engine.json"
	local frontend
	frontend=$(detect_frontend "$path")

	if [ ! -f "$record" ]; then
		emit_detect "NONE" "" "" "" "" "$frontend" "$record" \
			"no design engine recorded — /init-env Step 1c should ask figma|native (default native)"
		return 0
	fi

	local engine source seat cap
	engine=$(read_field "$record" '.engine' 'engine')
	source=$(read_field "$record" '.figma.source' 'source')
	seat=$(read_field "$record" '.figma.seat' 'seat')
	cap=$(read_field "$record" '.figma.capability' 'capability')
	emit_detect "RECORDED" "$engine" "$source" "$seat" "$cap" "$frontend" "$record" \
		"proto Step 0 routes on this record"
}

write_record() {
	local path="$1" engine="$2" seat="$3" cap="$4" source="$5" handle="$6"
	local dir="$path/.claude"
	mkdir -p "$dir"
	local file="$dir/design-engine.json"
	local tmp="$file.tmp.$$"
	local now
	now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

	local figma='null'
	if [ "$engine" = "figma" ]; then
		figma=$(printf '{ "source": "%s", "seat": "%s", "capability": "%s", "handle": "%s" }' \
			"$(json_escape "$source")" "$(json_escape "$seat")" "$(json_escape "$cap")" "$(json_escape "$handle")")
	fi

	cat >"$tmp" <<EOF
{
  "engine": "$engine",
  "figma": $figma,
  "recordedBy": "design-engine-setup.sh",
  "recordedAt": "$now"
}
EOF
	mv "$tmp" "$file"
	printf 'recorded: engine=%s → %s\n' "$engine" "$file"
	cmd_detect "$path"
}

cmd_record() {
	local path="." engine="" seat="" cap="" source="" handle=""
	while [ $# -gt 0 ]; do
		case "$1" in
		--path) path="$2"; shift 2 ;;
		--engine) engine="$2"; shift 2 ;;
		--seat) seat="$2"; shift 2 ;;
		--capability) cap="$2"; shift 2 ;;
		--source) source="$2"; shift 2 ;;
		--handle) handle="$2"; shift 2 ;;
		*) printf 'unknown record arg: %s\n' "$1" >&2; return 2 ;;
		esac
	done

	if [ "$engine" != "native" ] && [ "$engine" != "figma" ]; then
		printf 'error: --engine must be native|figma (got: %s)\n' "${engine:-<empty>}" >&2
		return 2
	fi
	write_record "$path" "$engine" "$seat" "$cap" "$source" "$handle"
}

# Pull an optional `--path DIR` out of a detect invocation's args.
detect_path_from_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		--path) printf '%s' "$2"; return 0 ;;
		*) shift ;;
		esac
	done
	printf '.'
}

main() {
	local sub="${1:-}"
	[ $# -gt 0 ] && shift
	case "$sub" in
	detect) cmd_detect "$(detect_path_from_args "$@")" ;;
	record) cmd_record "$@" ;;
	*)
		printf 'usage: design-engine-setup.sh detect [--path DIR]\n' >&2
		printf '       design-engine-setup.sh record --engine native|figma [--path DIR] [--seat S] [--capability read|write] [--source URL] [--handle NAME]\n' >&2
		return 2
		;;
	esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	main "$@"
fi
