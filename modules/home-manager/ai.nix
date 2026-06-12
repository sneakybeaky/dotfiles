{
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.home-extra-worktrunk.homeModules.default ];

  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;

    context = ./conf.d/claude/memory.md;

  };

  programs.worktrunk = {
    enable = true;
    package = pkgs.unstablePkgs.worktrunk;
    enableFishIntegration = true;
  };

  xdg.configFile."worktrunk".source = ./conf.d/worktrunk;

  # Additional AI tools
  home.packages = [
    pkgs.llm-agents.crush
    pkgs.claude-monitor
    pkgs.llm-agents.ccusage
    pkgs.llm-agents.agent-browser
    pkgs.llm-agents.nono
  ];

}
