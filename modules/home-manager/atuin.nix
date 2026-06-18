{
  pkgs,
  ...
}:
{
  programs.atuin = {
    enable = true;
    package = pkgs.unstablePkgs.atuin;
    enableFishIntegration = true;

    settings = {
      auto_sync = false;
      filter_mode = "session-preload";
      sync = {
        records = true;
      };
    };
  };
}
