{
  description = "Your new nix config";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # LLM Agents
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Agent Skills
    # Skill repositories are managed via the source registry
    # (registry/sources/*.nix + registry/sources.lock.json) rather than as
    # flake inputs. Refresh them with `nix run .#skills-sources-lock`.
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Supported systems for your flake packages, shell, etc.
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # This is a function that generates an attribute by calling a function you
      # pass to it, with each system as an argument
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # An instantiated nixpkgs with unfree allowed. 'nixpkgs.config' from
      # modules/home-manager/nixpkgs.nix cannot apply to an already-built pkgs
      # set (only overlays can be appended after the fact), so the config has to
      # be set here instead. pkgs/sentry is FSL-1.1, which nixpkgs treats as
      # unfree, and would otherwise refuse to build.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

    in
    {
      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (system: import ./pkgs (pkgsFor system));
      # Formatter for your nix files, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Refresh the agent-skills source registry lock via
      # 'nix run .#skills-sources-lock'.
      apps = forAllSystems (
        system:
        let
          agentLib = inputs.agent-skills.lib.agent-skills;
          sourceLockProgram = agentLib.mkSourceLockProgram {
            pkgs = nixpkgs.legacyPackages.${system};
            # npins >= 0.5 is required to emit the v8 source lock schema that
            # agent-skills-nix consumes; nixpkgs 26.05 still ships 0.4.x.
            npins = inputs.nixpkgs-unstable.legacyPackages.${system}.npins;
          };
        in
        {
          skills-sources-lock = {
            type = "app";
            program = "${sourceLockProgram}/bin/skills-sources-lock";
          };
        }
      );

      # Sandboxed checks, run via 'nix flake check'.
      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          # Acceptance tests for the nono pack reconcile logic (no network).
          nono-reconcile =
            pkgs.runCommand "nono-reconcile-test"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.jq
                  pkgs.coreutils
                  pkgs.gnugrep
                ];
              }
              ''
                bash ${./modules/home-manager/nono}/tests/reconcile_test.sh
                touch "$out"
              '';

          # The packaged sentry CLI must actually run on this system and report
          # the version the derivation pins.
          sentry =
            let
              sentry = self.packages.${system}.sentry;
            in
            pkgs.runCommand "sentry-version-test"
              {
                nativeBuildInputs = [ sentry ];
              }
              ''
                # The bundled runtime expects a writable HOME.
                export HOME="$(mktemp -d)"
                got="$(sentry --version)"
                want="${sentry.version}"
                if [ "$got" != "$want" ]; then
                  echo "sentry reported the wrong version" >&2
                  echo "  want: $want" >&2
                  echo "  got:  $got" >&2
                  exit 1
                fi
                touch "$out"
              '';
        }
      );

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      homeManagerModules = import ./modules/home-manager;

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations =
        let

          # Build a standalone home-manager configuration for an aarch64-darwin
          # host from a single entrypoint module.
          mkHome =
            module:
            home-manager.lib.homeManagerConfiguration {
              # Home-manager requires 'pkgs' instance
              pkgs = pkgsFor "aarch64-darwin";
              extraSpecialArgs = {
                inherit inputs;
              };
              modules = [ module ];
            };

        in
        {
          "jon@Jons-MacBook-Pro-72.local" = mkHome ./home-manager/home.nix;
          "jon@Jons-M1-MacBook-Pro.local" = mkHome ./home-manager/home.nix;
          "jon.barber@C4GV140CC2" = mkHome ./home-manager/work.nix;
        };
    };
}
