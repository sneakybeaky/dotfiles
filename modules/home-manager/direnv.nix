{
  pkgs,
  ...
}:
{
  programs.direnv = {
    enable = true;
    package = pkgs.direnv;

    # mise = {
    #   enable = true;
    #   package = pkgs.unstablePkgs.mise;
    # };
  };
}
