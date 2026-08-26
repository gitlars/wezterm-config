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

-- Equalizing a row/column of sibling panes.
--
-- window:perform_action(AdjustPaneSize { dir, n }, pane) always resizes
-- whichever pane is *active*, growing it on `dir`'s side ('Right'/'Left'/
-- 'Down'/'Up'). Which neighbor loses the space depends on WezTerm's internal
-- split-tree shape, not on visual left-to-right/top-to-bottom adjacency --
-- confirmed by hand against a live window, then confirmed as a known,
-- currently-open upstream bug: wezterm#7401 ("AdjustPaneSize does not work
-- on the 1st vertical slit after the 1st and 2nd panes are further
-- vertically splitted"). Some split-tree shapes have a boundary that
-- AdjustPaneSize cannot move via *any* pane/direction combination -- only a
-- mouse drag can. There is no Lua-side way to detect this in advance; only
-- pane geometry (left/top/width/height) is exposed, not the tree shape.
--
-- So: this only fully works for the simple case (a flat row or column
-- produced by repeatedly splitting in one direction, no sub-splits within an
-- entry). For anything more nested, it may hit an unmovable boundary. Rather
-- than guess or silently produce a wrong layout, every resize step activates
-- the exact pane we want to change, issues one resize, then re-reads
-- geometry to confirm that pane actually changed by the amount asked. If it
-- didn't -- the known bug, or something else -- stop immediately and say so.
--
-- get_pane_by_id: panes_with_info() entries carry an opaque Pane userdata;
-- match by :pane_id() since neither Lua table identity nor int() equality is
-- guaranteed to work across separate panes_with_info() calls.
local function get_pane_by_id(infos, id)
  for _, info in ipairs(infos) do
    if info.pane:pane_id() == id then return info end
  end
  return nil
end

