#!/usr/bin/env bash
# Run AD Suite from Git Bash / WSL. Requires pwsh or Windows PowerShell.
set -euo pipefail
ENGINES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$ENGINES_DIR/.." && pwd)"

PS_CMD=""
if command -v pwsh >/dev/null 2>&1; then PS_CMD="pwsh"
elif command -v powershell.exe >/dev/null 2>&1; then PS_CMD="powershell.exe"
elif [ -x "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]; then
  PS_CMD="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
else
  echo "No PowerShell found." >&2
  exit 1
fi

usage() {
  echo "Usage: $0 <adsi|rsat|combined|scan> [args...]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
MODE="$1"
shift

if command -v wslpath >/dev/null 2>&1; then
  REPO_WIN=$(wslpath -w "$REPO_ROOT")
  ENG_WIN=$(wslpath -w "$ENGINES_DIR")
elif command -v cygpath >/dev/null 2>&1; then
  REPO_WIN=$(cygpath -w "$REPO_ROOT")
  ENG_WIN=$(cygpath -w "$ENGINES_DIR")
else
  REPO_WIN="$REPO_ROOT"
  ENG_WIN="$ENGINES_DIR"
fi

case "$MODE" in
  adsi)
    "$PS_CMD" -NoProfile -ExecutionPolicy Bypass -File "$REPO_WIN\\adsi.ps1" "$@"
    ;;
  rsat)
    "$PS_CMD" -NoProfile -ExecutionPolicy Bypass -File "$ENG_WIN\\ADSuite-Engine-Rsat.ps1" "$@"
    ;;
  combined)
    "$PS_CMD" -NoProfile -ExecutionPolicy Bypass -File "$ENG_WIN\\ADSuite-CombinedEngine.ps1" "$@"
    ;;
  scan)
    "$PS_CMD" -NoProfile -ExecutionPolicy Bypass -File "$REPO_WIN\\Invoke-ADSuiteScan.ps1" "$@"
    ;;
  *)
    usage
    ;;
esac
