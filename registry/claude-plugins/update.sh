#!/usr/bin/env bash
# Move every pinned Claude Code plugin to the head of its tracked branch.
#
#   update.sh            bump sources.json to the latest commits
#   update.sh --check    report only; exit 1 if any plugin is behind
#
# Branch heads are read with `git ls-remote`, which needs no GitHub API token
# and is not rate limited. Hashes come from `nix flake prefetch`, whose NAR
# hash is exactly what fetchFromGitHub expects.
#
# Every new hash is computed before anything is written, so a failed fetch
# cannot leave behind a bumped rev with a stale hash.
#
# Env:
#   CLAUDE_PLUGINS_SOURCES_JSON  pin to read/write (default:
#                                registry/claude-plugins/sources.json relative
#                                to the current directory)

set -euo pipefail

check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  --help | -h)
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "update.sh: unknown argument '$1' (expected --check)" >&2
    exit 2
    ;;
esac

sources="${CLAUDE_PLUGINS_SOURCES_JSON:-registry/claude-plugins/sources.json}"

if [ ! -f "$sources" ]; then
  echo "update.sh: no pin at '$sources'" >&2
  echo "  run from the repository root, or set CLAUDE_PLUGINS_SOURCES_JSON" >&2
  exit 1
fi

updated="$(cat "$sources")"
behind=0

while IFS= read -r name; do
  owner="$(jq -r --arg n "$name" '.[$n].owner' "$sources")"
  repo="$(jq -r --arg n "$name" '.[$n].repo' "$sources")"
  branch="$(jq -r --arg n "$name" '.[$n].branch' "$sources")"
  pinned="$(jq -r --arg n "$name" '.[$n].rev' "$sources")"

  latest="$(git ls-remote "https://github.com/$owner/$repo.git" "refs/heads/$branch" | cut -f1)"

  if [ -z "$latest" ]; then
    echo "update.sh: could not read $owner/$repo branch '$branch'" >&2
    exit 1
  fi

  if [ "$latest" = "$pinned" ]; then
    echo "$name is up to date (${pinned:0:7})"
    continue
  fi

  behind=$((behind + 1))

  if [ "$check_only" = true ]; then
    echo "$name update available: ${pinned:0:7} -> ${latest:0:7}"
    continue
  fi

  printf '%s: %s -> %s ... ' "$name" "${pinned:0:7}" "${latest:0:7}"
  hash="$(
    nix --extra-experimental-features 'nix-command flakes' \
      flake prefetch --json "github:$owner/$repo/$latest" | jq -r '.hash'
  )"

  if [ -z "$hash" ] || [ "$hash" = "null" ]; then
    echo "failed" >&2
    echo "update.sh: no hash for github:$owner/$repo/$latest" >&2
    exit 1
  fi
  echo "$hash"

  updated="$(printf '%s' "$updated" | jq --arg n "$name" --arg r "$latest" --arg h "$hash" \
    '.[$n].rev = $r | .[$n].hash = $h')"
done < <(jq -r 'keys[]' "$sources")

if [ "$check_only" = true ]; then
  if [ "$behind" -gt 0 ]; then
    echo "  apply with: task claude-plugins-update"
    exit 1
  fi
  exit 0
fi

if [ "$behind" -eq 0 ]; then
  exit 0
fi

tmp="$(mktemp)"
printf '%s\n' "$updated" >"$tmp"
mv "$tmp" "$sources"

echo "updated $sources"
