#!/usr/bin/env bash
# Acceptance test for update.sh.
#
# Drives the script from the outside with a *fake* `curl` and `nix` on PATH:
#   - fake `curl` answers the GitHub releases API with a per-case tag
#   - fake `nix store prefetch-file` returns a hash derived from the requested
#     URL, so we can assert the tag and asset naming the script builds
# then asserts what was (or was not) written to a throwaway sources.json.
#
# No network, no real prefetching, no mutation of the tracked sources.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE="$SCRIPT_DIR/update.sh"

fail() {
  printf 'FAIL: %b\n' "$*" >&2
  exit 1
}

PINNED='{
  "repo": "penso/herdr-gpui",
  "version": "20261020.1",
  "hash": "sha256-old"
}'

# setup_case <latest-tag> [prefetch-exit-code]
# Prints the work directory; caller drives update.sh against it.
setup_case() {
  local latest="$1" prefetch_rc="${2:-0}"
  local work
  work="$(mktemp -d)"

  printf '%s' "$PINNED" >"$work/sources.json"
  mkdir -p "$work/bin"

  cat >"$work/bin/curl" <<EOF
#!/usr/bin/env bash
printf '{"tag_name": "%s"}' "$latest"
EOF

  # Fake nix: encodes the tag directory and asset name of the URL in the hash.
  cat >"$work/bin/nix" <<EOF
#!/usr/bin/env bash
if [ "$prefetch_rc" -ne 0 ]; then
  echo "fake nix: prefetch failed" >&2
  exit $prefetch_rc
fi
url="\${*##* }"
printf '{"hash": "sha256-fake-%s-%s"}' "\$(basename "\$(dirname "\$url")")" "\$(basename "\$url")"
EOF

  chmod +x "$work/bin/curl" "$work/bin/nix"
  printf '%s' "$work"
}

# run_update <work> [args...] -> exit code in $rc, output in $work/out.txt
run_update() {
  local work="$1"
  shift
  set +e
  PATH="$work/bin:$PATH" \
  HERDR_GPUI_SOURCES_JSON="$work/sources.json" \
    bash "$UPDATE" "$@" >"$work/out.txt" 2>&1
  rc=$?
  set -e
}

# Case 1: already current (tag carries the "v" prefix) -> writes nothing.
up_to_date_writes_nothing() {
  local work before
  work="$(setup_case "v20261020.1")"
  before="$(cat "$work/sources.json")"

  run_update "$work"
  [ "$rc" -eq 0 ] || fail "[up-to-date] expected exit 0, got $rc:\n$(cat "$work/out.txt")"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[up-to-date] sources.json was rewritten but should not have been"
  grep -qi "up to date" "$work/out.txt" \
    || fail "[up-to-date] expected an up-to-date message, got:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: up-to-date-writes-nothing"
}

# Case 2: --check with a newer release -> exit 1, still writes nothing.
check_reports_available_update() {
  local work before
  work="$(setup_case "v20261028.1")"
  before="$(cat "$work/sources.json")"

  run_update "$work" --check
  [ "$rc" -eq 1 ] || fail "[check-available] expected exit 1, got $rc:\n$(cat "$work/out.txt")"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[check-available] --check must not modify sources.json"
  grep -q "20261020.1 -> 20261028.1" "$work/out.txt" \
    || fail "[check-available] expected both versions in output, got:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: check-reports-available-update"
}

# Case 3: --check when current -> exit 0.
check_is_quiet_when_current() {
  local work
  work="$(setup_case "v20261020.1")"

  run_update "$work" --check
  [ "$rc" -eq 0 ] || fail "[check-current] expected exit 0, got $rc:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: check-is-quiet-when-current"
}

# Case 4: a newer release -> version (without "v") and hash rewritten, the hash
# fetched from the v-prefixed tag's macOS universal asset.
update_rewrites_version_and_hash() {
  local work got want
  work="$(setup_case "v20261028.1")"

  run_update "$work"
  [ "$rc" -eq 0 ] || fail "[update] expected exit 0, got $rc:\n$(cat "$work/out.txt")"

  got="$(jq -S . "$work/sources.json")"
  want="$(jq -S . <<'EOF'
{
  "repo": "penso/herdr-gpui",
  "version": "20261028.1",
  "hash": "sha256-fake-v20261028.1-herdr-gpui-20261028.1-macos-universal.app.tar.gz"
}
EOF
  )"
  [ "$got" = "$want" ] \
    || fail "[update] sources.json mismatch\n--- want ---\n$want\n--- got ---\n$got"

  rm -rf "$work"
  echo "ok: update-rewrites-version-and-hash"
}

# Case 5: a failing prefetch must leave the pin untouched.
prefetch_failure_leaves_pin_untouched() {
  local work before
  work="$(setup_case "v20261028.1" 1)"
  before="$(cat "$work/sources.json")"

  run_update "$work"
  [ "$rc" -ne 0 ] || fail "[prefetch-fail] expected non-zero exit, got 0"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[prefetch-fail] sources.json was left modified:\n$(cat "$work/sources.json")"

  rm -rf "$work"
  echo "ok: prefetch-failure-leaves-pin-untouched"
}

up_to_date_writes_nothing
check_reports_available_update
check_is_quiet_when_current
update_rewrites_version_and_hash
prefetch_failure_leaves_pin_untouched

echo "ALL TESTS PASSED"
