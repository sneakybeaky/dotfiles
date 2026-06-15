# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.homeManagerModules.nixpkgs
    inputs.self.homeManagerModules.tools
    inputs.self.homeManagerModules.ai
    inputs.self.homeManagerModules.ai-skills
    inputs.self.homeManagerModules.starship
    inputs.self.homeManagerModules.fish
    inputs.self.homeManagerModules.atuin
    inputs.self.homeManagerModules.zed
    inputs.self.homeManagerModules.eza
    inputs.self.homeManagerModules.direnv
    inputs.self.homeManagerModules.television
    inputs.self.homeManagerModules.fd
    inputs.self.homeManagerModules.bat
    inputs.self.homeManagerModules.fonts
  ];

  home = {
    username = "jon.barber";
    homeDirectory = "/Users/jon.barber";
  };

  home.packages = with pkgs; [
    unstablePkgs.granted
    unstablePkgs.postgresql_18
    unstablePkgs.gopls
    unstablePkgs.amazon-ecr-credential-helper
    unstablePkgs.gh
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

    # Work-specific shell additions, merged with the base config from fish.nix
    fish.shellInit = # fish
      ''
        source ~/.orbstack/shell/init2.fish 2>/dev/null || :
        fish_add_path "/Users/jon.barber/Library/Application Support/JetBrains/Toolbox/scripts"
      '';
  };

  fonts.fontconfig.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
