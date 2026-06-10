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
    inputs.self.homeManagerModules.yt-dlp
  ];

  home = {
    username = "jon";
    homeDirectory = "/Users/jon";
  };

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

  fonts.fontconfig.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
