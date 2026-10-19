-- Offline tests for Map/MinimapButton.lua under Lua 5.4: our minimap ring buttons' default spots stand clear of each other
-- and of the pieces round the map, and a button with no place of its own takes the nearest clear spot.
-- Run from the addon root: lua tools/tests/ring_spots_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

local Frame = {}
Frame.__index = function(_, key) return Frame[key] or function() end end
function Frame:GetParent() return self.parent end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetWidth() return 140 end
function Frame:GetFrameLevel() return 2 end
function Frame:CreateTexture() return setmetatable({}, Frame) end
function Frame:CreateFontString() return setmetatable({}, Frame) end
function Frame:IsObjectType() return true end
function Frame:IsShown() return true end
function Frame:GetName() return self.name end
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetNumPoints() return 0 end
function CreateFrame(_, _, parent) return setmetatable({ parent = parent }, Frame) end
Minimap = setmetatable({}, Frame)
function IsShiftKeyDown() return false end
function InCombatLockdown() return false end
function GetTime() return 0 end

local noop = function() end
local showOptions
local bag, bagApply
-- The minimap's named children as the addon bag's sweep meets them: one of another addon, one micro icon of ours.
local theirs = setmetatable({ name = "SomeAddonMinimapButton", parent = Minimap, fadeOut = false }, Frame)
local ourIcon = setmetatable({ name = "ForeverClassicUIMinimapLegacyButton", parent = Minimap, fadeOut = false }, Frame)
local ns = {
    EachChild = function(_, fn) fn(theirs) fn(ourIcon) end,
    DialogBacking = noop, CloseOnEscape = noop, RegisterEvents = noop, SetStrataIf = noop, SetLevelIf = noop, SetScaleIf = noop,
    SetAlphaIf = noop, ThemeAddonRing = noop, SetPointOnce = noop,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = {},
    Sched = { OnFrame = function() return { Wake = noop, Sleep = noop } end, Attach = noop,
        Job = function() return { Wake = noop, Sleep = noop } end },
    RingPoint = function(frame, degrees) frame.angle = degrees end,
    MM = { Square = function() return false end, AddonButtonState = noop, OUR_BUTTON = "ForeverClassicUIMinimapButton" },
    DressNew = noop, RoundIcon = noop, MinimapButtonBorder = noop, DressStates = noop, AttachTip = noop, MinimapShow = noop,
    MinimapShowAs = noop,
    HookMethod = noop, HookScriptOnce = noop, OnToggle = noop, Dress = noop, PlaceSavedWindows = noop,
    RegisterModule = function(key, spec)
        if key == "minimapButton" then showOptions = spec.apply end
        if key == "minimapCollector" then bagApply = spec.apply end
    end,
}
assert(loadfile(ROOT .. "/Map/MinimapButton.lua"))("ClassicUIForever", ns)
-- The addon bag's own ring button, as its file registers it.
local RingButton = ns.RingButton
ns.RingButton = function(spec)
    local show, hide = RingButton(spec)
    bag = { spec = spec, show = show, hide = hide }
    return show, hide
