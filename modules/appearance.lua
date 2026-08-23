-- Fonts, colors, window chrome.
local wezterm = require 'wezterm'
local platform = require 'modules.platform'
local p = require 'modules.colors'

local M = {}

function M.apply(config)
  config.color_scheme = 'Tokyo Night'

  -- Nerd Font first so status-bar/tab icons resolve; plain JetBrains Mono and
  -- the standalone symbol font are fallbacks for machines without it.
  config.font = wezterm.font_with_fallback {
    { family = 'JetBrainsMono Nerd Font', weight = 'Medium' },
    { family = 'JetBrains Mono', weight = 'Medium' },
    'Symbols Nerd Font Mono',
  }
  config.font_size = platform.is_mac and 13.0 or 11.0
  config.line_height = 1.1
  config.warn_about_missing_glyphs = false
  config.adjust_window_size_when_changing_font_size = false

  -- Window chrome
  config.window_decorations = 'TITLE|RESIZE'
  config.window_padding = { left = 12, right = 12, top = 10, bottom = 8 }
  config.window_background_opacity = 1.0
  config.window_close_confirmation = 'AlwaysPrompt'
  config.initial_cols = 160
  config.initial_rows = 44

  -- Dim panes that don't have focus, so the active one is unmistakable.
  config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.70 }

  -- Retro tab bar is required for powerline separators in format-tab-title.
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = false
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = false
  config.tab_max_width = 34

  config.colors = {
    tab_bar = {
      background = p.bg_dark,
      new_tab = { bg_color = p.bg_dark, fg_color = p.comment },
      new_tab_hover = { bg_color = p.bg_highlight, fg_color = p.fg },
    },
    split = p.blue,
    cursor_bg = p.orange,
    cursor_border = p.orange,
    cursor_fg = p.bg,
    selection_bg = p.bg_highlight,
    selection_fg = p.fg,
  }

  config.window_frame = {
    font = wezterm.font { family = 'JetBrainsMono Nerd Font', weight = 'Bold' },
    font_size = platform.is_mac and 12.0 or 10.0,
    active_titlebar_bg = p.bg_dark,
    inactive_titlebar_bg = p.bg_dark,
  }

  -- Cursor + bell
  config.default_cursor_style = 'BlinkingBar'
  config.cursor_blink_rate = 600
  config.cursor_blink_ease_in = 'Constant'
  config.cursor_blink_ease_out = 'Constant'
  config.audible_bell = 'Disabled'
  config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
    target = 'CursorColor',
  }

  config.command_palette_font_size = platform.is_mac and 13.0 or 11.0
  config.command_palette_bg_color = p.bg_highlight
  config.command_palette_fg_color = p.fg
end

return M
