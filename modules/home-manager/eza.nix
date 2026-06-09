{
  pkgs,
  ...
}:
{
  programs.eza = {
    enable = true;
    package = pkgs.unstablePkgs.eza;
    enableFishIntegration = true;
  };
}
