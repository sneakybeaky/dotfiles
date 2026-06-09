{
  pkgs,
  ...
}:
{
  programs.fd = {
    enable = true;
    package = pkgs.unstablePkgs.fd;
  };

}
