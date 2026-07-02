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
  pinned-mise = final: prev: {
    mise = inputs.pinnedMiseVersion.legacyPackages.${prev.stdenv.hostPlatform.system}.mise;
  };
}
