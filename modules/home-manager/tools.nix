{
  pkgs,
  ...
}:
{

  home.packages = with pkgs; [
    container
    gnumake
    dig
    unrar
    wget
    unstablePkgs._1password-cli
    unstablePkgs.asciinema
    unstablePkgs.axel
    unstablePkgs.devenv
    unstablePkgs.devbox
    unstablePkgs.duf
    unstablePkgs.gdb
    unstablePkgs.get_iplayer
    unstablePkgs.glow
    unstablePkgs.go-task
    unstablePkgs.hydra-check
    unstablePkgs.jq
    unstablePkgs.mkcert
    unstablePkgs.ncdu
    unstablePkgs.ngrok
    unstablePkgs.ripgrep
    unstablePkgs.tldr
  ];

}
