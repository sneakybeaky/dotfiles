{
  config,
  pkgs,
  ...
}:
{
  programs.aria2 = {
    enable = true;
    package = pkgs.unstablePkgs.aria2;
    settings = {
      dir = config.xdg.userDirs.download;
      continue = true;
      max-connection-per-server = 16;
      min-split-size = "10M";
      split = "16";
      file-allocation = "none";
    };
  };

  programs.yt-dlp = {
    enable = true;
    package = pkgs.unstablePkgs.yt-dlp;

    settings = {
      embed-thumbnail = true;
      embed-subs = true;
      sub-langs = "all";
      # Use aria2c for faster downloads
      downloader = "aria2c";
      downloader-args = "aria2c:'-c -x8 -s8 -k1M'";
      format = "bestvideo+bestaudio/best";
    };
  };
}
