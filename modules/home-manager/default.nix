# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # Modules imported by every host (via home-manager/common.nix). To add a
  # module to all hosts, drop it in here — common.nix imports the whole set.
  shared = {
    nixpkgs = import ./nixpkgs.nix;
    tools = import ./tools.nix;
    ai = import ./ai.nix;
    nono = import ./nono.nix;
    starship = import ./starship.nix;
    fish = import ./fish.nix;
    atuin = import ./atuin.nix;
    zed = import ./zed.nix;
    eza = import ./eza.nix;
    direnv = import ./direnv.nix;
    television = import ./television.nix;
    bat = import ./bat.nix;
    fd = import ./fd.nix;
    fonts = import ./fonts.nix;
  };

  # Host-specific modules, imported explicitly by the relevant entrypoint.
  yt-dlp = import ./yt-dlp.nix; # personal (home.nix)
  _1password-shell-plugins = import ./1password-shell-plugins.nix; # personal (home.nix)
  ai-skills = import ./ai-skills.nix; # work (work.nix)
}
