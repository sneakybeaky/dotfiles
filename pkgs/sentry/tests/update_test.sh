#!/usr/bin/env bash
# Acceptance test for update.sh.
#
# Drives the script from the outside with a *fake* `curl` and `nix` on PATH:
#   - fake `curl` answers the GitHub releases API from a per-case version
#   - fake `nix store prefetch-file` returns a hash derived from the asset name,
#     so we can assert each platform gets its *own* hash and not a shared one
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
  "repo": "getsentry/cli",
  "version": "0.43.0",
  "platforms": {
    "aarch64-darwin": { "asset": "sentry-darwin-arm64.gz", "hash": "sha256-old-darwin-arm64" },
    "x86_64-linux":   { "asset": "sentry-linux-x64.gz",    "hash": "sha256-old-linux-x64" }
  }
}'

# setup_case <latest-version> [prefetch-exit-code]
# Prints the work directory; caller drives update.sh against it.
setup_case() {
  local latest="$1" prefetch_rc="${2:-0}"
  local work
  work="$(mktemp -d)"

  printf '%s' "$PINNED" >"$work/sources.json"
  mkdir -p "$work/bin"

  # Fake curl: only ever asked for the releases API; answers with $latest.
  cat >"$work/bin/curl" <<EOF
#!/usr/bin/env bash
printf '{"tag_name": "%s"}' "$latest"
EOF

  # Fake nix: implements just \`nix store prefetch-file --json\`, returning a
  # hash derived from the requested asset so per-platform wiring is observable.
  cat >"$work/bin/nix" <<EOF
#!/usr/bin/env bash
if [ "$prefetch_rc" -ne 0 ]; then
  echo "fake nix: prefetch failed" >&2
  exit $prefetch_rc
fi
url="\${*##* }"
printf '{"hash": "sha256-fake-%s"}' "\$(basename "\$url")"
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
  SENTRY_SOURCES_JSON="$work/sources.json" \
    bash "$UPDATE" "$@" >"$work/out.txt" 2>&1
  rc=$?
  set -e
}

# Case 1: already current -> reports up to date, writes nothing.
up_to_date_writes_nothing() {
  local work
  work="$(setup_case "0.43.0")"
  local before
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
  local work
  work="$(setup_case "0.44.0")"
  local before
  before="$(cat "$work/sources.json")"

  run_update "$work" --check
  [ "$rc" -eq 1 ] || fail "[check-available] expected exit 1, got $rc:\n$(cat "$work/out.txt")"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[check-available] --check must not modify sources.json"
  grep -q "0.43.0" "$work/out.txt" && grep -q "0.44.0" "$work/out.txt" \
    || fail "[check-available] expected both versions in output, got:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: check-reports-available-update"
}

# Case 3: --check when current -> exit 0.
check_is_quiet_when_current() {
  local work
  work="$(setup_case "0.43.0")"

  run_update "$work" --check
  [ "$rc" -eq 0 ] || fail "[check-current] expected exit 0, got $rc:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: check-is-quiet-when-current"
}

# Case 4: a newer release -> version bumped and *every* platform hash refreshed
# from its own asset, with repo and asset names preserved.
update_rewrites_version_and_all_hashes() {
  local work
  work="$(setup_case "0.44.0")"

  run_update "$work"
  [ "$rc" -eq 0 ] || fail "[update] expected exit 0, got $rc:\n$(cat "$work/out.txt")"

  local got want
  got="$(jq -S . "$work/sources.json")"
  want="$(jq -S . <<'EOF'
{
  "repo": "getsentry/cli",
  "version": "0.44.0",
  "platforms": {
    "aarch64-darwin": { "asset": "sentry-darwin-arm64.gz", "hash": "sha256-fake-sentry-darwin-arm64.gz" },
    "x86_64-linux":   { "asset": "sentry-linux-x64.gz",    "hash": "sha256-fake-sentry-linux-x64.gz" }
  }
}
EOF
  )"
  [ "$got" = "$want" ] \
    || fail "[update] sources.json mismatch\n--- want ---\n$want\n--- got ---\n$got"

  rm -rf "$work"
  echo "ok: update-rewrites-version-and-all-hashes"
}

# Case 5: a failing prefetch must leave the pin untouched rather than writing a
# half-updated file (version bumped with stale hashes would be poison).
prefetch_failure_leaves_pin_untouched() {
  local work
  work="$(setup_case "0.44.0" 1)"
  local before
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
update_rewrites_version_and_all_hashes
prefetch_failure_leaves_pin_untouched

echo "ALL TESTS PASSED"
