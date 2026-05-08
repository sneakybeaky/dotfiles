{
  pkgsUnstable,
  ...
}: {
  programs.eza = {
    enable = true;
    package = pkgsUnstable.eza;
    enableFishIntegration = true;
  };
}
