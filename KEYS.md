# WezTerm keys

Leader is **CTRL+a**, then a key (2s window). Identical on macOS, Linux and
Windows. `LEADER a` sends a literal CTRL+a to the shell (beginning-of-line).

## Panes
| Keys | Action |
|---|---|
| `LEADER \|` or `LEADER \` | split right |
| `LEADER -` | split down |
| `LEADER h/j/k/l` (or arrows) | move between panes |
| `LEADER o` / `LEADER ;` | next / previous pane |
| `LEADER z` | zoom (toggle fullscreen pane) |
| `LEADER x` | close pane |
| `LEADER p` / `LEADER P` | pick a pane / swap with picked pane |
| `LEADER Space` | rotate panes clockwise |
| `LEADER !` | break pane out into its own tab |
| `LEADER r` then `h/j/k/l` | resize (stays active; Esc/Enter/q exits) |

## Tabs
| Keys | Action |
|---|---|
| `LEADER c` | new tab |
| `LEADER n` / `LEADER b` | next / previous tab |
| `LEADER 1..9` | jump to tab N |
| `LEADER Tab` | last tab |
| `LEADER { }` | move tab left / right |
| `LEADER ,` | rename tab |
| `LEADER &` | close tab |

## Workspaces (tmux "sessions")
| Keys | Action |
|---|---|
| `LEADER s` | fuzzy project picker -> opens repo in its own workspace |
| `LEADER w` | fuzzy switcher over open workspaces |
| `LEADER ( )` | previous / next workspace |
| `LEADER $` | rename workspace |

## Copy, search, links
| Keys | Action |
|---|---|
| `LEADER [` | copy mode (vim keys; `v` select, `y` yank, `q` exit) |
| `LEADER ]` | paste |
| `LEADER /` | search scrollback |
| `LEADER f` | quick select (jump to SHAs, paths, IPs, UUIDs, URLs) |
| `LEADER u` | quick select a URL and open it |
| `CTRL+click` | open link under cursor |
| triple click | select whole command + output |

## Misc
| Keys | Action |
|---|---|
| `LEADER ?` | command palette (every action, searchable) |
| `LEADER K` | clear scrollback |
| `LEADER R` | reload config |
| `LEADER D` | debug overlay (Lua errors land here) |
| `SHIFT+Enter` | newline without submitting (Claude Code, REPLs) |
| `CMD+k` | clear scrollback (macOS) |
| `CMD+Enter` | fullscreen (macOS) |

Copy/paste/new-window/font-size stay on WezTerm's native defaults: `CMD+c/v/n`
on macOS, `CTRL+SHIFT+c/v/n` on Linux and Windows.

## Layout
```
wezterm.lua            entry point
modules/platform.lua   OS detection (only place that branches per-OS)
modules/colors.lua     Tokyo Night palette
modules/appearance.lua fonts, chrome, tab bar colors
modules/behavior.lua   perf, scrollback, links, mouse
modules/keys.lua       leader + key tables
modules/sessions.lua   project -> workspace launcher (LEADER s)
modules/tabs.lua       powerline tab titles
modules/status.lua     status bar (workspace / git / cwd / battery / clock)
```
Project roots scanned by `LEADER s` are listed in `modules/sessions.lua`.
