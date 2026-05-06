# .files

Inspired [by](https://github.com/Misterio77/nix-starter-configs), and [also](https://github.com/zupo/dotfiles) 

1. Install nix - https://determinate.systems/nix/
  2. Update /etc/nix/nix.custom.conf - add `trusted-users = <whoami>`
3. `nix-shell -p go-task home-manager --run "task apply"`
