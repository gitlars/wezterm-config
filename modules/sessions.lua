-- Project -> workspace launcher. Globs for git repos under a few well-known
-- roots (wezterm.glob is cross-platform, so no `find`/`fd` dependency) and
-- opens the chosen one in its own named workspace.
local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

local home = wezterm.home_dir

-- Roots to scan. Missing directories are simply skipped.
M.roots = {
  home .. '/Projects',
  home .. '/Code',
  home .. '/code',
  home .. '/dev',
  home .. '/work',
  home .. '/src',
}

-- Always offered, repo or not.
M.extras = {
  home .. '/.config/wezterm',
  home .. '/.config',
}

local function basename(path)
  return path:gsub('[\\/]+$', ''):match('([^\\/]+)$') or path
end

-- Label as "parent/name" so same-named repos under different roots stay distinct.
local function label_for(path)
  local clean = path:gsub('[\\/]+$', '')
  local parent, name = clean:match('([^\\/]+)[\\/]([^\\/]+)$')
  if parent and name then return parent .. '/' .. name end
  return basename(clean)
end

function M.list()
  local seen, out = {}, {}

  local function add(path)
    if path and path ~= '' and not seen[path] then
      seen[path] = true
      table.insert(out, path)
    end
  end

  for _, root in ipairs(M.roots) do
    -- depth 1 and 2 below each root
    for _, pattern in ipairs { root .. '/*/.git', root .. '/*/*/.git' } do
      local ok, matches = pcall(wezterm.glob, pattern)
      if ok and matches then
        for _, git in ipairs(matches) do
          add((git:gsub('[\\/]%.git$', '')))
        end
      end
    end
  end

  for _, path in ipairs(M.extras) do
    local ok, matches = pcall(wezterm.glob, path)
    if ok and matches and #matches > 0 then add(path) end
  end

  table.sort(out, function(a, b) return label_for(a):lower() < label_for(b):lower() end)
  return out
end

-- LEADER+s
function M.pick(window, pane)
  local choices = {}
  for _, path in ipairs(M.list()) do
    table.insert(choices, { id = path, label = label_for(path) })
  end

  if #choices == 0 then
    window:toast_notification('wezterm', 'No projects found under ' .. table.concat(M.roots, ', '), nil, 4000)
    return
  end

  window:perform_action(
    act.InputSelector {
      title = 'Projects',
      description = 'Select a project to open in its own workspace',
      fuzzy_description = 'project> ',
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(win, p, id, label)
        if not id then return end
        win:perform_action(
          act.SwitchToWorkspace { name = label, spawn = { cwd = id } },
          p
        )
      end),
    },
    pane
  )
end

return M
