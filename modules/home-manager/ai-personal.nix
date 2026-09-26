# AI tools for personal machines only; shared AI tooling lives in ai.nix.
{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.llm-agents.crush
    pkgs.llm-agents.hermes-agent
    pkgs.llm-agents.hermes-desktop
  ];
}
