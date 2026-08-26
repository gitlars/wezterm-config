-- Performance, scrollback, links, mouse, shell selection.
local wezterm = require 'wezterm'
local act = wezterm.action
local platform = require 'modules.platform'

local M = {}

function M.apply(config)
  -- Rendering. This VM previously had no working 3D acceleration (VMware SVGA
  -- II Adapter with "Accelerate 3D Graphics" off), so WebGpu fell back to
  -- llvmpipe (software Vulkan) and pegged the CPU across many worker threads.
  -- 3D acceleration is now enabled in the VM settings and confirmed working
  -- for GNOME Shell (no llvmpipe threads there anymore). Trying OpenGL here
  -- as the first accelerated test: more conservative than WebGpu, and if it
  -- still falls back to software we'll see it the same way -- llvmpipe
  -- threads under wezterm-gui -- without repeating the earlier crisis.
  config.front_end = 'OpenGL'
  config.max_fps = 60
  config.animation_fps = 24

  config.scrollback_lines = 20000
  config.enable_scroll_bar = false
  config.check_for_updates = false
  config.automatically_reload_config = true

  -- audible_bell's SystemBeep is a no-op on Wayland (no system beep to
  -- call). Used by the pane resize nudge/equalize bindings in keys.lua as
  -- a lightweight "didn't work" signal instead of a toast on every miss --
  -- a brief cursor-colour flash, not a screen flash, so it's noticeable
  -- without being disruptive.
  config.visual_bell = {
    fade_in_duration_ms = 60,
    fade_out_duration_ms = 60,
    target = 'CursorColor',
  }
  -- 'Close', not 'CloseOnCleanExit': a bare `exit` returns the status of the
  -- *previous* command, so exiting after any failed command left the pane open
  -- with a warning. "My last command failed" is an ordinary state, not an
  -- event worth a dialog.
  config.exit_behavior = 'Close'
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
