#!/usr/bin/env bash
# test-repo-auth-setup.sh — unit tests for repo-auth-setup.sh's pure helpers
# (host extraction + provider classification). No real auth/network needed.

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./repo-auth-setup.sh
source "$DIR/repo-auth-setup.sh"

pass=0
fail=0

check() {
	local label="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf '  ✗ %s\n      expected: [%s]\n      actual:   [%s]\n' "$label" "$expected" "$actual"
	fi
}

echo "extract_host:"
check "github ssh scp"   "github.com"                 "$(extract_host 'git@github.com:acme/app.git')"
check "github https"     "github.com"                 "$(extract_host 'https://github.com/acme/app.git')"
check "gitlab.com scp"   "gitlab.com"                 "$(extract_host 'git@gitlab.com:drayanaindra/saki-builder.git')"
check "self-hosted https" "gitlab.example.com" "$(extract_host 'https://gitlab.example.com/acme/repo.git')"
check "self-hosted scp"  "gitlab.example.com"  "$(extract_host 'git@gitlab.example.com:acme/repo.git')"
check "ssh:// with port" "example.com"                "$(extract_host 'ssh://git@example.com:2222/team/repo.git')"
check "https with user"  "gitlab.com"                 "$(extract_host 'https://oauth2:tok@gitlab.com/acme/app.git')"
check "empty"            ""                            "$(extract_host '')"
check "garbage"          ""                            "$(extract_host 'not-a-url')"

echo "classify:"
check "github → gh"      "github gh"    "$(classify 'github.com')"
check "gitlab.com → glab" "gitlab glab" "$(classify 'gitlab.com')"
check "self-hosted gitlab" "gitlab glab" "$(classify 'gitlab.example.com')"
check "bitbucket → unknown" "unknown -" "$(classify 'bitbucket.org')"
check "gitea → unknown"  "unknown -"    "$(classify 'git.company.com')"

echo ""
if [ "$fail" -eq 0 ]; then
	echo "✓ all $pass assertions passed"
	exit 0
fi
echo "✗ $fail failed, $pass passed"
exit 1
