# Shared home-manager configuration imported by every host entrypoint
# (home.nix, work.nix). Host-specific bits — username, home directory,
# packages, and any extra modules/programs — live in those files.
{
  inputs,
  pkgs,
  ...
}:
{
  # Import every shared module; the set is defined in
  # modules/home-manager/default.nix.
  imports = builtins.attrValues inputs.self.homeManagerModules.shared;

  home.packages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nix-cache-check
  ];

  programs = {
    git.enable = true;
    home-manager.enable = true;
    go = {
      enable = true;
      package = pkgs.unstablePkgs.go;
    };
  };

  fonts.fontconfig.enable = true;

  manual.json.enable = false;
  manual.html.enable = false;
  manual.manpages.enable = false;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
