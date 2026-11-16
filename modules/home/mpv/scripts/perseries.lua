-- Keep subtitle/intro settings and playback speed with each title.
local utils = require 'mp.utils'
local function config_path(name)
    return mp.command_native({'expand-path', '~~/' .. name})
end

local cfg = {intro_skip_default = '85', sub_languages = 'en', os_apikey = '', os_username = '', os_password = ''}
local user_config = io.open(config_path('user.conf'), 'r')
if user_config then
    for line in user_config:lines() do
        local key, value = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        if key then cfg[key] = value end
    end
    user_config:close()
end
for key, value in pairs(cfg) do
    mp.set_property_native('user-data/config-' .. key, value)
end

local path = config_path('series.json')
local temporary = path .. '.' .. utils.getpid() .. '.tmp'
local function read_db()
    local f = io.open(path, 'r')
    if not f then return {files = {}, series = {}} end
    local data = utils.parse_json(f:read('*a'))
    f:close()
    if type(data) ~= 'table' then return {files = {}, series = {}} end
    return {files = data.files or {}, series = data.series or {}}
end

local db = read_db()
local changes = {files = {}, series = {}}
local timer
local function flush()
    if not timer then return end
    timer:kill()
    timer = nil
    local latest = read_db()
    for scope, titles in pairs(changes) do
        for title, fields in pairs(titles) do
            local entry = latest[scope][title] or {}
            for key, value in pairs(fields) do entry[key] = value end
            latest[scope][title] = entry
        end
    end
    local data = utils.format_json(latest)
    local f = data and io.open(temporary, 'w')
    if not f then return end
    local written = f:write(data)
    local closed = f:close()
    if written and closed and os.rename(temporary, path) then
        db = latest
        changes = {files = {}, series = {}}
    else
        os.remove(temporary)
    end
end
mp.register_event('shutdown', flush)

local function set(scope, title, key, value)
    if not title then return end
    local entry = db[scope][title] or {}
    if entry[key] == value then return end
    entry[key] = value
    db[scope][title] = entry
    local pending = changes[scope][title] or {}
    pending[key] = value
    changes[scope][title] = pending
    if timer then timer:kill() end
    timer = mp.add_timeout(0.35, flush)
end

local function keys()
    local file = mp.get_property('filename/no-ext', '')
    local normalized = file:gsub('[._]', ' ')
    local series = normalized:match('^(.-)%s*[Ss]%d+%s*[Ee]%d+')
        or normalized:match('^(.-)%s+[Ee][Pp]%s*%d+')
    local title = (series or normalized):gsub('%s*%(?%d%d%d%d%)?%s*$', ''):gsub('%s+$', ''):lower()
    return file, title, series ~= nil and title ~= ''
end

local file, series
local speed_scope, speed_title
local remember_speed = not mp.get_property_bool('option-info/speed/set-from-commandline', false)
local default_speed = mp.get_property_number('speed', 1)
mp.add_hook('on_before_start_file', 50, function()
    speed_title = nil
    if remember_speed then mp.set_property_number('speed', default_speed) end
end)
mp.add_hook('on_load', 50, function()
    if not remember_speed then return end
    local name, title, episodic = keys()
    if name == '' then return end
    local scope = episodic and 'series' or 'files'
    local id = episodic and title or name
    local entry = db[scope][id] or {}
    local speed = tonumber(entry.speed)
    local loaded_speed = mp.get_property_number('speed', default_speed)
    if not speed and loaded_speed ~= default_speed then
        -- Import legacy watch-later speed for this title on first open.
        speed = loaded_speed
        set(scope, id, 'speed', speed)
    end
    mp.set_property_number('file-local-options/speed', speed or default_speed)
end)

mp.register_event('file-loaded', function()
    local episodic
    file, series, episodic = keys()
    local pf = db.files[file] or {}
    local ps = db.series[series] or {}
    mp.set_property_native('user-data/intro_skip', pf.intro_skip or ps.intro_skip or tonumber(cfg.intro_skip_default) or 85)
    if pf.sub_delay then mp.set_property_number('sub-delay', pf.sub_delay) end
    mp.set_property_number('sub-pos', pf.sub_pos or 95)
    mp.set_property_native('user-data/series_sid', ps.sid or false)
    mp.set_property_native('user-data/autoskip_mode', pf.autoskip_mode or ps.autoskip_mode or 'off')
    mp.set_property_native('user-data/autoskip_chapter', pf.autoskip_chapter or ps.autoskip_chapter or false)
    if remember_speed and file ~= '' then
        speed_scope = episodic and 'series' or 'files'
        speed_title = episodic and series or file
    end
end)

mp.register_event('end-file', function()
    file, series, speed_title = nil, nil, nil
end)

mp.observe_property('speed', 'number', function(_, value)
    if speed_title and value then set(speed_scope, speed_title, 'speed', value) end
end)
mp.observe_property('sub-delay', 'number', function(_, value)
    if value then set('files', file, 'sub_delay', value) end
end)
mp.observe_property('sub-pos', 'number', function(_, value)
    if value then set('files', file, 'sub_pos', value) end
end)
mp.observe_property('sid', 'native', function(_, value)
    if type(value) == 'number' then set('series', series, 'sid', value) end
end)

for _, key in ipairs({'autoskip_mode', 'autoskip_chapter'}) do
    mp.observe_property('user-data/' .. key, 'native', function(_, value)
        if type(value) == 'string' then
            set('files', file, key, value)
            set('series', series, key, value)
        end
    end)
end

mp.register_script_message('set-intro', function(value)
    if not file then return end
    local seconds = math.max(0, tonumber(value) or 0)
    mp.set_property_native('user-data/intro_skip', seconds)
    set('files', file, 'intro_skip', seconds)
    set('series', series, 'intro_skip', seconds)
end)
