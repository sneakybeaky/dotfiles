# .files

Inspired by [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)
and [zupo/dotfiles](https://github.com/zupo/dotfiles).

A standalone [home-manager](https://github.com/nix-community/home-manager) flake.
Shared configuration lives in `home-manager/common.nix`; per-host entrypoints
(`home-manager/home.nix`, `home-manager/work.nix`) add host-specific packages and
modules. Reusable modules live in `modules/home-manager/`.

## Install

1. Install Nix — https://determinate.systems/nix/
2. Update `/etc/nix/nix.custom.conf` — add `trusted-users = <whoami>`
3. Apply the configuration:
   ```shell
   nix-shell -p go-task home-manager --run "task apply"
   ```

## Set fish as the default shell

Run from your current shell (bash/zsh):

```shell
fish_path="$HOME/.nix-profile/bin/fish"
grep -qF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells
chsh -s "$fish_path"
```

## Day-to-day tasks

Managed with [go-task](https://taskfile.dev); run `task` to list them.

| Task | Description |
| --- | --- |
| `task build` | Build the Nix configuration for the current host |
| `task apply` | Build and activate the configuration |
| `task update` | Update flake inputs, apply, and show what changed |
| `task update-skills` | Refresh agent skill revisions in the source registry lock |
| `task changed` | Show what changed with the last update |
| `task deps` | Show flake input versions (revisions, dates, nixpkgs release) |
| `task cache-check` | Show which packages are missing from binary caches |
| `task cache-check-unstable -- <pkg>` | Check if an unstable package is cached |

## Agent skills

Skill repositories are declared in `registry/sources/*.nix` and pinned in
`registry/sources.lock.json`. Refresh the pins with `task update-skills` (or
`nix run .#skills-sources-lock`), then review and commit the updated lock file.
