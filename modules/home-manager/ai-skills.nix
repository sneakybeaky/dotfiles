{
  inputs,
  ...
}:
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  programs.agent-skills = {
    enable = true;

    sources.mattpocock = {
      input = "mattpocock-skills";
      subdir = "skills/productivity";
      filter.maxDepth = 1;
    };

    sources.anthropic = {
      input = "anthropic-skills";
      subdir = "skills";
      filter.maxDepth = 1;
    };

    sources.vercel = {
      input = "vercel-skills";
      subdir = "skills";
      filter.maxDepth = 1;
    };

    skills.enable = [
      "skill-creator"
      "teach"
      "find-skills"
    ];
    targets.claude.enable = true;
  };

}
