#!/usr/bin/env bash
# Detect and apply new upstream releases of Herdr UI (herdr-gpui).
#
#   update.sh            bump sources.json to the latest release
#   update.sh --check    report only; exit 1 if a newer release exists
#
# Only the macOS universal app bundle is pinned (Linux builds from the upstream
# flake), so there is a single hash. Releases are read from the GitHub API,
# whose "latest" excludes drafts and prereleases. Set GITHUB_TOKEN to lift the
# 60 requests per hour anonymous rate limit.
#
# Env:
#   HERDR_GPUI_SOURCES_JSON  pin to read/write (default:
#                            pkgs/herdr-gpui/sources.json relative to the
#                            current directory)
#   GITHUB_TOKEN             optional GitHub API token

set -euo pipefail

check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  --help | -h)
    sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "update.sh: unknown argument '$1' (expected --check)" >&2
    exit 2
    ;;
esac

sources="${HERDR_GPUI_SOURCES_JSON:-pkgs/herdr-gpui/sources.json}"

if [ ! -f "$sources" ]; then
  echo "update.sh: no pin at '$sources'" >&2
  echo "  run from the repository root, or set HERDR_GPUI_SOURCES_JSON" >&2
  exit 1
fi

repo="$(jq -r '.repo' "$sources")"
pinned="$(jq -r '.version' "$sources")"

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
  echo "herdr-gpui is up to date ($pinned)"
  exit 0
fi

if [ "$check_only" = true ]; then
  echo "herdr-gpui update available: $pinned -> $latest"
  echo "  apply with: task herdr-gpui-update"
  exit 1
fi

echo "herdr-gpui: $pinned -> $latest"

# Must match the asset and tag naming in default.nix.
asset="herdr-gpui-$latest-macos-universal.app.tar.gz"
url="https://github.com/$repo/releases/download/v$latest/$asset"

printf '  %s ... ' "$asset"
hash="$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r '.hash')"

if [ -z "$hash" ] || [ "$hash" = "null" ]; then
  echo "failed" >&2
  echo "update.sh: no hash for $url" >&2
  exit 1
fi
echo "$hash"

# Write version and hash together, so a failed prefetch above can never leave a
# bumped version with a stale hash.
tmp="$(mktemp)"
jq --arg v "$latest" --arg h "$hash" '.version = $v | .hash = $h' "$sources" >"$tmp"
mv "$tmp" "$sources"

echo "updated $sources to $latest"
