#!/usr/bin/env bash
# anthropic-key.sh — prints the Anthropic API key from the macOS Keychain.
# Contains NO secret; safe to commit. Single source of truth for both
# Claude Code and opencode (both read ANTHROPIC_API_KEY from the environment).
#
# Store the key ONCE (interactive, hidden — never echoed, never in shell history
# because the value is typed at the prompt, not passed as an argument):
#
#   security add-generic-password -U -a "$USER" -s anthropic-api-key -w
#
# Rotate the same way (the -U flag updates the existing item).
exec security find-generic-password -a "$USER" -s anthropic-api-key -w 2>/dev/null
