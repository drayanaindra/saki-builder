#!/usr/bin/env bash
# repo-auth-setup.sh — Detect the git host of a repo, map it to its provider CLI
# (gh for GitHub, glab for GitLab), and report whether that CLI is installed and
# authenticated — so /init-env (or a human) can secure full MR/PR/commit/review
# access for the project.
#
# READ-ONLY + advisory. It NEVER logs in, installs, or writes anything: it only
# inspects `git remote` + `<cli> auth status` and prints a <repo-auth> block with
# the exact next command to run. Always exits 0 so it can't block a caller.
#
# Login (`gh|glab auth login`) is interactive and MUST be run by the human, so no
# token ever passes through Claude's chat context (the secrets rule). This script
# only tells you which command to run.
#
# Usage:
#   repo-auth-setup.sh [path] [override_host]
#     path           repo dir to inspect            (default: current directory)
#     override_host  skip remote detection, use     (for a fresh repo once the
#                    this host instead               user has picked a provider)

set -u

INSTALL_HINT_GH="brew install gh"
INSTALL_HINT_GLAB="brew install glab"

# Extract the bare hostname from any git remote URL form (scp-SSH, ssh://, https).
extract_host() {
	local url="$1"
	case "$url" in
	git@*)
		url="${url#git@}"
		printf '%s' "${url%%:*}"
		;;
	ssh://* | http://* | https://*)
		url="${url#*://}" # strip scheme
		url="${url#*@}"   # strip any user@
		url="${url%%/*}"  # strip path
		printf '%s' "${url%%:*}" # strip :port
		;;
	*)
		printf '%s' ""
		;;
	esac
}

# Map a host to "provider cli". Unknown hosts return "unknown -".
classify() {
	case "$1" in
	*github*) printf 'github gh' ;;
	*gitlab*) printf 'gitlab glab' ;;
	*) printf 'unknown -' ;;
	esac
}

# 0 if the CLI reports an authenticated session for this host, non-zero otherwise.
check_auth() {
	"$1" auth status --hostname "$2" >/dev/null 2>&1
}

# Best-effort account name — greps only the "as USER" / "account USER" fragment,
# so a token is never echoed. Empty if it can't be parsed.
get_account() {
	"$1" auth status --hostname "$2" 2>&1 |
		grep -oE '(as|account) [A-Za-z0-9._-]+' |
		head -1 | awk '{print $2}'
}

install_hint() {
	[ "$1" = "gh" ] && printf '%s' "$INSTALL_HINT_GH" || printf '%s' "$INSTALL_HINT_GLAB"
}

# Resolve the remote URL: prefer origin, else the first remote.
resolve_remote_url() {
	local url first
	url=$(git remote get-url origin 2>/dev/null)
	if [ -z "$url" ]; then
		first=$(git remote 2>/dev/null | head -1)
		[ -n "$first" ] && url=$(git remote get-url "$first" 2>/dev/null)
	fi
	printf '%s' "$url"
}

emit() {
	printf '<repo-auth>\n'
	printf 'status: %s\n' "$1"
	printf 'provider: %s\n' "$2"
	printf 'host: %s\n' "$3"
	printf 'cli: %s\n' "$4"
	printf 'cli_installed: %s\n' "$5"
	printf 'authed: %s\n' "$6"
	[ -n "$7" ] && printf 'account: %s\n' "$7"
	printf 'action: %s\n' "$8"
	printf 'note: %s\n' "$9"
	printf '</repo-auth>\n'
}

main() {
	local path="${1:-.}"
	local override_host="${2:-}"

	cd "$path" 2>/dev/null || {
		emit "NO_REMOTE" "none" "" "-" "n/a" "n/a" "" \
			"cd into a valid repo directory" \
			"path '$path' is not a directory"
		return 0
	}

	local host="$override_host"
	[ -z "$host" ] && host=$(extract_host "$(resolve_remote_url)")

	if [ -z "$host" ]; then
		emit "NO_REMOTE" "none" "" "-" "n/a" "n/a" "" \
			"ask which provider to use, then set the remote + log in" \
			"no git remote found — this looks like a fresh project"
		return 0
	fi

	local provider cli
	read -r provider cli <<<"$(classify "$host")"

	if [ "$provider" = "unknown" ]; then
		emit "UNKNOWN_HOST" "unknown" "$host" "-" "n/a" "n/a" "" \
			"ask the user whether $host is GitHub or GitLab, then use gh/glab" \
			"host '$host' is not recognizably github/gitlab (self-hosted?)"
		return 0
	fi

	if ! command -v "$cli" >/dev/null 2>&1; then
		emit "NEEDS_INSTALL" "$provider" "$host" "$cli" "no" "no" "" \
			"$(install_hint "$cli")" \
			"run it yourself with \`! $(install_hint "$cli")\`, then re-run this script"
		return 0
	fi

	if check_auth "$cli" "$host"; then
		emit "READY" "$provider" "$host" "$cli" "yes" "yes" "$(get_account "$cli" "$host")" \
			"$cli mr list  # (or: $cli pr list) — verify MR/commit/review access" \
			"full access ready — no login needed"
		return 0
	fi

	emit "NEEDS_LOGIN" "$provider" "$host" "$cli" "yes" "no" "" \
		"$cli auth login --hostname $host" \
		"run it yourself with \`! $cli auth login --hostname $host\` — never paste the token into chat"
	return 0
}

# Only run main when executed directly, so tests can `source` and unit-test the helpers.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	main "$@"
fi
