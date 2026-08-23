# wezterm-config

My WezTerm configuration. Tokyo Night, powerline tab bar, and a `CTRL+a` leader
that works identically on macOS, Linux and Windows.

See [KEYS.md](KEYS.md) for the full keybinding reference.

## Install

The repo *is* the config directory, so there are no symlinks to manage:

```sh
git clone https://github.com/<user>/wezterm-config ~/.config/wezterm
```

On Windows:

```powershell
git clone https://github.com/<user>/wezterm-config $env:USERPROFILE\.config\wezterm
```

Then install [JetBrainsMono Nerd Font](https://www.nerdfonts.com/) so the tab bar
and status bar icons render (the config falls back to plain JetBrains Mono and
text-only markers without it):

```sh
brew install --cask font-jetbrains-mono-nerd-font   # macOS
```

## Per-machine overrides

`local.lua` is gitignored. Copy `local.lua.example` to `local.lua` on any machine
that needs different settings:

```lua
function M.apply(config)
  config.font_size = 14.0
end
```

## Layout

| Path | Purpose |
|---|---|
| `wezterm.lua` | entry point |
| `modules/platform.lua` | OS detection — the only file that branches per-OS |
| `modules/colors.lua` | Tokyo Night palette |
| `modules/appearance.lua` | fonts, window chrome, tab bar colors |
| `modules/behavior.lua` | performance, scrollback, hyperlinks, mouse |
| `modules/keys.lua` | leader bindings and key tables |
| `modules/sessions.lua` | project → workspace launcher (`LEADER s`) |
| `modules/tabs.lua` | powerline tab titles |
| `modules/status.lua` | status bar (workspace / git / cwd / battery / clock) |
