-- menu.lua — bespoke anchored-popup list menu (ASS OSD overlay).
-- Replaces uosc's menus AND the old right-side sheet. A popup opens ANCHORED at
-- the OSC button it belongs to (rises out of it), sized to its content, with
-- vsync-locked buttery scroll, width-aware truncation (+ auto tooltip for
-- clipped names), Phosphor icons, and a scale-from-anchor open/close animation.
--
-- Public API (unchanged + additive):
--   Menu.open(data, on_select) ; Menu.close()
--   data = { title?, items = {{title,hint?,icon?,value,selectable?,active?,tip?}},
--            selected_index?, anchor? (osc button id), anchor_x? (canvas px) }
--   on_select(item, index) ; index is 1-based into ORIGINAL data.items.
-- Script-messages: menu-open <json>, menu-close ; emits menu-result {index,value}.
-- Style matches scripts/osc.lua (material 1C1C1E panel, Phosphor icons, Helvetica
-- Neue text, inset selection pill). Anchor is learned from user-data/osc-anchors
-- (published by osc.lua). Overlay z=30 so it always draws above the OSC bar.

local assdraw = require 'mp.assdraw'
package.path = mp.command_native({ 'expand-path', '~~/lib/?.lua' }) .. ';' .. package.path
local draw = require('draw')
local scroll = require('scroll')
local utils = require 'mp.utils'

local ICON = 'Phosphor-Fill'
local ACCENT = 'FFFFFF' -- monochrome selection
local FONT = 'Helvetica Neue'

Menu = {}

-- ── style / layout constants ────────────────────────────────────────────────
local o = {
    min_w = 200,
    max_w = 560,
    row_h = 40,
    header_h = 36,
    search_h = 36,
    pad_x = 16,
    pad_y = 8,
    icon_w = 22,
    icon_gap = 10,
    hint_gap = 14,
    check_w = 22,
    rad = 13,
    pill_rad = 8,
    pill_inset = 4,
    rows_cap = 9,
    gap_bar = 10,
    top_margin = 40,
    side_margin = 12,
    mat = '1C1C1E',
    mat_a = 0.82,
    bord_a = 0.14,
    shadow_a = 0.50,
    divider_a = 0.12,
    hint_col = 'A8A29E',
    pill_a = 0.16,
    pill_active_a = 0.08,
    snap_eps = 0.12,
    hover_lerp = 12,
    open_ms = 140,
    close_ms = 110,
    pop_scale_min = 0.90,
    scroll_step = 16,
    scroll_gamma = 0.7,
    scroll_ease = 22,                                       -- see lib/scroll.lua (gamma<1 = slow-finger sensitivity)
}

-- ── Phosphor glyph map (UTF-8 byte literals; verified present in Phosphor.ttf) ─
local GLYPH = {
    play_arrow = '\xEE\x8F\x90',
    pause = '\xEE\x8E\x9E',
    skip_previous = '\xEE\x96\xA4',
    skip_next = '\xEE\x96\xA6',
    fast_forward = '\xEE\x9A\xA6',
    bolt = '\xEE\x8B\x9E',
    eco = '\xEE\x8B\x9A',
    closed_caption = '\xEE\x86\xA4',
    graphic_eq = '\xEE\xA0\x82',
    download = '\xEE\x88\x8C',
    folder_open = '\xEE\x89\x96',
    folder = '\xEE\x89\x8A',
    fullscreen = '\xEE\x82\xA6',
    fullscreen_exit = '\xEE\x82\x9E',
    OLD_settings = '\xEE\x89\xB2',
    check = '\xEE\x86\x82',
    arrow_upward = '\xEE\x82\x8E',
    movie = '\xEE\x9E\x92',
    prohibit = '\xEE\x8F\x9E',
    clock = '\xEE\x86\x9A',
    timer = '\xEE\x92\x92',
    lightning = '\xEE\x8B\x9E',
    lightning_slash = '\xEE\x8B\xA0',
    subtitles = '\xEE\x86\xA8',
    caret_up = '\xEE\x84\xBC',
    caret_down = '\xEE\x84\xB8',
    close = '\xEE\x93\xB6',
    search = '\xEE\x8C\x8C',
    file_video = '\xEE\xA8\xA2',
    list = '\xEE\x8B\xB0',
    block = '\xEE\x8F\x9E',
    palette = '\xEE\x9B\x88',
    settings = '\xE2\x89\xB2',
    two_sliders = '\xEE\x88\xAA',
    display = '\xEE\x8C\xAE'
}
local function glyph(name) return name and GLYPH[name] or nil end

