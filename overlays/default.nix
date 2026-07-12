# This file defines overlays
# These are arbitrary named and just some conventions I use, you can name then whenever and/or make as many as you want
{ inputs, ... }:
let
  # Build an overlay that replaces named packages with the versions from a
  # pinned nixpkgs revision, keeping known-good pins independent of the
  # tracked channels.
  pinFromNixpkgs =
    {
      rev,
      narHash,
      names,
    }:
    final: prev:
    let
      pinned =
        import
          (fetchTree {
            type = "github";
            owner = "nixos";
            repo = "nixpkgs";
            inherit rev narHash;
          })
          {
            system = prev.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
    in
    builtins.listToAttrs (
      map (n: {
        name = n;
        value = pinned.${n};
      }) names
    );
in
{
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
  pinned-mise = pinFromNixpkgs {
    rev = "7a1a64774a5fd0b0cd39ac95d0e170ace8b266a0";
    narHash = "sha256-N66fYdUuZ9hpdM7jsQ7CUWtLJduqGDyTGCaLR62CXaQ=";
    names = [ "mise" ];
  };

  # Pin zed-editor to a specific nixpkgs rev so it stays on a known-good
  # version independent of the nixpkgs-unstable channel.
  # Pin: nixpkgs 6edbf1a6a03e75886a6609c088801a0856449e88
  pinned-zed = pinFromNixpkgs {
    rev = "6edbf1a6a03e75886a6609c088801a0856449e88";
    narHash = "sha256-0lkauQbtrljJqwtzTCILPAiHAJyMvn6XDo264moDv30=";
    names = [ "zed-editor" ];
  };

  # Expose the numtide/llm-agents.nix package set as 'pkgs.llm-agents'.
  # Upstream removed its own overlay output, so we build the namespace from
  # the flake's per-system 'packages' instead.
  llm-agents = final: prev: {
    llm-agents = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system};
  };

  # Bump Apple's `container` past the version in nixpkgs (0.12.3 in 26.05).
  # Upstream ships a signed .pkg installer that is unpacked with xar/bsdtar,
  # so overriding `version` + `src` is enough — the build phases are unchanged.
  # Refresh `hash` with `nix-prefetch-url <url>` when bumping the version.
  container =
    let
      version = "1.1.0";
    in
    final: prev: {
      container = prev.container.overrideAttrs {
        inherit version;
        src = prev.fetchurl {
          url = "https://github.com/apple/container/releases/download/${version}/container-${version}-installer-signed.pkg";
          hash = "sha256-DKHEKiJpwlV++x2CsbOKxVPmo6PaGxF5xDm87h59ZxQ=";
        };
      };
    };
}
