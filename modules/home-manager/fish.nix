{
  pkgs,
  ...}: {
  programs.fish = {
    enable = true;
    package = pkgs.unstablePkgs.fish;

    shellInit = # fish
      ''
        set -U fish_greeting ""

        set -x -U LESS_TERMCAP_md (printf "\e[01;31m")
        set -x -U LESS_TERMCAP_me (printf "\e[0m")
        set -x -U LESS_TERMCAP_se (printf "\e[0m")
        set -x -U LESS_TERMCAP_so (printf "\e[01;44;30m")
        set -x -U LESS_TERMCAP_ue (printf "\e[0m")
        set -x -U LESS_TERMCAP_us (printf "\e[01;32m")
        set -x -U MANROFFOPT "-c"

        set -x -U EDITOR "zeditor --wait"
        set -x -U VISUAL "zeditor --wait"

        fish_default_key_bindings

        if string match -qe -- "/dev/pts/" (tty)
          alias ssh="kitty +kitten ssh"
        end
      '';

      interactiveShellInit =
      ''
        # Fish syntax highlighting
        set -g fish_color_autosuggestion '555'  'brblack'
        set -g fish_color_cancel -r
        set -g fish_color_command --bold
        set -g fish_color_comment red
        set -g fish_color_cwd green
        set -g fish_color_cwd_root red
        set -g fish_color_end brmagenta
        set -g fish_color_error brred
        set -g fish_color_escape 'bryellow'  '--bold'
        set -g fish_color_history_current --bold
        set -g fish_color_host normal
        set -g fish_color_match --background=brblue
        set -g fish_color_normal normal
        set -g fish_color_operator bryellow
        set -g fish_color_param cyan
        set -g fish_color_quote yellow
        set -g fish_color_redirection brblue
        set -g fish_color_search_match 'bryellow'  '--background=brblack'
        set -g fish_color_selection 'white'  '--bold'  '--background=brblack'
        set -g fish_color_user brgreen
        set -g fish_color_valid_path --underline

        set fish_greeting "🐟 Welcome back, $(whoami)!"
      '';

  };
}
