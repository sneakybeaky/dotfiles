# Shared home-manager configuration imported by every host entrypoint
# (home.nix, work.nix). Host-specific bits — username, home directory,
# packages, and any extra modules/programs — live in those files.
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.homeManagerModules.nixpkgs
    inputs.self.homeManagerModules.tools
    inputs.self.homeManagerModules.ai
    inputs.self.homeManagerModules.nono
    inputs.self.homeManagerModules.starship
    inputs.self.homeManagerModules.fish
    inputs.self.homeManagerModules.atuin
    inputs.self.homeManagerModules.zed
    inputs.self.homeManagerModules.eza
    inputs.self.homeManagerModules.direnv
    inputs.self.homeManagerModules.television
    inputs.self.homeManagerModules.fd
    inputs.self.homeManagerModules.bat
    inputs.self.homeManagerModules.fonts
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

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
