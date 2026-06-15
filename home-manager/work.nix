# Work MacBook home-manager configuration.
# Shared config lives in ./common.nix.
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./common.nix
    inputs.self.homeManagerModules.ai-skills
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
}
