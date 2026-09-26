# 1Password Shell Plugins: wraps each CLI in `plugins` with a shell function
# that runs it via `op plugin run`, so credentials come from 1Password.
#
# The item each plugin uses is not declarative — pick it once per machine with
# `op plugin init <cli>` (stored in ~/.config/op/plugins/).
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs._1password-shell-plugins.hmModules.default ];

  programs._1password-shell-plugins = {
    enable = true;
    # Same op as tools.nix, so the module's plugin-support check runs against
    # the binary that's actually on PATH.
    package = pkgs.unstablePkgs._1password-cli;
    plugins = with pkgs.unstablePkgs; [
      flyctl
    ];
  };
}
