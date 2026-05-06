{
  pkgsUnstable,
  ...
}: {
  programs.starship = {
    enable = true;
    package = pkgsUnstable.starship;
    enableInteractive = true;
    enableFishIntegration = true;
    settings = {
      directory = {
        fish_style_pwd_dir_length = 1;
        substitutions = {
          "Documents" = " ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
          "Projects" = "📂";
        };
      };
      golang = {
        symbol = " ";
      };
    };
  };
}
