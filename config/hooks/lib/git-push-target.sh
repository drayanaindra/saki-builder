#!/usr/bin/env bash
# git-push-target.sh — does this shell command push to the repo's default branch?
#
# Sourced by sonar-gate.sh and coverage-gate.sh, which both gate on "is this a push
# to main/master". Shared so the two can't drift.
#
# Why not `grep -qE 'git\s+push\b' && grep -qE '\b(main|master)\b'`, which is what
# both hooks used to do? That grep reads the whole command string, so it:
#   over-matched  — `git push origin feature/main-refactor` (branch name contains a
#                   word-bounded "main"), `git push --dry-run origin main` (pushes
#                   nothing), `git push origin v1.2.3 # cut from main` (tag + comment),
#                   `echo 'git push origin main'` and `grep 'git push origin main' log`
#                   (the phrase merely appears inside a quoted string);
#   under-matched — `git push` with no refspec, which is the MOST common way to push
#                   to main and never contains the word "main" at all.
# Both were dormant while the hooks were inert (they read a nonexistent env var, so the
# command was always empty). Making the hooks work made these live, hence this matcher.
#
# Public API:
#   command_pushes_to_default_branch "<command string>"  → 0 = yes (gate it), 1 = no
#
# Failure stance: this answers "should the gate evaluate", not "is this code good". When
# git isn't available or the ref can't be resolved, it falls back to the literal branch
# names main/master rather than erroring.

_gpt_default_branch_names() {
	# The remote's advertised default, plus main/master as a safety net — these hooks
	# are documented as guarding main/master specifically.
	local dir="${1:-$PWD}" detected
	detected="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
	detected="${detected#origin/}"
	printf '%s\n' "$detected" main master | grep -v '^$' | sort -u
}

# _gpt_is_default_branch NAME [DIR] → 0 when NAME is a default-branch name.
_gpt_is_default_branch() {
	local name="$1" dir="${2:-$PWD}"
	[ -n "$name" ] || return 1
	name="${name#+}"          # force-push marker
	name="${name#refs/heads/}"
	_gpt_default_branch_names "$dir" | grep -qxF "$name"
}

# _gpt_strip_quotes_and_comments STR → STR with quoted spans and #-comments removed.
# Quoted spans are dropped entirely, so a command that merely *mentions* a push in a
# string ("echo 'git push origin main'") no longer looks like one.
_gpt_strip_quotes_and_comments() {
	local s="$1" out="" quote="" c i n=${#1}
	for ((i = 0; i < n; i++)); do
		c="${s:i:1}"
		if [ -n "$quote" ]; then
			[ "$c" = "$quote" ] && quote=""
			continue
		fi
		case "$c" in
			"'" | '"') quote="$c" ;;
			'#') break ;;
			*) out+="$c" ;;
		esac
	done
	printf '%s' "$out"
}

# _gpt_segments STR → one shell command per line (split on && || ; | and newlines),
# so `make build && git push origin main` is judged on its second segment.
#
# awk, not sed: BSD sed (macOS) does not expand \n in a replacement — it inserts a
# literal "n", silently joining chained commands into one unrecognisable segment.
# `print` also guarantees the trailing newline that `while read` needs to see the
# last segment at all (read returns EOF on an unterminated line, skipping the body).
_gpt_segments() {
	printf '%s\n' "$1" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }'
}

# _gpt_push_args SEGMENT → prints the args following `git push`, one per line, or
# returns 1 when the segment isn't a git push. Skips env prefixes (FOO=bar) and git's
# global options (-C <dir>, -c <k=v>, --git-dir=...) so `git -C /repo push` still counts.
_gpt_push_args() {
	local -a tok
	read -r -a tok <<<"$1"
	local i=0 n=${#tok[@]}

	while [ $i -lt $n ] && [[ "${tok[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do i=$((i + 1)); done
	[ $i -lt $n ] || return 1
	case "${tok[$i]}" in
		git | */git) ;;
		*) return 1 ;;
	esac
	i=$((i + 1))

	while [ $i -lt $n ]; do
		case "${tok[$i]}" in
			-C | -c) i=$((i + 2)) ;;
			--git-dir=* | --work-tree=* | --namespace=* | --no-pager | -P) i=$((i + 1)) ;;
			*) break ;;
		esac
	done

	[ $i -lt $n ] && [ "${tok[$i]}" = "push" ] || return 1
	i=$((i + 1))
	while [ $i -lt $n ]; do
		printf '%s\n' "${tok[$i]}"
		i=$((i + 1))
	done
	return 0
}

