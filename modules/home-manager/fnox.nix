{
  pkgs,
  ...
}:
{
  imports = [ ./upstream/fnox.nix ];

  programs.fnox = {
    enable = true;
    # nixpkgs' cargoSetupHook exports AWS_LC_SYS_USE_SYSTEM=1, but the fnox
    # package doesn't provide aws-lc (for aws-lc-sys) or sqlcipher (linked by
    # libsqlite3-sys), so the build fails. Drop this override once nixpkgs
    # adds them to fnox's buildInputs.
    package = pkgs.unstablePkgs.fnox.overrideAttrs (old: {
      buildInputs =
        (old.buildInputs or [ ])
        ++ (with pkgs.unstablePkgs; [
          aws-lc
          sqlcipher
        ]);
    });
    enableFishIntegration = true;
  };
}
