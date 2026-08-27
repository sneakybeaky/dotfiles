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
# To bump: change `version` below, then refresh each hash with
#   nix-prefetch-url https://github.com/getsentry/cli/releases/download/<version>/<asset>
#   nix hash to-sri --type sha256 <returned-hash>
{
  lib,
  stdenvNoCC,
  fetchurl,
  gzip,
}:
let
  version = "0.43.0";

  # Upstream publishes one self-contained executable per platform. There is no
  # 32-bit Linux build, so i686-linux is deliberately absent.
  sources = {
    aarch64-darwin = {
      asset = "sentry-darwin-arm64.gz";
      hash = "sha256-x7GwL7/LB6F46IpS3EVzKOND75VhstglBALrnIwSNHY=";
    };
    x86_64-darwin = {
      asset = "sentry-darwin-x64.gz";
      hash = "sha256-40Mdzff83b8qyrD0nFAZiaDLGVxW46AjS8CJD3kXhvs=";
    };
    aarch64-linux = {
      asset = "sentry-linux-arm64.gz";
      hash = "sha256-xNBZ3lZ/u6lEXEBmb/Nytu+RlqLVIxB1SALbT0adNhw=";
    };
    x86_64-linux = {
      asset = "sentry-linux-x64.gz";
      hash = "sha256-MAPXijwHQKzDlYQAnKLdbyjanwNlyyhT2JxDpCofFgs=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;

  source = sources.${system} or (throw "sentry: no upstream release build for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "sentry";
  inherit version;

  src = fetchurl {
    url = "https://github.com/getsentry/cli/releases/download/${version}/${source.asset}";
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

  meta = {
    description = "Sentry CLI for developers and agents";
    homepage = "https://cli.sentry.dev/";
    downloadPage = "https://github.com/getsentry/cli/releases";
    changelog = "https://github.com/getsentry/cli/releases/tag/${version}";
    # Source-available, not OSI open source: converts to Apache 2.0 two years
    # after each release. nixpkgs marks this unfree, hence allowUnfree.
    license = lib.licenses.fsl11Asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "sentry";
    platforms = lib.attrNames sources;
  };
}
