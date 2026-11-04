# Sheprd, formerly Herdr UI (https://sheprd.org,
# https://github.com/sheprd-labs/sheprd): a native GPUI client for the Herdr
# daemon (pkgs.llm-agents.herdr). The package keeps its herdr-gpui name.
#
# macOS only. Upstream's flake builds the Linux backend from source but not
# macOS, so on Darwin we install the signed and notarized universal app bundle
# from the GitHub release. Linux hosts should use the upstream flake input
# instead (see modules/home-manager/ai.nix).
#
# The version and hash live in ./sources.json. Do not edit that file by hand;
# run `task herdr-gpui-update` (or `nix run .#herdr-gpui-update`), which is also
# wired up as passthru.updateScript below.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  writeShellApplication,
  curl,
  jq,
  coreutils,
}:
let
  # Shared with update.sh, so there is one source of truth for the version and
  # hash. Release tags are "v<version>".
  pin = lib.importJSON ./sources.json;
  asset = "sheprd-${pin.version}-macos-universal.app.tar.gz";
in
stdenvNoCC.mkDerivation {
  pname = "herdr-gpui";
  inherit (pin) version;

  src = fetchurl {
    url = "https://github.com/${pin.repo}/releases/download/v${pin.version}/${asset}";
    inherit (pin) hash;
  };

  # The tarball holds a single Sheprd.app at its root.
  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  # The bundle is code signed. Stripping or patching anything inside it would
  # break the signature and Gatekeeper would refuse to launch it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R Sheprd.app "$out/Applications/"

    # A wrapper rather than a symlink: the app finds sheprd-acp,
    # sheprd-automate and sheprd-remote-control beside its own executable, so
    # it has to be exec'd from inside the bundle. Kept as `herdr-gpui` so the
    # command works the same on every host.
    makeWrapper "$out/Applications/Sheprd.app/Contents/MacOS/sheprd" "$out/bin/herdr-gpui"
    runHook postInstall
  '';

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "herdr-gpui-update";
    runtimeInputs = [
      curl
      jq
      coreutils
    ];
    text = builtins.readFile ./update.sh;
  });

  meta = {
    description = "Native GPUI client for an existing local Herdr daemon";
    homepage = "https://sheprd.org";
    downloadPage = "https://github.com/${pin.repo}/releases";
    changelog = "https://github.com/${pin.repo}/releases/tag/v${pin.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "herdr-gpui";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
