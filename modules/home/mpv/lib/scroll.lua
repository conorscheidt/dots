-- scroll.lua — shared momentum-free scroll feel for the popup/stats overlays.
-- Single source of truth so menu.lua and hud.lua can't drift (and tuning lives
-- in one place). Both drive scroll_target through gain() per WHEEL event, then
-- ease scroll_y toward it via approach() each frame.
--
-- WHEEL info.scale is fractional on high-res touchpads (see [[mpv-trackpad-scroll]]):
-- a linear map (delta = scale*step) loses slow-finger deltas because tiny scales
-- fall below a visible step. gamma<1 boosts small deltas (slow scroll registers)
-- while gently compressing large ones — higher low-end sensitivity, ~same overall
-- speed. Anchored so mid-range (scale~0.5) ≈ the old linear feel.
local M = {}
local abs, min, max = math.abs, math.min, math.max

-- signed scroll_target delta for one WHEEL event (dir ±1, scale = info.scale)
function M.gain(dir, scale, step, gamma) return dir * step * abs(scale or 1) ^ gamma end

-- ease y toward target; snaps (and reports done) within eps. returns new_y, moving
function M.approach(y, target, dt, rate, eps)
    eps = eps or 0.4
    if abs(y - target) <= eps then return target, false end
    y = y + (target - y) * min(1, dt * rate)
    if abs(y - target) <= eps then return target, false end
    return y, true
end

M.clamp = function(v, lo, hi) return max(lo, min(hi, v)) end
return M
