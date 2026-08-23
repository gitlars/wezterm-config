-- Keybindings.
--
-- Design rule: the LEADER (CTRL+a) owns the *workflow* -- panes, tabs,
-- workspaces -- and is byte-identical on macOS, Linux and Windows. Platform
-- keys (CMD on mac, CTRL+SHIFT elsewhere) are left to WezTerm's defaults so
-- copy/paste/new-window keep native manners with no config to maintain.
local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux
local platform = require 'modules.platform'
local sessions = require 'modules.sessions'
local p = require 'modules.colors'

local M = {}

local function prompt(label, on_line)
  return act.PromptInputLine {
    description = wezterm.format {
      { Attribute = { Intensity = 'Bold' } },
      { Foreground = { Color = p.magenta } },
      { Text = label },
    },
    action = wezterm.action_callback(function(window, pane, line)
      if line and line ~= '' then on_line(window, pane, line) end
    end),
  }
end

function M.apply(config)
  config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 2000 }

  -- macOS only, and currently the same as WezTerm's default -- pinned because
  -- Meta encoding is depended on everywhere (Option+D / Option+Backspace word
  -- deletion, readline and REPL bindings) and a silent upstream default change
  -- would be painful to diagnose. Left Option sends Meta; right Option is left
  -- alone so it still composes accented characters.
  config.send_composed_key_when_left_alt_is_pressed = false

  local keys = {
    -- LEADER,a -> literal CTRL+a, so readline's beginning-of-line survives.
    { key = 'a', mods = 'LEADER',      action = act.SendKey { key = 'a', mods = 'CTRL' } },
    { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },

    ----------------------------------------------------------------- panes --
    { key = '|',  mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '\\', mods = 'LEADER',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '-',  mods = 'LEADER',       action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = '_',  mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

    { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
    { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
    { key = 'LeftArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    { key = 'DownArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
    { key = 'UpArrow',    mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
    { key = 'o', mods = 'LEADER', action = act.ActivatePaneDirection 'Next' },
    { key = ';', mods = 'LEADER', action = act.ActivatePaneDirection 'Prev' },

    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
    { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
    { key = 'Space', mods = 'LEADER', action = act.RotatePanes 'Clockwise' },
    { key = 'p', mods = 'LEADER',       action = act.PaneSelect { alphabet = 'asdfghjkl' } },
    { key = 'P', mods = 'LEADER|SHIFT', action = act.PaneSelect { alphabet = 'asdfghjkl', mode = 'SwapWithActive' } },

    -- break the active pane out into its own tab (tmux: break-pane)
    { key = '!', mods = 'LEADER|SHIFT', action = wezterm.action_callback(function(_, pane)
        pane:move_to_new_tab()
      end) },

    -- hold LEADER,r then h/j/k/l or arrows to resize; Esc/Enter/q to exit
    { key = 'r', mods = 'LEADER', action = act.ActivateKeyTable {
        name = 'resize_pane', one_shot = false, timeout_milliseconds = 3000,
      } },

    ------------------------------------------------------------------ tabs --
    { key = 'c',   mods = 'LEADER',       action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'n',   mods = 'LEADER',       action = act.ActivateTabRelative(1) },
    { key = 'b',   mods = 'LEADER',       action = act.ActivateTabRelative(-1) },
    { key = 'Tab', mods = 'LEADER',       action = act.ActivateLastTab },
    { key = '{',   mods = 'LEADER|SHIFT', action = act.MoveTabRelative(-1) },
    { key = '}',   mods = 'LEADER|SHIFT', action = act.MoveTabRelative(1) },
    { key = '&',   mods = 'LEADER|SHIFT', action = act.CloseCurrentTab { confirm = true } },
    { key = ',',   mods = 'LEADER', action = prompt('Rename tab: ', function(window, _, line)
        window:active_tab():set_title(line)
      end) },

    ------------------------------------------------------------ workspaces --
    { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
    { key = 's', mods = 'LEADER', action = wezterm.action_callback(sessions.pick) },
    { key = '(', mods = 'LEADER|SHIFT', action = act.SwitchWorkspaceRelative(-1) },
    { key = ')', mods = 'LEADER|SHIFT', action = act.SwitchWorkspaceRelative(1) },
    { key = '$', mods = 'LEADER|SHIFT', action = prompt('Rename workspace: ', function(_, _, line)
        mux.rename_workspace(mux.get_active_workspace(), line)
      end) },

    -------------------------------------------------------- copy / search --
    { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
    { key = ']', mods = 'LEADER', action = act.PasteFrom 'Clipboard' },
    { key = '/', mods = 'LEADER', action = act.Search { CaseInSensitiveString = '' } },
    { key = 'f', mods = 'LEADER', action = act.QuickSelect },
    { key = 'u', mods = 'LEADER', action = act.QuickSelectArgs {
        label = 'open url',
        patterns = { 'https?://\\S+' },
        action = wezterm.action_callback(function(window, pane)
          local url = window:get_selection_text_for_pane(pane)
          if url and url ~= '' then wezterm.open_with(url) end
        end),
      } },

    ------------------------------------------------------------------ misc --
    { key = 'K', mods = 'LEADER|SHIFT', action = act.Multiple {
        act.ClearScrollback 'ScrollbackAndViewport',
        act.SendKey { key = 'l', mods = 'CTRL' },
      } },
    { key = '?', mods = 'LEADER|SHIFT', action = act.ActivateCommandPalette },
    { key = 'R', mods = 'LEADER|SHIFT', action = act.ReloadConfiguration },
    { key = 'D', mods = 'LEADER|SHIFT', action = act.ShowDebugOverlay },

    -- Claude Code / REPL multiline: SHIFT+Enter inserts a newline.
    { key = 'Enter', mods = 'SHIFT', action = act.SendString '\x1b\r' },
  }

  -- LEADER + 1..9 jumps straight to a tab
  for i = 1, 9 do
    table.insert(keys, { key = tostring(i), mods = 'LEADER', action = act.ActivateTab(i - 1) })
  end

  -- macOS-only conveniences layered on top of WezTerm's native CMD defaults.
  if platform.is_mac then
    table.insert(keys, { key = 'Enter', mods = 'CMD', action = act.ToggleFullScreen })
    table.insert(keys, { key = 'k', mods = 'CMD', action = act.Multiple {
      act.ClearScrollback 'ScrollbackAndViewport',
      act.SendKey { key = 'l', mods = 'CTRL' },
    } })
  end

  config.keys = keys

  config.key_tables = {
    resize_pane = {
      { key = 'h', action = act.AdjustPaneSize { 'Left', 3 } },
      { key = 'j', action = act.AdjustPaneSize { 'Down', 3 } },
      { key = 'k', action = act.AdjustPaneSize { 'Up', 3 } },
      { key = 'l', action = act.AdjustPaneSize { 'Right', 3 } },
      { key = 'LeftArrow',  action = act.AdjustPaneSize { 'Left', 3 } },
      { key = 'DownArrow',  action = act.AdjustPaneSize { 'Down', 3 } },
      { key = 'UpArrow',    action = act.AdjustPaneSize { 'Up', 3 } },
      { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 3 } },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'Enter',  action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
    },
  }
end

return M