-- Resize the pane with `pane_id` by growing/shrinking it in `direction` by
-- `amount` cells, verifying the change landed on that exact pane. Returns
-- true/false plus a message on failure. Leaves whatever pane was active
-- when this was called still active when it returns (mirrors normal-case
-- WezTerm behaviour: resizing shouldn't move your cursor focus).
local function resize_pane_verified(window, tab, pane_id, direction, amount)
  if amount == 0 then return true end

  local before = get_pane_by_id(tab:panes_with_info(), pane_id)
  if not before then return false, 'pane disappeared before resize' end

  local restore_id = window:active_pane():pane_id()
  if restore_id ~= pane_id then
    before.pane:activate()
  end

  window:perform_action(act.AdjustPaneSize { direction, amount }, before.pane)

  local after = get_pane_by_id(tab:panes_with_info(), pane_id)
  if not after then return false, 'pane disappeared after resize' end

  local dim_before = (direction == 'Left' or direction == 'Right') and before.width or before.height
  local dim_after = (direction == 'Left' or direction == 'Right') and after.width or after.height
  local sign = (direction == 'Right' or direction == 'Down') and 1 or -1
  local expected = dim_before + sign * amount

  if restore_id ~= pane_id then
    local restore = get_pane_by_id(tab:panes_with_info(), restore_id)
    if restore then restore.pane:activate() end
  end

  if dim_after ~= expected then
    return false, string.format(
      'a boundary would not move (expected %d, got %d) -- likely wezterm#7401',
      expected, dim_after)
  end
  return true
end

-- Equalizes the sibling group (row of columns, or column of rows) that the
-- active pane belongs to. Walks left-to-right (or top-to-bottom), moving
-- each internal boundary toward equal widths/heights one pane at a time,
-- verifying every single move. Stops and reports on the first surprise
-- rather than continuing to guess -- see resize_pane_verified's comment.
-- Fallback for when the active pane has no direct row/column siblings: it
-- may still be one row (or column) among several stacked in a simple
-- N-way split where some of the *other* rows have been further subdivided
-- -- e.g. a lone pane above a row of 3 above another lone pane (3 rows
-- total; the middle one just happens to contain 3 sub-panes). Panes that
-- are siblings within the same horizontal row are geometrically forced to
-- share identical height (they occupy the same top..top+height span);
-- panes within the same vertical column are forced to share identical
-- width. So any one member of a row/column is a valid stand-in for the
-- whole row/column: resizing it resizes all of its siblings in lockstep,
-- and its own height/width after the fact correctly reflects what the
-- whole row/column did.
--
-- Detects this by grouping ALL panes (including the active one) by their
-- `top` (looking for stacked rows) and separately by their `left` (looking
-- for stacked columns), keeping only those groups whose combined span
-- exactly tiles the active pane's full width (for rows) or full height
-- (for columns) -- i.e. every row spans the same columns, every column
-- spans the same rows. If that yields more than one row (or column)
-- total, including the active pane's own, that is the sibling set: one
-- representative pane per row/column, sorted by top (or left).
local function find_adjacent_tiled_group(infos, active)
  local function representatives(by_key, lo, hi, span_axis)
    local size_key = span_axis == 'left' and 'width' or 'height'
    local reps = {}
    for key, group in pairs(by_key) do
      table.sort(group, function(a, b) return a[span_axis] < b[span_axis] end)
      local last = group[#group]
      if group[1][span_axis] == lo and last[span_axis] + last[size_key] == hi then
        table.insert(reps, { key = key, pane = group[1] })
      end
    end
    return reps
  end

  local by_top, by_left = {}, {}
  for _, info in ipairs(infos) do
    by_top[info.top] = by_top[info.top] or {}
    table.insert(by_top[info.top], info)
    by_left[info.left] = by_left[info.left] or {}
    table.insert(by_left[info.left], info)
  end

  local row_reps = representatives(by_top, active.left, active.left + active.width, 'left')
  if #row_reps > 1 then
    local siblings = {}
    for _, r in ipairs(row_reps) do table.insert(siblings, r.pane) end
    table.sort(siblings, function(a, b) return a.top < b.top end)
    return siblings, 'height', 'Down', 'Up'
  end

  local col_reps = representatives(by_left, active.top, active.top + active.height, 'top')
  if #col_reps > 1 then
    local siblings = {}
    for _, r in ipairs(col_reps) do table.insert(siblings, r.pane) end
    table.sort(siblings, function(a, b) return a.left < b.left end)
    return siblings, 'width', 'Right', 'Left'
  end

  return nil
end

-- Finds the sibling group the active pane belongs to and which axis to
-- equalize along. Checks direct siblings first -- other panes sharing the
-- *exact* top+height (same row) or left+width (same column) as the active
-- pane. This is unambiguous: two panes can only share an exact top+height
-- if they are genuinely arranged side by side in the same row (WezTerm's
-- layout guarantees this), regardless of what either pane's `left` happens
-- to be. This must run and win before the cross-row/column fallback below:
-- find_adjacent_tiled_group's by-`left`/by-`top` bucketing can be fooled
-- when an active pane's row-sibling coincidentally shares a `left` value
-- with a completely unrelated pane in a different row (e.g. both happen to
-- be the leftmost pane of their respective row) -- that collision can make
-- a genuine sibling look unmatched while other, unrelated panes look like
-- matches. Direct top+height/left+width equality has no such ambiguity.
--
-- A pane can simultaneously be part of a horizontal row (shares top+height
-- with others) and a vertical column (shares left+width with others) at
-- different tree levels -- e.g. the top pane of a 2-row stack that's
-- itself one of 3 side-by-side columns. Prefer whichever axis actually has
-- more than one direct sibling; prefer horizontal if both do (rows of
-- columns is the far more common layout this binding is for).
--
-- Only if there are no direct siblings on either axis, fall back to
-- treating the active pane as one row/column among several stacked
-- rows/columns, one of which may itself be further subdivided -- see
-- find_adjacent_tiled_group.
local function find_sibling_group(infos, active)
  local horizontal, vertical = {}, {}
  for _, info in ipairs(infos) do
    if info.top == active.top and info.height == active.height then
      table.insert(horizontal, info)
    end
    if info.left == active.left and info.width == active.width then
      table.insert(vertical, info)
    end
  end

  -- Safety check before trusting a direct-match group: two panes can share
  -- an exact left+width (or top+height) coincidentally, without being
  -- adjacent siblings -- e.g. a lone pane above and a lone pane below a
  -- middle row of 3, where the outer two happen to both span full width.
  -- If some *other* pane exists whose column/row span falls strictly
  -- between two direct-match candidates, the direct match is wrong: it
  -- would silently skip that other pane's row/column entirely. Detect this
  -- and refuse rather than equalize an incomplete subset.
  local function has_pane_between(group, axis)
    if #group < 2 then return false end
    table.sort(group, function(a, b) return a[axis] < b[axis] end)
    for i = 1, #group - 1 do
      local lo, hi = group[i][axis], group[i + 1][axis]
      for _, info in ipairs(infos) do
        if info[axis] > lo and info[axis] < hi then return true end
      end
    end
    return false
  end

  if #horizontal > 1 then
    if has_pane_between(horizontal, 'left') then
      return nil, 'ambiguous'
    end
    table.sort(horizontal, function(a, b) return a.left < b.left end)
    return horizontal, 'width', 'Right', 'Left'
  end
  if #vertical > 1 then
    if has_pane_between(vertical, 'top') then
      return nil, 'ambiguous'
    end
    table.sort(vertical, function(a, b) return a.top < b.top end)
    return vertical, 'height', 'Down', 'Up'
  end

  return find_adjacent_tiled_group(infos, active)
end

local function equalize_pane_group(window, pane)
  local tab = pane:tab()
  if not tab then return end

  local infos = tab:panes_with_info()
  local active = get_pane_by_id(infos, pane:pane_id())
  if not active then return end

  local siblings, dim, grow_dir, shrink_dir = find_sibling_group(infos, active)
  if dim == 'ambiguous' then
    window:toast_notification('WezTerm',
      'Equalize not supported for this layout (3+-way split with a subdivided row/column)', nil, 3500)
    return
  end
  if not siblings then
    window:toast_notification('WezTerm', 'No sibling pane group found to equalize', nil, 2500)
    return
  end

  local total = 0
  for _, info in ipairs(siblings) do total = total + info[dim] end
  local base = math.floor(total / #siblings)
  local extra = total % #siblings

  -- Walk boundaries in order. After each successful move, re-fetch current
  -- sizes for the *remaining* panes -- an earlier move may have changed a
  -- pane other than the one visually next to it (see the tree-shape note
  -- above), so trust fresh geometry over the plan. Also re-check the group's
  -- total: if it changed, the window itself was resized/moved mid-run (e.g.
  -- dragged to a different display) and continuing would be equalizing
  -- against stale target sizes -- stop and say so plainly instead of
  -- blaming it on tree shape.
  for i = 1, #siblings - 1 do
    local target = base + (i <= extra and 1 or 0)
    local fresh = tab:panes_with_info()

    local fresh_total = 0
    for _, info in ipairs(siblings) do
      local f = get_pane_by_id(fresh, info.pane:pane_id())
      if not f then
        window:toast_notification('WezTerm', 'Pane vanished mid-equalize; stopped', nil, 3500)
        return
      end
      fresh_total = fresh_total + f[dim]
    end
    if fresh_total ~= total then
      window:toast_notification('WezTerm',
        'Equalize stopped: window size changed mid-run. Layout may be partially adjusted.', nil, 4500)
      return
    end

    local current = get_pane_by_id(fresh, siblings[i].pane:pane_id())
    local delta = target - current[dim]
    if delta ~= 0 then
      local direction = delta > 0 and grow_dir or shrink_dir
      local ok, err = resize_pane_verified(window, tab, siblings[i].pane:pane_id(), direction, math.abs(delta))
      if not ok then
        window:toast_notification('WezTerm',
          'Equalize stopped: ' .. err .. '. Layout may be partially adjusted.', nil, 4500)
        return
      end
    end
  end

  window:toast_notification('WezTerm', 'Equalized ' .. #siblings .. ' panes', nil, 2000)
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
  { group = 'Panes', desc = 'equalize the current row of panes', label = 'LEADER CTRL+=',
    key = '=', mods = 'LEADER|CTRL', action = wezterm.action_callback(equalize_pane_group) },
  -- Verified single-step nudges on the active pane's own edges (as opposed
  -- to `LEADER r` + h/j/k/l, which resizes whatever's active in whichever
  -- direction the key implies -- these always mean "grow/shrink the pane
  -- toward its own right/bottom edge specifically"). Uses the same
  -- activate -> resize -> verify pattern as equalize, so a boundary that
  -- can't move (the wezterm#7401 tree-shape bug) reports clearly instead of
  -- silently doing nothing.
  { group = 'Panes', desc = 'grow the active pane to the right by 1 cell', label = 'CTRL+→',
    key = 'RightArrow', mods = 'CTRL', action = wezterm.action_callback(function(window, pane)
      local tab = pane:tab()
      if not tab then return end
      local ok, err = resize_pane_verified(window, tab, pane:pane_id(), 'Right', 1)
      if not ok then
        window:toast_notification('WezTerm', 'Nudge stopped: ' .. err, nil, 3500)
      end
    end) },
  { group = 'Panes', desc = 'shrink the active pane from the right by 1 cell', label = 'CTRL+←',
    key = 'LeftArrow', mods = 'CTRL', action = wezterm.action_callback(function(window, pane)
      local tab = pane:tab()
      if not tab then return end
      local ok, err = resize_pane_verified(window, tab, pane:pane_id(), 'Left', 1)
      if not ok then
        window:toast_notification('WezTerm', 'Nudge stopped: ' .. err, nil, 3500)
      end
    end) },
  { group = 'Panes', desc = 'grow the active pane toward the bottom by 1 cell', label = 'CTRL+↓',
    key = 'DownArrow', mods = 'CTRL', action = wezterm.action_callback(function(window, pane)
      local tab = pane:tab()
      if not tab then return end
      local ok, err = resize_pane_verified(window, tab, pane:pane_id(), 'Down', 1)
      if not ok then
        window:toast_notification('WezTerm', 'Nudge stopped: ' .. err, nil, 3500)
      end
    end) },
  { group = 'Panes', desc = 'shrink the active pane from the bottom by 1 cell', label = 'CTRL+↑',
    key = 'UpArrow', mods = 'CTRL', action = wezterm.action_callback(function(window, pane)
      local tab = pane:tab()
      if not tab then return end
      local ok, err = resize_pane_verified(window, tab, pane:pane_id(), 'Up', 1)
      if not ok then
        window:toast_notification('WezTerm', 'Nudge stopped: ' .. err, nil, 3500)
      end
    end) },

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
