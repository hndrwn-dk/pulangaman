#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-$ROOT_DIR/apps/mobile/lib/features}"

# Heuristic for leftover hardcoded UI copy:
# 1) Text('...') / Text("...") with non-ASCII chars
# 2) Any string literal with non-ASCII *letters* (excludes typographic
#    separators like · — → used between dynamic values)
#
# Exclude matches that already use l10n.
#
# Default: print matches and exit 0.
# Fail for CI with: L10N_FAIL_ON_OFFENDERS=true ./scripts/check_l10n_coverage.sh

fail_on="${L10N_FAIL_ON_OFFENDERS:-false}"

matches_file="$(mktemp)"
trap 'rm -f "$matches_file"' EXIT

{
  # Pattern A: Text('non-ascii...')
  rg --pcre2 -n --no-heading \
    "Text\\(\\s*['\"][^'\"]*[\\x{0080}-\\x{FFFF}][^'\"]*['\"]\\s*\\)" \
    "$TARGET_DIR" --glob "*.dart" \
    --glob "!**/l10n/**" \
    || true

  # Pattern B: any quoted literal with a non-ASCII letter (Latin-1+ letters)
  rg --pcre2 -n --no-heading \
    "['\"][^'\"]*[\\x{00C0}-\\x{024F}\\x{1E00}-\\x{1EFF}][^'\"]*['\"]" \
    "$TARGET_DIR" --glob "*.dart" \
    --glob "!**/l10n/**" \
    || true
} \
  | (rg -v "l10n\\." || true) \
  | (rg -v "^\s*//" || true) \
  | sort -u \
  | tee "$matches_file" >/dev/null

count="$(wc -l < "$matches_file" | tr -d ' ')"

if [[ "$count" -eq 0 ]]; then
  echo "[l10n] OK: no non-ASCII UI string literals found in $TARGET_DIR"
  exit 0
fi

echo "[l10n] Found $count potential hardcoded UI strings in $TARGET_DIR"
echo "[l10n] Tip: run this after each migration batch to keep the count dropping."
echo
cat "$matches_file"

if [[ "$fail_on" == "true" ]]; then
  exit 1
fi

exit 0
