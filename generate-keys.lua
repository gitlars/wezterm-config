-- Regenerates KEYS.md from modules/keys.lua, so the docs cannot drift from the
-- actual bindings. It is a config file rather than a script because WezTerm has
-- no standalone Lua interpreter -- loading it as a config runs it, and it
-- returns an empty config so nothing else happens.
--
--   wezterm --config-file ~/.config/wezterm/generate-keys.lua ls-fonts >/dev/null
--
local wezterm = require 'wezterm'
local keys = require 'modules.keys'

local dir = wezterm.config_dir or (wezterm.home_dir .. '/.config/wezterm')
local out = dir .. '/KEYS.md'

-- '|' would break a markdown table cell.
local function esc(s) return (tostring(s):gsub('|', '\\|')) end

local lines = {}
local function w(s) table.insert(lines, s or '') end

w('# WezTerm keys')
w()
w('<!-- GENERATED FILE -- do not edit by hand.')
w('     Source: modules/keys.lua. Regenerate with:')
w('       wezterm --config-file generate-keys.lua ls-fonts >/dev/null -->')
w()
w('Leader is **CTRL+a**, then a key (2s window). Identical on macOS, Linux and')
w('Windows. `LEADER a` sends a literal CTRL+a to the shell.')
w()

for _, group in ipairs(keys.groups) do
  local rows = {}
  for _, e in ipairs(keys.spec) do
    if e.group == group and not e.doc_skip and e.desc then
      local note = e.platform and (' _(' .. e.platform .. ' only)_') or ''
      table.insert(rows, string.format('| `%s` | %s%s |', esc(keys.label_for(e)), esc(e.desc), note))
    end
  end
  if #rows > 0 then
    w('## ' .. group)
    w()
    w('| Keys | Action |')
    w('|---|---|')
    for _, r in ipairs(rows) do w(r) end
    w()
  end
end

w('## Platform defaults')
w()
w("Copy, paste, new window and font sizing stay on WezTerm's own defaults:")
w('`CMD+c/v/n` on macOS, `CTRL+SHIFT+c/v/n` on Linux and Windows. Nothing above')
w('overrides them.')
w()
w('Run `wezterm show-keys` to dump every binding from the running config,')
w('defaults included, or press `LEADER ?` for a searchable palette.')
w()
w('## Layout')
w()
w('```')
w('wezterm.lua            entry point')
w('generate-keys.lua      regenerates this file from modules/keys.lua')
w('modules/platform.lua   OS detection (only place that branches per-OS)')
w('modules/colors.lua     Tokyo Night palette')
w('modules/appearance.lua fonts, chrome, tab bar colors')
w('modules/behavior.lua   perf, scrollback, links, mouse')
w('modules/keys.lua       leader bindings -- the source for this file')
w('modules/sessions.lua   project -> workspace launcher (LEADER s)')
w('modules/tabs.lua       powerline tab titles')
w('modules/status.lua     status bar (workspace / git / cwd / battery / clock)')
w('```')
w()
w('Project roots scanned by `LEADER s` are listed in `modules/sessions.lua`.')

local f = assert(io.open(out, 'w'))
f:write(table.concat(lines, '\n'))
f:close()
wezterm.log_info('KEYS.md regenerated: ' .. #keys.spec .. ' spec entries')

return {}
