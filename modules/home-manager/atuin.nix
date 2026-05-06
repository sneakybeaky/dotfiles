{
  pkgsUnstable,
  ...
}: {
  programs.atuin = {
    enable = true;
    package = pkgsUnstable.atuin;
    enableFishIntegration = true;
  };
}
