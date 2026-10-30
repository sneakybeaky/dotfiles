# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  herdr-gpui = pkgs.callPackage ./herdr-gpui { };
  nix-cache-check = pkgs.callPackage ./nix-cache-check { };
  sentry = pkgs.callPackage ./sentry { };
}
