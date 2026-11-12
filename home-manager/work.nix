# Work MacBook home-manager configuration.
# Shared config lives in ./common.nix.
{
  inputs,
  pkgs,
  ...
}:
let
  # Single source of truth for the mise package used below.
  # Swap to `pkgs.mise` to use the pinned version from the pinned-mise overlay.
  misePackage = pkgs.unstablePkgs.mise;
in
{
  imports = [
    ./common.nix
  ];

  home = {
    username = "jon.barber";
    homeDirectory = "/Users/jon.barber";
  };

  home.packages = with pkgs; [
    unstablePkgs.postgresql_18
    unstablePkgs.gopls
    unstablePkgs.amazon-ecr-credential-helper
    unstablePkgs.gh
    unstablePkgs.python315
    unstablePkgs.firecrawl-cli
    # Sentry's TypeScript CLI, from pkgs/sentry (not in nixpkgs).
    sentry
  ];

  programs = {
    granted = {
      enable = true;
      package = pkgs.unstablePkgs.granted;
      enableFishIntegration = true;
    };
    mise = {
      enable = true;
      package = misePackage;
      enableFishIntegration = true;
    };
    direnv = {
      mise = {
        package = misePackage;
        enable = true;
      };
    };
    awscli = {
      enable = true;
      package = pkgs.unstablePkgs.awscli2;
    };

    # Sandbox profile for running Claude on work repos:
    #   nono run --profile claude-work -- claude
    # Builds on the nolabs-ai/claude pack (installed by ai.nix). Paths are
    # expanded by nono at run time.
    nono.profiles.claude-work = {
      extends = "nolabs-ai/claude";
      meta.description = "Claude Code on the work MacBook (risk-ledger repos, mise, gh, ssh, 1Password)";

      # Read+write on the directory nono is launched from (`--allow .`).
      workdir.access = "readwrite";

      filesystem = {
        allow = [
          "$HOME/work/risk-ledger"
          "$HOME/.local/state/mise"
          "$HOME/.cache"
        ];
        allow_file = [
          "$HOME/.config/iterm2/cc-status"
        ];
        # Read-only: a writable ssh config could add a ProxyCommand that runs
        # outside the sandbox the next time ssh runs from a normal shell.
        read_file = [
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
        ];
        read = [
          "$HOME/.config/gh"
          "$HOME/.local/share/mise/installs"
          # 1Password SSH agent socket + shell plugin config.
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password"
        ];
        # 1Password SSH agent (ssh auth + op-ssh-sign commit signing). A
        # read grant doesn't cover connect(2); sockets need their own grant.
        unix_socket = [
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        ];
        # These sit under nono's default credential deny groups; lift the
        # deny so the grants above take effect. Only the two ssh files are
        # bypassed: the key lives in 1Password, so the rest of ~/.ssh stays
        # denied.
        bypass_protection = [
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password"
        ];
      };
    };

    # Work-specific shell additions, merged with the base config from fish.nix
    fish.shellInit = # fish
      ''
        fish_add_path "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
      '';

    # `cw [claude args...]` -- Claude in the claude-work nono sandbox.
    fish.functions.cw = {
      description = "Run claude in the claude-work nono sandbox";
      wraps = "claude";
      body = "nono run --profile claude-work -- claude $argv";
    };
  };
}
