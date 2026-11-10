# Declaratively manage nono packs from home-manager.
#
# nono packs are *not* pure store artifacts (they are Sigstore-signed, install
# into mutable $HOME, and run "wiring" side effects such as merging into
# ~/.claude/settings.json). So rather than a gcloud-style symlinkJoin, this
# module records the desired set and reconciles it through nono's own CLI at
# activation time -- keeping signature verification and wiring intact.
#
# Example:
#   programs.nono = {
#     enable = true;
#     package = pkgs.llm-agents.nono;     # this repo ships nono under llm-agents
#     packs = [ "always-further/claude@0.0.16" ];
#
#     # User profiles, unlike packs, are plain JSON -- written to
#     # ~/.config/nono/profiles/<name>.json and used via `nono run --profile <name>`.
#     profiles.my-claude = {
#       extends = "always-further/claude";
#       filesystem.read = [ "$HOME/.config/gh" ];
#     };
#   };
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nono;

  # "<ns>/<name>" or "<ns>/<name>@<version>"
  packRefPattern = "[^/@[:space:]]+/[^/@[:space:]]+(@[^/@[:space:]]+)?";

  parsePack =
    ref:
    let
      parts = lib.splitString "@" ref;
    in
    {
      key = builtins.head parts;
      version = if builtins.length parts > 1 then builtins.elemAt parts 1 else null;
    };

  desiredJSON = builtins.toJSON (map parsePack cfg.packs);

  jsonFormat = pkgs.formats.json { };

  # nono's own naming rule: alphanumeric + hyphens, no leading/trailing hyphen.
  profileNamePattern = "[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?";

  profileFile =
    name: profile:
    jsonFormat.generate "nono-profile-${name}.json" (
      lib.recursiveUpdate { meta.name = name; } profile
    );

  # The reconcile runner, wrapped so it is shellcheck-validated at build time
  # and gets jq + coreutils on PATH declaratively (no manual makeBinPath). The
  # planner is passed by absolute store path via NONO_PLAN_JQ, so the script
  # need not live next to plan.jq.
  reconcile = pkgs.writeShellApplication {
    name = "nono-packs-reconcile";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./nono/reconcile.sh;
  };
in
{
  options.programs.nono = {
    enable = lib.mkEnableOption "declarative nono pack management";

    package = lib.mkPackageOption pkgs "nono" { };

    packs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "always-further/claude@0.0.16"
        "always-further/codex"
      ];
      description = ''
        nono packs to keep installed, as `<namespace>/<name>` optionally
        pinned with `@<version>`. A versionless entry is satisfied by any
        installed version (use `nono update` to move it forward).
      '';
    };

    pruneUnmanaged = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Remove installed packs that are not listed in {option}`packs`,
        making the declared set authoritative. Disable to only ever add.
      '';
    };

    force = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Pass `--force` to `nono pull`, accepting signer changes and
        overwriting conflicts. Needed to switch the version of a pinned pack.
      '';
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf jsonFormat.type);
      default = { };
      example = lib.literalExpression ''
        {
          my-claude = {
            extends = "nolabs-ai/claude";
            workdir.access = "readwrite";
            filesystem.read = [ "$HOME/.config/gh" ];
          };
        }
      '';
      description = ''
        User profiles written to
        {file}`$XDG_CONFIG_HOME/nono/profiles/<name>.json`, usable as
        `nono run --profile <name>`. Each value is the profile JSON (see
        `nono profile guide` / `nono profile schema`); `meta.name` defaults to
        the attribute name. Path strings are expanded by nono at run time, so
        `$HOME`, `$WORKDIR`, `$XDG_*` etc. can be used verbatim (Nix only
        interpolates `''${...}`, not `$VAR`).
      '';
    };

    registry = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://registry.nono.sh";
      description = "Override the pack registry (exported as `NONO_REGISTRY`).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (ref: builtins.match packRefPattern ref != null) cfg.packs;
        message =
          "programs.nono.packs entries must look like '<namespace>/<name>' or "
          + "'<namespace>/<name>@<version>'. Offending: "
          + lib.concatMapStringsSep ", " (r: "'${r}'") (
            lib.filter (ref: builtins.match packRefPattern ref == null) cfg.packs
          );
      }
      {
        assertion = lib.all (name: builtins.match profileNamePattern name != null) (
          lib.attrNames cfg.profiles
        );
        message =
          "programs.nono.profiles names must be alphanumeric with hyphens "
          + "(no leading/trailing hyphen). Offending: "
          + lib.concatMapStringsSep ", " (n: "'${n}'") (
            lib.filter (name: builtins.match profileNamePattern name == null) (lib.attrNames cfg.profiles)
          );
      }
    ];

    home.packages = [ cfg.package ];

    xdg.configFile = lib.mapAttrs' (
      name: profile: lib.nameValuePair "nono/profiles/${name}.json" { source = profileFile name profile; }
    ) cfg.profiles;

    # Reconcile after files are written; idempotent, so it is a no-op once
    # the installed set matches `packs`. Honours $DRY_RUN_CMD via NONO_RUN.
    home.activation.nonoPacks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export NONO_BIN=${lib.escapeShellArg (lib.getExe cfg.package)}
      export NONO_PLAN_JQ=${./nono/plan.jq}
      export NONO_DESIRED_JSON=${lib.escapeShellArg desiredJSON}
      export NONO_PRUNE=${lib.boolToString cfg.pruneUnmanaged}
      export NONO_FORCE=${lib.boolToString cfg.force}
      export NONO_RUN="$DRY_RUN_CMD"
      ${lib.optionalString (
        cfg.registry != null
      ) "export NONO_REGISTRY=${lib.escapeShellArg cfg.registry}"}
      ${lib.getExe reconcile}
    '';

    # Profiles can `extends` pack profiles, which only exist once the packs
    # above are installed -- so validation can't happen at build time. Check
    # after linking + pack reconcile, and warn (not fail) on problems.
    home.activation.nonoProfiles = lib.mkIf (cfg.profiles != { }) (
      lib.hm.dag.entryAfter [ "linkGeneration" "nonoPacks" ] (
        lib.concatMapStrings (name: ''
          if ! ${lib.getExe cfg.package} profile validate --silent \
              ${lib.escapeShellArg "${config.xdg.configHome}/nono/profiles/${name}.json"} >/dev/null 2>&1; then
            warnEcho ${lib.escapeShellArg "nono profile '${name}' failed validation; run: nono profile validate ${name}"}
          fi
        '') (lib.attrNames cfg.profiles)
      )
    );
  };
}
