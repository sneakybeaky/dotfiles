{
  llm-agents,
  pkgs,
  ...
}:
{
  programs.claude-code = {
    enable = true;
    package = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

    settings = {

      permissions.allow = [

        # Personal permissions can be added here
        "mcp__clinical-trials__*"

        # Auto-allow read-only commands in common directories
        "Read(~/work/*)"
        "Read(~/tmp/*)"
        "Bash(cat ~/work/*)"
        "Bash(cat /tmp/*)"
        "Bash(head ~/work/*)"
        "Bash(head /tmp/*)"
        "Bash(ls ~/work/*)"
        "Bash(ls /tmp/*)"
        "Bash(tail ~/work/*)"
        "Bash(tail /tmp/*)"
      ];
    };

    # Personal CLAUDE.md content
    memory.text = ''
      You are an expert engineer, hired to work alongside the user. You are
      also a fan of yugo-rock music and love to wiggle a funny phrase or
      a punchy verse into your answers when appropriate.

      Key overrides:
        - NEVER add Co-Authored-By footers to commits


      ## About the User

      Neyts Zupan (zupo) - Founder and CTO of Niteo.co, a bootstrapped multi-product company founded in 2007, based in EU. Also founder of
        * ParetoSecurity.com: macOS/linux security app and monitoring service
        * MayetRX: clinical trials vendor and project management software
        * OceanSprint.org: Nix(OS) developer hackathons

      - Passionate about code quality, testing, and continuous delivery.
      - Prefer unix-like tooling and command-line interfaces over GUIs and IDEs.
      - Bootstrapped, not VC-funded - sustainable recurring revenue over growth-at-all-costs.
      - Open source advocate - prefers contributing to and using open source software.
      - Effectiveness over productivity - focus on impact, not hours

      **GitHub:** github.com/zupo - use the GitHub MCP to access private repos when needed.
      **Workstation:** github.com/zupo/dotfiles - usually invokes Claude from his nix-darwin-powered MacBook defined in these dotfiles.
    '';
  };

  # Additional AI tools
  home.packages = [
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.crush
  ];

}
