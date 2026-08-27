# The Sentry CLI (https://cli.sentry.dev/, https://github.com/getsentry/cli).
#
# This is Sentry's newer TypeScript CLI published to npm as `sentry`, not the
# older Rust `sentry-cli`. Upstream ships a self-contained bundle per platform
# (the runtime is baked in, so there is no Node.js dependency) which is what we
# install here — the alternative would be building the pnpm workspace, which
# needs a lockfile-derived FOD for no benefit over the official artifact.
#
# We fetch the gzipped asset: 27MB compressed against 102MB uncompressed.
#
# The version and per-platform hashes live in ./sources.json. Do not edit that
# file by hand — run `task sentry-update` (or `nix run .#sentry-update`), which
# is also wired up as passthru.updateScript below.
{
  lib,
  stdenvNoCC,
  fetchurl,
  gzip,
  writeShellApplication,
  curl,
  jq,
  coreutils,
}:
let
  # The pin, shared with update.sh so there is one source of truth for the
  # version, the asset names and their hashes.
  pin = lib.importJSON ./sources.json;

  inherit (stdenvNoCC.hostPlatform) system;

  # Upstream publishes no 32-bit Linux build, so i686-linux is absent from the
  # pin. Kept lazy: this only fires on an actual build for such a system.
  source = pin.platforms.${system} or (throw "sentry: no upstream release build for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "sentry";
  inherit (pin) version;

  src = fetchurl {
    url = "https://github.com/${pin.repo}/releases/download/${pin.version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = [ gzip ];

  # The artifact is a single gzipped executable, not a tarball.
  unpackPhase = ''
    runHook preUnpack
    gzip -dc "$src" > sentry
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 sentry "$out/bin/sentry"
    runHook postInstall
  '';

  # The nixpkgs convention for packages whose pin a generic updater cannot
  # rewrite: nix-update -F -u sentry will run this. Wrapped so it is
  # shellcheck-validated at build time and gets its tools declaratively.
  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "sentry-update";
    runtimeInputs = [
      curl
      jq
      coreutils
    ];
    text = builtins.readFile ./update.sh;
  });

  meta = {
    description = "Sentry CLI for developers and agents";
    homepage = "https://cli.sentry.dev/";
    downloadPage = "https://github.com/getsentry/cli/releases";
    changelog = "https://github.com/${pin.repo}/releases/tag/${pin.version}";
    # Source-available, not OSI open source: converts to Apache 2.0 two years
    # after each release. nixpkgs marks this unfree, hence allowUnfree.
    license = lib.licenses.fsl11Asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "sentry";
    platforms = lib.attrNames pin.platforms;
  };
}