-- ── drawing helpers ──────────────────────────────────────────────────────────
local av, shp, ease_out_cubic = draw.av, draw.shp, draw.ease_out_cubic

-- opts: {font, size, color, vis, bold, clip}
local function text_line(x, y, an, str, opts)
    opts = opts or {}
    return string.format('{\\an%d\\pos(%.1f,%.1f)\\fn%s\\fs%.1f%s\\bord0\\shad0\\1c&H%s&\\1a&H%s&%s}%s',
        an, x, y, opts.font or FONT, opts.size or 14, opts.bold and '\\b1' or '',
        opts.color or 'FFFFFF', av(opts.vis or 1), opts.clip or '', str)
end

local ass_escape = draw.escape

-- ── UTF-8-aware width + truncation (LuaJIT: no utf8 lib, no << ops) ───────────
local function utf8_iter(str)
    local i, n = 1, #str
    return function()
        if i > n then return nil end
        local c = str:byte(i)
        local len = (c < 0x80 and 1) or (c < 0xE0 and 2) or (c < 0xF0 and 3) or 4
        local cp = c
        if len == 2 then
            cp = (c % 0x20) * 64 + (str:byte(i + 1) or 0) % 0x40
        elseif len == 3 then
            cp = (c % 0x10) * 4096 + ((str:byte(i + 1) or 0) % 0x40) * 64 + (str:byte(i + 2) or 0) % 0x40
        elseif len == 4 then
            cp = (c % 0x08) * 262144 + ((str:byte(i + 1) or 0) % 0x40) * 4096 + ((str:byte(i + 2) or 0) % 0x40) * 64 +
            (str:byte(i + 3) or 0) % 0x40
        end
        local st = i; i = i + len; return cp, st, len
    end
end
local function is_wide(cp)
    return (cp >= 0x1100 and cp <= 0x115F) or (cp >= 0x2E80 and cp <= 0xA4CF)
        or (cp >= 0xAC00 and cp <= 0xD7A3) or (cp >= 0xF900 and cp <= 0xFAFF)
        or (cp >= 0xFF00 and cp <= 0xFF60) or (cp >= 0x20000 and cp <= 0x3FFFD)
end
local function adv_of(cp, sz) return sz * (is_wide(cp) and 1.00 or (cp < 0x2000 and 0.52 or 0.55)) end
local function text_w(str, sz)
    local w = 0
    for cp in utf8_iter(str or '') do w = w + adv_of(cp, sz) end
    return w
end
local function fit_ellipsis(str, sz, maxw)
    if text_w(str, sz) <= maxw then return str, false end
    local ell = '…'; local budget = maxw - text_w(ell, sz)
    local w, cut = 0, 1
    for cp, st, len in utf8_iter(str) do
        local adv = adv_of(cp, sz)
        if w + adv > budget then break end
        w = w + adv; cut = st + len
    end
    return str:sub(1, cut - 1) .. ell, true
end

-- ── state ────────────────────────────────────────────────────────────────────
local s = {
    open = false,
    data = nil,
    items = {},
    filtered = {},
    selected = 1,
    query = '',
    scroll_y = 0,
    scroll_target = 0,
    appear = 0,
    appear_target = 0,
    hov = {},
    hover_item = nil,
    on_select = nil,
    kbd_nav = false,
    anchor_x = 0,
    bar_top = 648,
    ow = 0,
    oh = 0,
    sc = 1,
    mx = -1,
    my = -1,
    tprev = 0,
    frame_dt = 1 / 120,
    tip_row = nil,
    tip_hov = 0,
    edit_item = nil,
    edit_buf = '',
}
local ov = mp.create_osd_overlay('ass-events'); ov.z = 30
local timer

-- ── data helpers ─────────────────────────────────────────────────────────────
local function normalize_items(data)
    local items = {}
    for i, it in ipairs(data.items or {}) do
        items[#items + 1] = {
            title = (type(it.title) == 'string') and it.title or tostring(it.title or ''),
            hint = (type(it.hint) == 'string') and it.hint or nil,
            icon = (type(it.icon) == 'string') and it.icon or nil,
            tip = (type(it.tip) == 'string') and it.tip or nil,
            value = it.value,
            selectable = (it.selectable == nil) and true or (it.selectable and true or false),
            active = it.active and true or false,
            edit = it.edit and true or false,
            idx = i,
        }
    end
    return items
end

