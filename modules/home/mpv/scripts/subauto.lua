-- subauto.lua — subtitle acquisition flow on play:
--   1. built-in sub, preferring the series' remembered track (user-data/series_sid)
--   2. subs mpv auto-loaded (sub-auto=fuzzy handles exact/similar sibling names)
--   3. fuzzy scan of the folder for a same-episode manual sub (catches renamed ones)
--   4. open the OpenSubtitles download dialogue (last resort)
local utils = require 'mp.utils'
local SUBEXT = { srt = 1, ass = 1, ssa = 1, sub = 1, vtt = 1, mks = 1 }
local function episode_of(name)
    local s, e = name:match('[Ss](%d+)[Ee](%d+)')
    if s then return tonumber(s), tonumber(e) end
    local e2 = name:match('[Ee][Pp]?%.?%s?(%d%d?)')
    return nil, e2 and tonumber(e2) or nil
end

-- normalized series title (everything before SxxExx / year), for matching subs
-- to THIS show. ~/Documents/shows is flat + mixes many series, so an
-- episode-number-only match wrongly grabs another show's same episode.
local function series_key(name)
    local t = name:gsub('%.[^.]+$', ''):gsub('[._]', ' ')
    t = t:match('^(.-)%s*[Ss]%d+[Ee]%d+') or t:match('^(.-)%s*[Ee][Pp]?%.?%s?%d') or t
    return (t:gsub('%s*%(?%d%d%d%d%)?.*$', ''):gsub('^%s+', ''):gsub('%s+$', ''):lower():gsub('%s+', ' '))
end

local timer
mp.register_event('end-file', function()
    if timer then timer:kill(); timer = nil end
end)
mp.register_event('file-loaded', function()
    timer = mp.add_timeout(0.7, function()
        timer = nil
        local subs = {}
        for _, t in ipairs(mp.get_property_native('track-list', {})) do if t.type == 'sub' then subs[#subs + 1] = t end end
        -- (1) prefer the series' remembered track if present
        local want = mp.get_property_native('user-data/series_sid')
        if want then for _, t in ipairs(subs) do if t.id == want then mp.set_property_number('sid', want); return end end end
        -- (1.5) audio is NOT English but a preferred-language (en/eng) sub exists
        -- -> auto-select it (K/C-drama with foreign audio + English subs).
        local cfg = mp.get_property('user-data/config-sub_languages', 'en')
        local prefs = {}
        for l in cfg:gmatch('%a+') do prefs[l:lower()] = true end
        local function pref_match(l) l = (l or ''):lower(); for p in pairs(prefs) do if #l > 0 and l:sub(1, #p) == p then return true end end; return false end
        local alang = (mp.get_property('current-tracks/audio/lang') or ''):lower()
        if alang ~= '' and not pref_match(alang) then
            for _, t in ipairs(subs) do
                if pref_match(t.lang) then mp.set_property_number('sid', t.id); mp.osd_message('Subtitle: ' .. (t.lang or 'sub'), 1.2); return end
            end
        end
        -- (2) any sub already loaded (built-in or fuzzy-auto) -> done
        if #subs > 0 then return end
        -- (3) fuzzy scan folder for a same-episode sub
        local vpath = mp.get_property('path'); if not vpath then return end
        local dir, vfile = utils.split_path(vpath)
        local vs, ve = episode_of(vfile)
        local vkey = series_key(vfile)
        if ve and vkey ~= '' then
            for _, f in ipairs(utils.readdir(dir, 'files') or {}) do
                local ext = f:match('%.([^.]+)$')
                if ext and SUBEXT[ext:lower()] then
                    local ss, se = episode_of(f)
                    -- BOTH same series AND same episode (no cross-show collisions)
                    if se == ve and (vs == nil or ss == nil or vs == ss) and series_key(f) == vkey then
                        mp.commandv('sub-add', dir .. f, 'select'); mp.osd_message('Subtitle found', 1.4); return
                    end
                end
            end
        end
        -- Search online automatically only for known foreign-language audio.
        if alang ~= '' and not pref_match(alang) then
            mp.commandv('script-message', 'open-download')
        end
    end)
end)
