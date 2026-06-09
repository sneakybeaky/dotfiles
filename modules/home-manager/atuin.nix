{
  pkgs,
  ...
}:
{
  programs.atuin = {
    enable = true;
    package = pkgs.unstablePkgs.atuin;
    enableFishIntegration = true;
  };
}
