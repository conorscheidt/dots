-- seekboost.lua — OPTIONAL instant-seek hybrid, OFF by default.
--
-- Profiling (real files, warm cache) showed pure video-sync=display-resample
-- already seeks fast (~288ms, no stalls) — faster than this hybrid's audio flip,
-- and with no flip = no flip-stutter. So the default is pure display-resample;
-- this hybrid is a runtime A/B toggle (HUD Controls / script-message).
--
-- When ON: the instant a seek starts, flip to video-sync=audio (snappy jump),
-- then restore display-resample once playback settles (interpolation back). Only
-- acts when the base sync is display-resample. State: user-data/seekboost.
local BASE = 'display-resample'
local SETTLE = 0.35
local flipped = false
local settle

local function on() return mp.get_property_native('user-data/seekboost', false) end

mp.register_event('seek', function()
    if not on() then return end
    if mp.get_property('video-sync') == 'audio' and not flipped then return end
    if not flipped then mp.set_property('video-sync', 'audio'); flipped = true end
    if settle then settle:kill(); settle = nil end
end)
mp.register_event('playback-restart', function()
    if not flipped then return end
    if settle then settle:kill() end
    settle = mp.add_timeout(SETTLE, function() mp.set_property('video-sync', BASE); flipped = false; settle = nil end)
end)

mp.register_script_message('seekboost-toggle', function()
    local v = not on(); mp.set_property_native('user-data/seekboost', v)
    if not v and flipped then mp.set_property('video-sync', BASE); flipped = false end
    mp.osd_message('Seek boost: ' .. (v and 'on (audio-flip hybrid)' or 'off (pure display-resample)'), 1.6)
end)
