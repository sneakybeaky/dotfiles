#!/usr/bin/env bash
# Acceptance test for reconcile.sh.
#
# Drives the script from the outside with a *fake* `nono` on PATH that:
#   - answers `nono list --installed --json` from a fixture file
#   - records every `nono pull`/`nono remove` invocation to a calls file
# then asserts the recorded calls match what a declarative reconcile should do.
#
# No network, no real nono, no mutation of $HOME.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECONCILE="$SCRIPT_DIR/reconcile.sh"

fail() {
  printf 'FAIL: %b\n' "$*" >&2
  exit 1
}

# run_case <name> <installed-json> <desired-json> <prune> <expected-sorted-calls> [force]
run_case() {
  local name="$1" installed="$2" desired="$3" prune="$4" expected="$5" force="${6:-false}"

  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN

  # Fixture: what `nono list --installed --json` returns.
  printf '%s' "$installed" >"$work/installed.json"

  # Fake nono: records pull/remove, replays the installed fixture for list.
  mkdir -p "$work/bin"
  cat >"$work/bin/nono" <<EOF
#!/usr/bin/env bash
case "\$1" in
  list)   cat "$work/installed.json" ;;
  pull)   shift; echo "pull \$*"   >>"$work/calls.txt" ;;
  remove) shift; echo "remove \$*" >>"$work/calls.txt" ;;
  *) echo "fake nono: unexpected args: \$*" >&2; exit 99 ;;
esac
EOF
  chmod +x "$work/bin/nono"
  : >"$work/calls.txt"

  PATH="$work/bin:$PATH" \
  NONO_BIN="nono" \
  NONO_DESIRED_JSON="$desired" \
  NONO_PRUNE="$prune" \
  NONO_FORCE="$force" \
    bash "$RECONCILE" >/dev/null 2>"$work/err.txt" \
    || fail "[$name] reconcile.sh exited non-zero:\n$(cat "$work/err.txt")"

  local got
  got="$(sort "$work/calls.txt")"
  if [ "$got" != "$expected" ]; then
    fail "[$name] calls mismatch\n--- expected ---\n$expected\n--- got ---\n$got"
  fi
  echo "ok: $name"
}

INSTALLED='{
  "lockfile_version": 4,
  "registry": "https://registry.nono.sh",
  "packages": {
    "always-further/claude": { "version": "0.0.16", "pinned": false },
    "legacy/old":            { "version": "1.0.0",  "pinned": false },
    "keep/stable":           { "version": "2.0.0",  "pinned": false }
  }
}'

# Case 1: a version bump, a brand-new pack, an up-to-date pack, and pruning.
run_case "reconcile-with-prune" \
  "$INSTALLED" \
  '[{"key":"always-further/claude","version":"0.0.17"},
    {"key":"team/new","version":null},
    {"key":"keep/stable","version":"2.0.0"}]' \
  "true" \
  "$(printf '%s\n' 'pull always-further/claude@0.0.17' 'pull team/new' 'remove legacy/old' | sort)"

# Case 2: prune disabled -> never remove unmanaged packs; nothing to change.
run_case "no-prune-noop" \
  "$INSTALLED" \
  '[{"key":"always-further/claude","version":"0.0.16"}]' \
  "false" \
  ""

# Case 3: empty / first-run state (no lockfile yet) -> pull everything desired.
run_case "first-run" \
  '{}' \
  '[{"key":"always-further/claude","version":null},{"key":"team/new","version":"3.1.4"}]' \
  "true" \
  "$(printf '%s\n' 'pull always-further/claude' 'pull team/new@3.1.4' | sort)"

# Case 4: force=true threads --force through to every pull.
run_case "force-pull" \
  '{}' \
  '[{"key":"team/new","version":"3.1.4"}]' \
  "true" \
  "pull team/new@3.1.4 --force" \
  "true"

# Case 5: a dry run ($NONO_RUN set) must NOT mutate -- no pull/remove reaches
# nono, even though the plan has work to do.
dry_run_makes_no_mutations() {
  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN

  printf '%s' "$INSTALLED" >"$work/installed.json"
  mkdir -p "$work/bin"
  cat >"$work/bin/nono" <<EOF
#!/usr/bin/env bash
case "\$1" in
  list)          cat "$work/installed.json" ;;
  pull|remove)   echo "MUTATED: \$*" >>"$work/calls.txt" ;;
  *) exit 99 ;;
esac
EOF
  chmod +x "$work/bin/nono"
  : >"$work/calls.txt"

  PATH="$work/bin:$PATH" \
  NONO_BIN="nono" \
  NONO_DESIRED_JSON='[{"key":"team/new","version":"9.9.9"}]' \
  NONO_PRUNE="true" \
  NONO_RUN="echo would-run:" \
    bash "$RECONCILE" >"$work/out.txt" 2>&1 \
    || fail "[dry-run] reconcile.sh exited non-zero:\n$(cat "$work/out.txt")"

  [ ! -s "$work/calls.txt" ] || fail "[dry-run] nono was mutated:\n$(cat "$work/calls.txt")"
  grep -q 'would-run: nono pull team/new@9.9.9' "$work/out.txt" \
    || fail "[dry-run] expected printed pull plan, got:\n$(cat "$work/out.txt")"
  grep -q 'would-run: nono remove legacy/old' "$work/out.txt" \
    || fail "[dry-run] expected printed remove plan, got:\n$(cat "$work/out.txt")"
  echo "ok: dry-run-no-mutations"
}
dry_run_makes_no_mutations

echo "ALL TESTS PASSED"
