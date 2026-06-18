#!/usr/bin/env bash
# Reconcile installed nono packs against a declarative desired set.
#
# Reads the desired set from the environment (the home-manager module bakes
# these in), asks nono what is currently installed, computes a plan with
# plan.jq, then drives `nono pull` / `nono remove` to converge.
#
# Configuration (all via environment):
#   NONO_BIN          path to the nono binary           (default: nono)
#   NONO_DESIRED_JSON desired set, JSON array of         (default: [])
#                       { "key": "<ns>/<name>", "version": <string|null> }
#   NONO_PRUNE        "true" -> remove unmanaged packs   (default: false)
#   NONO_FORCE        "true" -> pass --force to pull     (default: false)
#   NONO_REGISTRY     honoured natively by nono itself (we never pass --registry)
#   NONO_RUN          prefix for *mutating* calls (default: none). The module
#                       wires this to home-manager's $DRY_RUN_CMD so that
#                       `home-manager build` / `switch --dry-run` only prints
#                       the pull/remove it would run. The read-only `list` is
#                       never prefixed, so planning still works during a dry run.
#
# Idempotent: a fully-converged system produces no pull/remove calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_JQ="${NONO_PLAN_JQ:-$SCRIPT_DIR/plan.jq}"

NONO_BIN="${NONO_BIN:-nono}"
NONO_DESIRED_JSON="${NONO_DESIRED_JSON:-[]}"
NONO_PRUNE="${NONO_PRUNE:-false}"
NONO_FORCE="${NONO_FORCE:-false}"
NONO_RUN="${NONO_RUN:-}"

log() { echo "nono-packs: $*"; }

# Current state. `list` exits non-zero / prints nothing before nono is set up;
# treat any failure as an empty lockfile so first-run still converges.
installed="$("$NONO_BIN" list --installed --json 2>/dev/null || true)"
[ -n "$installed" ] || installed='{}'

prune_bool=false
[ "$NONO_PRUNE" = "true" ] && prune_bool=true

plan="$(
  printf '%s' "$installed" \
    | jq -c --argjson desired "$NONO_DESIRED_JSON" --argjson prune "$prune_bool" -f "$PLAN_JQ"
)"

# Summarise up front so a fully-converged (no-op) run is still visible in the
# activation log rather than printing nothing at all.
log "$(printf '%s' "$plan" \
  | jq -r '"\(.pull|length) to pull, \(.remove|length) to remove, \(.keep|length) already present"')"

# Pull missing / changed packs.
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  log "pull $ref"
  # $NONO_RUN is intentionally unquoted: empty -> runs directly; under a dry
  # run it is $DRY_RUN_CMD and turns the mutation into a printed no-op.
  if [ "$NONO_FORCE" = "true" ]; then
    # shellcheck disable=SC2086
    $NONO_RUN "$NONO_BIN" pull "$ref" --force
  else
    # shellcheck disable=SC2086
    $NONO_RUN "$NONO_BIN" pull "$ref"
  fi
done < <(printf '%s' "$plan" | jq -r '.pull[]')

# Remove unmanaged packs (only when pruning is enabled).
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  log "remove $ref"
  # shellcheck disable=SC2086
  $NONO_RUN "$NONO_BIN" remove "$ref"
done < <(printf '%s' "$plan" | jq -r '.remove[]')
