#!/usr/bin/env bash
# Acceptance test for update.sh.
#
# Drives the script from the outside with a *fake* `git` and `nix` on PATH:
#   - fake `git ls-remote` answers with a per-case head commit per repo
#   - fake `nix flake prefetch` returns a hash derived from the requested ref,
#     so we can assert each plugin gets its *own* hash
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

OLD_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
NEW_A=1111111111111111111111111111111111111111
OLD_B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

PINNED="{
  \"alpha\": { \"owner\": \"o\", \"repo\": \"alpha\", \"branch\": \"main\", \"rev\": \"$OLD_A\", \"hash\": \"sha256-old-alpha\" },
  \"beta\":  { \"owner\": \"o\", \"repo\": \"beta\",  \"branch\": \"dev\",  \"rev\": \"$OLD_B\", \"hash\": \"sha256-old-beta\" }
}"

# setup_case <alpha-head> <beta-head> [prefetch-exit-code]
# Prints the work directory; caller drives update.sh against it.
setup_case() {
  local alpha="$1" beta="$2" prefetch_rc="${3:-0}"
  local work
  work="$(mktemp -d)"

  printf '%s' "$PINNED" >"$work/sources.json"
  mkdir -p "$work/bin"

  # Fake git: only `git ls-remote <url> refs/heads/<branch>`. Answers only for
  # the branch each repo is pinned to, so tracking the wrong branch fails.
  cat >"$work/bin/git" <<EOF
#!/usr/bin/env bash
case "\$2 \$3" in
  "https://github.com/o/alpha.git refs/heads/main") printf '%s\trefs/heads/main\n' "$alpha" ;;
  "https://github.com/o/beta.git refs/heads/dev")   printf '%s\trefs/heads/dev\n' "$beta" ;;
esac
EOF

  # Fake nix: implements just \`nix flake prefetch --json <ref>\`.
  cat >"$work/bin/nix" <<EOF
#!/usr/bin/env bash
if [ "$prefetch_rc" -ne 0 ]; then
  echo "fake nix: prefetch failed" >&2
  exit $prefetch_rc
fi
ref="\${@: -1}"
printf '{"hash": "sha256-fake-%s"}' "\${ref##*/}"
EOF

  chmod +x "$work/bin/git" "$work/bin/nix"
  printf '%s' "$work"
}

# run_update <work> [args...] -> exit code in $rc, output in $work/out.txt
run_update() {
  local work="$1"
  shift
  set +e
  PATH="$work/bin:$PATH" \
  CLAUDE_PLUGINS_SOURCES_JSON="$work/sources.json" \
    bash "$UPDATE" "$@" >"$work/out.txt" 2>&1
  rc=$?
  set -e
}

# Case 1: all current -> reports up to date, writes nothing.
up_to_date_writes_nothing() {
  local work before
  work="$(setup_case "$OLD_A" "$OLD_B")"
  before="$(cat "$work/sources.json")"

  run_update "$work"
  [ "$rc" -eq 0 ] || fail "[up-to-date] expected exit 0, got $rc:\n$(cat "$work/out.txt")"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[up-to-date] sources.json was rewritten but should not have been"
  [ "$(grep -c "up to date" "$work/out.txt")" -eq 2 ] \
    || fail "[up-to-date] expected two up-to-date messages, got:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: up-to-date-writes-nothing"
}

# Case 2: --check with one plugin behind -> exit 1, writes nothing.
check_reports_available_update() {
  local work before
  work="$(setup_case "$NEW_A" "$OLD_B")"
  before="$(cat "$work/sources.json")"

  run_update "$work" --check
  [ "$rc" -eq 1 ] || fail "[check-available] expected exit 1, got $rc:\n$(cat "$work/out.txt")"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[check-available] --check must not modify sources.json"
  grep -q "alpha update available: aaaaaaa -> 1111111" "$work/out.txt" \
    || fail "[check-available] expected alpha update line, got:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: check-reports-available-update"
}

# Case 3: --check when current -> exit 0.
check_is_quiet_when_current() {
  local work
  work="$(setup_case "$OLD_A" "$OLD_B")"

  run_update "$work" --check
  [ "$rc" -eq 0 ] || fail "[check-current] expected exit 0, got $rc:\n$(cat "$work/out.txt")"

  rm -rf "$work"
  echo "ok: check-is-quiet-when-current"
}

# Case 4: one plugin behind -> only it gets a new rev and its own hash; the
# other entry and all other fields are preserved.
update_rewrites_only_stale_plugins() {
  local work got want
  work="$(setup_case "$NEW_A" "$OLD_B")"

  run_update "$work"
  [ "$rc" -eq 0 ] || fail "[update] expected exit 0, got $rc:\n$(cat "$work/out.txt")"

  got="$(jq -S . "$work/sources.json")"
  want="$(jq -S . <<EOF
{
  "alpha": { "owner": "o", "repo": "alpha", "branch": "main", "rev": "$NEW_A", "hash": "sha256-fake-$NEW_A" },
  "beta":  { "owner": "o", "repo": "beta",  "branch": "dev",  "rev": "$OLD_B", "hash": "sha256-old-beta" }
}
EOF
  )"
  [ "$got" = "$want" ] \
    || fail "[update] sources.json mismatch\n--- want ---\n$want\n--- got ---\n$got"

  rm -rf "$work"
  echo "ok: update-rewrites-only-stale-plugins"
}

# Case 5: a failing prefetch must leave the pin untouched.
prefetch_failure_leaves_pin_untouched() {
  local work before
  work="$(setup_case "$NEW_A" "$OLD_B" 1)"
  before="$(cat "$work/sources.json")"

  run_update "$work"
  [ "$rc" -ne 0 ] || fail "[prefetch-fail] expected non-zero exit, got 0"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[prefetch-fail] sources.json was left modified:\n$(cat "$work/sources.json")"

  rm -rf "$work"
  echo "ok: prefetch-failure-leaves-pin-untouched"
}

# Case 6: an unreadable branch is an error, not a silent "up to date".
missing_branch_fails() {
  local work before
  work="$(setup_case "$NEW_A" "")"
  before="$(cat "$work/sources.json")"

  run_update "$work"
  [ "$rc" -ne 0 ] || fail "[missing-branch] expected non-zero exit, got 0"
  [ "$(cat "$work/sources.json")" = "$before" ] \
    || fail "[missing-branch] sources.json was left modified"

  rm -rf "$work"
  echo "ok: missing-branch-fails"
}

up_to_date_writes_nothing
check_reports_available_update
check_is_quiet_when_current
update_rewrites_only_stale_plugins
prefetch_failure_leaves_pin_untouched
missing_branch_fails

echo "ALL TESTS PASSED"
