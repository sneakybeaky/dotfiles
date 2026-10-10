{
  pin = {
    type = "github";
    owner = "DrCatHicks";
    repo = "learning-opportunities";
    branch = "main";
  };

  # DrCatHicks/learning-opportunities is a plugin marketplace: each top-level
  # directory is a plugin whose skills live under <plugin>/skills/. Pointing
  # subdir at the core plugin's skills dir keeps the skill id flat
  # ("learning-opportunities"); ids containing a `/` nest one directory deeper
  # than Claude's one-level scan of ~/.claude/skills/<name>/SKILL.md (see
  # modules/home-manager/ai-skills.nix). Add a sibling manifest per plugin if
  # skills from the other plugins are wanted too.
  subdir = "learning-opportunities/skills";
  filter.maxDepth = 1;
}
