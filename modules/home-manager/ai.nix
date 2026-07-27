{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  inherit (lib) getExe;
in

{

  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;

    context = ./conf.d/claude/memory.md;

  };

  # nono installs the binary (via programs.nono below), and declaratively
  # manages its packs. Versionless: any installed version satisfies the
  # entry, so `nono update` controls when claude moves forward.
  programs.nono = {
    enable = true;
    package = pkgs.llm-agents.nono;
    packs = [
      "always-further/claude"
    ];
  };

  # Generate nono's fish completions at build time so they're autoloaded
  # lazily by fish (and validated at build time) rather than re-sourced on
  # every shell startup.
  xdg.configFile."fish/completions/nono.fish".source = pkgs.runCommand "nono-completions.fish" { } ''
    ${getExe config.programs.nono.package} completion fish > $out
  '';

  # Additional AI tools
  home.packages = [
    pkgs.llm-agents.crush
    pkgs.claude-monitor
    pkgs.llm-agents.ccusage
    pkgs.llm-agents.agent-browser
    pkgs.llm-agents.skills
    pkgs.llm-agents.herdr
  ];

}
