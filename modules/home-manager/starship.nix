{
  pkgsUnstable,
  ...
}: {
  programs.starship = {
    enable = true;
    package = pkgsUnstable.starship;
  };
}
