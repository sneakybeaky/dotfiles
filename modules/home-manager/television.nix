{
  pkgs,
  ...
}: {
  programs.television = {
    enable = true;
    package = pkgs.unstablePkgs.television;
    enableFishIntegration = true;
  };

}
