-- Offline test under Lua 5.4 for the combo points (Units/ComboPoints.lua). Forever's ComboFrame became five modern orbs
-- in beta build 70291, re-laid by the client on every update; our layout of its old arc showed four of them in the
-- modern look. Now our own five 1.x orbs show on every client and the client's orbs are faded, then handed back.
-- Run from the addon root: lua tools/tests/combo_points_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

------------------------------------------------------------------ the stub client

local function Frame()
    local f = { shown = true, alpha = 1, scripts = {} }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:IsShown() return self.shown end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetAlpha() return self.alpha end
    function f:SetSize() end
    function f:SetPoint() end
    function f:SetFrameLevel() end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetToplevel() end
    function f:GetFrameLevel() return 5 end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    return f
end
function CreateFrame() return Frame() end
function UIFrameFadeIn(f, _, _, to) f:SetAlpha(to or 1) end
function UIFrameFade() end
function UIFrameFadeOut(f) f:SetAlpha(0) end
Enum = { PowerType = { ComboPoints = 4 } }
local power, max, target = 0, 5, true
function UnitPowerMax() return max end
function UnitPower() return power end
function GetComboPoints() return power end
function UnitExists() return target end
function UnitCanAttack() return target end
TargetFrame = Frame()

local clientOrbs = {}
for i = 1, 5 do clientOrbs[i] = Frame() end
ComboFrame = Frame()
ComboFrame.ComboPoints = clientOrbs

local module
local ns = { db = {}, EMPTY = {} }
function ns.RegisterModule(_, m) module = m end
function ns.Path() return TargetFrame end
function ns.SetPointOnce() end
function ns.DressNew() return Frame() end
function ns.Fade(f) if f then f:SetAlpha(0) end end
function ns.Unfade(f) if f then f:SetAlpha(1) end end
function ns.SetAlphaIf(f, a) f:SetAlpha(a) end
function ns.Safe(v, default) if v == nil then return default end return v end
function ns.OnForever() return true end
local registered = {}
function ns.RegisterEvents(f, list) for _, e in ipairs(list) do registered[e] = true end end

-- The first frame the module makes is its own orb frame (Build); the orbs follow.
local built
local realCreate = CreateFrame
CreateFrame = function(...) local f = realCreate(...) built = built or f return f end
assert(loadfile(ROOT .. "/Units/ComboPoints.lua"))("ClassicUIForever", ns)
Check(module and module.apply and module.restore, "the module registers apply and restore")

local shownOrbs, lit = 0, 0
local function Count(frame)
    shownOrbs, lit = 0, 0
    for _, orb in ipairs(frame.orbs or {}) do
        if orb.shown then shownOrbs = shownOrbs + 1 end
        if orb.lit:GetAlpha() > 0 then lit = lit + 1 end
    end
end

------------------------------------------------------------------ checks

power = 3
module.apply()
CreateFrame = realCreate
for i = 1, 5 do Check(clientOrbs[i]:GetAlpha() == 0, "the client's orb " .. i .. " is faded") end
Check(registered.COMBO_TARGET_CHANGED, "points moving to a new target are heard")
Check(built and built.orbs and #built.orbs == 5, "our frame has five orbs (" .. tostring(built and built.orbs and #built.orbs) .. ")")
Check(built and built.strata == "MEDIUM", "a strata over the target frame and its PvP flag, as Era's (#156)")
if built and built.orbs then
    Count(built)
    Check(built.shown, "with points on an enemy target our orbs show")
    Check(shownOrbs == 5, "all five orbs stand for a five point class (" .. shownOrbs .. ")")
    Check(lit == 3, "three points light three orbs (" .. lit .. ")")
    power = 5
    built.scripts.OnEvent()
    Count(built)
    Check(lit == 5, "five points light all five (" .. lit .. ")")
    target = false
    built.scripts.OnEvent()
    Check(not built.shown, "no target: our orbs hide")
end

module.restore()
for i = 1, 5 do Check(clientOrbs[i]:GetAlpha() == 1, "the client's orb " .. i .. " is handed back") end
for i = 1, 5 do clientOrbs[i]:SetAlpha(0.7) end
module.restore()
Check(clientOrbs[1]:GetAlpha() == 0.7, "off again, the client's orbs are left alone")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("combo_points_test: ok")
