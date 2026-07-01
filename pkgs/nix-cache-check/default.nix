{ buildGoModule, lib }:

buildGoModule {
  pname = "nix-cache-check";
  version = "0.1.0";

  src = ./.;

  # No external module dependencies.
  vendorHash = null;

  meta = {
    description = "Report which Nix store paths are available in binary caches";
    mainProgram = "nix-cache-check";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
