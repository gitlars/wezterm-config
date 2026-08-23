-- Performance, scrollback, links, mouse, shell selection.
local wezterm = require 'wezterm'
local act = wezterm.action
local platform = require 'modules.platform'

local M = {}

function M.apply(config)
  -- Rendering. Flip front_end to 'OpenGL' if you ever see flicker/artifacts.
  config.front_end = 'WebGpu'
  config.webgpu_power_preference = 'HighPerformance'
  config.max_fps = 120
  config.animation_fps = 60

  config.scrollback_lines = 20000
  config.enable_scroll_bar = false
  config.check_for_updates = false
  config.automatically_reload_config = true
  config.exit_behavior = 'CloseOnCleanExit'
  config.default_workspace = 'main'
  config.status_update_interval = 1000
  config.unzoom_on_switch_pane = true
  config.enable_kitty_graphics = true

  -- Deliberately no default_prog: WezTerm inherits the system default shell on
  -- every platform. Hardcoding pwsh.exe would fail on stock Windows, which
  -- ships powershell.exe (5.1) and not PowerShell 7. Set it in local.lua on
  -- machines where you want a specific shell.

  -- LEADER+f (quick select) jumps to any of these without touching the mouse.
  config.quick_select_patterns = {
    '[0-9a-f]{7,40}',                          -- git SHAs
    '[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+',         -- emails
    '\\b\\d{1,3}(\\.\\d{1,3}){3}\\b',          -- IPv4
    '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}', -- UUIDs
    '(?:[.\\w\\-@~$]+)?(?:/[.\\w\\-@]+)+',     -- file paths
    '#[0-9a-fA-F]{3,8}',                       -- hex colors
    '[a-zA-Z0-9\\-]+:[0-9]+',                  -- host:port
  }

  config.hyperlink_rules = wezterm.default_hyperlink_rules()
  -- org/repo#123 -> GitHub issue
  table.insert(config.hyperlink_rules, {
    regex = [[\b([\w\-]+/[\w\-]+)#(\d+)\b]],
    format = 'https://github.com/$1/issues/$2',
  })

  config.mouse_bindings = {
    -- CTRL+click opens a link; plain click keeps normal selection behaviour.
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
    },
    {
      event = { Down = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.Nop,
    },
    -- Triple click selects the whole shell command + its output.
    {
      event = { Down = { streak = 3, button = 'Left' } },
      mods = 'NONE',
      action = act.SelectTextAtMouseCursor 'SemanticZone',
    },
  }
end

return M
