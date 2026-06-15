{
  pkgs,
  inputs,
  lib,
  ...
}:

let
  inherit (lib) mkAfter getExe;
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

  # Additional AI tools
  home.packages = [
    pkgs.llm-agents.crush
    pkgs.claude-monitor
    pkgs.llm-agents.ccusage
    pkgs.llm-agents.agent-browser
    pkgs.llm-agents.nono
  ];

  programs.fish.interactiveShellInit =
    # Using `mkAfter` to make it more likely to appear after other
    # manipulations of the prompt.
    mkAfter ''
      ${getExe pkgs.llm-agents.nono} completion fish | source
    '';

}
