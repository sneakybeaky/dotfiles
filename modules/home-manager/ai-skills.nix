{
  inputs,
  ...
}:
let
  agentLib = inputs.agent-skills.lib.agent-skills;

  # Skill sources are declared in registry/sources/*.nix and pinned in
  # registry/sources.lock.json. Refresh them with `nix run .#skills-sources-lock`.
  # Skill IDs are deliberately NOT namespaced with idPrefix: prefixed IDs
  # contain a `/`, which nests each skill one directory deeper than Claude's
  # one-level scan of ~/.claude/skills/<name>/SKILL.md. Cross-source ID
  # collisions still fail the build (discoverCatalog throws on duplicates).
  sources = agentLib.sourcesFromLock {
    manifestsDir = ../../registry/sources;
    lockFile = ../../registry/sources.lock.json;
  };
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  programs.agent-skills = {
    enable = true;

    inherit sources;

    skills.enable = [
      "skill-creator"
      "teach"
      "find-skills"
      "test-driven-development"
      "use-modern-go"
    ];
    targets.claude.enable = true;
  };

}
