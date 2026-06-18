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

  # Ship reconcile.sh + plan.jq together so the script finds the planner
  # next to itself, without dragging the tests/ dir into the store.
  reconcileDir = pkgs.runCommand "nono-packs-reconcile" { } ''
    mkdir -p "$out"
    cp ${./nono/reconcile.sh} "$out/reconcile.sh"
    cp ${./nono/plan.jq} "$out/plan.jq"
    chmod +x "$out/reconcile.sh"
  '';
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
    ];

    home.packages = [ cfg.package ];

    # Reconcile after files are written; idempotent, so it is a no-op once
    # the installed set matches `packs`. Honours $DRY_RUN_CMD via NONO_RUN.
    home.activation.nonoPacks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${lib.makeBinPath [ pkgs.jq pkgs.coreutils ]}:$PATH"
      export NONO_BIN=${lib.escapeShellArg (lib.getExe cfg.package)}
      export NONO_DESIRED_JSON=${lib.escapeShellArg desiredJSON}
      export NONO_PRUNE=${lib.boolToString cfg.pruneUnmanaged}
      export NONO_FORCE=${lib.boolToString cfg.force}
      export NONO_RUN="$DRY_RUN_CMD"
      ${lib.optionalString (
        cfg.registry != null
      ) "export NONO_REGISTRY=${lib.escapeShellArg cfg.registry}"}
      ${lib.getExe pkgs.bash} ${reconcileDir}/reconcile.sh
    '';
  };
}
