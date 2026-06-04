{
  pkgs,
  ...
}:
{
  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;

  };

  # Additional AI tools
  home.packages = [
    pkgs.llm-agents.crush
    pkgs.claude-monitor
  ];

}
