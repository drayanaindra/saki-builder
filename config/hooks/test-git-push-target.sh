#!/usr/bin/env bash
# test-git-push-target.sh — unit tests for the shared push-target matcher.
# Runs against a throwaway git repo so branch/upstream resolution is real, not mocked.

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/git-push-target.sh
source "$DIR/lib/git-push-target.sh"

TMP="$(mktemp -d)"
trap 'cd /; rm -rf "$TMP"' EXIT

# A real repo with a real "origin", so bare-push resolution exercises actual git.
git init -q --initial-branch=main "$TMP/remote.git" 2>/dev/null || {
	git init -q "$TMP/remote.git"; git -C "$TMP/remote.git" symbolic-ref HEAD refs/heads/main
}
git -C "$TMP/remote.git" config user.email t@t.t
git -C "$TMP/remote.git" config user.name t
git -C "$TMP/remote.git" commit -q --allow-empty -m init
git clone -q "$TMP/remote.git" "$TMP/work" 2>/dev/null
cd "$TMP/work" || exit 1
git config user.email t@t.t
git config user.name t

pass=0
fail=0
ok() { # label command...  → expect MATCH
	if command_pushes_to_default_branch "$2"; then pass=$((pass + 1)); printf '  ok    %s\n' "$1"
	else fail=$((fail + 1)); printf '  FAIL  %s — expected MATCH, got no-match\n' "$1"; fi
}
no() { # label command...  → expect NO match
	if command_pushes_to_default_branch "$2"; then fail=$((fail + 1)); printf '  FAIL  %s — expected no-match, got MATCH\n' "$1"
	else pass=$((pass + 1)); printf '  ok    %s\n' "$1"; fi
}

echo "real pushes to the default branch (must match):"
ok "explicit main"              'git push origin main'
ok "explicit master"            'git push origin master'
ok "-u origin main"             'git push -u origin main'
ok "force main"                 'git push -f origin main'
ok "force-with-lease main"      'git push --force-with-lease origin main'
ok "refs/heads/main"            'git push origin refs/heads/main'
ok "leading + (force refspec)"  'git push origin +main'
ok "src:dst landing on main"    'git push origin feature/x:main'
ok "HEAD:main"                  'git push origin HEAD:main'
ok "--all"                      'git push --all origin'
ok "--mirror"                   'git push --mirror origin'
ok "git -C <dir> push main"     'git -C /some/repo push origin main'
ok "chained after &&"           'npm test && git push origin main'
ok "chained after ;"            'echo done; git push origin main'
ok "delete main"                'git push origin --delete main'

echo
echo "bare push while ON main — the case the old grep missed entirely:"
ok "bare git push"              'git push'
ok "git push origin"            'git push origin'
ok "git push -u origin HEAD"    'git push -u origin HEAD'

echo
echo "NOT pushes to the default branch (must not match):"
no "feature branch"             'git push origin feat/x'
no "branch containing 'main'"   'git push origin feature/main-refactor'
no "branch 'maintenance'"       'git push origin chore/maintenance'
no "branch 'domain-parsing'"    'git push origin fix/domain-parsing'
no "dry run to main"            'git push --dry-run origin main'
no "dry run short flag"         'git push -n origin main'
no "tag push w/ main in comment" 'git push origin v1.2.3 # cut from main'
no "prose in single quotes"     "echo 'git push origin main later'"
no "prose in double quotes"     'echo "git push origin main"'
no "grep for the phrase"        "grep 'git push origin main' deploy.log"
no "not a push at all"          'git status main'
no "unrelated command"          'ls -la'
no "empty"                      ''

echo
echo "bare push while on a FEATURE branch (must not match):"
git checkout -q -b feature/cancel-cta
no "bare push off main"         'git push'
no "push -u origin HEAD off main" 'git push -u origin HEAD'
git checkout -q main

echo
echo "push_command_cwd — the repo the push runs in, not the shell's cwd:"
eq() { # label expected actual
	if [ "$2" = "$3" ]; then pass=$((pass + 1)); printf '  ok    %s\n' "$1"
	else fail=$((fail + 1)); printf '  FAIL  %s — expected [%s] got [%s]\n' "$1" "$2" "$3"; fi
}
mkdir -p "$TMP/elsewhere"
eq "no cd -> PWD"            "$PWD"            "$(push_command_cwd 'git push origin main')"
eq "cd <abs> && push"        "$TMP/elsewhere"  "$(push_command_cwd "cd $TMP/elsewhere && git push origin main")"
eq "git -C <dir> push"       "$TMP/elsewhere"  "$(push_command_cwd "git -C $TMP/elsewhere push origin main")"
eq "cd to a missing dir"     "$PWD"            "$(push_command_cwd 'cd /no/such/dir && git push origin main')"

# The repo a push targets decides the branch, not the shell's cwd: this work tree is on
# main, the sibling clone is on a feature branch — a bare push there must NOT match.
git clone -q "$TMP/remote.git" "$TMP/other" 2>/dev/null
git -C "$TMP/other" checkout -q -b feature/other
no "bare push in a repo on a feature branch" "cd $TMP/other && git push"
ok "bare push back in the main work tree"    "cd $TMP/work && git push"

echo
printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
