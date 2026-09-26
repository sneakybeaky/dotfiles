# Personal MacBook home-manager configuration.
# Shared config lives in ./common.nix.
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./common.nix
    inputs.self.homeManagerModules.yt-dlp
    inputs.self.homeManagerModules.ai-personal
    inputs.self.homeManagerModules._1password-shell-plugins
  ];

  home = {
    username = "jon";
    homeDirectory = "/Users/jon";
  };

  home.packages = with pkgs; [
    unstablePkgs.go-task
  ];
}
