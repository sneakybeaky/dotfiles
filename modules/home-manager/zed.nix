{
  pkgs,
  ...
}:
{

  home.packages = with pkgs.unstablePkgs; [
    nil
    nixd
  ];

  programs.zed-editor = {
    enable = true;
    package = pkgs.unstablePkgs.zed-editor;

    mutableUserSettings = true;
    mutableUserKeymaps = true;
    mutableUserDebug = true;

    # This populates the userSettings "auto_install_extensions"
    extensions = [
      "nix"
      "toml"
      "make"
    ];

    userSettings = {
      cli_default_open_behavior = "new_window";
      project_panel = {
        dock = "left";
      };
      outline_panel = {
        dock = "left";
      };
      collaboration_panel = {
        dock = "left";
      };
      git_panel = {
        dock = "left";
      };
      agent = {
        dock = "right";
        default_model = {
          provider = "zed.dev";
          model = "claude-sonnet-4-6";
          enable_thinking = true;
          effort = "high";
        };
        favorite_models = [

        ];
        model_parameters = [

        ];
      };
      ui_font_size = 16;
      buffer_font_size = 16;
      soft_wrap = "editor_width";
    };

  };
}