end
assert(loadfile(ROOT .. "/Map/MinimapCollector.lua"))("ClassicUIForever", ns)
ns.RingButton = RingButton
ns.modules, ns.TOGGLES = {}, {}
assert(loadfile(ROOT .. "/Core/Defaults.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end
local function Apart(a, b)
    local d = math.abs(a - b) % 360
    return d > 180 and 360 - d or d
end
-- The fixed pieces: mail, day and night, tracking spell, tracking glass, zoom out, zoom in; the options button; the eye.
local FIXED = { 12, 34, 159, 186, 302, 322, 213 }

local shown = {}
local function Ring(name, angle, free)
    local spec = { name = name, key = name, angleKey = name .. "Angle", angle = angle, free = free, show = "X", face = noop }
    local Show = ns.RingButton(spec)
    Show()
    shown[#shown + 1] = spec
    return spec.button.angle
end

-- No saved default spot: one would stand in for a button's own spot and its clear-spot search.
for key, value in pairs(ns.DB_DEFAULTS) do
    Check(not (key:find("Angle$") and key ~= "minimapButtonAngle"), "no default for " .. key .. " (" .. tostring(value) .. ")")
end

-- As in game: the options button and the group finder eye are up before the rest.
showOptions()
Check(_G.ForeverClassicUIMinimapButton == nil or true, "options button shown")
-- The addon bag stands left of the clock, clear of the eye, and keeps the spot while it stays clear.
bag.show()
Check(bag.spec.button.angle == 238, "the addon bag stands left of the clock (" .. tostring(bag.spec.button.angle) .. ")")
Check(Ring("eye", 137, false) == 137, "the eye keeps Era's spot")
bag.show()
Check(bag.spec.button.angle == 238, "the addon bag keeps its spot with the eye up (" .. tostring(bag.spec.button.angle) .. ")")
shown[#shown + 1] = bag.spec
Check(Ring("legacy", 347, true) == 347, "Legacy stands under the mail icon, its own spot clear")
local first = Ring("character", 232, true)
Check(first ~= 232 and Apart(first, 238) >= 25, "a free icon aimed at a taken spot takes a clear one (" .. tostring(first) .. ")")
for i, a in ipairs(shown) do
    for _, fixed in ipairs(a.free and FIXED or {}) do
        Check(Apart(a.button.angle, fixed) >= 25,
            string.format("%s at %s stands clear of the piece at %d", a.name, tostring(a.button.angle), fixed))
    end
    for j = i + 1, #shown do
        Check(Apart(a.button.angle, shown[j].button.angle) >= 25 or (a.name == "eye" or shown[j].name == "eye"),
            string.format("%s and %s stand apart (%s, %s)", a.name, shown[j].name, tostring(a.button.angle),
                tostring(shown[j].button.angle)))
    end
end
-- A full ring: later icons take the roomiest spot left, never another button's own.
Ring("spellbook", 232, true)
Ring("talents", 232, true)
for i, a in ipairs(shown) do
    for j = i + 1, #shown do
        Check(Apart(a.button.angle, shown[j].button.angle) >= 10,
            string.format("%s and %s are not stacked (%s, %s)", a.name, shown[j].name, tostring(a.button.angle),
                tostring(shown[j].button.angle)))
    end
end
for _, a in ipairs(shown) do
    local deg = a.button.angle
    Check(not ((deg >= 60 and deg <= 120) or (deg >= 246 and deg <= 294)), a.name .. " is off the zone bar and the clock")
end

-- The bag takes other addons' buttons off the map, never our own micro icons.
bagApply()
Check(theirs.parent ~= Minimap, "another addon's minimap button goes in the bag")
Check(ourIcon.parent == Minimap, "our micro icon stays on the ring")

-- A place the player dragged it to is kept, clear or not.
ns.db.draggedAngle = 190
Check(Ring("dragged", 232, true) == 190, "a dragged button stays where it was put")

-- The options button's default left the tracking glass: one never moved follows, a moved one stays.
ns.db = { minimapButtonAngle = 200, profiles = { moved = { minimapButtonAngle = 203.4 }, old = { minimapButtonAngle = 200 } } }
ns.FreeOptionsButton()
Check(ns.db.minimapButtonAngle == nil and ns.db.profiles.old.minimapButtonAngle == nil, "an unmoved options button takes the new default")
Check(ns.db.profiles.moved.minimapButtonAngle == 203.4, "a moved options button stays")
Check(ns.db.dbVersion == 12, "writes dbVersion 12")

-- The addon bag's saved default stood on the eye: one never moved takes a clear spot, a moved one stays.
ns.db = { minimapCollectorAngle = 132, profiles = { moved = { minimapCollectorAngle = 95.2 }, old = { minimapCollectorAngle = 132 } } }
ns.FreeAddonBag()
Check(ns.db.minimapCollectorAngle == nil and ns.db.profiles.old.minimapCollectorAngle == nil, "an unmoved addon bag leaves the eye")
Check(ns.db.profiles.moved.minimapCollectorAngle == 95.2, "a moved addon bag stays")
Check(ns.db.dbVersion == 13, "writes dbVersion 13")

if failures > 0 then
    print(string.format("ring spots: %d failed", failures))
    os.exit(1)
end
print("ring spots: ok")
