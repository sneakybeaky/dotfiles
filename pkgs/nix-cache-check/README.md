# nix-cache-check

A small Go CLI that reports which Nix store paths are already available in one
or more binary caches (substituters). It answers the question: *"when I install
this, what will Nix download vs. build locally?"*

It resolves the store paths to check, then issues a `HEAD` request for each
path's `.narinfo` on every cache. A `200` means the path can be substituted; a
`404` means it would be built locally.

## Building / running

```sh
# Build via the flake
nix build .#nix-cache-check
./result/bin/nix-cache-check -h

# Or run directly during development
go run . -h
```

## Usage

```
nix-cache-check [flags] [installable|store-path ...]
```

Store paths come from one of three sources:

1. **Installables** passed as arguments, resolved with `nix path-info`
   (the paths must already be built/valid locally).
2. **Installables with `-eval`**, resolved with `nix derivation show` — this
   only evaluates, so it works for things you haven't built yet (it reports the
   build-time closure).
3. **stdin** (newline-separated store paths) when no arguments are given.

### Flags

| Flag       | Description                                                          |
| ---------- | -------------------------------------------------------------------- |
| `-caches`  | Comma-separated cache URLs. Defaults to `nix config show substituters`. |
| `-r`       | Expand each installable to its full closure.                         |
| `-eval`    | Resolve output paths by evaluation (works for unbuilt installables). |
| `-missing` | Only report paths missing from at least one cache.                   |
| `-quiet`   | Print bare store paths only (implies `-missing` unless `-json`).     |
| `-json`    | Emit results as JSON.                                                |
| `-j`       | Number of concurrent requests (default 16).                          |
| `-timeout` | Per-request timeout (default 15s).                                   |

## Examples

```sh
# Full closure of a package that isn't built yet, against configured caches
nix-cache-check -eval -r nixpkgs#hello

# Check the current home-manager generation's runtime closure
nix path-info -r ~/.local/state/nix/profiles/home-manager | nix-cache-check

# Only paths missing everywhere, as bare paths (handy for scripting)
nix-cache-check -eval -r -quiet .#packages.aarch64-darwin.default

# Query specific caches as JSON
nix-cache-check -json -caches https://cache.numtide.com,https://cache.garnix.io \
  /nix/store/xxxx-hello-2.12.3
```

## Taskfile helpers

Two convenience tasks are defined in the repo's `Taskfile.yml`:

```sh
# Build the current host's home config and list closure paths missing from caches
task cache-check

# Check whether an unstable package would be substituted. This resolves the
# package's output path through the flake's *locked* nixpkgs-unstable input
# (same config as the overlay), so it matches exactly what home-manager builds.
task cache-check-unstable -- mise
```
