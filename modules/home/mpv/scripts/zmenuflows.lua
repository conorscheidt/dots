-- zmenuflows.lua — wires bespoke menu.lua to real flows via script-messages
-- (mpv scripts are sandboxed; no shared globals). Each menu item's `value`
-- carries an {act=...} tag so the single menu-result handler can dispatch.
local utils = require("mp.utils")
package.path = mp.command_native({ "expand-path", "~~/lib/?.lua" }) .. ";" .. package.path
local draw = require("draw")
local fmt_t = draw.fmt -- shared m:ss formatter + parse_t (no dup)

local function track_menu(kind)
	local want = (kind == "sub") and "sub" or "audio"
	local prop = (kind == "sub") and "sid" or "aid"
	local cur = mp.get_property_number(prop)
	local items = {
		{
			title = "Off",
			icon = "block",
			value = { act = "track", prop = prop, id = false },
			selectable = true,
			active = (cur == nil),
		},
	}
	if kind == "sub" then
		items[#items + 1] =
			{ title = "Load from file…", icon = "folder_open", value = { act = "loadsub" }, selectable = true }
		items[#items + 1] =
			{ title = "Search OpenSubtitles…", icon = "download", value = { act = "searchsub" }, selectable = true }
	end
	for _, tr in ipairs(mp.get_property_native("track-list", {})) do
		if tr.type == want then
			local title = tr.title or tr.lang or ("Track " .. tr.id)
			local bits = {}
			if tr.lang then
				bits[#bits + 1] = tr.lang
			end
			if tr.codec then
				bits[#bits + 1] = tr.codec
			end
			items[#items + 1] = {
				title = title,
				hint = table.concat(bits, " · "),
				icon = (kind == "sub") and "subtitles" or "graphic_eq",
				value = { act = "track", prop = prop, id = tr.id },
				selectable = true,
				active = (tr.id == cur),
			}
		end
	end
	mp.commandv(
		"script-message",
		"menu-open",
		utils.format_json({
			title = (kind == "sub") and "Subtitles" or "Audio",
			items = items,
			anchor = (kind == "sub") and "subs" or "audio",
		})
	)
end

mp.add_key_binding(nil, "subs", function()
	track_menu("sub")
end)
mp.add_key_binding(nil, "audio", function()
	track_menu("audio")
end)

-- ── chapters + playlist popups (bespoke; replace uosc/chapters, uosc/playlist) ──
local function chapters_menu()
	local ch = mp.get_property_native("chapter-list", {})
	if #ch == 0 then
		mp.osd_message("No chapters", 1.4)
		return
	end
	local cur = mp.get_property_number("chapter", -1) or -1
	local items = {}
	for i, c in ipairs(ch) do
		items[#items + 1] = {
			title = (c.title and c.title ~= "") and c.title or ("Chapter " .. i),
			hint = fmt_t(c.time),
			icon = "list",
			value = { act = "chapter", index = i - 1 },
			selectable = true,
			active = (i - 1 == cur),
		}
	end
	mp.commandv(
		"script-message",
		"menu-open",
		utils.format_json({ title = "Chapters", items = items, selected_index = math.max(1, cur + 1) })
	)
end
local function playlist_menu()
	local pl = mp.get_property_native("playlist", {})
	if #pl == 0 then
		mp.osd_message("Empty playlist", 1.4)
		return
	end
	local items, cursel = {}, 1
	for i, e in ipairs(pl) do
		local name = (e.title and e.title ~= "") and e.title or ((e.filename or ""):gsub(".*/", ""))
		if e.current then
			cursel = i
		end
		items[#items + 1] = {
			title = (name ~= "" and name) or ("Item " .. i),
			icon = "movie",
			value = { act = "playlist", index = i - 1 },
			selectable = true,
			active = e.current or false,
		}
	end
	mp.commandv(
		"script-message",
		"menu-open",
		utils.format_json({ title = "Playlist", items = items, selected_index = cursel })
	)
end
mp.add_key_binding(nil, "chapters", chapters_menu)
mp.add_key_binding(nil, "playlist", playlist_menu)

-- ── auto-skip picker — mirrors the subtitle picker (Off / Manual / list) ──────
-- Off; Manual segment (triggers the bar's inline M:SS editor); then every chapter
-- in order. Picking a chapter auto-skips that same-named segment on every episode.
local function skip_menu()
	local mode = mp.get_property_native("user-data/autoskip_mode") or "off"
	local curch = mp.get_property_native("user-data/autoskip_chapter")
	local isk = mp.get_property_native("user-data/intro_skip") or 0
	local items = {
		{
			title = "Off",
			icon = "block",
			value = { act = "skipmode", m = "off" },
			selectable = true,
			active = (mode == "off"),
		},
		-- inline m:ss editor lives here in the picker (not on the bar button)
		{
			title = "Manual segment…",
			hint = (mode == "manual") and fmt_t(isk) or nil,
			icon = "timer",
			edit = true,
			value = { act = "skipmanual" },
			selectable = true,
			active = (mode == "manual"),
		},
	}
	local chapters = mp.get_property_native("chapter-list", {})
	local dur = mp.get_property_number("duration")
	for i, c in ipairs(chapters) do
		local title = (c.title and c.title ~= "") and c.title or ("Chapter " .. i)
		local nxt = chapters[i + 1]
		local endt = nxt and nxt.time or dur
		items[#items + 1] = {
			title = title,
			icon = "fast_forward",
			hint = fmt_t(c.time) .. (endt and (" – " .. fmt_t(endt)) or ""),
			value = { act = "skipchapter", title = title },
			selectable = true,
			active = (mode == "chapter" and curch == title),
		}
	end
	mp.commandv(
		"script-message",
		"menu-open",
		utils.format_json({ title = "Auto-skip", items = items, anchor = "skip" })
	)
end
mp.add_key_binding(nil, "autoskip", skip_menu)

-- ── bespoke OpenSubtitles download (replaces uosc/download-subtitles) ──────
-- nixpkgs' uosc wrapper exports its ziggy binary.
local ZIGGY = os.getenv("MPV_UOSC_ZIGGY")
-- The key stays in the unmanaged user.conf, which perseries.lua loads.
local function apikey()
	return mp.get_property_native("user-data/config-os_apikey") or ""
end
local function can_download_subtitles()
	if not ZIGGY or ZIGGY == "" then
		mp.osd_message("OpenSubtitles unavailable. Open mpv from Home Manager Apps.", 3)
		return false
	end
	if apikey() == "" then
		mp.osd_message("OpenSubtitles needs an API key in user.conf", 3)
		return false
	end
	return true
end
local AGENT = "uosc v5.13.0"

-- Cache the OpenSubtitles login token for the session.
local os_token = nil
local os_login_tried = false
local function ensure_token(cb)
	if os_token or os_login_tried then
		cb(os_token)
		return
	end
	os_login_tried = true
	local u = mp.get_property_native("user-data/config-os_username")
	local p = mp.get_property_native("user-data/config-os_password")
	if not (u and p and #u > 0 and #p > 0) then
		cb(nil)
		return
	end
	mp.command_native_async({
		name = "subprocess",
		playback_only = false,
		capture_stdout = true,
		args = { ZIGGY, "login", "--api-key", apikey(), "--agent", AGENT, "--username", u, "--password", p },
	}, function(ok, res)
		if ok and res and res.status == 0 then
			local d = utils.parse_json(res.stdout or "")
			if d and d.token then
				os_token = d.token
			end
		end
		cb(os_token)
	end)
end

-- Build an accurate OpenSubtitles query from a noisy release filename:
-- "The.Double.2024.S1E01.2160p.YOUKU.WEB-DL..." -> "The Double S01E01".
local function clean_query(name)
	name = (name or ""):gsub("[._]", " ")
	local title, se, ep = name:match("^(.-)%s*[Ss](%d+)[Ee](%d+)")
	if title then
		title = title:gsub("%s*%(?%d%d%d%d%)?%s*$", "") -- drop trailing year
		return string.format("%s S%02dE%02d", title:gsub("%s+$", ""), tonumber(se), tonumber(ep))
	end
	-- movie: title up to the first quality/resolution token
	local cut = name:match("^(.-)%s+%d?%d?%d?%d?[pP]") or name:match("^(.-)%s+[12]%d%d%d%s") or name
	return (cut:gsub("%s+$", ""))
end

-- Rank OpenSubtitles results by likelihood of matching THIS file — same
-- heuristic as subauto's autoload (series title + episode), plus resolution
-- affinity, with download_count/trust as tiebreakers. Fixes "hunt for the
-- right series" in a noisy result list.
local function z_series_key(name)
	local t = name:gsub("%.[^.]+$", ""):gsub("[._]", " ")
	t = t:match("^(.-)%s*[Ss]%d+[Ee]%d+") or t:match("^(.-)%s*[Ee][Pp]?%.?%s?%d") or t
	return (t:gsub("%s*%(?%d%d%d%d%)?.*$", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower():gsub("%s+", " "))
end
local function z_episode(name)
	local a, b = name:match("[Ss](%d+)[Ee](%d+)")
	if a then
		return tonumber(a), tonumber(b)
	end
	local e2 = name:match("[Ee][Pp]?%.?%s?(%d%d?)")
	return nil, e2 and tonumber(e2) or nil
end
local function score_result(at, vkey, vs, ve, vres)
	local rel = ((at.release or "") .. " " .. ((at.files and at.files[1] and at.files[1].file_name) or "")):lower()
	local score = 0
	if ve then
		local rs, re = rel:match("[sS](%d+)[eE](%d+)")
		if re then
			if tonumber(re) == ve and (vs == nil or tonumber(rs) == vs) then
				score = score + 1000
			end
		else
			local re2 = rel:match("[eE][pP]?%.?%s?(%d%d?)")
			if re2 and tonumber(re2) == ve then
				score = score + 600
			end
		end
	end
	local kt = 0
	for w in vkey:gmatch("%a+") do
		if #w >= 3 and rel:find(w, 1, true) then
			kt = kt + 1
		end
	end
	score = score + kt * 120
	if vres and rel:find(vres, 1, true) then
		score = score + 60
	end
	score = score + math.min(60, (tonumber(at.download_count) or 0) / 150)
	if at.from_trusted then
		score = score + 25
	end
	return score
end

local search_cache = {} -- query -> {items, time}; avoids re-searching on repeat opens
local function open_dl_menu(items)
	mp.osd_message("", 0)
	mp.commandv(
		"script-message",
		"menu-open",
		utils.format_json({ title = "Download subtitles", items = items, anchor = "subs" })
	)
end
local function download_subs()
	if not can_download_subtitles() then
		return
	end
	local q = clean_query(mp.get_property("filename/no-ext") or mp.get_property("media-title") or "")
	if q == "" then
		mp.osd_message("No file", 2)
		return
	end
	local cached = search_cache[q]
	if cached and (mp.get_time() - cached.time) < 300 and #cached.items > 0 then
		open_dl_menu(cached.items)
		return
	end
	mp.osd_message("Searching subtitles…", 30)
	ensure_token(function(tok)
		local langs = mp.get_property_native("user-data/config-sub_languages") or "en"
		local sargs = {
			ZIGGY,
			"search-subtitles",
			"--api-key",
			apikey(),
			"--agent",
			AGENT,
			"--languages",
			langs,
			"--query",
			q,
		}
		if tok then
			sargs[#sargs + 1] = "--token"
			sargs[#sargs + 1] = tok
		end
		mp.command_native_async(
			{ name = "subprocess", playback_only = false, capture_stdout = true, args = sargs },
			function(ok, res)
				if not ok or not res or res.status ~= 0 then
					mp.osd_message("Search failed", 2)
					return
				end
				local data = utils.parse_json(res.stdout or "")
				if not (data and type(data.data) == "table" and #data.data > 0) then
					mp.osd_message("No subtitles found", 2)
					return
				end
				local vfile = mp.get_property("filename/no-ext") or ""
				local vkey = z_series_key(vfile)
				local vs, ve = z_episode(vfile)
				local vh = mp.get_property_number("height", 0) or 0
				local vres = (vh >= 1600 and "2160") or (vh >= 900 and "1080") or (vh >= 600 and "720") or nil
				table.sort(data.data, function(a, b)
					return score_result(a.attributes or {}, vkey, vs, ve, vres)
						> score_result(b.attributes or {}, vkey, vs, ve, vres)
				end)
				local items = {}
				for _, sub in ipairs(data.data) do
					local at = sub.attributes
					if at and type(at.files) == "table" and at.files[1] then
						local dl = tonumber(at.download_count) or 0
						local hint = (dl >= 1000 and string.format("%.1fk", dl / 1000) or tostring(dl))
							.. "  "
							.. (at.language or "")
						if at.hearing_impaired then
							hint = hint .. " · HI"
						end
						if at.from_trusted then
							hint = hint .. " · ✓"
						end
						items[#items + 1] = {
							title = at.release or at.files[1].file_name or "subtitle",
							hint = hint,
							icon = "subtitles",
							value = {
								act = "dlsub",
								file_id = at.files[1].file_id,
								file_name = at.files[1].file_name,
								lang = at.language or "en",
							},
							selectable = true,
						}
					end
				end
				search_cache[q] = { items = items, time = mp.get_time() }
				open_dl_menu(items)
			end
		)
	end)
end
mp.add_key_binding(nil, "download", download_subs)
mp.register_script_message("open-download", download_subs)

local function do_download(v)
	if not can_download_subtitles() then
		return
	end
	local vpath = mp.get_property("path")
	if not vpath then
		return
	end
	local dir = utils.split_path(vpath)
	local base = (select(2, utils.split_path(vpath))):gsub("%.[^.]+$", "")
	mp.osd_message("Downloading subtitle…", 30)
	-- snapshot dir before download so we can detect the ACTUAL saved filename
	-- (ziggy's on-disk name is not guaranteed to equal file_name)
	local before = {}
	for _, f in ipairs(utils.readdir(dir, "files") or {}) do
		before[f] = true
	end
	mp.command_native_async({
		name = "subprocess",
		playback_only = false,
		capture_stdout = true,
		args = (function()
			local a = {
				ZIGGY,
				"download-subtitles",
				"--api-key",
				apikey(),
				"--agent",
				AGENT,
				"--file-id",
				tostring(v.file_id),
				"--destination",
				dir,
			}
			if os_token then
				a[#a + 1] = "--token"
				a[#a + 1] = os_token
			end
			return a
		end)(),
	}, function(ok, res)
		if not (ok and res and res.status == 0) then
			mp.osd_message("Download failed (quota? need login)", 3)
			return
		end
		-- find the newly-appeared subtitle file
		local newfile
		for _, f in ipairs(utils.readdir(dir, "files") or {}) do
			local e = f:match("%.([^.]+)$")
			e = e and e:lower()
			if not before[f] and (e == "srt" or e == "ass" or e == "ssa" or e == "sub" or e == "vtt") then
				newfile = f
				break
			end
		end
		local dst = dir .. base .. "." .. (v.lang or "en") .. ".srt"
		if newfile then
			os.rename(dir .. newfile, dst)
		else
			dst = dir .. (v.file_name or (base .. "." .. (v.lang or "en") .. ".srt"))
		end
		mp.commandv("sub-add", dst, "select") -- appears in the track list immediately
		mp.set_property("sid", mp.get_property("sid")) -- nudge observers
		mp.osd_message("Subtitle added", 2)
	end)
end

-- ── bespoke file browser (replaces uosc/open-file) ─────────────────────────
local VIDEO_EXT = { mkv = 1, mp4 = 1, m4v = 1, avi = 1, mov = 1, webm = 1, ts = 1, flv = 1 }
local function is_video(name)
	local e = name:match("%.([^.]+)$")
	return e and VIDEO_EXT[e:lower()]
end
local function parent(dir)
	return dir:match("^(.*)/[^/]+/?$") or "/"
end

local SUB_EXT = { srt = 1, ass = 1, ssa = 1, sub = 1, vtt = 1, idx = 1 }
local function is_sub(name)
	local e = name:match("%.([^.]+)$")
	return e and SUB_EXT[e:lower()]
end
local VID_ICON = {
	mp4 = "file_video",
	m4v = "file_video",
	mkv = "movie",
	webm = "movie",
	avi = "movie",
	mov = "movie",
	ts = "movie",
	flv = "movie",
}
local SUB_ICON = {
	srt = "subtitles",
	vtt = "closed_caption",
	ass = "list",
	ssa = "list",
	sub = "subtitles",
	idx = "subtitles",
}
local function file_icon(fn, mode)
	local e = (fn:match("%.([^.]+)$") or ""):lower()
	if mode == "sub" then
		return SUB_ICON[e] or "subtitles"
	end
	return VID_ICON[e] or "movie"
end
-- same series+episode heuristic as autoload/download, for ranking sub files
local function video_score(fn, vkey, ve)
	local score = 0
	local same = (vkey ~= "" and z_series_key(fn) == vkey)
	if same then
		score = score + 300
	end
	local _, se = z_episode(fn)
	if same and ve and se then
		if se == ve + 1 then
			score = score + 1000 -- the likely NEXT episode
		elseif se == ve then
			score = score + 250 -- current (rewatch)
		elseif se > ve then
			score = score + 500 - (se - ve) -- later, nearer = higher
		else
			score = score + 100 - (ve - se)
		end -- earlier
	end
	return score
end
local function sub_file_score(fn, vkey, ve)
	local rel = fn:lower()
	local score = 0
	local _, se = z_episode(fn)
	if ve and se == ve then
		score = score + 1000
	end
	if vkey ~= "" and z_series_key(fn) == vkey then
		score = score + 500
	end
	for w in vkey:gmatch("%a+") do
		if #w >= 3 and rel:find(w, 1, true) then
			score = score + 80
		end
	end
	return score
end

local function browse(dir, mode)
	mode = mode or "video"
	if not dir or dir == "" then
		local p = mp.get_property("path")
		dir = p and utils.split_path and select(1, utils.split_path(p)) or (os.getenv("HOME") .. "/Documents/shows")
	end
	dir = dir:gsub("/+$", "")
	local dirs = utils.readdir(dir, "dirs") or {}
	local files = utils.readdir(dir, "files") or {}
	table.sort(dirs)
	table.sort(files)
	local items = {
		{
			title = "..",
			icon = "arrow_upward",
			value = { act = "browse", path = parent(dir), mode = mode },
			selectable = true,
		},
	}
	for _, d in ipairs(dirs) do
		if d:sub(1, 1) ~= "." then
			items[#items + 1] = {
				title = d,
				icon = "folder",
				value = { act = "browse", path = dir .. "/" .. d, mode = mode },
				selectable = true,
			}
		end
	end
	local match = (mode == "sub") and is_sub or is_video
	local facet = (mode == "sub") and "loadsubfile" or "open"
	local flist = {}
	for _, fn in ipairs(files) do
		if match(fn) then
			flist[#flist + 1] = fn
		end
	end
	do
		local vfile = mp.get_property("filename/no-ext") or ""
		local vkey = z_series_key(vfile)
		local _, ve = z_episode(vfile)
		local scorer = (mode == "sub") and sub_file_score or video_score
		table.sort(flist, function(a, b)
			local sa, sb = scorer(a, vkey, ve), scorer(b, vkey, ve)
			if sa ~= sb then
				return sa > sb
			end -- best match first
			return a:lower() < b:lower() -- else alphabetical (groups series)
		end)
	end
	for _, fn in ipairs(flist) do
		items[#items + 1] = {
			title = fn,
			icon = file_icon(fn, mode),
			value = { act = facet, path = dir .. "/" .. fn },
			selectable = true,
		}
	end
	local title = (mode == "sub" and "Load subtitle · " or "") .. (dir:match("[^/]+$") or dir)
	mp.commandv("script-message", "menu-open", utils.format_json({ title = title, items = items, anchor = "browse" }))
end
mp.add_key_binding(nil, "browse", function()
	browse(nil, "video")
end)
mp.add_key_binding(nil, "loadsub", function()
	browse(nil, "sub")
end)

-- ── settings menu (all knobs; the bar's sliders button) ───────────────────
-- Each row toggles/cycles a knob and re-opens the menu in place (Menu.open on an
-- already-open menu updates without re-animating), so you can A/B live.
local function toggle_hdr()
	local gamma = mp.get_property("video-params/gamma")
	if gamma ~= "pq" and gamma ~= "hlg" then
		mp.osd_message("Current video is SDR", 1.5)
		return
	end
	local native = mp.get_property("target-colorspace-hint") ~= "yes"
	mp.set_property("target-colorspace-hint", native and "yes" or "no")
	mp.osd_message(native and "HDR output: XDR" or "HDR output: SDR tone mapping", 1.5)
end
mp.add_key_binding(nil, "toggle-hdr", toggle_hdr)

local SETTINGS = {
	{
		id = "preset",
		label = "Quality",
		icon = "bolt",
		state = function()
			local eco = mp.get_property_native("user-data/preset") == "eco"
			return eco and "Eco" or "Full", not eco
		end,
		fire = function()
			mp.commandv("script-binding", "prefs/cycle-preset")
		end,
	},
	{
		id = "upscale",
		label = "HD / SD upscaling",
		icon = "movie",
		state = function()
			local ewa = mp.get_property_native("user-data/upscale") == "ewa"
			return ewa and "Built-in" or "Auto (RAVU / CfL)", not ewa
		end,
		fire = function()
			local ewa = mp.get_property_native("user-data/upscale") == "ewa"
			mp.commandv("script-message-to", "prefs", "set-upscale", ewa and "auto" or "ewa")
		end,
	},
	{
		id = "interp",
		label = "Interpolation",
		icon = "fast_forward",
		state = function()
			local dsa = mp.get_property_native("display-sync-active")
			local it = mp.get_property_native("interpolation")
			if dsa and it then
				return "Active", true
			elseif it then
				return "Inert (audio)", false
			end
			return "Off", false
		end,
		fire = function()
			if mp.get_property("video-sync") == "audio" then
				mp.command("set video-sync display-resample; set interpolation yes")
			else
				mp.command("set video-sync audio")
			end
		end,
	},
	-- {
	--     id = 'look',
	--     label = 'Color look',
	--     icon = 'graphic_eq',
	--     state = function() return (mp.get_property_native('user-data/look') or 'reference'), false end,
	--     fire = function()
	--         local v = mp.get_property_native('user-data/look') or 'reference'; mp.commandv('script-message-to', 'prefs',
	--             'set-look', v == 'vivid' and 'reference' or 'vivid')
	--     end
	-- },
	-- {
	--     id = 'ssim',
	--     label = 'SSim downscale (4K)',
	--     icon = 'movie',
	--     state = function()
	--         local v = mp.get_property_native('user-data/ssim'); return v and 'on' or 'off', v and true or false
	--     end,
	--     fire = function() mp.commandv('script-message-to', 'ssim', 'ssim-toggle') end
	-- },
	-- {
	--     id = 'denoise',
	--     label = 'Denoise (nlmeans)',
	--     icon = 'eco',
	--     state = function()
	--         local v = mp.get_property_native('user-data/denoise'); return v and 'on' or 'off', v and true or false
	--     end,
	--     fire = function() mp.commandv('script-binding', 'denoise/toggle') end
	-- },
	{
		id = "peak",
		label = "HDR peak detect",
		icon = "bolt",
		state = function()
			local v = mp.get_property("hdr-compute-peak")
			return v, false
		end,
		fire = function()
			mp.command("cycle hdr-compute-peak")
		end,
	},
	{
		id = "hint",
		label = "HDR output",
		icon = "graphic_eq",
		state = function()
			local gamma = mp.get_property("video-target-params/gamma")
			return gamma == "pq" and "PQ" or gamma == "hlg" and "HLG" or "SDR", false
		end,
		fire = toggle_hdr,
	},
	{
		id = "target-prim",
		label = "Target primaries",
		icon = "palette",
		state = function()
			return mp.get_property("target-prim") or "auto", false
		end,
		fire = function()
			mp.command("cycle target-prim")
		end,
		-- fire = function() mp.command('cycle-values target-prim auto bt.709 bt.2020 apple display-p3') end
	},
	{
		id = "target-trc",
		label = "Target transfer",
		icon = "two_sliders",
		state = function()
			return mp.get_property("target-trc") or "auto", false
		end,
		fire = function()
			mp.command("cycle target-trc")
		end,
		-- fire = function() mp.command('cycle-values target-trc auto bt.1886 gamma2.2 gamma2.8 linear') end
	},
	{
		id = "icc-profile-auto",
		label = "ICC profile auto",
		icon = "display",
		state = function()
			local v = mp.get_property_native("icc-profile-auto")
			return v and "on" or "off", v and true or false
		end,
		fire = function()
			mp.command("cycle icc-profile-auto")
		end,
	},
	{
		id = "tscale",
		label = "tscale kernel",
		icon = "fast_forward",
		state = function()
			return mp.get_property("tscale") or "oversample", false
		end,
		fire = function()
			mp.command("cycle tscale")
		end,
	},
	{
		id = "seekboost",
		label = "Seek boost (audio-flip)",
		icon = "timer",
		state = function()
			local v = mp.get_property_native("user-data/seekboost")
			return v and "on" or "off (pure)", v and true or false
		end,
		fire = function()
			mp.commandv("script-message-to", "seekboost", "seekboost-toggle")
		end,
	},
	{
		id = "subdelay",
		label = "Subtitle delay (reset)",
		icon = "timer",
		state = function()
			return string.format("%+.1fs", mp.get_property_number("sub-delay", 0) or 0), false
		end,
		fire = function()
			mp.set_property_number("sub-delay", 0)
		end,
	},
}
local function settings_menu(sel)
	local items = {}
	for i, c in ipairs(SETTINGS) do
		local txt, active = c.state()
		items[#items + 1] = {
			title = c.label,
			hint = txt,
			icon = c.icon,
			active = active,
			value = { act = "setting", i = i },
			selectable = true,
		}
	end
	-- auto-skip (mode + manual length + chapter) lives entirely in the bar's skip
	-- picker now (mirrors the subtitle picker) — no duplicate rows here.
	local sp = mp.get_property_number("sub-pos", 95) or 95
	items[#items + 1] = {
		title = "Subtitle position",
		hint = tostring(sp),
		icon = "closed_caption",
		edit = true,
		value = { act = "setsubpos" },
		selectable = true,
	}
	mp.commandv(
		"script-message",
		"menu-open",
		utils.format_json({ title = "Settings", items = items, anchor = "settings", selected_index = sel or 1 })
	)
end
mp.add_key_binding(nil, "settings", function()
	settings_menu(1)
end)

mp.register_script_message("menu-result", function(json)
	local r = utils.parse_json(json)
	if not (r and r.value and type(r.value) == "table") then
		return
	end
	local v = r.value
	if v.act == "track" then
		mp.set_property(v.prop, (v.id ~= nil and v.id ~= false) and tostring(v.id) or "no")
	elseif v.act == "searchsub" then
		download_subs()
	elseif v.act == "loadsub" then
		mp.add_timeout(0.02, function()
			browse(nil, "sub")
		end)
	elseif v.act == "browse" then
		mp.add_timeout(0.02, function()
			browse(v.path, v.mode)
		end)
	elseif v.act == "loadsubfile" then
		mp.commandv("sub-add", v.path, "select")
		mp.osd_message("Subtitle added", 1.5)
	elseif v.act == "chapter" then
		mp.set_property_number("chapter", v.index)
	elseif v.act == "playlist" then
		mp.set_property_number("playlist-pos", v.index)
	elseif v.act == "setting" then
		local c = SETTINGS[v.i]
		if c then
			c.fire()
			mp.add_timeout(0.04, function()
				settings_menu(v.i)
			end)
		end
	elseif v.act == "setsubpos" then
		mp.set_property_number("sub-pos", math.max(0, math.min(150, tonumber(v.num) or 95)))
		mp.add_timeout(0.04, function()
			settings_menu(#SETTINGS + 1)
		end)
	elseif v.act == "skipmode" then
		mp.commandv("script-message", "skip-set-mode", v.m)
	elseif v.act == "skipmanual" then
		local n = math.max(0, math.min(600, draw.parse_t(v.text) or 0))
		mp.commandv("script-message", "set-intro", tostring(n))
		mp.commandv("script-message", "skip-set-mode", n > 0 and "manual" or "off")
		mp.commandv("script-message", "menu-close")
	elseif v.act == "skipchapter" then
		mp.commandv("script-message", "skip-set-chapter", v.title)
	elseif v.act == "open" then
		mp.commandv("loadfile", v.path)
	elseif v.act == "dlsub" then
		do_download(v)
	end
end)
