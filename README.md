# .files

Inspired [by](https://github.com/Misterio77/nix-starter-configs), and [also](https://github.com/zupo/dotfiles) 

1. Install nix - https://determinate.systems/nix/
2. Update `/etc/nix/nix.custom.conf` - add `trusted-users = <whoami>`
3. `nix-shell -p go-task home-manager --run "task apply"`

# Set fish as default shell
```shell
SHELL=(printf "%s" $HOME/.nix-profile/bin/fish) FILE=/etc/shells bash -c  'grep -qF "$SHELL" "$FILE" || echo "$SHELL" | sudo tee -a "$FILE"'
SHELL=(printf "%s" $HOME/.nix-profile/bin/fish) chsh -s "$SHELL"
```
