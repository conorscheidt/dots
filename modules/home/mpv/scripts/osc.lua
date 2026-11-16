-- osc.lua — bespoke macOS OSC. Full-width floating bar, FLEX timeline.
-- Transport sits left of the flexible timeline. Tracks and display controls
-- are grouped on the right. uosc OSC is disabled at source.
-- Animated: eased reveal (slide+fade), hover scale/brighten, momentum-free bar.

local assdraw = require("mp.assdraw")
package.path = mp.command_native({ "expand-path", "~~/lib/?.lua" }) .. ";" .. package.path
local draw = require("draw")
local ICON = "Phosphor-Fill" -- filled Phosphor (hover / active state)
local ACCENT = "FFFFFF" -- monochrome (progress / knob / active glow)
-- Phosphor icon codepoints (PUA). Rendered as font glyphs: crisp at any DPI,
-- immune to macOS font-fallback, zero hand geometry.
local GLYPH = {
	play_arrow = "\xEE\x8F\x90",
	pause = "\xEE\x8E\x9E",
	skip_previous = "\xEE\x96\xA4",
	skip_next = "\xEE\x96\xA6",
	fast_forward = "\xEE\x9A\xA6",
	bolt = "\xEE\x8B\x9E",
	eco = "\xEE\x8B\x9A",
	closed_caption = "\xEE\x86\xA4",
	graphic_eq = "\xEE\xA0\x82",
	download = "\xEE\x88\x8C",
	folder_open = "\xEE\x89\x96",
	folder = "\xEE\x89\x8A",
	fullscreen = "\xEE\x82\xA6",
	fullscreen_exit = "\xEE\x82\x9E",
	settings = "\xE2\x89\xB2",
	check = "\xEE\x86\x82",
	arrow_upward = "\xEE\x82\x8E",
	movie = "\xEE\x9E\x92",
	sliders = "\xEE\x89\xB2",
}

local o = {
	-- CONCENTRIC CORNERS: pill (30 tall, r10) is inset (46-30)/2 = 8 from the
	-- bar edge, so bar_r = pill_r + 8 = 18 makes the end pills nest exactly
	-- inside the bar corners (shared corner-center). pad=6 lines the outer end
	-- pills up flush so the nesting is symmetric on both ends.
	h = 46,
	mx = 40,
	mb = 26,
	rad = 18,
	pad = 6,
	islot = 34,
	sgap = 12, -- gap on either side of the timeline
	mat = "1C1C1E",
	mat_a = 0.74,
	pill_r = 10,
	hide = 1.0,
	reveal_spd = 6.5,
	hover_spd = 10.0,
}

local s = {
	a = 0,
	last = 0,
	last_render = 0,
	redraw = true,
	hover = nil,
	tl_frac = nil,
	timeline_scroll = 0,
	hov = {},
	pause = false,
	preset = "full",
	fs = false,
	dur = 0,
	pos = 0,
	chapters = {},
	ow = 0,
	oh = 0,
	sc = 1,
	mx = -1,
	my = -1,
	thumb = nil,
	thumb_request = nil,
	zones = {},
	tprev = 0,
	anchor_key = "",
	menu_open = false,
}
local ov = mp.create_osd_overlay("ass-events")
local TIP = {
	prev = "Previous",
	play = "Play / pause",
	next = "Next",
	preset = "Switch Full / Eco",
	skip = "Auto-skip intro",
	subs = "Subtitles",
	audio = "Audio track",
	browse = "Open file",
	settings = "Settings",
	fs = "Fullscreen",
}

local function left_seq(compact)
	local play = { "play", "icon", s.pause and "play_arrow" or "pause", 22 }
	if compact then return { play } end
	return {
		{ "browse", "icon", "folder_open", 20 },
		{ "prev", "icon", "skip_previous", 21 },
		play,
		{ "next", "icon", "skip_next", 21 },
	}
end

local function right_seq(compact)
	local track_audio = { "audio", "icon", "graphic_eq", 20, 34 }
	local track_subs = { "subs", "icon", "closed_caption", 21, 34 }
	local settings = { "settings", "icon", "sliders", 20, 34 }
	local fullscreen = { "fs", "icon", s.fs and "fullscreen_exit" or "fullscreen", 20, 34 }
	if compact then return { track_audio, track_subs, settings, fullscreen } end
	local skip = (mp.get_property_native("user-data/autoskip_mode") or "off") ~= "off"
	return {
		{ "time", "time", nil, 100 },
		{ "skip", "icon", "fast_forward", 20, 34, skip },
		{ "tracks-divider", "div", nil, 16 },
		track_audio,
		track_subs,
		{ "display-divider", "div", nil, 16 },
		{ "preset", "text", s.preset == "eco" and "Eco" or "Full", 42 },
		settings,
		fullscreen,
	}
