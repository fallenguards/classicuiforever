-- Offline test under Lua 5.4 for the addon-button bag (Map/MinimapCollector.lua): a LibDBIcon button pins its strata
-- and level (MEDIUM 8, fixed), which ignored ours and left it under the bag's dark backing, drawn dim (#168). In the
-- bag it stands on the bag's strata over the backing; handed back, it has its own strata, level and pins again. A named
-- button made late is taken on the next frame's sweep.
-- Run from the addon root: lua tools/tests/collector_strata_test.lua (CI runs every tools/tests/*_test.lua).
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

local noop = function() end
-- A frame whose strata and level obey their pins, as the client's do; any other method does nothing, fields are nil.
local Frame = {}
Frame.__index = function(_, key)
    local method = rawget(Frame, key)
    if method then return method end
    if type(key) == "string" and key:match("^%u") then return noop end
end
function Frame:GetFrameStrata() return self.strata or "MEDIUM" end
function Frame:SetFrameStrata(strata) if not self.fixedStrata then self.strata = strata end end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetFrameLevel(level) if not self.fixedLevel then self.level = level end end
function Frame:HasFixedFrameStrata() return self.fixedStrata == true end
function Frame:SetFixedFrameStrata(on) self.fixedStrata = on end
function Frame:HasFixedFrameLevel() return self.fixedLevel == true end
function Frame:SetFixedFrameLevel(on) self.fixedLevel = on end
function Frame:GetParent() return self.parent end
function Frame:GetName() return self.name end
function Frame:SetParent(parent) self.parent = parent end
function Frame:IsShown() return true end
function Frame:GetScale() return 1 end
function Frame:GetWidth() return 31 end
function Frame:GetNumPoints() return 0 end
function Frame:CreateFontString() return setmetatable({}, Frame) end
local function New(fields) return setmetatable(fields or {}, Frame) end
function CreateFrame() return New() end
Minimap = New()

-- LibDBIcon's button as version 56 makes it.
local sack = New({ name = "LibDBIcon10_BugSack", parent = Minimap, strata = "MEDIUM", level = 8 })
sack.fixedStrata, sack.fixedLevel = true, true
local lib = {
    GetButtonList = function() return { "BugSack" } end,
    GetMinimapButton = function() return sack end,
}
function LibStub() return lib end

local apply, restore, sweep
local children = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = {},
    RingButton = function() return noop, noop end,
    RegisterModule = function(key, spec)
        if key == "minimapCollector" then apply, restore = spec.apply, spec.restore end
    end,
    DialogBacking = noop, CloseOnEscape = noop, RegisterEvents = noop, ThemeAddonRing = noop, SetPointOnce = noop,
    SetAlphaIf = noop, SetScaleIf = noop,
    EachChild = function(_, fn) for _, child in ipairs(children) do fn(child) end end,
    SetStrataIf = function(frame, strata) if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end end,
    SetLevelIf = function(frame, level) if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end end,
    Sched = { Attach = noop, Job = function(spec) sweep = spec return { Wake = noop, Sleep = noop } end },
}
function GetTime() return 0 end
assert(loadfile(ROOT .. "/Map/MinimapCollector.lua"))("ClassicUIForever", ns)

apply()
Check(sack:GetFrameStrata() == "HIGH", "in the bag: on the bag's strata, over its backing (was " .. sack:GetFrameStrata() .. ")")
Check(sack:GetFrameLevel() > 1, "in the bag: above the backing's level")
-- A button its addon makes on a timer after login (0.6 s in): taken on the sweep's next pass, which is every frame.
local late = New({ name = "BoundToLearnMinimapButton", parent = Minimap })
function late:IsObjectType(kind) return kind == "Button" end
children[#children + 1] = late
Check(sweep and sweep.every == 0, "the sweep runs every frame (every 2 s left a late button on the map)")
sweep.fn({ Sleep = noop })
Check(late:GetParent() ~= Minimap, "a late named button is in the bag after one sweep pass")
restore()
Check(sack:GetFrameStrata() == "MEDIUM" and sack:GetFrameLevel() == 8, "handed back: its own strata and level")
Check(sack.fixedStrata == true and sack.fixedLevel == true, "handed back: pinned again, as its library left it")
Check(late:GetParent() == Minimap, "the late button handed back to the map")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("collector_strata_test: all checks passed")
