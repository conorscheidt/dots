-- hud.lua — live stats panel (right-side sheet, ASS overlay). Replaces mpv's
-- built-in text stats: shows the whole pipeline (playback, sync/interpolation,
-- drops VO-vs-decode, shaders, color/HDR, cache, audio, subs) with LIVE values +
-- drops/cache/frame-time graphs and expandable per-pass GPU timings. Read-only:
-- runtime A/B toggles live in the settings menu (zmenuflows), not here, to avoid
-- duplicating them. Styling matches osc.lua/menu.lua.
-- Toggle: script-binding hud/toggle (bound to `i` in input.conf). ESC closes.

local assdraw = require("mp.assdraw")
package.path = mp.command_native({ "expand-path", "~~/lib/?.lua" }) .. ";" .. package.path
local draw = require("draw")
local scroll = require("scroll")
local ICON = "Phosphor-Fill"
local FONT = "SF Pro Rounded"

local GLYPH = {
	settings = "\xE2\x89\xB2",
	movie = "\xEE\x9E\x92",
	fast_forward = "\xEE\x9A\xA6",
	bolt = "\xEE\x8B\x9E",
	closed_caption = "\xEE\x86\xA4",
	graphic_eq = "\xEE\xA0\x82",
	download = "\xEE\x88\x8C",
}

local o = {
	panel_w = 410,
	edge_margin = 18,
	right_margin = 14,
	pad_x = 16,
	row_h = 21,
	head_h = 27,
	gap = 6,
	rad = 14,
	pill_rad = 8,
	pill_inset = 3,
	mat = "1C1C1E",
	mat_a = 0.82,
	bord_a = 0.16,
	shadow_a = 0.55,
	divider_a = 0.12,
	label_col = "A8A29E",
	val_col = "FFFFFF",
	good_col = "86EFAC",
	warn_col = "FCA5A5",
	dim_col = "6B6B70",
	chip_col = "8A8A90",
	accent = "FFFFFF",
	hover_lerp = 12,
	fade_ms = 140,
	slide_ms = 150,
	graph_h = 40,
	ring = 90,
	scroll_step = 12,
	scroll_gamma = 0.7,
	scroll_ease = 22, -- see lib/scroll.lua (gamma<1 = slow-finger sensitivity)
}

local s = {
	open = false,
	opacity = 0,
	opacity_target = 0,
	slide = 0,
	slide_target = 0,
	scroll_y = 0,
	scroll_target = 0,
	max_scroll = 0,
	hov = {},
	hover_id = nil,
	zones = {},
	rows = {},
	ow = 0,
	oh = 0,
	sc = 1,
	mx = -1,
	my = -1,
	tprev = 0,
	g_drop = {},
	g_cache = {},
	g_ft = {},
	last_drop = nil,
	passes = {},
	passes_expanded = false,
}
local ov = mp.create_osd_overlay("ass-events")
ov.z = 25
local anim_timer, sample_timer

-- ── helpers ──────────────────────────────────────────────────────────────────
local av, shp, ease = draw.av, draw.shp, draw.ease_out_cubic
local esc = draw.escape
local function tl(x, y, an, str, opt)
	opt = opt or {}
	return string.format(
		"{\\an%d\\pos(%.1f,%.1f)\\fn%s\\fs%.1f%s\\bord0\\shad0\\1c&H%s&\\1a&H%s&%s}%s",
		an,
		x,
		y,
		opt.font or FONT,
		opt.size or 13,
		opt.bold and "\\b1" or "",
		opt.color or o.val_col,
		av(opt.vis or 1),
		opt.clip or "",
		esc(str)
	)
end
local function tw(str, sz) -- rough width (Latin-heavy; fine for value ellipsis)
	return #tostring(str or "") * sz * 0.53
end
local function ellip(str, sz, maxw)
	str = tostring(str or "")
	if tw(str, sz) <= maxw then
		return str
	end
	local keep = math.max(1, math.floor(maxw / (sz * 0.53)) - 1)
	return str:sub(1, keep) .. "…"
end