end

local av, rr, shp, fmt = draw.av, draw.rr, draw.shp, draw.fmt

local function rwidth(g)
	return g[5] or g[4] or o.islot
end

local function geo()
	s.sc = s.oh / 720
	local W = s.ow / s.sc
	local compact = W < 650
	local margin = math.min(o.mx, W * 0.05)
	local ax, bx = margin, W - margin
	local slide = (1 - s.a) * 12
	local ay = 720 - o.mb - o.h + slide
	local by = ay + o.h
	local left, right = left_seq(compact), right_seq(compact)
	local lw = #left * o.islot
	local rw = 0
	for _, g in ipairs(right) do
		rw = rw + rwidth(g)
	end
	local tl_ax = ax + o.pad + (lw > 0 and (lw + o.sgap) or 0)
	local tl_bx = bx - o.pad - rw - o.sgap
	return W, ax, ay, bx, by, tl_ax, math.max(tl_ax + 1, tl_bx), left, right
end

local function hit(mx, my)
	if s.oh == 0 or s.a < 0.1 then
		return nil, nil
	end
	local _, ax, ay, bx, by = geo()
	local cx, cy = mx / s.sc, my / s.sc
	if cx < ax or cx > bx or cy < ay - 4 or cy > by then
		return nil, nil
	end
	for id, z in pairs(s.zones) do
		if cx >= z[1] and cx <= z[2] then
			return id, (id == "tl") and ((cx - z[1]) / (z[2] - z[1])) or nil
		end
	end
	return "bar", nil
end

