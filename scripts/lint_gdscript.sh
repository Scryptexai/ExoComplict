#!/usr/bin/env bash
# Run gdtoolkit lint and formatting checks on the Godot scripts.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x "$ROOT_DIR/.venv/bin/gdlint" ]]; then
  GDLINT="$ROOT_DIR/.venv/bin/gdlint"
  GDFORMAT="$ROOT_DIR/.venv/bin/gdformat"
elif command -v gdlint >/dev/null 2>&1 && command -v gdformat >/dev/null 2>&1; then
  GDLINT="$(command -v gdlint)"
  GDFORMAT="$(command -v gdformat)"
else
  printf 'gdtoolkit is not installed. Optional setup:\n'
  printf '  python3 -m venv .venv\n'
  printf '  .venv/bin/pip install -r requirements-dev.txt\n'
  exit 127
fi

mapfile -d '' gd_files < <(
  find "$ROOT_DIR/game" -type f -name '*.gd' -not -path '*/.godot/*' -print0 | sort -z
)
if (( ${#gd_files[@]} == 0 )); then
  printf 'No GDScript files found under game/.\n'
  exit 0
fi

"$GDLINT" "${gd_files[@]}" && "$GDFORMAT" --check "${gd_files[@]}"