local function matches(title, query)
    if query == '' then return true end
    local lt, lq = title:lower(), query:lower()
    if lt:find(lq, 1, true) then return true end
    local qi, qlen = 1, #lq
    for i = 1, #lt do
        if qi > qlen then break end
        if lt:sub(i, i) == lq:sub(qi, qi) then qi = qi + 1 end
    end
    return qi > qlen
end

-- ── selection state machine ──────────────────────────────────────────────────
local function first_selectable(dir)
    local n = #s.filtered
    if dir >= 0 then
        for i = 1, n do if s.filtered[i].selectable then return i end end
    else
        for i = n, 1, -1 do if s.filtered[i].selectable then return i end end
    end
    return nil
end
local function clamp_select_from(i, dir)
    local n = #s.filtered
    if n == 0 then return 0 end
    i = math.max(1, math.min(n, i))
    local step = (dir >= 0) and 1 or -1
    local j = i
    while j >= 1 and j <= n do
        if s.filtered[j].selectable then return j end
        j = j + step
    end
    return first_selectable(1) or 1
end

-- ── geometry (anchored, content-sized) ───────────────────────────────────────
local function measure()
    local nat = 0
    if s.data and type(s.data.title) == 'string' and #s.data.title > 0 then
        nat = math.max(nat, o.pad_x * 2 + text_w(s.data.title, 15))
    end
    for _, it in ipairs(s.filtered) do
        local w = o.pad_x * 2
        if glyph(it.icon) then w = w + o.icon_w + o.icon_gap end
        w = w + text_w(it.title, 15)
        if it.hint and #it.hint > 0 then w = w + o.hint_gap + text_w(it.hint, 12) end
        if it.active then w = w + o.check_w end
        nat = math.max(nat, w)
    end
    return nat
end

local function geo()
    s.sc = (s.oh and s.oh > 0) and (s.oh / 720) or 1
    local W = (s.sc > 0) and (s.ow / s.sc) or 1280

    local pw = math.floor(math.max(o.min_w, math.min(o.max_w, measure())) + 0.5)
    pw = math.min(pw, W - o.side_margin * 2)

    local has_title = s.data and type(s.data.title) == 'string' and #s.data.title > 0
    local has_search = #s.query > 0
    local header_h = has_title and o.header_h or 0
    local search_h = has_search and o.search_h or 0

    local n = #s.filtered
    local content_h = (n > 0) and (n * o.row_h) or o.row_h
    local popup_bottom = s.bar_top - o.gap_bar
    local avail = popup_bottom - o.top_margin - header_h - search_h - o.pad_y * 2
    local list_h = math.max(o.row_h, math.min(content_h, math.min(avail, o.rows_cap * o.row_h)))
    local popup_h = header_h + search_h + o.pad_y * 2 + list_h

    local px = s.anchor_x - pw / 2
    px = math.max(o.side_margin, math.min(W - o.side_margin - pw, px))
    local py = math.max(o.top_margin, popup_bottom - popup_h)

    local list_y0 = py + header_h + search_h + o.pad_y
    local max_scroll = math.max(0, content_h - list_h)
    local pivot_x = math.max(px, math.min(px + pw, s.anchor_x))

    return {
        W = W,
        px = px,
        py = py,
        pw = pw,
        ph = popup_h,
        header_h = header_h,
        search_h = search_h,
        list_y0 = list_y0,
        list_h = list_h,
        content_h = content_h,
        max_scroll = max_scroll,
        pivot_x = pivot_x,
        pivot_y = popup_bottom,
        has_title = has_title,
        has_search = has_search
    }
end

local function ensure_visible()
    local n = #s.filtered
    if n == 0 then return end
    local g = geo()
    local row_top = (s.selected - 1) * o.row_h
    local row_bottom = row_top + o.row_h
    local target = s.scroll_target
    if row_top < target then
        target = row_top
    elseif row_bottom > target + g.list_h then
        target = row_bottom - g.list_h
    end
    s.scroll_target = math.max(0, math.min(g.max_scroll, target))
