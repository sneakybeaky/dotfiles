{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) getExe;

  # Pinned in registry/claude-plugins/sources.json; refresh with
  # `task claude-plugins-update`.
  claudePlugins = (pkgs.callPackage ../../registry/claude-plugins { }).plugins;
in

{

  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;

    context = ./conf.d/claude/memory.md;

    # Claude Code plugins, loaded via `--plugin-dir` in the claude wrapper.
    # These are full plugins (commands + MCP servers), not SKILL.md skills, so
    # they can't go through agent-skills-nix (see ai-skills.nix).
    plugins = [
      # Dave Farley's ATDD course (CD.Training). Plugin name is "msec", so the
      # commands are /msec:atdd-learn, /msec:atdd-build, /msec:atdd-review and
      # /msec:signin. Also registers the msec-mcp content server.
      claudePlugins.atdd
    ];

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

  # Additional AI tools (all hosts; personal-only tools live in ai-personal.nix)
  home.packages = [
    pkgs.claude-monitor
    pkgs.llm-agents.ccusage
    pkgs.llm-agents.agent-browser
    pkgs.llm-agents.skills
    pkgs.llm-agents.herdr
  ];

}
