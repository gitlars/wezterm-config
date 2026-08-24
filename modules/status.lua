-- Status bar.
--   left : workspace name, plus a LEADER indicator while the leader is armed
--   right: git branch / cwd / battery / clock
local wezterm = require 'wezterm'
local p = require 'modules.colors'
local nf = wezterm.nerdfonts

local M = {}

local function glyph(name, fallback)
  local g = nf[name]
  if g == nil or g == '' then return fallback end
  return g
end

local SEP_L = glyph('pl_right_hard_divider', '')

local ICON_WS     = glyph('md_layers_triple_outline', 'WS')
local ICON_BRANCH = glyph('dev_git_branch', 'git')
local ICON_DIR    = glyph('md_folder_outline', 'dir')
local ICON_CLOCK  = glyph('md_clock_outline', '')

-- git rev-parse is a subprocess on the GUI thread, so cache it hard: only
-- re-run when the directory changes or every REFRESH_TICKS status updates
-- (status_update_interval is 1000ms, so ~10s).
local REFRESH_TICKS = 10
local git_cache = { dir = nil, branch = nil, ticks = 0 }

local function cwd_of(pane)
  local ok, cwd = pcall(function() return pane:get_current_working_dir() end)
  if not ok or not cwd then return nil end
  if type(cwd) == 'userdata' then return cwd.file_path end
  return (tostring(cwd):gsub('^file://[^/]*', ''))
end

local function git_branch(dir)
  if not dir then return nil end

  git_cache.ticks = git_cache.ticks + 1
  if dir == git_cache.dir and git_cache.ticks < REFRESH_TICKS then
    return git_cache.branch
  end

  git_cache.dir = dir
  git_cache.ticks = 0
  git_cache.branch = nil

  local ok, success, stdout = pcall(wezterm.run_child_process, {
    'git', '-C', dir, 'rev-parse', '--abbrev-ref', 'HEAD',
  })
  if ok and success and stdout then
    local branch = stdout:gsub('%s+$', '')
    if branch ~= '' and branch ~= 'HEAD' then git_cache.branch = branch end
  end

  return git_cache.branch
end

local function battery()
  local ok, info = pcall(wezterm.battery_info)
  if not ok or not info or #info == 0 then return nil end

  local b = info[1]
  local pct = math.floor((b.state_of_charge or 0) * 100 + 0.5)

  local icon
  if b.state == 'Charging' then
    icon = glyph('md_battery_charging', '~')
  elseif pct >= 90 then icon = glyph('md_battery', '')
  elseif pct >= 60 then icon = glyph('md_battery_70', '')
  elseif pct >= 35 then icon = glyph('md_battery_50', '')
  elseif pct >= 15 then icon = glyph('md_battery_30', '')
  else icon = glyph('md_battery_alert', '!')
  end

  return string.format('%s %d%%', icon, pct)
end

local function basename(s)
  if not s or s == '' then return nil end
  return s:gsub('[\\/]+$', ''):match('([^\\/]+)$')
end

-- One powerline-separated segment.
--
-- The divider glyph is a solid triangle: it is painted in the FOREGROUND colour
-- while the rest of its cell takes the BACKGROUND. So the triangle must carry
-- the incoming segment's colour and sit on the outgoing segment's background.
-- Reversing these two is what makes the chevron ends look inverted.
local function segment(cells, text, fg, bg, prev_bg)
  table.insert(cells, { Background = { Color = prev_bg } })
  table.insert(cells, { Foreground = { Color = bg } })
  table.insert(cells, { Text = SEP_L })
  table.insert(cells, { Background = { Color = bg } })
  table.insert(cells, { Foreground = { Color = fg } })
  table.insert(cells, { Text = ' ' .. text .. ' ' })
  return bg
end

function M.setup()
  wezterm.on('update-status', function(window, pane)
    ---------------------------------------------------------------- left --
    local left = {}
    if window:leader_is_active() then
      table.insert(left, { Background = { Color = p.orange } })
      table.insert(left, { Foreground = { Color = p.bg_dark } })
      table.insert(left, { Attribute = { Intensity = 'Bold' } })
      table.insert(left, { Text = ' LEADER ' })
      table.insert(left, { Background = { Color = p.bg_dark } })
      table.insert(left, { Foreground = { Color = p.orange } })
      table.insert(left, { Text = glyph('pl_left_hard_divider', '') })
    else
      table.insert(left, { Background = { Color = p.bg_dark } })
      table.insert(left, { Foreground = { Color = p.magenta } })
      table.insert(left, { Attribute = { Intensity = 'Bold' } })
      table.insert(left, { Text = string.format(' %s %s ', ICON_WS, window:active_workspace()) })
    end
    window:set_left_status(wezterm.format(left))

    --------------------------------------------------------------- right --
    local dir = cwd_of(pane)
    local cells = {}
    local prev = p.bg_dark

    local branch = git_branch(dir)
    if branch then
      prev = segment(cells, ICON_BRANCH .. ' ' .. branch, p.bg_dark, p.green, prev)
    end

    local short = basename(dir)
    if short then
      prev = segment(cells, ICON_DIR .. ' ' .. short, p.fg, p.bg_highlight, prev)
    end

    local bat = battery()
    if bat then
      prev = segment(cells, bat, p.bg_dark, p.yellow, prev)
    end

    local clock = wezterm.strftime('%a %d %b  %H:%M')
    if ICON_CLOCK ~= '' then clock = ICON_CLOCK .. ' ' .. clock end
    prev = segment(cells, clock, p.bg_dark, p.blue, prev)

    table.insert(cells, { Text = ' ' })
    window:set_right_status(wezterm.format(cells))
  end)
end

return M
