# wezterm-config

My WezTerm configuration. Tokyo Night, powerline tab bar, and a `CTRL+a` leader
that works identically on macOS, Linux and Windows.

See [KEYS.md](KEYS.md) for the full keybinding reference.

## Install

The repo *is* the config directory, so there are no symlinks to manage. Each
command below resolves the destination from environment variables, so it lands
in the right place regardless of how the machine is set up.

**bash / zsh** (macOS, Linux, WSL, Git Bash):

```sh
git clone https://github.com/gitlars/wezterm-config \
  "${XDG_CONFIG_HOME:-$HOME/.config}/wezterm"
```

**fish**:

```fish
git clone https://github.com/gitlars/wezterm-config \
  (test -n "$XDG_CONFIG_HOME"; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/wezterm
```

**PowerShell** (Windows):

```powershell
$dest = if ($env:XDG_CONFIG_HOME) {
  Join-Path $env:XDG_CONFIG_HOME 'wezterm'
} else {
  Join-Path $env:USERPROFILE '.config\wezterm'
}
git clone https://github.com/gitlars/wezterm-config $dest
```

### Keeping the repo somewhere else

`WEZTERM_CONFIG_FILE` overrides the search entirely, so the clone can live
anywhere — useful if you keep all your source under one directory:

```sh
git clone https://github.com/gitlars/wezterm-config ~/src/wezterm-config
export WEZTERM_CONFIG_FILE="$HOME/src/wezterm-config/wezterm.lua"   # in your shell rc
```

```powershell
[Environment]::SetEnvironmentVariable(
  'WEZTERM_CONFIG_FILE', "$env:USERPROFILE\src\wezterm-config\wezterm.lua", 'User')
```

Modules resolve relative to the config file, so `modules/` is found either way.

## Where WezTerm looks for config

First match wins:

| Order | Location |
|---|---|
| 1 | `$WEZTERM_CONFIG_FILE` (a file path, not a directory — overrides everything) |
| 2 | `$XDG_CONFIG_HOME/wezterm/wezterm.lua` |
| 3 | `$HOME/.config/wezterm/wezterm.lua` (`%USERPROFILE%\.config\` on Windows) |
| 4 | `$HOME/.wezterm.lua` |

## Font

Install [JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts) so the
tab bar and status bar icons render. Without it the config falls back to plain
JetBrains Mono with text-only markers — degraded, but not broken.

**macOS**:

```sh
brew install --cask font-jetbrains-mono-nerd-font
```

**Windows** (scoop):

```powershell
scoop bucket add nerd-fonts
scoop install nerd-fonts/JetBrainsMono-NF
```

**Linux**:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMono"
curl -fsSL -o /tmp/JetBrainsMono.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o /tmp/JetBrainsMono.zip \
  -d "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMono"
fc-cache -f
```

## Per-machine overrides

`local.lua` is gitignored. Copy `local.lua.example` to `local.lua` on any machine
that needs different settings:

```lua
function M.apply(config)
  config.font_size = 14.0
end
```

It is applied last, so it wins over everything in `modules/`.

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

## Troubleshooting

**Config changes do nothing, or WezTerm reports a missing file.** WezTerm exports
`WEZTERM_CONFIG_FILE` into every pane it spawns, pointing at the config it loaded
*at startup*. If that path moved, running instances keep chasing the old one.
Quit WezTerm completely (not just the window) and relaunch. To see what a fresh
process would pick up:

```sh
env -u WEZTERM_CONFIG_FILE wezterm show-keys | head -1
```

**Icons show as boxes.** The Nerd Font is not installed or not visible to the
font system. Check what actually resolved:

```sh
wezterm ls-fonts | head
```

**Lua errors.** `LEADER D` opens the debug overlay, where config errors are
logged.

**Rendering artifacts.** Set `config.front_end = 'OpenGL'` in
`modules/behavior.lua` (it defaults to `WebGpu`).
