{
  inputs,
  ...
}:
let
  agentLib = inputs.agent-skills.lib.agent-skills;

  # Skill sources are declared in registry/sources/*.nix and pinned in
  # registry/sources.lock.json. Refresh them with `nix run .#skills-sources-lock`.
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
