{
  ...
}:
{

  programs.agent-skills = {
    enable = true;
    sources.mattpocock = {
      input = "mattpocock-skills";
      subdir = "skills";
    };
    skills.enable = [
      "teach"
    ];
    targets.claude.enable = true;
  };

}
