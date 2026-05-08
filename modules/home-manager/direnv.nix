{
  pkgsUnstable,
  ...
}: {
  programs.direnv = {
    enable = true;
    package = pkgsUnstable.direnv;

    mise = {
      enable = true;
      package = pkgsUnstable.mise;
    };
  };
}
