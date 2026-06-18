{
  description = "Your new nix config";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
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

    # Worktrunk
    home-extra-worktrunk.url = "github:max-sixty/worktrunk";

    # Agent Skills
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };

    addyosmani-skills = {
      url = "github:addyosmani/agent-skills";
      flake = false;
    };

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

    in
    {
      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Formatter for your nix files, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Sandboxed checks, run via 'nix flake check'.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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

          # Default home-manager configuration for MacBooks
          defaultMac = home-manager.lib.homeManagerConfiguration {
            # Home-manager requires 'pkgs' instance
            pkgs = nixpkgs.legacyPackages.aarch64-darwin;
            extraSpecialArgs = {
              inherit inputs;
            };
            modules = [
              ./home-manager/home.nix
            ];
          };

        in
        {
          "jon@Jons-MacBook-Pro-72.local" = defaultMac;
          "jon@Jons-M1-MacBook-Pro.local" = defaultMac;
          "jon.barber@C4GV140CC2" = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.aarch64-darwin;
            extraSpecialArgs = {
              inherit inputs;
            };
            modules = [
              ./home-manager/work.nix
            ];
          };
        };
    };
}