local function render()
	if s.oh == 0 or s.a < 0.004 then
		ov.data = ""
		ov:update()
		return
	end
	local W, ax, ay, bx, _, tl_ax, tl_bx, left, right = geo()
	local iw = bx - ax
	local cy = ay + o.h / 2
	local t = {}
	s.zones = {}
	s.tip = nil

	-- material: shadow (below only), body, hairline border. NO specular line.
	local sh = assdraw.ass_new()
	sh:append(shp("000000", s.a * 0.5, "\\blur7"))
	sh:draw_start()
	rr(sh, ax, ay + 5, iw, o.h, o.rad + 2)
	sh:draw_stop()
	t[#t + 1] = sh.text
	local bg = assdraw.ass_new()
	bg:append(shp(o.mat, s.a * o.mat_a, "\\blur0.5"))
	bg:draw_start()
	rr(bg, ax, ay, iw, o.h, o.rad)
	bg:draw_stop()
	t[#t + 1] = bg.text
	local spec = assdraw.ass_new()
	spec:append(shp("FFFFFF", s.a * 0.10, "\\blur1.2"))
	spec:draw_start()
	rr(spec, ax + 14, ay + 1, iw - 28, 1.4, 0.7)
	spec:draw_stop()
	t[#t + 1] = spec.text
	local bd = assdraw.ass_new()
	bd:append(string.format("{\\pos(0,0)\\an7\\1a&HFF&\\bord1\\3c&HFFFFFF&\\3a&H%s&\\shad0}", av(s.a * 0.14)))
	bd:draw_start()
	rr(bd, ax, ay, iw, o.h, o.rad)
	bd:draw_stop()
	t[#t + 1] = bd.text

	local function hpill(cx, w, hv, col)
		if hv > 0.01 then
			local p = assdraw.ass_new()
			p:append(shp(col or "FFFFFF", s.a * hv * 0.15))
			p:draw_start()
			rr(p, cx - w / 2, cy - 15, w, 30, o.pill_r)
			p:draw_stop()
			t[#t + 1] = p.text
		end
	end
	local function icon(cx, sz, g, hv, active)
		-- CONSISTENT across all glyphs: solid Fill, scale + brighten on hover;
		-- active toggles stay fully bright. (Dropped the outline->fill morph — it
		-- was inconsistent because some Phosphor glyphs lack a distinct fill.)
		local gl = GLYPH[g] or "\xEE\x93\xB6"
		local a = s.a * (active and 1.0 or (0.72 + 0.28 * hv))
		t[#t + 1] = string.format(
			"{\\an5\\pos(%.1f,%.1f)\\fn%s\\fs%.1f\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%s&}%s",
			cx,
			cy,
			ICON,
			sz * (1 + 0.14 * hv),
			av(a),
			gl
		)
	end
	local function label(cx, str, sz, v, col, an, b)
		t[#t + 1] = string.format(
			"{\\an%d\\pos(%.1f,%.1f)\\fnHelvetica Neue\\fs%.1f%s\\bord0\\shad0\\1c&H%s&\\1a&H%s&}%s",
			an or 5,
			cx,
			cy,
			sz,
			b and "\\b1" or "",
			col or "FFFFFF",
			av(v),
			str
		)
	end

	-- LEFT cluster
	local x = ax + o.pad
	for _, g in ipairs(left) do
		local id, hv = g[1], s.hov[g[1]] or 0
		local mid = x + o.islot / 2
		icon(mid, g[4], g[3], hv)
		s.zones[id] = { x, x + o.islot }
		if TIP[id] and hv > 0.5 then
			s.tip = { mid, TIP[id] }
		end
		x = x + o.islot
	end

	-- TIMELINE (flex)
	do
		local tw = tl_bx - tl_ax
		local eh = s.hov.tl or 0
		local th = 4 + 3 * eh
		local ty = cy - th / 2
		local frac = s.dur > 0 and math.min(1, s.pos / s.dur) or 0
		local trk = assdraw.ass_new()
		trk:append(shp("FFFFFF", s.a * 0.24))
		trk:draw_start()
		rr(trk, tl_ax, ty, tw, th, th / 2)
		trk:draw_stop()
		t[#t + 1] = trk.text
		-- auto-skip highlight: band over the region that gets skipped — manual =
		-- 0..length from the start; chapter = the chosen segment's own span.
		local askmode = mp.get_property_native("user-data/autoskip_mode") or "off"
		if s.dur > 0 and askmode ~= "off" then
			local bstart, bend = 0, 0
			if askmode == "manual" then
				bend = mp.get_property_native("user-data/intro_skip") or 0
			elseif askmode == "chapter" then
				local want = mp.get_property_native("user-data/autoskip_chapter")
				for i, c in ipairs(s.chapters) do
					if c.title == want then
						bstart = c.time or 0
						local nxt = s.chapters[i + 1]
						bend = nxt and nxt.time or s.dur
						break
					end
				end
			end
			if bend - bstart > 1 then
				local bx = tl_ax + tw * math.min(1, bstart / s.dur)
				local bw = tw * math.min(1, (bend - bstart) / s.dur)
				local sb = assdraw.ass_new()
				sb:append(shp("0A9FFF", s.a * 0.55))
				sb:draw_start()
				rr(sb, bx, ty, bw, th, th / 2)
				sb:draw_stop()
				t[#t + 1] = sb.text
			end
		end
		local pr = assdraw.ass_new()
		pr:append(shp(ACCENT, s.a * 0.96))
		pr:draw_start()
		rr(pr, tl_ax, ty, math.max(th, tw * frac), th, th / 2)
		pr:draw_stop()
		t[#t + 1] = pr.text
		-- segment marks across the FULL track (notches punched over track+progress)
		if s.dur > 0 and #s.chapters > 0 then
			local mk = assdraw.ass_new()
			mk:append(shp(o.mat, s.a * 0.85))
			mk:draw_start()
			for _, c in ipairs(s.chapters) do
				if c.time > 1 then
					local ccx = tl_ax + tw * math.min(1, c.time / s.dur)
					rr(mk, ccx - 1.2, ty - 1, 2.4, th + 2, 1)
				end
			end
			mk:draw_stop()
			t[#t + 1] = mk.text
		end
		if eh > 0.05 then
			local kx = tl_ax + tw * frac
			local kn = assdraw.ass_new()
			kn:append(shp(ACCENT, s.a * eh))
			kn:draw_start()
			rr(kn, kx - 6, ty + th / 2 - 6, 12, 12, 6)
			kn:draw_stop()
			t[#t + 1] = kn.text
		end
		s.zones.tl = { tl_ax, tl_bx }
		if s.hover == "tl" and s.tl_frac and s.dur > 0 then
			local hf = math.max(0, math.min(1, s.tl_frac))
			local hx = tl_ax + tw * hf
			local htime = s.dur * hf
			-- highlight the hovered chapter's span on the track (duration indicator)
			if #s.chapters > 0 then
				local ci
				for i = #s.chapters, 1, -1 do
					if htime >= (s.chapters[i].time or 0) then
						ci = i
						break
					end
				end
				if ci then
					local c0 = s.chapters[ci].time or 0
					local c1 = s.chapters[ci + 1] and s.chapters[ci + 1].time or s.dur
					local hl = assdraw.ass_new()
					hl:append(shp("FFFFFF", s.a * 0.13))
					hl:draw_start()
					rr(hl, tl_ax + tw * (c0 / s.dur), ty - 1, tw * ((c1 - c0) / s.dur), th + 2, th / 2)
					hl:draw_stop()
					t[#t + 1] = hl.text
				end
			end
			-- stack above the timeline: thumbnail (top), chapter title, time (bottom)
			t[#t + 1] = string.format(
				"{\\an2\\pos(%.1f,%.1f)\\fnHelvetica Neue\\fs12\\b1\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%s&}%s",
				hx,
				ay - 8,
				av(s.a),
				fmt(htime)
			)
			if #s.chapters > 0 then
				local title
				for i = #s.chapters, 1, -1 do
					local c = s.chapters[i]
					if htime >= (c.time or 0) then
						title = c.title
						break
					end
				end
				if title and title ~= "" then
					title = draw.escape(title)
					local tw2 = #title * 6.6 + 20
					local px2 = math.max(o.mx, math.min(W - o.mx - tw2, hx - tw2 / 2))
					local cb = assdraw.ass_new()
					cb:append(shp(o.mat, s.a * 0.92))
					cb:draw_start()
					rr(cb, px2, ay - 38, tw2, 17, 6)
					cb:draw_stop()
					t[#t + 1] = cb.text
					t[#t + 1] = string.format(
						"{\\an5\\pos(%.1f,%.1f)\\fnHelvetica Neue\\fs11\\b1\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%s&}%s",
						px2 + tw2 / 2,
						ay - 30,
						av(s.a),
						title
					)
				end
			end
			if s.thumb and not s.thumb.disabled then
				local x = math.max(0, math.min(s.ow - s.thumb.width, math.floor(hx * s.sc - s.thumb.width / 2)))
				local y = math.max(0, math.floor((ay - 44) * s.sc - s.thumb.height))
				local request = string.format("%.2f:%d:%d", htime, x, y)
				if request ~= s.thumb_request then
					s.thumb_request = request
					mp.commandv("script-message-to", "thumbfast", "thumb", htime, x, y)
				end
			end
		elseif s.thumb_request then
			s.thumb_request = nil
			mp.commandv("script-message-to", "thumbfast", "clear")
		end
	end

	-- RIGHT cluster
	x = tl_bx + o.sgap
	for _, g in ipairs(right) do
		local id, kind, w = g[1], g[2], rwidth(g)
		local hv = s.hov[id] or 0
		local mid = x + w / 2
		if kind == "icon" then
			icon(mid, g[4], g[3], hv, g[6])
			s.zones[id] = { x, x + w }
			if id == "skip" then
				-- tiny label under the icon = current skip target: the M:SS manual
				-- length, or the chosen chapter's name (like the sub-picker shows).
				local am = mp.get_property_native("user-data/autoskip_mode") or "off"
				local lbl, tip
				if am == "manual" then
					local sk = mp.get_property_native("user-data/intro_skip") or 0
					lbl = fmt(sk)
					tip = "Auto-skip: manual " .. fmt(sk)
				elseif am == "chapter" then
					lbl = mp.get_property_native("user-data/autoskip_chapter") or ""
					tip = "Auto-skip: " .. lbl
					if #lbl > 9 then
						lbl = lbl:sub(1, 8) .. "…"
					end
				else
					tip = "Auto-skip: off"
				end
				if lbl and lbl ~= "" then
					t[#t + 1] = string.format(
						"{\\an8\\pos(%.1f,%.1f)\\fnHelvetica Neue\\fs8\\b1\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%s&}%s",
						mid,
						cy + 8,
						av(s.a * 0.8),
						lbl
					)
				end
				if hv > 0.5 then
					s.tip = { mid, tip }
				end
			elseif TIP[id] and hv > 0.5 then
				s.tip = { mid, TIP[id] }
			end
		elseif kind == "text" then
			hpill(mid, w - 4, hv)
			label(mid, g[3], 12, s.a * (0.82 + 0.18 * hv), "FFFFFF", 5, true)
			s.zones[id] = { x, x + w }
			if TIP[id] and hv > 0.5 then
				s.tip = { mid, TIP[id] }
			end
		elseif kind == "time" then
			label(mid, fmt(s.pos) .. " / " .. fmt(s.dur), 12, s.a * 0.82, "A8A29E", 5, false)
		elseif kind == "div" then
			local dv = assdraw.ass_new()
			dv:append(shp("FFFFFF", s.a * 0.12))
			dv:draw_start()
			rr(dv, x + w / 2 - 0.5, cy - 9, 1, 18, 0.5)
			dv:draw_stop()
			t[#t + 1] = dv.text

		end
		x = x + w
	end

	if s.tip then
		local tx, txt = s.tip[1], s.tip[2]
		local tw2 = #txt * 6.6 + 16
		tx = math.max(tw2 / 2 + 8, math.min(W - tw2 / 2 - 8, tx))
		local ty2 = ay - 30
		local tb = assdraw.ass_new()
		tb:append(shp(o.mat, s.a * 0.94))
		tb:draw_start()
		rr(tb, tx - tw2 / 2, ty2, tw2, 22, 7)
		tb:draw_stop()
		t[#t + 1] = tb.text
		t[#t + 1] = string.format(
			"{\\an5\\pos(%.1f,%.1f)\\fnHelvetica Neue\\fs12\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%s&}%s",
			tx,
			ty2 + 11,
			av(s.a),
			txt
		)
	end
	-- publish button anchors + resting bar-top for the popup menu (only on change)
	do
		local a = { bar_top = 720 - o.mb - o.h }
		for _, id in ipairs({ "subs", "audio", "browse", "settings", "skip", "preset", "fs" }) do
			local z = s.zones[id]
			if z then
				a[id] = (z[1] + z[2]) / 2
			end
		end
		local key = string.format("%.0f:%.0f", W, a.subs or 0)
		if key ~= s.anchor_key then
			s.anchor_key = key
			mp.set_property_native("user-data/osc-anchors", a)
		end
	end
	ov.res_x = math.floor(s.ow / s.sc)
	ov.res_y = 720
	ov.data = table.concat(t, "\n")
	ov:update()
end

local timer
local function anim()
	local now = mp.get_time()
	local dt = math.min(0.05, now - (s.tprev > 0 and s.tprev or now))
	s.tprev = now
	local vis = s.pause or s.hover ~= nil or s.menu_open or (now - s.last < o.hide)
	local at = vis and 1 or 0
	s.a = s.a + (at - s.a) * math.min(1, dt * o.reveal_spd)
	if math.abs(s.a - at) < 0.004 then
		s.a = at
	end
	local moving = math.abs(s.a - at) > 0.004
	for _, id in ipairs({
		"prev",
		"play",
		"next",
		"tl",
		"time",
		"preset",
		"skip",
		"subs",
		"audio",
		"browse",
		"settings",
		"fs",
	}) do
		local tgt = (s.hover == id) and 1 or 0
		local cur = s.hov[id] or 0
		cur = cur + (tgt - cur) * math.min(1, dt * o.hover_spd)
		if math.abs(cur - tgt) < 0.004 then
			cur = tgt
		end
		s.hov[id] = cur
		if cur ~= tgt then
			moving = true
		end
	end
	if moving or s.redraw or s.a == 0 or (not s.pause and now - s.last_render >= 1 / 20) then
		render()
		s.last_render = now
		s.redraw = false
	end
	if not moving and (s.a == 0 or (s.pause and not s.hover and not s.menu_open)) then
		timer:kill()
		s.tprev = 0
		if s.thumb_request then
			s.thumb_request = nil
			mp.commandv("script-message-to", "thumbfast", "clear")
		end
	end
end
timer = mp.add_periodic_timer(1 / 60, anim)
timer:kill()
local function poke()
	s.last = mp.get_time()
	s.redraw = true
	if timer:is_enabled() == false then
		s.tprev = mp.get_time()
		timer:resume()
	end
end

mp.observe_property("mouse-pos", "native", function(_, p)
	if not p then
		return
	end
	s.mx, s.my = p.x, p.y
	if p.hover == false then
		s.last = 0
		s.hover = nil
		s.tl_frac = nil
		s.timeline_scroll = 0
		return
	end
	local id, frac = hit(p.x, p.y)
	s.hover = id
	if id ~= "tl" then s.timeline_scroll = 0 end
	-- reveal ONLY when the cursor is near the bar (bottom band) or on an element
	-- (previously any movement anywhere flashed the bar).
	local cy = p.y / (s.sc > 0 and s.sc or 1)
	if id ~= nil or cy >= (720 - o.mb - o.h - 76) then
		poke()
	end
	if id == "tl" and frac and s.dur > 0 then
		-- magnetic hover: snap the hovered position onto a nearby chapter mark
		local target = s.dur * math.max(0, math.min(1, frac))
		local win = math.max(4, s.dur * 0.01)
		for _, c in ipairs(s.chapters) do
			if c.time > 1 and math.abs(c.time - target) < win then
				frac = c.time / s.dur
				break
			end
		end
	end
	s.tl_frac = (id == "tl") and frac or nil
end)

local ACT = {
	prev = function()
		mp.command("playlist-prev")
	end,
	next = function()
		mp.command("playlist-next")
	end,
	play = function()
		mp.command("cycle pause")
	end,
	b10 = function()
		mp.command("no-osd seek -10 relative+keyframes")
	end,
	f10 = function()
		mp.command("no-osd seek 10 relative+keyframes")
	end,
	subs = function()
		mp.command("script-binding zmenuflows/subs")
	end,
	audio = function()
		mp.command("script-binding zmenuflows/audio")
	end,
	fs = function()
		mp.command("cycle fullscreen")
	end,
	browse = function()
		mp.command("script-binding zmenuflows/browse")
	end,
	preset = function()
		mp.command("script-binding prefs/cycle-preset")
	end,
	settings = function()
		mp.command("script-binding zmenuflows/settings")
	end,
	skip = function()
		mp.command("script-binding zmenuflows/autoskip")
	end, -- Off / Manual / chapter list

}
mp.add_forced_key_binding("MBTN_LEFT", "osc-click", function()
	if s.menu_open then return end
	-- Seek once on click using the same chapter snap as the preview.
	local id, frac = hit(s.mx, s.my)
	if id == "tl" and s.dur > 0 then
		local f = s.tl_frac or frac or 0
		mp.commandv("seek", s.dur * math.max(0, math.min(1, f)), "absolute+exact")
	elseif id and ACT[id] then
		ACT[id]()
	end
	poke()
end)
local function scroll_timeline(direction, event)
	if s.menu_open or hit(s.mx, s.my) ~= "tl" then return end
	s.timeline_scroll = s.timeline_scroll + direction * math.abs(event.scale or 1)
	local steps = math.floor(math.abs(s.timeline_scroll))
	if steps == 0 then return end
	if s.timeline_scroll < 0 then steps = -steps end
	s.timeline_scroll = s.timeline_scroll - steps
	mp.commandv("no-osd", "seek", steps * 10, "relative+keyframes")
end
mp.add_forced_key_binding("WHEEL_UP", "osc-wu", function(event)
	scroll_timeline(1, event)
end, { complex = true })
mp.add_forced_key_binding("WHEEL_DOWN", "osc-wd", function(event)
	scroll_timeline(-1, event)
end, { complex = true })

mp.observe_property("pause", "bool", function(_, v)
	s.pause = v or false
	poke()
end)
mp.observe_property("fullscreen", "bool", function(_, v)
	s.fs = v or false
	poke()
end)
mp.observe_property("duration", "number", function(_, v)
	s.dur = v or 0
	s.redraw = true
end)
mp.observe_property("time-pos", "number", function(_, v)
	s.pos = v or 0
	if s.pause and s.a > 0 then poke() end
end)
mp.observe_property("chapter-list", "native", function(_, v)
	s.chapters = v or {}
	s.redraw = true
end)
mp.observe_property("user-data/preset", "native", function(_, v)
	s.preset = v or "full"
	poke()
end)
mp.observe_property("user-data/menu-open", "bool", function(_, v)
	s.menu_open = v or false
	poke()
end)
mp.observe_property("osd-dimensions", "native", function(_, v)
	if v and v.w and v.w > 0 then
		s.ow, s.oh = v.w, v.h
		s.redraw = true
	end
end)
mp.register_event("start-file", function()
	s.thumb_request = nil
	s.redraw = true
end)
mp.register_script_message("thumbfast-info", function(j)
	local d = require("mp.utils").parse_json(j)
	if d then
		s.thumb = d
	end
end)
