#!/usr/bin/env bash
# Generate the OMP-facing skills, commands, agents, and rules from canonical sources.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$REPO/bin/build-omp-bundle.py"
