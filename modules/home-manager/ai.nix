{
  pkgs,
  inputs,
  lib,
  ...
}:

let
  inherit (lib) getExe;
in

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

  # Generate nono's fish completions at build time so they're autoloaded
  # lazily by fish (and validated at build time) rather than re-sourced on
  # every shell startup.
  xdg.configFile."fish/completions/nono.fish".source = pkgs.runCommand "nono-completions.fish" { } ''
    ${getExe pkgs.llm-agents.nono} completion fish > $out
  '';

  # Additional AI tools
  home.packages = [
    pkgs.llm-agents.crush
    pkgs.claude-monitor
    pkgs.llm-agents.ccusage
    pkgs.llm-agents.agent-browser
    pkgs.llm-agents.nono
    pkgs.llm-agents.skills
  ];

}
