-- Powerline tab bar: index, process icon, smart title, zoom + unseen-output marks.
local wezterm = require 'wezterm'
local p = require 'modules.colors'
local nf = wezterm.nerdfonts

local M = {}

-- Nerd Font glyph names vary between releases; fall back to plain text.
local function glyph(name, fallback)
  local g = nf[name]
  if g == nil or g == '' then return fallback end
  return g
end

local SEP = glyph('pl_left_hard_divider', '')

local SHELLS = { zsh = true, bash = true, fish = true, sh = true, nu = true,
                 pwsh = true, powershell = true, cmd = true }

local PROC_ICONS = {
  zsh    = glyph('dev_terminal', '$'),
  bash   = glyph('cod_terminal_bash', '$'),
  fish   = glyph('md_fish', '$'),
  pwsh   = glyph('cod_terminal_powershell', '$'),
  nvim   = glyph('custom_vim', 'V'),
  vim    = glyph('custom_vim', 'V'),
  node   = glyph('md_nodejs', 'JS'),
  npm    = glyph('md_npm', 'npm'),
  python = glyph('md_language_python', 'PY'),
  python3= glyph('md_language_python', 'PY'),
  cargo  = glyph('dev_rust', 'RS'),
  rustc  = glyph('dev_rust', 'RS'),
  go     = glyph('seti_go', 'GO'),
  lua    = glyph('seti_lua', 'LUA'),
  git    = glyph('dev_git', 'git'),
  docker = glyph('md_docker', 'DK'),
  ssh    = glyph('md_ssh', 'SSH'),
  claude = glyph('md_robot_outline', 'AI'),
  htop   = glyph('md_chart_line', 'TOP'),
  btop   = glyph('md_chart_line', 'TOP'),
  make   = glyph('seti_makefile', 'MK'),
}
local DEFAULT_ICON = glyph('cod_terminal', '>')

local function basename(s)
  if not s or s == '' then return nil end
  s = s:gsub('%.exe$', '')
  return s:match('([^\\/]+)$')
end

local function cwd_of(pane_info)
  local cwd = pane_info.current_working_dir
  if not cwd then return nil end
  if type(cwd) == 'userdata' then return cwd.file_path end
  return (tostring(cwd):gsub('^file://[^/]*', ''))
end

-- A shell tab is most usefully named by its directory; anything else by the
-- program that is running.
local function title_for(tab, max_width)
  if tab.tab_title and #tab.tab_title > 0 then
    return tab.tab_title, DEFAULT_ICON
  end

  local pane = tab.active_pane
  local proc = basename(pane.foreground_process_name)
  local icon = (proc and PROC_ICONS[proc]) or DEFAULT_ICON

  local title
  if proc and SHELLS[proc] then
    title = basename(cwd_of(pane)) or proc
  else
    title = proc or (pane.title or 'shell')
  end

  return wezterm.truncate_right(title, math.max(max_width - 8, 6)), icon
end

function M.setup()
  wezterm.on('format-tab-title', function(tab, tabs, _, _, hover, max_width)
    local active = tab.is_active
    local bg = active and p.blue or (hover and p.bg_highlight or p.bg)
    local fg = active and p.bg_dark or (hover and p.fg or p.dark3)

    -- Match the separator to whatever comes next so tabs butt together cleanly.
    local next_tab = tabs[tab.tab_index + 2]
    local next_bg = p.bg_dark
    if next_tab then
      next_bg = next_tab.is_active and p.blue or p.bg
    end

    local title, icon = title_for(tab, max_width)

    local marks = ''
    if tab.active_pane.is_zoomed then
      marks = marks .. ' ' .. glyph('md_magnify_plus_outline', '[Z]')
    end
    if not active and tab.active_pane.has_unseen_output then
      marks = marks .. ' ' .. glyph('md_circle_medium', '*')
    end

    return {
      { Background = { Color = bg } },
      { Foreground = { Color = fg } },
      { Attribute = { Intensity = active and 'Bold' or 'Normal' } },
      { Text = string.format(' %d %s %s%s ', tab.tab_index + 1, icon, title, marks) },
      { Background = { Color = next_bg } },
      { Foreground = { Color = bg } },
      { Text = SEP },
    }
  end)
end

return M
