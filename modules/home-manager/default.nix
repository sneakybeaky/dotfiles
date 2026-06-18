# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;
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
  yt-dlp = import ./yt-dlp.nix;
  ai-skills = import ./ai-skills.nix;
}
