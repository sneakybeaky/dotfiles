{
  pkgs,
  ...
}:
{
  home.packages = with pkgs.unstablePkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
