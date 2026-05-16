# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # inputs.self.homeManagerModules.example
    (inputs.self.homeManagerModules.tools { inherit pkgs;})
    (inputs.self.homeManagerModules.ai { inherit pkgs;})
    (inputs.self.homeManagerModules.starship { inherit pkgs;})
    (inputs.self.homeManagerModules.fish { inherit pkgs;})
    (inputs.self.homeManagerModules.atuin { inherit pkgs;})
    (inputs.self.homeManagerModules.zed { inherit pkgs;})
    (inputs.self.homeManagerModules.eza { inherit pkgs;})
    (inputs.self.homeManagerModules.direnv { inherit pkgs;})
    (inputs.self.homeManagerModules.television { inherit pkgs;})
    (inputs.self.homeManagerModules.fd { inherit pkgs;})
    (inputs.self.homeManagerModules.bat { inherit pkgs;})
    (inputs.self.homeManagerModules.fonts { inherit pkgs;})

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages
      inputs.llm-agents.overlays.default

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # TODO: Set your username
  home = {
    username = "jon";
    homeDirectory = "/Users/jon";
  };

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];
  home.packages = with pkgs; [
    unstablePkgs.go-task
  ];


  programs = {
    git.enable = true;
    home-manager.enable = true;
    go = {
      enable = true;
      package = pkgs.unstablePkgs.go;
    };
  };

  fonts.fontconfig = {
    enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
