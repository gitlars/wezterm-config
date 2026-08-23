-- OS detection. The only place in the config allowed to branch on platform.
local wezterm = require 'wezterm'

local triple = wezterm.target_triple

return {
  is_mac = triple:find('darwin') ~= nil,
  is_windows = triple:find('windows') ~= nil,
  is_linux = triple:find('linux') ~= nil,
}
