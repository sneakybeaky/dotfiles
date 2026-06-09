{
  pkgs,
  ...
}:
{
  programs.direnv = {
    enable = true;
    package = pkgs.unstablePkgs.direnv;

    mise = {
      enable = true;
      package = pkgs.unstablePkgs.mise;
    };
  };
}
