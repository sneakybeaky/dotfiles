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
      meta.description = "Claude Code on the work MacBook (risk-ledger repos, mise, gh, git over HTTPS, 1Password)";

      # Read+write on the directory nono is launched from (`--allow .`).
      workdir.access = "readwrite";

      # git reaches GitHub over HTTPS through nono's credential proxy, which
      # adds the host's gh token to requests for riskledger repos only. The
      # sandbox needs nothing from ~/.ssh, and ssh itself is blocked while the
      # proxy runs.
      network = {
        credentials = [ "github_git" ];
        custom_credentials.github_git = {
          upstream = "https://github.com";
          credential_key = "cmd://gh_git";
          env_var = "GITHUB_GIT_TOKEN";
          inject_mode = "basic_auth";
          endpoint_rules = [
            {
              method = "*";
              path = "/riskledger/**";
            }
          ];
        };
      };

      # Runs on the host, outside the sandbox. gh is a store path so the
      # sandbox can't plant a different gh earlier on PATH.
      credential_capture.gh_git = {
        command = [
          "/bin/sh"
          "-c"
          "printf 'x-access-token:%s' \"$(${pkgs.unstablePkgs.gh}/bin/gh auth token)\""
        ];
        timeout_secs = 10;
        cache_ttl_secs = 900;
      };

      # Existing clones use ssh remotes; rewrite them to HTTPS for the proxy.
      environment.set_vars = {
        GIT_CONFIG_COUNT = "1";
        GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
        GIT_CONFIG_VALUE_0 = "git@github.com:";
      };

      filesystem = {
        allow = [
          "$HOME/work/risk-ledger"
          "$HOME/.local/state/mise"
          "$HOME/.cache"
        ];
        allow_file = [
          "$HOME/.config/iterm2/cc-status"
        ];
        read = [
          "$HOME/.config/gh"
          "$HOME/.local/share/mise/installs"
          # 1Password SSH agent socket + shell plugin config.
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password"
        ];
        # 1Password SSH agent, for op-ssh-sign commit signing. A read grant
        # doesn't cover connect(2); sockets need their own grant.
        unix_socket = [
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        ];
        # This sits under nono's default credential deny groups; lift the
        # deny so the grants above take effect.
        bypass_protection = [
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password"
        ];
      };
    };

    # The team quick-start profile (Part 1 of the Notion guide), kept here to
    # use what teammates use: git over ssh, two read-only ssh files, and only
    # the 1Password agent socket.
    #   nono run --profile wcso -- claude
    nono.profiles.wcso = {
      extends = "nolabs-ai/claude";
      meta.description = "Team quick start: risk-ledger repos, mise, gh, git over ssh, 1Password agent socket only";

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
        read = [
          "$HOME/.config/gh"
          "$HOME/.local/share/mise/installs"
        ];
        # Read-only: a writable ssh config could add a ProxyCommand that runs
        # outside the sandbox the next time ssh runs from a normal shell.
        read_file = [
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
        ];
        # Only the agent socket: granting the whole 1Password folder lets the
        # op CLI inside the sandbox reach the 1Password app.
        unix_socket = [
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        ];
        bypass_protection = [
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
          "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
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

    # `wcso [claude args...]` -- Claude in the team quick-start profile.
    fish.functions.wcso = {
      description = "Run claude in the wcso nono sandbox (team quick start)";
      wraps = "claude";
      body = "nono run --profile wcso -- claude $argv";
    };
  };
}
