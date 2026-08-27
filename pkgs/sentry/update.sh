#!/usr/bin/env bash
# Detect and apply new upstream releases of the sentry CLI.
#
#   update.sh            bump sources.json to the latest release
#   update.sh --check    report only; exit 1 if a newer release exists
#
# The pin lives in sources.json rather than in default.nix so that updating is a
# JSON edit (robust) instead of a Nix-expression rewrite (fragile). That is also
# why nix-update cannot drive this package directly: it rewrites a single
# version/hash pair, and we carry one hash per platform. Hence the nixpkgs
# convention of passthru.updateScript, which points here.
#
# Releases are read from the GitHub API because that is where we fetch the
# assets from, so there is no window where a version is announced but its
# artifacts are not yet downloadable. Set GITHUB_TOKEN to lift the 60 requests
# per hour anonymous rate limit.
#
# Env:
#   SENTRY_SOURCES_JSON  pin to read/write (default: pkgs/sentry/sources.json
#                        relative to the current directory)
#   GITHUB_TOKEN         optional GitHub API token

set -euo pipefail

check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  --help | -h)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "update.sh: unknown argument '$1' (expected --check)" >&2
    exit 2
    ;;
esac

sources="${SENTRY_SOURCES_JSON:-pkgs/sentry/sources.json}"

if [ ! -f "$sources" ]; then
  echo "update.sh: no pin at '$sources'" >&2
  echo "  run from the repository root, or set SENTRY_SOURCES_JSON" >&2
  exit 1
fi

repo="$(jq -r '.repo' "$sources")"
pinned="$(jq -r '.version' "$sources")"

# GitHub's "latest" excludes drafts and prereleases, which is what we want.
auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

latest="$(
  curl -fsSL "${auth[@]}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name'
)"
latest="${latest#v}"

if [ -z "$latest" ] || [ "$latest" = "null" ]; then
  echo "update.sh: could not determine the latest $repo release" >&2
  exit 1
fi

if [ "$latest" = "$pinned" ]; then
  echo "sentry is up to date ($pinned)"
  exit 0
fi

if [ "$check_only" = true ]; then
  echo "sentry update available: $pinned -> $latest"
  echo "  apply with: task sentry-update"
  exit 1
fi

echo "sentry: $pinned -> $latest"

# Refresh every platform hash before touching the pin, so a failed prefetch
# cannot leave behind a bumped version with stale hashes.
updated="$(jq --arg v "$latest" '.version = $v' "$sources")"

while IFS= read -r system; do
  asset="$(jq -r --arg s "$system" '.platforms[$s].asset' "$sources")"
  url="https://github.com/$repo/releases/download/$latest/$asset"

  printf '  %-16s %s ... ' "$system" "$asset"
  hash="$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r '.hash')"

  if [ -z "$hash" ] || [ "$hash" = "null" ]; then
    echo "failed" >&2
    echo "update.sh: no hash for $url" >&2
    exit 1
  fi
  echo "$hash"

  updated="$(printf '%s' "$updated" | jq --arg s "$system" --arg h "$hash" \
    '.platforms[$s].hash = $h')"
done < <(jq -r '.platforms | keys[]' "$sources")

tmp="$(mktemp)"
printf '%s\n' "$updated" >"$tmp"
mv "$tmp" "$sources"

echo "updated $sources to $latest"
