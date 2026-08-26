-- Pane resize: equalize a row/column of sibling panes (LEADER CTRL+=) and
-- single-cell nudges on the active pane's own edges (CTRL+Arrow, see
-- keys.lua). Split out from keys.lua because this logic is self-contained
-- and involved enough to want its own file -- keys.lua just requires this
-- module and wires the two key bindings to M.equalize/M.resize_verified/
-- M.ring_bell.
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
local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

-- panes_with_info() entries carry an opaque Pane userdata; match by
-- :pane_id() since neither Lua table identity nor int() equality is
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
function M.resize_verified(window, tab, pane_id, direction, amount)
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

  if restore_id ~= pane_id then
    local restore = get_pane_by_id(tab:panes_with_info(), restore_id)
    if restore then restore.pane:activate() end
  end

  -- Whether `direction` grows or shrinks a *specific* pane depends on
  -- which side of that pane actually has a movable boundary in that
  -- direction -- a tree-shape fact, not a fixed convention. Confirmed by
  -- hand: for the bottom-most pane in a column, 'Up' *grows* it (its only
  -- boundary is its top edge, and pushing that edge up enlarges the pane
  -- below it) while 'Down' shrinks it -- the reverse of what a middle pane
  -- would do. So this does not assert a growth/shrink direction; it only
  -- confirms the pane's dimension changed by exactly `amount` in some
  -- direction, which is what "the resize actually landed on this pane, at
  -- the size requested" means here. A boundary that doesn't move at all
  -- (the wezterm#7401 case) is the failure this actually needs to catch.
  local delta = dim_after - dim_before
  if math.abs(delta) ~= amount then
    return false, string.format(
      'a boundary would not move (changed by %d, expected %d) -- likely wezterm#7401',
      delta, amount)
  end
  return true
end

-- Single-key nudges (CTRL+Arrow) can hit the wezterm#7401 dead-boundary
-- case often while exploring a layout; a toast on every miss is too heavy
-- for something this frequent. Ring the terminal bell instead -- a brief
-- cursor-colour flash (see visual_bell in behavior.lua; audible_bell's
-- SystemBeep is silent on Wayland, so this deliberately doesn't rely on
-- sound). inject_output only works on local panes, not multiplexer ones,
-- which is fine here: nothing in this config attaches to a mux domain.
function M.ring_bell(pane)
  pane:inject_output('\x07')
end

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

-- Equalizes the sibling group (row of columns, or column of rows) that the
-- active pane belongs to. Walks left-to-right (or top-to-bottom), moving
-- each internal boundary toward equal widths/heights one pane at a time,
-- verifying every single move. Stops and reports on the first surprise
-- rather than continuing to guess -- see M.resize_verified's comment. Says
-- nothing on success -- LEADER CTRL+= is meant to be pressed freely while
-- eyeballing a layout, and a toast every time it just works is noise; only
-- failures/refusals are worth interrupting for.
function M.equalize(window, pane)
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
  -- above), so trust fresh geometry over the plan. Also re-check the
  -- group's total: if it changed, the window itself was resized/moved
  -- mid-run (e.g. dragged to a different display) and continuing would be
  -- equalizing against stale target sizes -- stop and say so plainly
  -- instead of blaming it on tree shape.
  --
  -- Never ask a pane to *shrink itself*. Confirmed by hand: a pane in the
  -- middle of a 3+-way row/column can have AdjustPaneSize on its own
  -- Left/Right (or Up/Down) silently redirect to the *wrong* boundary --
  -- e.g. asking pane B (between A and C) to shrink toward C instead grows
  -- A and shrinks B toward A, moving the A/B boundary instead of the B/C
  -- one, even though B's own width does change by the requested amount
  -- (so a same-pane magnitude check alone doesn't catch it). What always
  -- worked in testing was asking a pane to *grow*: growing pane[i+1] in
  -- the direction that eats into pane[i] reliably moves the i/(i+1)
  -- boundary correctly. So every step here grows the pane on whichever
  -- side needs to end up smaller, into the pane on the other side -- it
  -- never issues a "shrink yourself" call.
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
      local ok, err
      if delta > 0 then
        -- siblings[i] needs to grow: grow it directly, into siblings[i+1].
        ok, err = M.resize_verified(window, tab, siblings[i].pane:pane_id(), grow_dir, delta)
      else
        -- siblings[i] needs to shrink: don't ask it to shrink itself --
        -- grow siblings[i+1] toward it instead, same net boundary move.
        ok, err = M.resize_verified(window, tab, siblings[i + 1].pane:pane_id(), shrink_dir, -delta)
      end
      if not ok then
        window:toast_notification('WezTerm',
          'Equalize stopped: ' .. err .. '. Layout may be partially adjusted.', nil, 4500)
        return
      end
    end

    -- Belt-and-suspenders: confirm every previously-fixed sibling is still
    -- at its target after this step. Growing siblings[i+1] could in
    -- principle still reach past it into siblings[i+2] etc. on some tree
    -- shape we haven't seen yet -- if so, stop and say so rather than
    -- report false success.
    local after_this_step = tab:panes_with_info()
    for j = 1, i do
      local prior_target = base + (j <= extra and 1 or 0)
      local prior_now = get_pane_by_id(after_this_step, siblings[j].pane:pane_id())
      if not prior_now or prior_now[dim] ~= prior_target then
        window:toast_notification('WezTerm',
          'Equalize stopped: fixing one boundary undid another -- these panes share a boundary WezTerm can\'t move independently.',
          nil, 4500)
        return
      end
    end
  end
end

return M
