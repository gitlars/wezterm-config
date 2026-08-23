-- ~/.config/wezterm/wezterm.lua
-- Entry point. Identical on macOS / Linux / Windows; platform differences are
-- isolated in modules/platform.lua. Safe to symlink from a dotfiles repo.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

require('modules.appearance').apply(config)
require('modules.behavior').apply(config)
require('modules.keys').apply(config)

-- Event handlers (tab titles, status bar). These register globally.
require('modules.tabs').setup()
require('modules.status').setup()

-- Optional per-machine overrides. Copy local.lua.example -> local.lua on a
-- given machine; it is gitignored, so home/work differences stay local.
local ok, machine = pcall(require, 'local')
if ok and type(machine) == 'table' and type(machine.apply) == 'function' then
  machine.apply(config)
end

return config