end
local function refilter()
    s.kbd_nav = true -- typing to filter highlights the first match
    local f = {}
    for _, it in ipairs(s.items) do if matches(it.title, s.query) then f[#f + 1] = it end end
    s.filtered = f
    s.selected = first_selectable(1) or 0
    s.scroll_target = 0; s.scroll_y = 0
end
local function move_selection(delta)
    local n = #s.filtered
    if n == 0 then return end
    s.kbd_nav = true
    if s.selected < 1 or s.selected > n then
        s.selected = first_selectable(1) or 1; ensure_visible(); return
    end
    local i = s.selected
    for _ = 1, n do
        i = i + delta
        if i < 1 then i = n elseif i > n then i = 1 end
        if s.filtered[i].selectable then
            s.selected = i; ensure_visible(); return
        end
    end
end
local function move_page(dir)
    if #s.filtered == 0 then return end
    s.kbd_nav = true
    local g = geo()
    local page = math.max(1, math.floor(g.list_h / o.row_h))
    s.selected = clamp_select_from(s.selected + dir * page, dir); ensure_visible()
end
local function move_home() if #s.filtered > 0 then
        s.kbd_nav = true; s.selected = clamp_select_from(1, 1); ensure_visible()
    end end
local function move_end_() if #s.filtered > 0 then
        s.kbd_nav = true; s.selected = clamp_select_from(#s.filtered, -1); ensure_visible()
    end end

-- ── hit testing (resting geo; input targets what is drawn) ───────────────────
local function hit(mx, my)
    if not s.open or not s.sc or s.sc == 0 then return nil, nil end
    local cx, cy = mx / s.sc, my / s.sc
    local g = geo()
    if cx < g.px or cx > g.px + g.pw or cy < g.py or cy > g.py + g.ph then return nil, 'outside' end
    if cy < g.list_y0 or cy > g.list_y0 + g.list_h then return nil, 'panel' end
    local i = math.floor((cy - g.list_y0 + s.scroll_y) / o.row_h) + 1
    if i >= 1 and i <= #s.filtered then return i, 'panel' end
    return nil, 'panel'
end

local function start_timer()
    if timer and timer:is_enabled() == false then
        s.tprev = mp.get_time(); timer:resume()
    end
end
-- one WHEEL event nudges scroll_target (gamma-shaped by scale); scroll_y eases
-- toward it each frame. macOS supplies inertial (momentum) events after a flick.
local function scroll_by(dir, scale)
    local g = geo()
    s.scroll_target = scroll.clamp(s.scroll_target + scroll.gain(dir, scale, o.scroll_step, o.scroll_gamma), 0,
        g.max_scroll)
    start_timer()
end

-- ── activation ───────────────────────────────────────────────────────────────
local function emit_result(it)
    local ok, j = pcall(utils.format_json, { index = it.idx, value = it.value })
    if not ok then
        local ok2, j2 = pcall(utils.format_json, { index = it.idx }); j = ok2 and j2 or '{}'
    end
    mp.commandv('script-message', 'menu-result', j)
end
local function commit_edit()
    local it = s.edit_item; if not it then return end
    local val = {}
    if type(it.value) == 'table' then for k, v in pairs(it.value) do val[k] = v end end
    val.num = tonumber(s.edit_buf)
    val.text = s.edit_buf -- raw string; consumer may parse M:SS etc.
    local ok, j = pcall(utils.format_json, { index = it.idx, value = val })
    if ok then mp.commandv('script-message', 'menu-result', j) end
    s.edit_item = nil
end
local function activate_selected()
    local it = s.filtered[s.selected]
    if not it or not it.selectable then return end
    if it.edit then
        s.edit_item = it; s.edit_buf = ''; return
    end                                                           -- blank on focus: type fresh
    emit_result(it)
    local cb = s.on_select
    if cb then
        local ok, err = pcall(cb, {
            title = it.title,
            hint = it.hint,
            icon = it.icon,
            value = it.value,
            selectable = it.selectable,
            active = it.active
        }, it.idx)
        if not ok then mp.msg.error('menu.lua: on_select error: ' .. tostring(err)) end
    end
    Menu.close()
end

-- ── tooltip (per-row tip, or auto for a truncated title) ─────────────────────
local function render_tooltip(t, g, TX, TY, TS, vis, scl)
    local it = s.hover_item
    local txt = it and (it.tip or (it._trunc and it.title)) or nil
    s.tip_row = txt and it or nil
    if not txt or s.tip_hov < 0.02 then return end
    local idx
    for i, x in ipairs(s.filtered) do if x == it then
            idx = i; break
        end end
    if not idx then return end
    local cy = g.list_y0 + (idx - 1) * o.row_h - s.scroll_y + o.row_h / 2
    if cy < g.list_y0 or cy > g.list_y0 + g.list_h then return end
    local label = ass_escape(txt)
    local pad = 11
    local tw = text_w(label, 12) + pad * 2; local th = 24
    local tx = g.px - 10 - tw
    if tx < o.side_margin then tx = g.px + g.pw + 10 end
    local a = vis * s.tip_hov * 0.96
    local tb = assdraw.ass_new(); tb:append(shp(o.mat, a)); tb:draw_start()
    tb:round_rect_cw(TX(tx), TY(cy - th / 2), TX(tx + tw), TY(cy + th / 2), 8 * scl); tb:draw_stop(); t[#t + 1] = tb
    .text
    local bd = assdraw.ass_new(); bd:append(string.format(
    '{\\pos(0,0)\\an7\\1a&HFF&\\bord1\\3c&HFFFFFF&\\3a&H%s&\\shad0}', av(a * 0.16))); bd:draw_start(); bd:round_rect_cw(
    TX(tx), TY(cy - th / 2), TX(tx + tw), TY(cy + th / 2), 8 * scl); bd:draw_stop(); t[#t + 1] = bd.text
    t[#t + 1] = text_line(TX(tx + tw / 2), TY(cy), 5, label, { size = TS(12), vis = a })
end

-- ── render (scale-from-anchor via TX/TY/TS) ──────────────────────────────────
local function render()
    if not s.oh or s.oh == 0 then
        ov.data = ''; ov:update(); return
    end
    if s.appear <= 0.004 and not s.open then
        ov.data = ''; ov:update(); return
    end

    local g = geo()
    local eas = ease_out_cubic(s.appear)
    local scl = o.pop_scale_min + (1 - o.pop_scale_min) * eas
    local vis = eas
    local pvx, pvy = g.pivot_x, g.pivot_y
    local function TX(x) return pvx + (x - pvx) * scl end
    local function TY(y) return pvy + (y - pvy) * scl end
    local function TS(z) return z * scl end
    local function trect(a, x, y, w, h, r) a:round_rect_cw(TX(x), TY(y), TX(x + w), TY(y + h),
            math.min(r * scl, (w * scl) / 2, (h * scl) / 2)) end
    local t = {}

    local sh = assdraw.ass_new(); sh:append(shp('000000', vis * o.shadow_a, '\\blur7')); sh:draw_start(); trect(sh,
        g.px - 2, g.py + 4, g.pw + 4, g.ph, o.rad + 2); sh:draw_stop(); t[#t + 1] = sh.text
    local bg = assdraw.ass_new(); bg:append(shp(o.mat, vis * o.mat_a, '\\blur0.5')); bg:draw_start(); trect(bg, g.px,
        g.py, g.pw, g.ph, o.rad); bg:draw_stop(); t[#t + 1] = bg.text
    local spec = assdraw.ass_new(); spec:append(shp('FFFFFF', vis * 0.09, '\\blur1.2')); spec:draw_start(); trect(spec,
        g.px + 14, g.py + 1.5, g.pw - 28, 1.4, 0.7); spec:draw_stop(); t[#t + 1] = spec.text
    local bd = assdraw.ass_new(); bd:append(string.format(
    '{\\pos(0,0)\\an7\\1a&HFF&\\bord1\\3c&HFFFFFF&\\3a&H%s&\\shad0}', av(vis * o.bord_a))); bd:draw_start(); trect(bd,
        g.px, g.py, g.pw, g.ph, o.rad); bd:draw_stop(); t[#t + 1] = bd.text

    local cy0 = g.py
    if g.has_title then
        t[#t + 1] = text_line(TX(g.px + o.pad_x), TY(cy0 + g.header_h / 2), 4, ass_escape(s.data.title),
            { size = TS(15), bold = true, vis = vis })
        cy0 = cy0 + g.header_h
    end
    if g.has_search then
        t[#t + 1] = text_line(TX(g.px + o.pad_x), TY(cy0 + g.search_h / 2), 4, GLYPH.search,
            { font = ICON, size = TS(15), vis = vis * 0.8 })
        t[#t + 1] = text_line(TX(g.px + o.pad_x + 24), TY(cy0 + g.search_h / 2), 4, ass_escape(s.query),
            { size = TS(14), vis = vis })
        cy0 = cy0 + g.search_h
    end
    if g.has_title or g.has_search then
        local dv = assdraw.ass_new(); dv:append(shp('FFFFFF', vis * o.divider_a)); dv:draw_start(); trect(dv,
            g.px + o.pad_x, cy0 - 0.5, g.pw - o.pad_x * 2, 1, 0.5); dv:draw_stop(); t[#t + 1] = dv.text
    end

    local lx1, ly1, lx2, ly2 = TX(g.px), TY(g.list_y0), TX(g.px + g.pw), TY(g.list_y0 + g.list_h)
    local clip = string.format('\\clip(%.1f,%.1f,%.1f,%.1f)', lx1, ly1, lx2, ly2)

    if #s.filtered == 0 then
        local msg = (#s.query > 0) and 'No matches' or 'No items'
        t[#t + 1] = text_line(TX(g.px + g.pw / 2), TY(g.list_y0 + g.list_h / 2), 5, msg,
            { size = TS(13), color = o.hint_col, vis = vis * 0.8, clip = clip })
    else
        local first_i = math.max(1, math.floor(s.scroll_y / o.row_h) + 1)
        local last_i = math.min(#s.filtered, math.floor((s.scroll_y + g.list_h) / o.row_h) + 1)
        for i = first_i, last_i do
            local it = s.filtered[i]
            local row_y = g.list_y0 + (i - 1) * o.row_h - s.scroll_y
            local cy = row_y + o.row_h / 2
            local hv = s.hov[it] or 0
            if it.selectable then
                -- subtle row tint + a macOS-sidebar-style left accent bar (grows on
                -- hover); active/current items keep a faint persistent indicator.
                local tint = math.max(it.active and 0.05 or 0, hv * 0.09)
                if tint > 0.004 then
                    local p = assdraw.ass_new(); p:append(shp('FFFFFF', vis * tint, clip)); p:draw_start()
                    p:round_rect_cw(TX(g.px + o.pill_inset), TY(row_y + o.pill_inset), TX(g.px + g.pw - o.pill_inset),
                        TY(row_y + o.row_h - o.pill_inset), o.pill_rad * scl); p:draw_stop(); t[#t + 1] = p.text
                end
                local barv = math.max(it.active and 0.5 or 0, hv * 0.95)
                if barv > 0.02 then
                    local bh = (o.row_h - 12) * math.max(it.active and 0.65 or 0, hv)
                    local ab = assdraw.ass_new(); ab:append(shp('FFFFFF', vis * barv, clip)); ab:draw_start()
                    ab:round_rect_cw(TX(g.px + 3), TY(cy - bh / 2), TX(g.px + 6), TY(cy + bh / 2), 1.6 * scl); ab
                        :draw_stop(); t[#t + 1] = ab.text
                end
            end

            local xL = g.px + o.pad_x
            local gl = glyph(it.icon)
            if gl then
                t[#t + 1] = text_line(TX(xL + o.icon_w / 2), TY(cy), 5, gl,
                    { font = ICON, size = TS(17), vis = vis * (it.selectable and (0.9 + 0.1 * hv) or 0.4), clip = clip })
                xL = xL + o.icon_w + o.icon_gap
            end
            local xR = g.px + g.pw - o.pad_x
            if it.active then
                t[#t + 1] = text_line(TX(xR), TY(cy), 6, GLYPH.check,
                    { font = ICON, size = TS(15), vis = vis * (0.85 + 0.15 * hv), clip = clip })
                xR = xR - o.check_w
            end
            if it == s.edit_item then
                -- blank on focus; raw string centered in a fixed field with a
                -- following caret, so it fills from the middle out like a textbox.
                -- caret keeps a constant '|' advance (alpha blinks) => no reflow.
                local on = math.floor(mp.get_time() * 2) % 2 == 0
                local etxt = s.edit_buf .. (on and '|' or '{\\1a&HFF&}|')
                local fw = 52
                t[#t + 1] = text_line(TX(xR - fw / 2), TY(cy), 5, etxt,
                    { size = TS(13), color = 'FFFFFF', vis = vis, bold = true, clip = clip })
                xR = xR - fw - o.hint_gap
            elseif it.hint and #it.hint > 0 then
                t[#t + 1] = text_line(TX(xR), TY(cy), 6, ass_escape(it.hint),
                    { size = TS(12), color = o.hint_col, vis = vis * 0.8, clip = clip })
                xR = xR - text_w(it.hint, 12) - o.hint_gap
            end
            -- cache truncation per (title,budget): re-scanning long download-result
            -- titles every frame stalled the main thread -> audio crackle.
            local budget = xR - xL
            if it._fit_budget ~= budget then
                it._fitted, it._trunc = fit_ellipsis(it.title, 15, budget); it._fit_budget = budget
            end
            local title = it._fitted
            local col = it.selectable and 'FFFFFF' or o.hint_col
            t[#t + 1] = text_line(TX(xL), TY(cy), 4, ass_escape(title),
                { size = TS(15), color = col, vis = vis * (it.selectable and (0.92 + 0.08 * hv) or 0.55), clip = clip })
        end

        if g.max_scroll > 0.5 then
            local track_x = g.px + g.pw - 3
            local thumb_h = g.list_h * (g.list_h / g.content_h)
            local thumb_y = g.list_y0 + (g.list_h - thumb_h) * (s.scroll_y / g.max_scroll)
            local tb = assdraw.ass_new(); tb:append(shp('FFFFFF', vis * 0.22)); tb:draw_start(); trect(tb, track_x,
                thumb_y, 2, thumb_h, 1); tb:draw_stop(); t[#t + 1] = tb.text
        end
    end

    render_tooltip(t, g, TX, TY, TS, vis, scl)

    ov.res_x = math.floor(g.W); ov.res_y = 720; ov.data = table.concat(t, '\n'); ov:update()
end

-- ── animation loop (display-rate; exp-smoothed scroll + appear scale/fade) ───
local function anim()
    local now = mp.get_time()
    local dt = math.min(0.05, now - ((s.tprev > 0) and s.tprev or now)); s.tprev = now

    local rate = 1000 / ((s.appear_target > s.appear) and o.open_ms or o.close_ms)
    if s.appear < s.appear_target then
        s.appear = math.min(s.appear_target, s.appear + rate * dt)
    elseif s.appear > s.appear_target then
        s.appear = math.max(s.appear_target, s.appear - rate * dt)
    end

    local scrolling
    s.scroll_y, scrolling = scroll.approach(s.scroll_y, s.scroll_target, dt, o.scroll_ease)

    local moving = math.abs(s.appear - s.appear_target) > 0.004 or scrolling

    local sel = s.filtered[s.selected]
    for _, it in ipairs(s.filtered) do
        -- highlight follows the mouse (hover_item); the keyboard cursor (sel) only
        -- highlights while navigating by key — so moving the mouse OUT clears it.
        local tgt = (it.selectable and (it == s.hover_item or (s.kbd_nav and it == sel))) and 1 or 0
        local cur = s.hov[it] or 0; cur = cur + (tgt - cur) * math.min(1, dt * o.hover_lerp)
        if math.abs(cur - tgt) < 0.004 then cur = tgt end
        s.hov[it] = cur; if cur ~= tgt then moving = true end
    end
    local tt = (s.tip_row ~= nil) and 1 or 0
    s.tip_hov = s.tip_hov + (tt - s.tip_hov) * math.min(1, dt * o.hover_lerp)
    if math.abs(s.tip_hov - tt) > 0.004 then moving = true end

    render()
    if (not s.open) and s.appear <= 0.004 and not moving then
        ov.data = ''; ov:update(); timer:kill(); s.tprev = 0
    end
end

local function make_timer()
    if timer then timer:kill() end
    local fps = mp.get_property_number('display-fps', 120) or 120
    s.frame_dt = 1 / math.max(60, math.min(240, fps))
    timer = mp.add_periodic_timer(s.frame_dt, anim); timer:kill()
end

-- ── key / mouse bindings (active only while open) ────────────────────────────
local function bind_keys()
    mp.add_forced_key_binding('UP', 'menu-up', function() move_selection(-1) end, { repeatable = true })
    mp.add_forced_key_binding('DOWN', 'menu-down', function() move_selection(1) end, { repeatable = true })
    mp.add_forced_key_binding('ENTER', 'menu-enter',
        function() if s.edit_item then commit_edit() else activate_selected() end end)
    mp.add_forced_key_binding('KP_ENTER', 'menu-kpenter',
        function() if s.edit_item then commit_edit() else activate_selected() end end)
    mp.add_forced_key_binding('ESC', 'menu-esc',
        function() if s.edit_item then s.edit_item = nil elseif #s.query > 0 then
                s.query = ''; refilter()
            else Menu.close() end end)
    mp.add_forced_key_binding('PGUP', 'menu-pgup', function() move_page(-1) end, { repeatable = true })
    mp.add_forced_key_binding('PGDWN', 'menu-pgdn', function() move_page(1) end, { repeatable = true })
    mp.add_forced_key_binding('HOME', 'menu-home', move_home)
    mp.add_forced_key_binding('END', 'menu-end', move_end_)
    mp.add_forced_key_binding('BS', 'menu-bs',
        function() if s.edit_item then s.edit_buf = s.edit_buf:sub(1, -2) elseif #s.query > 0 then
                s.query = s.query:sub(1, -2); refilter()
            end end, { repeatable = true })
    mp.add_forced_key_binding('MBTN_LEFT', 'menu-click', function()
        local i, where = hit(s.mx, s.my)
        if where == 'outside' then
            Menu.close(); return
        end
        if i and s.filtered[i] and s.filtered[i].selectable then
            s.selected = i; activate_selected()
        end
    end)
    -- complex bindings expose info.scale: fractional on high-res touchpads (fires
    -- many fine events even on slow finger movement), 1 on coarse mouse wheels.
    -- (AXIS_* are deprecated aliases for WHEEL_* — binding them would double-fire.)
    local function on_wheel(dir, info)
        if info.event == 'up' or info.canceled then return end
        scroll_by(dir, info.scale or 1)
    end
    mp.add_forced_key_binding('WHEEL_UP', 'menu-wu', function(i) on_wheel(-1, i) end, { complex = true })
    mp.add_forced_key_binding('WHEEL_DOWN', 'menu-wd', function(i) on_wheel(1, i) end, { complex = true })
    mp.add_forced_key_binding('any_unicode', 'menu-search-input', function(info)
        if info.key_text and (info.event == 'press' or info.event == 'down' or info.event == 'repeat') then
            if s.edit_item then
                if info.key_text:match('[%d:]') and #s.edit_buf < 6 then s.edit_buf = s.edit_buf .. info.key_text end
            else
                s.query = s.query .. info.key_text; refilter()
            end
        end
    end, { repeatable = true, complex = true })
end
local function unbind_keys()
    for _, n in ipairs({ 'menu-up', 'menu-down', 'menu-enter', 'menu-kpenter', 'menu-esc',
        'menu-pgup', 'menu-pgdn', 'menu-home', 'menu-end', 'menu-bs', 'menu-click',
        'menu-wu', 'menu-wd', 'menu-search-input' }) do mp.remove_key_binding(n) end
end

-- ── public API ───────────────────────────────────────────────────────────────
function Menu.open(data, on_select)
    data = data or {}
    s.data = data; s.items = normalize_items(data); s.on_select = on_select
    s.query = ''; s.filtered = {}
    for _, it in ipairs(s.items) do s.filtered[#s.filtered + 1] = it end
    s.hov = {}; s.hover_item = nil; s.tip_row = nil; s.tip_hov = 0; s.kbd_nav = false

    local A = mp.get_property_native('user-data/osc-anchors') or {}
    s.bar_top = tonumber(A.bar_top) or (720 - 26 - 46)
    local W = ((s.oh and s.oh > 0) and (s.ow / (s.oh / 720))) or 1280
    if tonumber(data.anchor_x) then
        s.anchor_x = tonumber(data.anchor_x)
    elseif data.anchor and A[data.anchor] then
        s.anchor_x = A[data.anchor]
    else
        s.anchor_x = W / 2
    end

    s.selected = clamp_select_from(tonumber(data.selected_index) or 1, 1)
    s.scroll_target = 0; ensure_visible(); s.scroll_y = s.scroll_target
    s.appear_target = 1
    if not s.open then
        s.open = true; make_timer(); bind_keys(); mp.set_property_native('user-data/menu-open', true)
    end

    if s.mx and s.mx >= 0 then
        local i, where = hit(s.mx, s.my)
        if where == 'panel' and i and s.filtered[i] and s.filtered[i].selectable then s.hover_item = s.filtered[i] end
    end
    start_timer()
end

function Menu.close()
    if not s.open and s.appear_target == 0 then return end
    s.open = false; unbind_keys()
    s.appear_target = 0
    mp.set_property_native('user-data/menu-open', false)
    start_timer()
end

-- ── script-message + observers ───────────────────────────────────────────────
mp.register_script_message('menu-open', function(json)
    local ok, data = pcall(utils.parse_json, json)
    if not ok or type(data) ~= 'table' then
        mp.msg.error('menu.lua: menu-open invalid JSON'); return
    end
    Menu.open(data, nil)
end)
mp.register_script_message('menu-close', function() Menu.close() end)

mp.observe_property('mouse-pos', 'native', function(_, p)
    if not p then return end
    s.mx, s.my = p.x, p.y
    if not s.open then return end
    s.kbd_nav = false -- any mouse movement hands control back to hover
    if p.hover == false then
        s.hover_item = nil; return
    end
    local i, where = hit(p.x, p.y)
    if where == 'panel' and i and s.filtered[i] and s.filtered[i].selectable then
        s.hover_item = s.filtered[i]; s.selected = i
    else
        s.hover_item = nil
    end
end)
mp.observe_property('osd-dimensions', 'native', function(_, v)
    if v and v.w and v.w > 0 then
        s.ow, s.oh = v.w, v.h; if s.open then
            make_timer(); start_timer()
        end
    end
end)

make_timer()
return Menu
