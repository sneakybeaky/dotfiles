# Claude Code plugins (commands, agents, MCP servers), as opposed to the
# SKILL.md skills managed by agent-skills-nix in ../sources.
#
# Each plugin is pinned to a GitHub commit in ./sources.json. Do not edit that
# file by hand — run `task claude-plugins-update` (or
# `nix run .#claude-plugins-update`) to move every plugin to the head of its
# tracked branch.
{
  lib,
  fetchFromGitHub,
  writeShellApplication,
  git,
  jq,
  coreutils,
}:
let
  pins = lib.importJSON ./sources.json;
in
{
  # Plugin source trees, keyed by the names in sources.json.
  plugins = lib.mapAttrs (
    _: pin:
    fetchFromGitHub {
      inherit (pin)
        owner
        repo
        rev
        hash
        ;
    }
  ) pins;

  updateScript = lib.getExe (writeShellApplication {
    name = "claude-plugins-update";
    runtimeInputs = [
      git
      jq
      coreutils
    ];
    text = builtins.readFile ./update.sh;
  });
}
