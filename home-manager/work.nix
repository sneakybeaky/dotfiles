# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  pkgs,
  ...
}:
{
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # inputs.self.homeManagerModules.example
    (inputs.self.homeManagerModules.tools { inherit pkgs; })
    (inputs.self.homeManagerModules.ai { inherit pkgs; })
    (inputs.self.homeManagerModules.starship { inherit pkgs; })
    (inputs.self.homeManagerModules.atuin { inherit pkgs; })
    (inputs.self.homeManagerModules.zed { inherit pkgs; })
    (inputs.self.homeManagerModules.eza { inherit pkgs; })
    (inputs.self.homeManagerModules.direnv { inherit pkgs; })
    (inputs.self.homeManagerModules.television { inherit pkgs; })
    (inputs.self.homeManagerModules.fd { inherit pkgs; })
    (inputs.self.homeManagerModules.bat { inherit pkgs; })
    (inputs.self.homeManagerModules.fonts { inherit pkgs; })

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
    username = "jon.barber";
    homeDirectory = "/Users/jon.barber";
    shell.enableFishIntegration = true;
  };

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];
  home.packages = with pkgs; [
    unstablePkgs.granted
    unstablePkgs.postgresql_18
    unstablePkgs.gopls
    unstablePkgs.mise
    unstablePkgs.amazon-ecr-credential-helper
    unstablePkgs.gh
    unstablePkgs.amazon-ecr-credential-helper
  ];

  programs = {
    git.enable = true;
    home-manager.enable = true;
    go = {
      enable = true;
      package = pkgs.unstablePkgs.go;
    };

    mise = {
      enable = true;
      package = pkgs.unstablePkgs.mise;
      enableFishIntegration = true;
    };

    awscli = {
      enable = true;
      package = pkgs.unstablePkgs.awscli;
    };

    fish = {
      enable = true;
      package = pkgs.unstablePkgs.fish;

      shellInit = # fish
        ''
          fish_add_path $HOME/.nix-profile/bin /nix/var/nix/profiles/default/bin
          set -x -U EDITOR "zeditor --wait"
          set -x -U VISUAL "zeditor --wait"

          source ~/.orbstack/shell/init2.fish 2>/dev/null || :

          fish_add_path "/Users/jon.barber/Library/Application Support/JetBrains/Toolbox/scripts"

          fish_default_key_bindings
        '';

      interactiveShellInit = ''
        # Fish syntax highlighting
        set -g fish_color_autosuggestion '555'  'brblack'
        set -g fish_color_cancel -r
        set -g fish_color_command --bold
        set -g fish_color_comment red
        set -g fish_color_cwd green
        set -g fish_color_cwd_root red
        set -g fish_color_end brmagenta
        set -g fish_color_error brred
        set -g fish_color_escape 'bryellow'  '--bold'
        set -g fish_color_history_current --bold
        set -g fish_color_host normal
        set -g fish_color_match --background=brblue
        set -g fish_color_normal normal
        set -g fish_color_operator bryellow
        set -g fish_color_param cyan
        set -g fish_color_quote yellow
        set -g fish_color_redirection brblue
        set -g fish_color_search_match 'bryellow'  '--background=brblack'
        set -g fish_color_selection 'white'  '--bold'  '--background=brblack'
        set -g fish_color_user brgreen
        set -g fish_color_valid_path --underline

        set fish_greeting "🐟 Welcome back, $(whoami)!"
      '';

    };

  };

  fonts.fontconfig = {
    enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
