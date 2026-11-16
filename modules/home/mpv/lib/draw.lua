-- draw.lua — shared ASS drawing helpers for the bespoke UI (osc/menu/hud), so
-- the identical one-liners aren't copy-pasted across scripts.
-- Use: package.path = mp.command_native({'expand-path','~~/lib/?.lua'})..';'..package.path
--      local draw = require('draw')
local M = {}
-- ASS \1a inverse-alpha byte: visibility 1 -> 00 (opaque), 0 -> FF (transparent)
function M.av(vis) return string.format('%02X', math.max(0, math.min(255, math.floor((1 - vis) * 255)))) end
-- filled-shape override block at (0,0): colour + visibility (+ optional extra tags)
function M.shp(c, vis, ex) return string.format('{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&%s}', c, M.av(vis), ex or '') end
-- rounded rect into an assdraw object
function M.rr(a, x, y, w, h, r) a:round_rect_cw(x, y, x + w, y + h, math.min(r, w / 2, h / 2)) end
-- ease-out cubic, input/output clamped to [0,1]
function M.ease_out_cubic(t) t = math.max(0, math.min(1, t)); local u = 1 - t; return 1 - u * u * u end
-- make arbitrary text safe inside an ASS override block (neutralise \ { } newlines)
function M.escape(str) return (tostring(str or ''):gsub('\\', '/'):gsub('{', '('):gsub('}', ')'):gsub('[\r\n]+', ' ')) end
-- compact speed label, e.g. 1.5 -> "1.5×", 1.0 -> "1×"
function M.fmt_speed(v) return (('%.2f'):format(v or 1):gsub('%.?0+$', '')) .. '×' end
-- m:ss / h:mm:ss
function M.fmt(t) t = math.max(0, math.floor(t or 0)); local h, m, se = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60; if h > 0 then return string.format('%d:%02d:%02d', h, m, se) end return string.format('%d:%02d', m, se) end
-- inverse of fmt: a colon => [h:]m:ss, no colon => raw seconds. nil if unparseable.
function M.parse_t(s)
    if type(s) ~= 'string' then return tonumber(s) end
    if not s:find(':') then return tonumber(s) end
    local t = 0; for p in s:gmatch('%d+') do t = t * 60 + tonumber(p) end
    return t
end
return M
