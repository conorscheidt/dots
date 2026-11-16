-- Persist the user's playback quality preset. Speed is stored per title.
local utils = require 'mp.utils'
local path = mp.command_native({'expand-path', '~~/prefs.json'})
local temporary = path .. '.' .. utils.getpid() .. '.tmp'
local prefs = {}
local f = io.open(path, 'r')
if f then
    local data = utils.parse_json(f:read('*a'))
    f:close()
    if type(data) == 'table' then prefs = data end
end

local next_preset = {full = 'eco', eco = 'full'}
local upscale_modes = {auto = true, ewa = true}
local function apply(preset)
    mp.set_property_native('user-data/preset', preset)
    mp.osd_message(preset == 'full' and 'Quality: Full' or 'Quality: Eco', 1.2)
end

-- The old preset was only a label. Start at Full until a functional preset is chosen.
local saved = next_preset[prefs.quality_preset] and prefs.quality_preset or 'full'
mp.set_property_native('user-data/preset', saved)
mp.set_property_native('user-data/upscale', upscale_modes[prefs.upscale] and prefs.upscale or 'auto')

mp.add_key_binding(nil, 'cycle-preset', function()
    apply(next_preset[mp.get_property_native('user-data/preset')] or 'full')
end)

mp.register_script_message('set-preset', function(preset)
    if next_preset[preset] then apply(preset) end
end)

mp.register_script_message('set-upscale', function(mode)
    if upscale_modes[mode] then mp.set_property_native('user-data/upscale', mode) end
end)

local function persist(key, value)
    if prefs[key] == value then return end
    local previous = prefs[key]
    prefs[key] = value
    local data = utils.format_json(prefs)
    local out = data and io.open(temporary, 'w')
    if out then
        local written = out:write(data)
        local closed = out:close()
        if written and closed and os.rename(temporary, path) then return end
    end
    os.remove(temporary)
    prefs[key] = previous
end

mp.observe_property('user-data/preset', 'native', function(_, preset)
    if next_preset[preset] then persist('quality_preset', preset) end
end)
mp.observe_property('user-data/upscale', 'native', function(_, mode)
    if upscale_modes[mode] then persist('upscale', mode) end
end)