# _gpt_current_branch_targets [DIR] → the default-branch-relevant names a bare
# `git push` would update: the current branch, and its upstream's remote branch
# (push.default=upstream means a locally-renamed branch can still land on main).
_gpt_current_branch_targets() {
	local dir="${1:-$PWD}"
	git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null
	git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null | sed 's#^[^/]*/##'
}

# push_command_cwd COMMAND → the directory the push would actually run in.
#
# `cd ~/other-repo && git push origin main` runs in ~/other-repo, but a hook's own PWD
# is wherever the shell happens to be. Judging the push against the shell's directory
# gates the wrong repository — it blocked a legitimate push to one repo by reading a
# different project's quality gate. `git -C <dir> push` wins over a preceding `cd`.
push_command_cwd() {
	local cleaned seg dir="$PWD" candidate
	cleaned="$(_gpt_strip_quotes_and_comments "${1:-}")"
	while IFS= read -r seg; do
		# shellcheck disable=SC2086
		set -- $seg
		[ $# -gt 0 ] || continue
		if [ "$1" = "cd" ] && [ -n "${2:-}" ]; then
			candidate="${2/#\~/$HOME}"
			case "$candidate" in
				/*) dir="$candidate" ;;
				*) dir="$dir/$candidate" ;;
			esac
		elif [ "$1" = "git" ] && [ "${2:-}" = "-C" ] && [ -n "${3:-}" ]; then
			candidate="${3/#\~/$HOME}"
			[ -d "$candidate" ] && dir="$candidate"
		fi
	done < <(_gpt_segments "$cleaned")
	[ -d "$dir" ] && printf '%s' "$dir" || printf '%s' "$PWD"
}

# _gpt_refspec_dst REFSPEC → the destination ref (right of ':', or the whole thing).
_gpt_refspec_dst() {
	local spec="${1#+}"
	case "$spec" in
		*:*) printf '%s' "${spec#*:}" ;;
		*) printf '%s' "$spec" ;;
	esac
}

# _gpt_segment_targets_default SEGMENT [DIR] → 0 when this one command pushes to a
# default branch, resolving refs against DIR (the repo the push runs in).
_gpt_segment_targets_default() {
	local args dir="${2:-$PWD}"
	args="$(_gpt_push_args "$1")" || return 1

	local -a positional=() flags=()
	local skip_value=0 a
	while IFS= read -r a; do
		[ -n "$a" ] || continue
		if [ "$skip_value" = "1" ]; then skip_value=0; continue; fi
		case "$a" in
			-o | --push-option | --repo | --receive-pack | --exec) flags+=("$a"); skip_value=1 ;;
			-*) flags+=("$a") ;;
			*) positional+=("$a") ;;
		esac
	done <<<"$args"

	# A dry run changes nothing on the remote — never gate it.
	printf '%s\n' "${flags[@]+"${flags[@]}"}" | grep -qxE -- '--dry-run|-n' && return 1

	# --all / --mirror push every branch, default branch included.
	printf '%s\n' "${flags[@]+"${flags[@]}"}" | grep -qxE -- '--all|--mirror' && return 0

	# positional[0] is the remote (git's own semantics); the rest are refspecs.
	local dst
	if [ "${#positional[@]}" -gt 1 ]; then
		local idx
		for ((idx = 1; idx < ${#positional[@]}; idx++)); do
			dst="$(_gpt_refspec_dst "${positional[$idx]}")"
			if [ "$dst" = "HEAD" ]; then
				local h
				while IFS= read -r h; do
					_gpt_is_default_branch "$h" "$dir" && return 0
				done < <(_gpt_current_branch_targets "$dir")
				continue
			fi
			_gpt_is_default_branch "$dst" "$dir" && return 0
		done
		return 1
	fi

	# No refspec: git pushes the current branch (or its upstream). This is the case the
	# old grep missed entirely — `git push` while sitting on main.
	local b
	while IFS= read -r b; do
		_gpt_is_default_branch "$b" "$dir" && return 0
	done < <(_gpt_current_branch_targets "$dir")
	return 1
}

# command_pushes_to_default_branch COMMAND → 0 when the command would update main/master.
command_pushes_to_default_branch() {
	local cleaned seg dir
	cleaned="$(_gpt_strip_quotes_and_comments "${1:-}")"
	[ -n "$cleaned" ] || return 1
	dir="$(push_command_cwd "${1:-}")"
	while IFS= read -r seg; do
		[ -n "$seg" ] || continue
		_gpt_segment_targets_default "$seg" "$dir" && return 0
	done < <(_gpt_segments "$cleaned")
	return 1
}
