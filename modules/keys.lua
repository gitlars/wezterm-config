-- Keybindings.
--
-- SINGLE SOURCE OF TRUTH: the SPEC table below drives both the live key
-- assignments and KEYS.md. After changing anything here, regenerate the docs:
--
--   wezterm --config-file ~/.config/wezterm/generate-keys.lua ls-fonts >/dev/null
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

local function prompt_equal_splits(label, direction)
  return prompt(label, function(window, pane, line)
    local n = math.floor(tonumber(line) or 0)
    if n < 2 then
      window:toast_notification('WezTerm', 'Enter an integer >= 2', nil, 3000)
      return
    end

    local anchor = pane
    for remaining = n, 2, -1 do
      anchor:split {
        direction = direction,
        size = 1 / remaining,
      }
    end
  end)
end

-- Group order controls the section order in KEYS.md.
M.groups = { 'Leader', 'Panes', 'Tabs', 'Workspaces', 'Copy, search, links', 'Misc' }

-- Each entry: group, desc, key, mods, action.
-- Optional: label (override the auto-formatted key label), platform ('mac'),
-- doc_skip (bind it, but keep it out of the docs).
local SPEC = {
  -------------------------------------------------------------------- leader --
  { group = 'Leader', desc = 'send a literal CTRL+a (readline beginning-of-line)',
    key = 'a', mods = 'LEADER', action = act.SendKey { key = 'a', mods = 'CTRL' } },
  { group = 'Leader', desc = 'same, with CTRL still held',
    key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' }, doc_skip = true },

  --------------------------------------------------------------------- panes --
  { group = 'Panes', desc = 'split right', label = 'LEADER | or LEADER \\',
    key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { group = 'Panes', desc = 'split right', key = '\\', mods = 'LEADER',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' }, doc_skip = true },
  { group = 'Panes', desc = 'split down', label = 'LEADER -',
    key = '-', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { group = 'Panes', desc = 'split down', key = '_', mods = 'LEADER|SHIFT',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' }, doc_skip = true },
  { group = 'Panes', desc = 'prompt for N equal columns', label = 'LEADER CTRL+|',
    key = '|', mods = 'LEADER|CTRL|SHIFT', action = prompt_equal_splits('Equal columns: ', 'Right') },
  { group = 'Panes', desc = 'prompt for N equal rows', label = 'LEADER CTRL+-',
    key = '-', mods = 'LEADER|CTRL', action = prompt_equal_splits('Equal rows: ', 'Bottom') },

  { group = 'Panes', desc = 'move between panes', label = 'LEADER h j k l',
    key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { group = 'Panes', desc = 'move down', key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down', doc_skip = true },
  { group = 'Panes', desc = 'move up',   key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up',   doc_skip = true },
  { group = 'Panes', desc = 'move right',key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right',doc_skip = true },
  { group = 'Panes', desc = 'move between panes', label = 'LEADER ← ↓ ↑ →',
    key = 'LeftArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { group = 'Panes', desc = 'move down', key = 'DownArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Down',  doc_skip = true },
  { group = 'Panes', desc = 'move up',   key = 'UpArrow',    mods = 'LEADER', action = act.ActivatePaneDirection 'Up',    doc_skip = true },
  { group = 'Panes', desc = 'move right',key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Right', doc_skip = true },

  { group = 'Panes', desc = 'next pane',     key = 'o', mods = 'LEADER', action = act.ActivatePaneDirection 'Next' },
  { group = 'Panes', desc = 'previous pane', key = ';', mods = 'LEADER', action = act.ActivatePaneDirection 'Prev' },
  { group = 'Panes', desc = 'close pane',    key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { group = 'Panes', desc = 'zoom pane to fill the tab (toggle)', key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { group = 'Panes', desc = 'rotate panes clockwise', key = 'Space', mods = 'LEADER', action = act.RotatePanes 'Clockwise' },
  { group = 'Panes', desc = 'pick a pane by letter', key = 'p', mods = 'LEADER',
    action = act.PaneSelect { alphabet = 'asdfghjkl' } },
  { group = 'Panes', desc = 'swap the active pane with a picked one', key = 'P', mods = 'LEADER|SHIFT',
    action = act.PaneSelect { alphabet = 'asdfghjkl', mode = 'SwapWithActive' } },
  { group = 'Panes', desc = 'break the pane out into its own tab', key = '!', mods = 'LEADER|SHIFT',
    action = wezterm.action_callback(function(_, pane) pane:move_to_new_tab() end) },
  { group = 'Panes', desc = 'resize mode: then h/j/k/l or arrows; Esc, Enter or q exits',
    key = 'r', mods = 'LEADER',
    action = act.ActivateKeyTable { name = 'resize_pane', one_shot = false, timeout_milliseconds = 3000 } },

  ---------------------------------------------------------------------- tabs --
  { group = 'Tabs', desc = 'new tab',            key = 'c',   mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { group = 'Tabs', desc = 'next tab',           key = 'n',   mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { group = 'Tabs', desc = 'previous tab',       key = 'b',   mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { group = 'Tabs', desc = 'last tab (A/B flip)',key = 'Tab', mods = 'LEADER', action = act.ActivateLastTab },
  { group = 'Tabs', desc = 'move tab left',      key = '{',   mods = 'LEADER|SHIFT', action = act.MoveTabRelative(-1) },
  { group = 'Tabs', desc = 'move tab right',     key = '}',   mods = 'LEADER|SHIFT', action = act.MoveTabRelative(1) },
  { group = 'Tabs', desc = 'close tab',          key = '&',   mods = 'LEADER|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { group = 'Tabs', desc = 'rename tab (pins the name so it stops changing)', key = ',', mods = 'LEADER',
    action = prompt('Rename tab: ', function(window, _, line) window:active_tab():set_title(line) end) },

  ---------------------------------------------------------------- workspaces --
  { group = 'Workspaces', desc = 'fuzzy switcher over open workspaces', key = 'w', mods = 'LEADER',
    action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { group = 'Workspaces', desc = 'project picker -- opens a repo in its own workspace', key = 's', mods = 'LEADER',
    action = wezterm.action_callback(sessions.pick) },
  { group = 'Workspaces', desc = 'previous workspace', key = '(', mods = 'LEADER|SHIFT', action = act.SwitchWorkspaceRelative(-1) },
  { group = 'Workspaces', desc = 'next workspace',     key = ')', mods = 'LEADER|SHIFT', action = act.SwitchWorkspaceRelative(1) },
  { group = 'Workspaces', desc = 'rename workspace',   key = '$', mods = 'LEADER|SHIFT',
    action = prompt('Rename workspace: ', function(_, _, line)
      mux.rename_workspace(mux.get_active_workspace(), line)
    end) },

  ------------------------------------------------------- copy, search, links --
  { group = 'Copy, search, links', desc = 'copy mode (vim keys; v select, y yank, q exit)',
    key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
  { group = 'Copy, search, links', desc = 'paste', key = ']', mods = 'LEADER', action = act.PasteFrom 'Clipboard' },
  { group = 'Copy, search, links', desc = 'search scrollback', key = '/', mods = 'LEADER',
    action = act.Search { CaseInSensitiveString = '' } },
  { group = 'Copy, search, links', desc = 'quick select: jump to SHAs, paths, IPs, UUIDs',
    key = 'f', mods = 'LEADER', action = act.QuickSelect },
  { group = 'Copy, search, links', desc = 'quick select a URL and open it', key = 'u', mods = 'LEADER',
    action = act.QuickSelectArgs {
      label = 'open url',
      patterns = { 'https?://\\S+' },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        if url and url ~= '' then wezterm.open_with(url) end
      end),
    } },

  ---------------------------------------------------------------------- misc --
  { group = 'Misc', desc = 'command palette -- every action, searchable', key = '?', mods = 'LEADER|SHIFT',
    action = act.ActivateCommandPalette },
  { group = 'Misc', desc = 'clear scrollback', key = 'K', mods = 'LEADER|SHIFT',
    action = act.Multiple { act.ClearScrollback 'ScrollbackAndViewport', act.SendKey { key = 'l', mods = 'CTRL' } } },
  { group = 'Misc', desc = 'reload config',  key = 'R', mods = 'LEADER|SHIFT', action = act.ReloadConfiguration },
  { group = 'Misc', desc = 'debug overlay -- Lua errors land here', key = 'D', mods = 'LEADER|SHIFT',
    action = act.ShowDebugOverlay },
  { group = 'Misc', desc = 'newline without submitting (Claude Code, REPLs)', key = 'Enter', mods = 'SHIFT',
    action = act.SendString '\x1b\r' },
  { group = 'Misc', desc = 'fullscreen', key = 'Enter', mods = 'CMD', action = act.ToggleFullScreen, platform = 'mac' },
  { group = 'Misc', desc = 'clear scrollback', key = 'k', mods = 'CMD', platform = 'mac',
    action = act.Multiple { act.ClearScrollback 'ScrollbackAndViewport', act.SendKey { key = 'l', mods = 'CTRL' } } },
}

-- LEADER + 1..9 jumps to a tab. Generated, so bindings and docs stay in step.
for i = 1, 9 do
  table.insert(SPEC, {
    group = 'Tabs',
    desc = i == 1 and 'jump straight to tab N' or nil,
    label = i == 1 and 'LEADER 1 … 9' or nil,
    doc_skip = i > 1,
    key = tostring(i), mods = 'LEADER', action = act.ActivateTab(i - 1),
  })
end

M.spec = SPEC

-- "LEADER|SHIFT" + "|" reads better as "LEADER |": SHIFT is implicit in a
-- shifted symbol, and repeating it is noise.
function M.label_for(e)
  if e.label then return e.label end
  local mods, has_leader, parts = e.mods or '', false, {}
  for m in mods:gmatch('[^|]+') do
    if m == 'LEADER' then has_leader = true
    elseif m == 'SHIFT' and mods:find('LEADER') then -- implicit
    else table.insert(parts, m) end
  end
  local prefix = has_leader and 'LEADER ' or ''
  if #parts > 0 then prefix = prefix .. table.concat(parts, '+') .. '+' end
  return prefix .. e.key
end

function M.applies_here(e)
  if not e.platform then return true end
  if e.platform == 'mac' then return platform.is_mac end
  return false
end

function M.apply(config)
  config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 2000 }

  -- macOS only, and currently the same as WezTerm's default -- pinned because
  -- Meta encoding is depended on everywhere (Option+D / Option+Backspace word
  -- deletion, readline and REPL bindings) and a silent upstream default change
  -- would be painful to diagnose. Left Option sends Meta; right Option is left
  -- alone so it still composes accented characters.
  config.send_composed_key_when_left_alt_is_pressed = false

  -- WezTerm validates key entries strictly, so hand it only the fields it
  -- knows: the doc metadata stays behind in SPEC.
  local keys = {}
  for _, e in ipairs(SPEC) do
    if M.applies_here(e) then
      table.insert(keys, { key = e.key, mods = e.mods, action = e.action })
    end
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
