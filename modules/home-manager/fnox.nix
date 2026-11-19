{
  pkgs,
  ...
}:
{
  imports = [ ./upstream/fnox.nix ];

  programs.fnox = {
    enable = true;
    package = pkgs.unstablePkgs.fnox;
    enableFishIntegration = true;
  };
}
