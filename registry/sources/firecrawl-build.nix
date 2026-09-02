{
  pin = {
    type = "github";
    owner = "firecrawl";
    repo = "skills";
    branch = "main";
  };

  # firecrawl/skills groups its skills two levels deep (core/, workflows/,
  # build/). Scanning from "skills" with maxDepth = 2 would make each skill id
  # its relative path, e.g. "build/firecrawl-build-search", and ids containing a
  # `/` nest one directory deeper than Claude's one-level scan of
  # ~/.claude/skills/<name>/SKILL.md (see modules/home-manager/ai-skills.nix).
  # Pointing subdir at the group instead keeps ids flat. Add a sibling manifest
  # per group if the core/ or workflows/ skills are wanted too.
  subdir = "skills/build";
  filter.maxDepth = 1;
}
