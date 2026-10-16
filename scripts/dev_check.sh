#!/usr/bin/env bash
# One-shot static development check for Project Overdrive.
#
# Runs every verification step that does *not* need the Godot engine binary:
#   1. GDScript syntax parse + style lint + format check (gdtoolkit)
#   2. Static project doctor (references, contracts, docs, assets)
#   3. Smoke-test inventory and documentation cross-check
#
# The engine itself is still required for gameplay verification; use
# scripts/run_smoke_tests.sh once Godot is installed (scripts/install_godot.sh).
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"

FAILED_STEPS=0
SKIPPED_STEPS=0

step_passed() { printf '  [PASS] %s\n' "$1"; }
step_failed() { printf '  [FAIL] %s\n' "$1"; FAILED_STEPS=$((FAILED_STEPS + 1)); }
step_skipped() { printf '  [SKIP] %s\n' "$1"; SKIPPED_STEPS=$((SKIPPED_STEPS + 1)); }

printf 'Project Overdrive — static development check\n'
printf 'Repository: %s\n\n' "$ROOT_DIR"

if [[ ! -d "$GAME_DIR" ]]; then
  printf 'ERROR: game/ directory not found. Run this script from the repository.\n' >&2
  exit 2
fi

# --------------------------------------------------------------------------- #
# 1. GDScript static analysis (gdtoolkit)
# --------------------------------------------------------------------------- #
printf '[1/3] GDScript static analysis\n'

PYTHON_BIN=""
if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
fi

GDLINT=""
GDFORMAT=""
GDPARSE=""
if [[ -x "$ROOT_DIR/.venv/bin/gdlint" ]]; then
  GDLINT="$ROOT_DIR/.venv/bin/gdlint"
  GDFORMAT="$ROOT_DIR/.venv/bin/gdformat"
  GDPARSE="$ROOT_DIR/.venv/bin/gdparse"
elif command -v gdlint >/dev/null 2>&1; then
  GDLINT="$(command -v gdlint)"
  GDFORMAT="$(command -v gdformat || true)"
  GDPARSE="$(command -v gdparse || true)"
fi

if [[ -z "$GDLINT" || -z "$GDFORMAT" ]]; then
  step_skipped 'gdtoolkit not installed (python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt)'
else
  mapfile -d '' GD_FILES < <(
    find "$GAME_DIR" -type f -name '*.gd' -not -path '*/.godot/*' -print0 | sort -z
  )
  if (( ${#GD_FILES[@]} == 0 )); then
    step_failed 'no GDScript files found under game/'
  else
    if [[ -n "$GDPARSE" ]]; then
      parse_failures=0
      for gd_file in "${GD_FILES[@]}"; do
        if ! "$GDPARSE" "$gd_file" >/dev/null 2>&1; then
          printf '         syntax error: %s\n' "${gd_file#"$ROOT_DIR"/}"
          parse_failures=$((parse_failures + 1))
        fi
      done
      if (( parse_failures == 0 )); then
        step_passed "syntax parse: ${#GD_FILES[@]} file(s) parse as valid GDScript"
      else
        step_failed "syntax parse: $parse_failures file(s) failed"
      fi
    else
      step_skipped 'gdparse not available; syntax parse skipped'
    fi

    if "$GDLINT" "${GD_FILES[@]}" >/dev/null 2>&1; then
      step_passed "gdlint: ${#GD_FILES[@]} file(s) pass the configured linter rules"
    else
      step_failed 'gdlint reported problems (run .venv/bin/gdlint on the reported files)'
      "$GDLINT" "${GD_FILES[@]}" 2>&1 | sed 's/^/         /' | head -20
    fi

    if "$GDFORMAT" --check "${GD_FILES[@]}" >/dev/null 2>&1; then
      step_passed "gdformat: ${#GD_FILES[@]} file(s) already formatted"
    else
      step_failed 'gdformat --check found files that need formatting'
      "$GDFORMAT" --check "${GD_FILES[@]}" 2>&1 | sed 's/^/         /' | head -10
    fi
  fi
fi
printf '\n'

# --------------------------------------------------------------------------- #
# 2. Static project doctor
# --------------------------------------------------------------------------- #
printf '[2/3] Static project doctor (references, contracts, assets, docs)\n'
DOCTOR="$ROOT_DIR/tools/project_doctor.py"
if [[ ! -f "$DOCTOR" ]]; then
  step_failed 'tools/project_doctor.py is missing'
elif [[ -z "$PYTHON_BIN" ]]; then
  step_skipped 'no python3 interpreter available for tools/project_doctor.py'
else
  doctor_output="$("$PYTHON_BIN" "$DOCTOR" --root "$ROOT_DIR" --quiet 2>&1)"
  doctor_code=$?
  printf '%s\n' "$doctor_output" | sed 's/^/         /'
  if (( doctor_code == 0 )); then
    step_passed 'project doctor found no structural failures'
  else
    step_failed 'project doctor reported structural failures (see above)'
  fi
fi
printf '\n'

# --------------------------------------------------------------------------- #
# 3. Smoke-test inventory
# --------------------------------------------------------------------------- #
printf '[3/3] Smoke-test inventory\n'
shopt -s nullglob
SMOKE_TESTS=("$GAME_DIR"/tests/*_smoke.gd)
shopt -u nullglob
if (( ${#SMOKE_TESTS[@]} == 0 )); then
  step_failed 'no smoke tests found under game/tests/'
else
  step_passed "${#SMOKE_TESTS[@]} smoke test(s) present: $(printf '%s ' "${SMOKE_TESTS[@]##*/}")"
fi

if ! command -v "${GODOT_BIN:-godot}" >/dev/null 2>&1 && ! command -v godot4 >/dev/null 2>&1; then
  step_skipped 'Godot engine not on PATH; run scripts/install_godot.sh then scripts/run_smoke_tests.sh'
else
  step_passed 'Godot engine detected on PATH; scripts/run_smoke_tests.sh can execute the tests'
fi
printf '\n'

printf 'Summary: %d failed step(s), %d skipped step(s).\n' "$FAILED_STEPS" "$SKIPPED_STEPS"
if (( FAILED_STEPS > 0 )); then
  printf 'Fix the failures before claiming the change is verified.\n'
  exit 1
fi
printf 'Static checks are clean. Runtime behaviour still requires a Godot run.\n'