local function push_ring(buf, v)
	buf[#buf + 1] = v
	if #buf > o.ring then
		table.remove(buf, 1)
	end
end
local function row_height(row)
	local k = row.kind
	if k == "header" or k == "passhead" then
		return o.head_h
	end
	if k == "graph" then
		return o.graph_h + 18
	end
	return o.row_h
end
-- ASS area+line graph from a ring buffer; optional red budget line
local function draw_graph(t, x, y, w, h, buf, col, budget, op, clip)
	local bgp = assdraw.ass_new()
	bgp:append(shp("FFFFFF", op * 0.05, clip))
	bgp:draw_start()
	bgp:round_rect_cw(x, y, x + w, y + h, 4)
	bgp:draw_stop()
	t[#t + 1] = bgp.text
	local n = #buf
	if n < 2 then
		t[#t + 1] =
			tl(x + w / 2, y + h / 2, 5, "collecting…", { size = 10, color = o.dim_col, vis = op * 0.7, clip = clip })
		return
	end
	local mx = budget or 0.0001
	for _, v in ipairs(buf) do
		if v > mx then
			mx = v
		end
	end
	mx = mx * 1.15
	local step = w / (n - 1)
	local function py(i)
		return y + h - (buf[i] / mx) * (h - 2)
	end
	local ar = assdraw.ass_new()
	ar:append(shp(col, op * 0.20, clip))
	ar:draw_start()
	ar:move_to(x, y + h)
	for i = 1, n do
		ar:line_to(x + (i - 1) * step, py(i))
	end
	ar:line_to(x + (n - 1) * step, y + h)
	ar:draw_stop()
	t[#t + 1] = ar.text
	local ln = assdraw.ass_new()
	ln:append(shp(col, op * 0.9, clip))
	ln:draw_start()
	ln:move_to(x, py(1) - 0.6)
	for i = 2, n do
		ln:line_to(x + (i - 1) * step, py(i) - 0.6)
	end
	for i = n, 1, -1 do
		ln:line_to(x + (i - 1) * step, py(i) + 0.6)
	end
	ln:draw_stop()
	t[#t + 1] = ln.text
	if budget then
		local by = y + h - (budget / mx) * (h - 2)
		if by > y and by < y + h then
			local bl = assdraw.ass_new()
			bl:append(shp("FCA5A5", op * 0.45, clip))
			bl:draw_start()
			bl:round_rect_cw(x, by - 0.4, x + w, by + 0.4, 0)
			bl:draw_stop()
			t[#t + 1] = bl.text
		end
	end
end

local function getn(p, d)
	return mp.get_property_number(p, d)
end
local function get(p, d)
	return mp.get_property(p, d)
end
local function getnat(p)
	return mp.get_property_native(p)
end

local fmt_time = draw.fmt
local fmt_speed = draw.fmt_speed

local SHMAP = {
	["ravu%-zoom%-ar%-r3"] = "RAVU-Zoom AR r3 (luma)",
	["ravu%-lite%-ar%-r4"] = "RAVU-Lite AR r4 (luma)",
	["ArtCNN_C4F16"] = "ArtCNN C4F16 (luma)",
	["ArtCNN_C4F32"] = "ArtCNN C4F32 (luma)",
	["CfL_Prediction_Lite"] = "CfL Lite (chroma)",
	["CfL_Prediction"] = "CfL Prediction (chroma)",
	["adaptive%-sharpen"] = "Adaptive Sharpen",
	["SSimDownscaler"] = "SSim Downscale",
	["nlmeans"] = "NLMeans Denoise",
	["CAS"] = "CAS Sharpen",
}
local function friendly_shaders()
	local list = getnat("glsl-shaders") or {}
	if #list == 0 then
		return { "none" }
	end
	local seen, out = {}, {}
	for _, p in ipairs(list) do
		local base = tostring(p):gsub(".*/", ""):gsub("%.%w+$", "")
		local name
		for pat, lbl in pairs(SHMAP) do
			if base:find(pat) then
				name = lbl
				break
			end
		end
		name = name or base
		if not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	return out
end

-- ── build the row list from live properties ──────────────────────────────────
local function push(rows, kind, a, b, c)
	rows[#rows + 1] = { kind = kind, a = a, b = b, c = c }
end
local function build_rows()
	local r = {}
	push(r, "header", "Playback", "movie")
	local vw, vh = getn("video-params/w"), getn("video-params/h")
	local dw, dh = getn("dwidth"), getn("dheight")
	push(r, "stat", "File", ellip(get("media-title") or get("filename") or "—", 12, 220))
	if vw then
		push(r, "stat", "Source", string.format("%d×%d", vw, vh or 0))
	end
	if dw then
		push(r, "stat", "Scaled to", string.format("%d×%d", dw, dh or 0))
	end
	push(r, "stat", "FPS", string.format("%.3g → %.3g", getn("container-fps", 0), getn("estimated-vf-fps", 0)))
	push(r, "stat", "Speed", fmt_speed(getn("speed", 1)))
	push(
		r,
		"stat",
		"Position",
		string.format(
			"%s / %s  (%d%%)",
			fmt_time(getn("playback-time", 0)),
			fmt_time(getn("duration", 0)),
			getn("percent-pos", 0)
		)
	)

	push(r, "header", "Sync / Interpolation", "fast_forward")
	push(r, "stat", "Video sync", get("video-sync") or "—")
	local dsa, it = getnat("display-sync-active"), getnat("interpolation")
	local verdict, vcol = "Off", o.warn_col
	if dsa and it then
		verdict =
			string.format("Active  (%.3g → %.3g Hz)", getn("container-fps", 0), getn("estimated-display-fps", 0))
		vcol = o.good_col
	elseif it then
		verdict = "Inert (audio sync)"
		vcol = o.label_col
	end
	push(r, "stat", "Interpolation", verdict)
	r[#r].bcol = vcol
	push(r, "stat", "tscale", get("tscale") or "—")
	push(r, "stat", "A/V sync", string.format("%+.3f s", getn("avsync", 0)))
	local jit = getn("vsync-jitter", 0)
	push(r, "stat", "Vsync jitter", string.format("%.3f", jit))
	if jit > 0.05 then
		r[#r].bcol = o.warn_col
	end

	push(r, "header", "Frame drops", "bolt")
	local vod = getn("frame-drop-count", 0)
	push(r, "stat", "Dropped (VO)", tostring(vod))
	if vod > 0 then
		r[#r].bcol = o.warn_col
	end
	push(r, "stat", "Dropped (decode)", tostring(getn("decoder-frame-drop-count", 0)))
	push(r, "stat", "Delayed (VO)", tostring(getn("vo-delayed-frame-count", 0)))
	push(r, "stat", "Mistimed", tostring(getn("mistimed-frame-count", 0)))
	r[#r + 1] = { kind = "graph", a = "VO drops / sec", gbuf = s.g_drop, gcol = "FCA5A5" }

	push(r, "header", "Video pipeline", "settings")
	push(r, "stat", "Preset", (getnat("user-data/preset") or "full"):upper())
	push(r, "stat", "HW decoder", get("hwdec-current") or "no")
	push(r, "stat", "VO", get("current-vo") or "—")
	local sh = friendly_shaders()
	push(r, "stat", "Shaders", sh[1] or "none")
	for i = 2, #sh do
		push(r, "stat", "", sh[i])
	end
	push(r, "stat", "Dither", string.format("%s @ %s", get("dither") or "no", get("dither-depth") or "auto"))
	push(
		r,
		"stat",
		"Deband",
		getnat("deband") and string.format("on (%d×/%d)", getn("deband-iterations", 0), getn("deband-threshold", 0))
			or "off"
	)
	-- Render passes (expandable; per-pass GPU timings via vo-passes, live while expanded)
	local ptot = 0
	for _, p in ipairs(s.passes) do
		ptot = ptot + (p.avg or 0)
	end
	r[#r + 1] = { kind = "passhead", a = "Render passes", total = ptot / 1000000, expanded = s.passes_expanded }
	if s.passes_expanded then
		r[#r + 1] = { kind = "stat", a = "", b = "pass  last / avg / peak  µs" }
		r[#r + 1] = {
			kind = "graph",
			a = "Frame time (ms) — red line = vsync budget",
			gbuf = s.g_ft,
			gcol = o.accent,
			budget = 1000 / (getn("estimated-display-fps", 120) or 120),
		}
		if #s.passes == 0 then
			r[#r + 1] = { kind = "stat", a = "", b = "collecting… (needs an active render)" }
		end
		local maxa = 1
		for _, p in ipairs(s.passes) do
			if (p.avg or 0) > maxa then
				maxa = p.avg
			end
		end
		for _, p in ipairs(s.passes) do
			r[#r + 1] = {
				kind = "pass",
				a = p.desc or "?",
				last = p.last or 0,
				avg = p.avg or 0,
				peak = p.peak or 0,
				maxa = maxa,
			}
		end
	end

	push(r, "header", "Color / HDR", "graphic_eq")
	push(
		r,
		"stat",
		"Source",
		string.format("%s / %s", get("video-params/primaries") or "—", get("video-params/gamma") or "—")
	)
	push(r, "stat", "Colormatrix", get("video-params/colormatrix") or "—")
	local dovi = getn("current-tracks/video/dolby-vision-profile")
	if dovi then push(r, "stat", "Dolby Vision", "Profile " .. dovi) end
	push(r, "stat", "Output", string.format("%s / %s", get("video-target-params/primaries") or "—", get("video-target-params/gamma") or "—"))
	push(r, "stat", "Gamut map", get("gamut-mapping-mode") or "—")
	push(r, "stat", "HDR peak detect", getnat("hdr-compute-peak") and "on" or "off")
	push(r, "stat", "Colorspace hint", get("target-colorspace-hint") or "—")
	push(r, "stat", "ICC auto", getnat("icc-profile-auto") and "on" or "off")

	push(r, "header", "Cache", "download")
	push(r, "stat", "Buffered ahead", string.format("%.0f s", getn("demuxer-cache-duration", 0)))
	local cs = getnat("demuxer-cache-state")
	if cs and cs["fw-bytes"] then
		push(r, "stat", "Cached", string.format("%.0f MiB", cs["fw-bytes"] / 1048576))
	end
	push(r, "stat", "Read speed", string.format("%.1f MiB/s", getn("cache-speed", 0) / 1048576))
	r[#r + 1] = { kind = "graph", a = "Buffered ahead (s)", gbuf = s.g_cache, gcol = "86EFAC" }

	push(r, "header", "Audio", "graphic_eq")
	local at = getnat("current-tracks/audio") or {}
	push(r, "stat", "Codec", get("audio-codec-name") or "—")
	push(
		r,
		"stat",
		"Params",
		string.format(
			"%d kHz · %s · %s",
			(getn("audio-params/samplerate", 0)) / 1000,
			get("audio-params/hr-channels") or get("audio-params/channels") or "—",
			get("audio-params/format") or "—"
		)
	)
	push(r, "stat", "Track", string.format("%s [%s]", at.title or "—", at.lang or "—"))
	push(r, "stat", "Output", get("current-ao") or "—")

	push(r, "header", "Subtitles", "closed_caption")
	local st = getnat("current-tracks/sub")
	push(
		r,
		"stat",
		"Track",
		st and string.format("#%s %s [%s]", tostring(st.id or "?"), st.title or "", st.lang or "?") or "off"
	)
	push(r, "stat", "Delay", string.format("%+.1f s", getn("sub-delay", 0)))
	push(r, "stat", "Position", tostring(getn("sub-pos", 0)))

	return r
end

-- ── geometry ─────────────────────────────────────────────────────────────────
local function layout()
	s.sc = (s.oh and s.oh > 0) and (s.oh / 720) or 1
	local W = (s.sc > 0) and (s.ow / s.sc) or 1280
	local pw = math.min(o.panel_w, math.max(200, W - 8))
	local px = W - o.right_margin - pw
	local py = o.edge_margin
	local ph = 720 - o.edge_margin * 2
	local content = 8
	for _, row in ipairs(s.rows) do
		content = content + row_height(row)
	end
	content = content + 8
	s.max_scroll = math.max(0, content - ph)
	return W, px, py, pw, ph, content
end

-- ── render ───────────────────────────────────────────────────────────────────
local function render()
	if not s.oh or s.oh == 0 then
		ov.data = ""
		ov:update()
		return
	end
	if s.opacity <= 0.004 and not s.open then
		ov.data = ""
		ov:update()
		return
	end
	local W, px, py, pw, ph = layout()
	local dx = (1 - ease(s.slide)) * (pw + o.right_margin + 20)
	px = px + dx
	local op = s.opacity
	local t = {}
	s.zones = {}

	local sh = assdraw.ass_new()
	sh:append(shp("000000", op * o.shadow_a, "\\blur8"))
	sh:draw_start()
	sh:round_rect_cw(px - 8, py - 2, px + pw + 8, py + ph + 2, o.rad + 2)
	sh:draw_stop()
	t[#t + 1] = sh.text
	local bg = assdraw.ass_new()
	bg:append(shp(o.mat, op * o.mat_a, "\\blur0.5"))
	bg:draw_start()
	bg:round_rect_cw(px, py, px + pw, py + ph, o.rad)
	bg:draw_stop()
	t[#t + 1] = bg.text
	local spec = assdraw.ass_new()
	spec:append(shp("FFFFFF", op * 0.09, "\\blur1.2"))
	spec:draw_start()
	spec:round_rect_cw(px + 16, py + 1.5, px + pw - 16, py + 3, 0.7)
	spec:draw_stop()
	t[#t + 1] = spec.text
	local bd = assdraw.ass_new()
	bd:append(string.format("{\\pos(0,0)\\an7\\1a&HFF&\\bord1\\3c&HFFFFFF&\\3a&H%s&\\shad0}", av(op * o.bord_a)))
	bd:draw_start()
	bd:round_rect_cw(px, py, px + pw, py + ph, o.rad)
	bd:draw_stop()
	t[#t + 1] = bd.text

	local clip = string.format("\\clip(%.1f,%.1f,%.1f,%.1f)", px, py, px + pw, py + ph)
	local y = py + 8 - s.scroll_y
	local lx, rx = px + o.pad_x, px + pw - o.pad_x
	for _, row in ipairs(s.rows) do
		local rh = row_height(row)
		if y + rh > py and y < py + ph then
			if row.kind == "header" then
				if GLYPH[row.b] then
					t[#t + 1] = tl(
						lx + 7,
						y + rh / 2 + 1,
						5,
						GLYPH[row.b],
						{ font = ICON, size = 14, color = o.label_col, vis = op, clip = clip }
					)
				end
				t[#t + 1] = tl(lx + 20, y + rh / 2 + 1, 4, row.a, { size = 13, bold = true, vis = op, clip = clip })
				local dv = assdraw.ass_new()
				dv:append(shp("FFFFFF", op * o.divider_a, clip))
				dv:draw_start()
				dv:round_rect_cw(lx, y + rh - 3, rx, y + rh - 2, 0.5)
				dv:draw_stop()
				t[#t + 1] = dv.text
			elseif row.kind == "graph" then
				t[#t + 1] = tl(lx, y + 9, 4, row.a, { size = 11, color = o.label_col, vis = op * 0.85, clip = clip })
				draw_graph(t, lx, y + 15, pw - o.pad_x * 2, o.graph_h - 2, row.gbuf, row.gcol, row.budget, op, clip)
			elseif row.kind == "passhead" then
				local hv = s.hov["passhead"] or 0
				if hv > 0.01 then
					local p = assdraw.ass_new()
					p:append(shp("FFFFFF", op * hv * 0.14, clip))
					p:draw_start()
					p:round_rect_cw(
						px + o.pill_inset,
						y + o.pill_inset,
						px + pw - o.pill_inset,
						y + rh - o.pill_inset,
						o.pill_rad
					)
					p:draw_stop()
					t[#t + 1] = p.text
				end
				t[#t + 1] = tl(
					lx,
					y + rh / 2 + 1,
					4,
					(row.expanded and "▾ " or "▸ ") .. row.a,
					{ size = 13, bold = true, vis = op, clip = clip }
				)
				t[#t + 1] = tl(
					rx,
					y + rh / 2 + 1,
					6,
					string.format("%.1f ms", row.total or 0),
					{ size = 12, color = o.label_col, vis = op * 0.9, clip = clip }
				)
				s.zones["passhead"] = { y, y + rh, {
					fire = function()
						s.passes_expanded = not s.passes_expanded
					end,
				} }
			elseif row.kind == "pass" then
				local frac = (row.maxa > 0) and (row.avg / row.maxa) or 0
				local barw = pw - o.pad_x * 2 - 132
				local bar = assdraw.ass_new()
				bar:append(shp("FFFFFF", op * 0.12, clip))
				bar:draw_start()
				bar:round_rect_cw(lx, y + rh / 2 - 7, lx + math.max(2, barw * frac), y + rh / 2 + 7, 3)
				bar:draw_stop()
				t[#t + 1] = bar.text
				t[#t + 1] =
					tl(lx + 6, y + rh / 2, 4, ellip(row.a, 11, barw - 8), { size = 11, vis = op * 0.95, clip = clip })
				t[#t + 1] = tl(
					rx,
					y + rh / 2,
					6,
					string.format(
						"%.0f / %.0f / %.0f",
						(row.last or 0) / 1000,
						(row.avg or 0) / 1000,
						(row.peak or 0) / 1000
					),
					{ size = 11, color = o.label_col, vis = op * 0.9, clip = clip }
				)
			else -- stat
				if row.a ~= "" then
					t[#t + 1] =
						tl(lx, y + rh / 2, 4, row.a, { size = 12, color = o.label_col, vis = op * 0.9, clip = clip })
				end
				t[#t + 1] = tl(
					rx,
					y + rh / 2,
					6,
					ellip(row.b, 13, pw - 130),
					{ size = 13, color = row.bcol or o.val_col, vis = op, clip = clip }
				)
			end
		end
		y = y + rh
	end

	if s.max_scroll > 0.5 then
		local ty = py + ph * (s.scroll_y / s.max_scroll) * (1 - 0.2)
		local th = ph * 0.2
		local tb = assdraw.ass_new()
		tb:append(shp("FFFFFF", op * 0.18))
		tb:draw_start()
		tb:round_rect_cw(px + pw - 3, ty, px + pw - 1, ty + th, 1)
		tb:draw_stop()
		t[#t + 1] = tb.text
	end

	ov.res_x = math.floor(W)
	ov.res_y = 720
	ov.data = table.concat(t, "\n")
	ov:update()
end

-- ── timers ───────────────────────────────────────────────────────────────────
local function anim()
	local now = mp.get_time()
	local dt = math.min(0.05, now - ((s.tprev > 0) and s.tprev or now))
	s.tprev = now
	local fr = 1000 / o.fade_ms
	if s.opacity < s.opacity_target then
		s.opacity = math.min(s.opacity_target, s.opacity + fr * dt)
	elseif s.opacity > s.opacity_target then
		s.opacity = math.max(s.opacity_target, s.opacity - fr * dt)
	end
	local sr = 1000 / o.slide_ms
	if s.slide < s.slide_target then
		s.slide = math.min(s.slide_target, s.slide + sr * dt)
	elseif s.slide > s.slide_target then
		s.slide = math.max(s.slide_target, s.slide - sr * dt)
	end
	local scrolling
	s.scroll_y, scrolling = scroll.approach(s.scroll_y, s.scroll_target, dt, o.scroll_ease)
	local moving = math.abs(s.opacity - s.opacity_target) > 0.004
		or math.abs(s.slide - s.slide_target) > 0.004
		or scrolling
	for id, _ in pairs(s.hov) do
		local tgt = (s.hover_id == id) and 1 or 0
		local cur = s.hov[id]
		cur = cur + (tgt - cur) * math.min(1, dt * o.hover_lerp)
		if math.abs(cur - tgt) < 0.004 then
			cur = tgt
		end
		s.hov[id] = cur
		if cur ~= tgt then
			moving = true
		end
	end
	if s.hover_id and s.hov[s.hover_id] == nil then
		s.hov[s.hover_id] = 0
	end
	render()
	-- kill the 60Hz loop as soon as transitions/hover settle; the 4Hz sampler
	-- then drives value updates (was pinned at 60Hz while open = the frame drops).
	if not moving then
		if anim_timer then
			anim_timer:kill()
		end
		s.tprev = 0
		if (not s.open) and s.opacity <= 0.004 then
			ov.data = ""
			ov:update()
		end
	end
end
local function start_anim()
	if anim_timer and not anim_timer:is_enabled() then
		s.tprev = mp.get_time()
		anim_timer:resume()
	end
end

local function sample()
	if not s.open then
		return
	end
	local dc = getn("frame-drop-count", 0)
	if s.last_drop then
		push_ring(s.g_drop, math.max(0, (dc - s.last_drop) * 4))
	end
	s.last_drop = dc
	push_ring(s.g_cache, getn("demuxer-cache-duration", 0))
	if s.passes_expanded then
		local vp = getnat("vo-passes")
		s.passes = (vp and vp.fresh) or {}
		local tot = 0
		for _, p in ipairs(s.passes) do
			tot = tot + (p.avg or 0)
		end
		push_ring(s.g_ft, tot / 1000000)
	end
	s.rows = build_rows()
	layout()
	s.scroll_target = scroll.clamp(s.scroll_target, 0, s.max_scroll)
	s.scroll_y = scroll.clamp(s.scroll_y, 0, s.max_scroll)
	render()
end

-- ── input ────────────────────────────────────────────────────────────────────
local function hit(mx, my)
	if not s.open or not s.sc or s.sc == 0 then
		return nil
	end
	local cy = my / s.sc
	local cx = mx / s.sc
	local _, px, py, pw, ph = layout()
	if cx < px or cx > px + pw or cy < py or cy > py + ph then
		return "outside"
	end
	for id, z in pairs(s.zones) do
		if cy >= z[1] and cy <= z[2] then
			return id
		end
	end
	return "panel"
end

local function bind_keys()
	mp.add_forced_key_binding("ESC", "hud-esc", function()
		Hud_close()
	end)
	mp.add_forced_key_binding("MBTN_LEFT", "hud-click", function()
		local h = hit(s.mx, s.my)
		if h == "outside" then
			Hud_close()
			return
		end
		local z = h and s.zones[h]
		if z and z[3] then
			z[3].fire()
			mp.add_timeout(0.03, sample)
		end
	end)
	-- complex bindings expose info.scale (fractional on high-res touchpads);
	-- gamma-shaped by scroll.gain so slow finger movement still registers.
	local function on_wheel(dir, info)
		if info.event == "up" or info.canceled then
			return
		end
		s.scroll_target =
			scroll.clamp(s.scroll_target + scroll.gain(dir, info.scale, o.scroll_step, o.scroll_gamma), 0, s.max_scroll)
		start_anim()
	end
	mp.add_forced_key_binding("WHEEL_UP", "hud-wu", function(i)
		on_wheel(-1, i)
	end, { complex = true })
	mp.add_forced_key_binding("WHEEL_DOWN", "hud-wd", function(i)
		on_wheel(1, i)
	end, { complex = true })
end
local function unbind_keys()
	for _, n in ipairs({ "hud-esc", "hud-click", "hud-wu", "hud-wd" }) do
		mp.remove_key_binding(n)
	end
end

-- ── open / close ─────────────────────────────────────────────────────────────
function Hud_open()
	if s.open then
		return
	end
	s.open = true
	s.opacity_target = 1
	s.slide_target = 1
	s.scroll_target = 0
	s.scroll_y = 0
	s.rows = build_rows()
	bind_keys()
	if sample_timer then
		sample_timer:kill()
	end
	sample_timer = mp.add_periodic_timer(0.25, sample)
	start_anim()
end
function Hud_close()
	if not s.open then
		return
	end
	s.open = false
	s.opacity_target = 0
	s.slide_target = 0
	unbind_keys()
	if sample_timer then
		sample_timer:kill()
		sample_timer = nil
	end
	start_anim()
end

local function anim_hz()
	local f = mp.get_property_number("display-fps", 120) or 120
	return 1 / math.max(60, math.min(240, f))
end
anim_timer = mp.add_periodic_timer(anim_hz(), anim)
anim_timer:kill()

mp.add_key_binding(nil, "toggle", function()
	if s.open then
		Hud_close()
	else
		Hud_open()
	end
end)
mp.observe_property("osd-dimensions", "native", function(_, v)
	if v and v.w and v.w > 0 then
		s.ow, s.oh = v.w, v.h
	end
end)
mp.observe_property("mouse-pos", "native", function(_, p)
	if not p or not s.open then
		return
	end
	s.mx, s.my = p.x, p.y
	local h = (p.hover ~= false) and hit(p.x, p.y) or nil
	s.hover_id = (h and s.zones[h]) and h or nil
	start_anim()
end)
