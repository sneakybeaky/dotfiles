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
  ];

  home = {
    username = "jon";
    homeDirectory = "/Users/jon";
  };

  home.packages = with pkgs; [
    unstablePkgs.go-task
  ];
}
