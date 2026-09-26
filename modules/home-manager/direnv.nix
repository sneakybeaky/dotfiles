{
  pkgs,
  ...
}:
{
  programs.direnv = {
    enable = true;
    package = pkgs.direnv;

    # Cached, GC-rooted `use flake` / `use nix` in .envrc files.
    nix-direnv.enable = true;

    # mise = {
    #   enable = true;
    #   package = pkgs.unstablePkgs.mise;
    # };
  };
}
