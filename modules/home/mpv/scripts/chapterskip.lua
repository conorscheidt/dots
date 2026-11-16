-- chapterskip.lua — auto-skip driver. Three modes (user-data/autoskip_mode):
--   off     — never skip.
--   manual  — on load, skip the first user-data/intro_skip seconds.
--   chapter — auto-skip the segment named user-data/autoskip_chapter (chosen in
--             the bar's skip picker): whenever playback enters that chapter, jump
--             to the next one. The same-named chapter is skipped on every episode.
-- Mode / manual length / chosen chapter are all picked in the bar picker
-- (zmenuflows) and PERSISTED per series by perseries.lua — this script is pure
-- reaction to the user-data props, it owns no persistence of its own.
local function mode() return mp.get_property_native('user-data/autoskip_mode') or 'off' end

-- skip the chosen chapter if playback is currently inside it
local function skip_named()
    local want = mp.get_property_native('user-data/autoskip_chapter')
    if not want then return end
    local chapters = mp.get_property_native('chapter-list', {})
    local ch = mp.get_property_number('chapter', -1) or -1
    local cur = chapters[ch + 1]
    if cur and cur.title == want then
        local nxt = chapters[ch + 2]
        if nxt then mp.set_property_number('time-pos', nxt.time); mp.osd_message('Skipped: ' .. want, 1.0) end
    end
end

local function do_load()
    local m = mode()
    if m == 'manual' then
        local secs = mp.get_property_native('user-data/intro_skip') or 0
        if secs > 0 and (mp.get_property_number('time-pos', 0) or 0) < 3 then
            mp.set_property_number('time-pos', secs); mp.osd_message('Skipped ' .. secs .. 's', 1.0)
        end
    elseif m == 'chapter' then
        skip_named()
    end
end
mp.register_event('file-loaded', function() mp.add_timeout(0.4, do_load) end)

-- chapter mode: skip the chosen segment whenever it's entered mid-playback too
mp.observe_property('chapter', 'number', function() if mode() == 'chapter' then skip_named() end end)

mp.register_script_message('skip-set-mode', function(m)
    if m == 'off' or m == 'manual' or m == 'chapter' then mp.set_property_native('user-data/autoskip_mode', m) end
end)
mp.register_script_message('skip-set-chapter', function(title)
    mp.set_property_native('user-data/autoskip_chapter', title)
    mp.set_property_native('user-data/autoskip_mode', 'chapter')
    mp.add_timeout(0.05, skip_named) -- if already inside the chosen segment, skip now
end)
