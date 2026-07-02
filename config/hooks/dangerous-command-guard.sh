#!/usr/bin/env bash
# dangerous-command-guard.sh — Global safety policy for Claude Code bash execution
# Runs as PreToolUse:Bash hook. Blocks destructive commands, allows everything else.
#
# Distribution: shipped by the saki-builder plugin (config/hooks/), registered via hooks.json.
# Applies to ALL projects as a PreToolUse:Bash hook.

COMMAND="${CLAUDE_TOOL_INPUT_COMMAND:-}"

# Normalize: lowercase for case-insensitive matching on SQL keywords
CMD_LOWER="$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')"

# ─── 1. DATABASE DESTRUCTION ────────────────────────────────────────────────
# Block DROP DATABASE, DROP TABLE, DROP SCHEMA (any env)
if echo "$CMD_LOWER" | grep -qE '\bdrop\s+(database|table|schema)\b'; then
  echo "BLOCKED: DROP DATABASE/TABLE/SCHEMA detected."
  echo "This command can cause irreversible data loss. If intentional, run it manually outside Claude Code."
  exit 1
fi

# Block TRUNCATE (deletes all rows without logging)
if echo "$CMD_LOWER" | grep -qE '\btruncate\s+(table\s+)?\w'; then
  echo "BLOCKED: TRUNCATE detected."
  echo "This deletes all rows irreversibly. If intentional, run it manually outside Claude Code."
  exit 1
fi

# Block DELETE FROM without WHERE (mass delete)
if echo "$CMD_LOWER" | grep -qE '\bdelete\s+from\s+\w+\s*[";]' | grep -qvE '\bwhere\b'; then
  # More precise: check if DELETE FROM ... has no WHERE before the statement end
  DELETE_STMT="$(echo "$CMD_LOWER" | grep -oE 'delete\s+from\s+\w+[^;]*')"
  if [ -n "$DELETE_STMT" ] && ! echo "$DELETE_STMT" | grep -qE '\bwhere\b'; then
    echo "BLOCKED: DELETE FROM without WHERE clause detected."
    echo "This would delete all rows in the table. Add a WHERE clause or run manually."
    exit 1
  fi
fi

# ─── 2. FILE SYSTEM DESTRUCTION ─────────────────────────────────────────────
# Block rm -rf on root, home, or current dir
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|(-[a-zA-Z]*f[a-zA-Z]*r))\s+(/(\s|$)|~/|/Users|/home|\.(\s|$)|\./)'; then
  echo "BLOCKED: Destructive rm -rf on root/home/current directory."
  echo "This would cause catastrophic data loss. If intentional, run manually."
  exit 1
fi

# Block rm -rf on critical project directories
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|(-[a-zA-Z]*f[a-zA-Z]*r))\s+[./]*(internal|frontend/src|db/migrations|cmd|\.claude|src|app|pkg|public|dist|build|node_modules|vendor)/?(\s|$)'; then
  echo "BLOCKED: rm -rf on critical project directory."
  echo "Removing these directories would break the project. If intentional, run manually."
  exit 1
fi

# Block rm on critical config/lock files
if echo "$COMMAND" | grep -qE 'rm\s+.*(\.env|go\.sum|go\.mod|package-lock\.json|package\.json|docker-compose\.yml|docker-compose\.yaml|Makefile|Cargo\.lock|Cargo\.toml|pyproject\.toml|tsconfig\.json)(\s|$)'; then
  echo "BLOCKED: rm on critical config/lock file."
  echo "Removing this file would break the build or lose configuration. If intentional, run manually."
  exit 1
fi

# ─── 3. GIT DESTRUCTION ─────────────────────────────────────────────────────
# Block git push --force to main/master
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(-f|--force)' && echo "$COMMAND" | grep -qE '\b(main|master)\b'; then
  echo "BLOCKED: git push --force to main/master."
  echo "Force pushing to the primary branch can overwrite team history. If intentional, run manually."
  exit 1
fi

# Block git reset --hard
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard."
  echo "This discards all uncommitted changes irreversibly. If intentional, run manually."
  exit 1
fi

# Block git clean -fd / -fx (removes untracked files)
if echo "$COMMAND" | grep -qE 'git\s+clean\s+-[a-zA-Z]*[fdx]'; then
  echo "BLOCKED: git clean with force flag."
  echo "This removes untracked files permanently. If intentional, run manually."
  exit 1
fi

# Block git branch -D on main/master
if echo "$COMMAND" | grep -qE 'git\s+branch\s+-D\s+(main|master)\b'; then
  echo "BLOCKED: git branch -D on main/master."
  echo "Deleting the primary branch is almost never correct. If intentional, run manually."
  exit 1
fi

# ─── 4. MIGRATION SAFETY ────────────────────────────────────────────────────
# Block migrate force (resets version without running migration)
if echo "$COMMAND" | grep -qE '\bmigrate\b.*\bforce\b'; then
  echo "BLOCKED: migrate force."
  echo "This resets the migration version without running the migration, causing schema drift. If intentional, run manually."
  exit 1
fi

# Block migrate down (rollback needs explicit approval)
if echo "$COMMAND" | grep -qE '\bmigrate\b.*\bdown\b'; then
  echo "BLOCKED: migrate down (rollback)."
  echo "Rolling back migrations can cause data loss if not backward-compatible. If intentional, run manually."
  exit 1
fi

# Block migrate drop (drops everything)
if echo "$COMMAND" | grep -qE '\bmigrate\b.*\bdrop\b'; then
  echo "BLOCKED: migrate drop."
  echo "This drops all migrations and database objects. If intentional, run manually."
  exit 1
fi

# Block alembic downgrade base (Python equivalent of dropping all)
if echo "$CMD_LOWER" | grep -qE '\balembic\s+downgrade\s+base\b'; then
  echo "BLOCKED: alembic downgrade base."
  echo "This rolls back ALL migrations. If intentional, run manually."
  exit 1
fi

# ─── 5. SYSTEM / PROCESS DESTRUCTION ────────────────────────────────────────
# Block shutdown / reboot
if echo "$CMD_LOWER" | grep -qE '\b(shutdown|reboot)\b'; then
  echo "BLOCKED: shutdown/reboot command."
  echo "System power commands should not be run by Claude Code."
  exit 1
fi

# Block curl piped to shell (remote code execution)
if echo "$COMMAND" | grep -qE 'curl\s.*\|\s*(sh|bash|zsh|source)'; then
  echo "BLOCKED: curl piped to shell."
  echo "Executing remote scripts is a security risk. Download first, review, then execute."
  exit 1
fi

# Block wget piped to shell
if echo "$COMMAND" | grep -qE 'wget\s.*\|\s*(sh|bash|zsh|source)'; then
  echo "BLOCKED: wget piped to shell."
  echo "Executing remote scripts is a security risk. Download first, review, then execute."
  exit 1
fi

# Block chmod -R 777 (world-writable permissions)
if echo "$COMMAND" | grep -qE 'chmod\s+(-R\s+)?777'; then
  echo "BLOCKED: chmod 777 (world-writable permissions)."
  echo "This creates a security vulnerability. Use more restrictive permissions."
  exit 1
fi

# Block dd if= (raw disk writes)
if echo "$COMMAND" | grep -qE '\bdd\s+if='; then
  echo "BLOCKED: dd command (raw disk write)."
  echo "dd can overwrite disks. If intentional, run manually."
  exit 1
fi

# All checks passed — allow the command
exit 0
