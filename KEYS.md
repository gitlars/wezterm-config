# WezTerm keys

<!-- GENERATED FILE -- do not edit by hand.
     Source: modules/keys.lua. Regenerate with:
       wezterm --config-file generate-keys.lua ls-fonts >/dev/null -->

Leader is **CTRL+a**, then a key (2s window). Identical on macOS, Linux and
Windows. `LEADER a` sends a literal CTRL+a to the shell.

## Leader

| Keys | Action |
|---|---|
| `LEADER a` | send a literal CTRL+a (readline beginning-of-line) |

## Panes

| Keys | Action |
|---|---|
| `LEADER \| or LEADER \` | split right |
| `LEADER -` | split down |
| `LEADER CTRL+\|` | prompt for N equal columns |
| `LEADER CTRL+-` | prompt for N equal rows |
| `LEADER h j k l` | move between panes |
| `LEADER ← ↓ ↑ →` | move between panes |
| `LEADER o` | next pane |
| `LEADER ;` | previous pane |
| `LEADER x` | close pane |
| `LEADER z` | zoom pane to fill the tab (toggle) |
| `LEADER Space` | rotate panes clockwise |
| `LEADER p` | pick a pane by letter |
| `LEADER P` | swap the active pane with a picked one |
| `LEADER !` | break the pane out into its own tab |
| `LEADER r` | resize mode: then h/j/k/l or arrows; Esc, Enter or q exits |

## Tabs

| Keys | Action |
|---|---|
| `LEADER c` | new tab |
| `LEADER n` | next tab |
| `LEADER b` | previous tab |
| `LEADER Tab` | last tab (A/B flip) |
| `LEADER {` | move tab left |
| `LEADER }` | move tab right |
| `LEADER &` | close tab |
| `LEADER ,` | rename tab (pins the name so it stops changing) |
| `LEADER 1 … 9` | jump straight to tab N |

## Workspaces

| Keys | Action |
|---|---|
| `LEADER w` | fuzzy switcher over open workspaces |
| `LEADER s` | project picker -- opens a repo in its own workspace |
| `LEADER (` | previous workspace |
| `LEADER )` | next workspace |
| `LEADER $` | rename workspace |

## Copy, search, links

| Keys | Action |
|---|---|
| `LEADER [` | copy mode (vim keys; v select, y yank, q exit) |
| `LEADER ]` | paste |
| `LEADER /` | search scrollback |
| `LEADER f` | quick select: jump to SHAs, paths, IPs, UUIDs |
| `LEADER u` | quick select a URL and open it |

## Misc

| Keys | Action |
|---|---|
| `LEADER ?` | command palette -- every action, searchable |
| `LEADER K` | clear scrollback |
| `LEADER R` | reload config |
| `LEADER D` | debug overlay -- Lua errors land here |
| `SHIFT+Enter` | newline without submitting (Claude Code, REPLs) |
| `CMD+Enter` | fullscreen _(mac only)_ |
| `CMD+k` | clear scrollback _(mac only)_ |

## Platform defaults

Copy, paste, new window and font sizing stay on WezTerm's own defaults:
`CMD+c/v/n` on macOS, `CTRL+SHIFT+c/v/n` on Linux and Windows. Nothing above
overrides them.

Run `wezterm show-keys` to dump every binding from the running config,
defaults included, or press `LEADER ?` for a searchable palette.

## Layout

```
wezterm.lua            entry point
generate-keys.lua      regenerates this file from modules/keys.lua
modules/platform.lua   OS detection (only place that branches per-OS)
modules/colors.lua     Tokyo Night palette
modules/appearance.lua fonts, chrome, tab bar colors
modules/behavior.lua   perf, scrollback, links, mouse
modules/keys.lua       leader bindings -- the source for this file
modules/sessions.lua   project -> workspace launcher (LEADER s)
modules/tabs.lua       powerline tab titles
modules/status.lua     status bar (workspace / git / cwd / battery / clock)
```

Project roots scanned by `LEADER s` are listed in `modules/sessions.lua`.