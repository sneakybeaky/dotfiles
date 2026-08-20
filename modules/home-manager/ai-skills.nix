{
  inputs,
  ...
}:
let
  agentLib = inputs.agent-skills.lib.agent-skills;

  # Skill sources are declared in registry/sources/*.nix and pinned in
  # registry/sources.lock.json. Refresh them with `nix run .#skills-sources-lock`.
  # Each source's skill IDs are namespaced under its registry name (e.g.
  # `anthropic/pdf`), so the prefix is derived here rather than duplicated in
  # every manifest.
  sources = builtins.mapAttrs (name: src: src // { idPrefix = name; }) (
    agentLib.sourcesFromLock {
      manifestsDir = ../../registry/sources;
      lockFile = ../../registry/sources.lock.json;
    }
  );
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  programs.agent-skills = {
    enable = true;

    inherit sources;

    skills.enable = [
      "anthropic/skill-creator"
      "mattpocock/teach"
      "vercel/find-skills"
      "addyosmani/test-driven-development"
      "jetbrains/use-modern-go"
    ];
    targets.claude.enable = true;
  };

}
