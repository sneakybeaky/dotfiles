# This file defines overlays
# These are arbitrary named and just some conventions I use, you can name then whenever and/or make as many as you want
{ inputs, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstablePkgs'
  unstable-packages = final: _prev: {
    unstablePkgs = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # Override mise with a pinned nixpkgs rev so home-manager's programs.mise
  # module uses a known-good version regardless of the main nixpkgs channel.
  # Pin: mise 2026.6.11 — update via https://www.nixhub.io/packages/mise
  pinned-mise =
    let
      pinnedNixpkgs = builtins.fetchTree {
        type = "github";
        owner = "nixos";
        repo = "nixpkgs";
        rev = "7a1a64774a5fd0b0cd39ac95d0e170ace8b266a0";
        narHash = "sha256-N66fYdUuZ9hpdM7jsQ7CUWtLJduqGDyTGCaLR62CXaQ=";
      };
    in
    final: prev: {
      mise = (import pinnedNixpkgs { system = prev.stdenv.hostPlatform.system; }).mise;
    };
}
