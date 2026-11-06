-- Offline test under Lua 5.4 for the fight layer's values (Map/WorldMapFight.lua FightValues): the scale a fight lays the
-- windowed map at is the player's Windows size on top of the header style's own, as out of a fight (UI/WindowHandles.lua);
-- a size alone opened the map at 1.05 instead of 0.735 in a fight (2026-11-05). Also three watchers: map, toggle, pane.
-- Run from the addon root: lua tools/tests/map_fight_scale_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Frame()
    local f = { attributes = {}, refs = {} }
    function f:SetFrameRef(key, frame) self.refs[key] = frame end
    function f:SetAttribute(key, value) self.attributes[key] = value end
    function f:GetAttribute(key) return self.attributes[key] end
    function f:SetParent(parent) self.parent = parent end
    function f:GetParent() return self.parent end
    function f:Hide() end
    return f
end

UIParent = { GetSize = function() return 1365, 768 end, GetHeight = function() return 768 end }
function InCombatLockdown() return false end
function CreateFrame() return Frame() end

local map = Frame()
map.SidePanelToggle, map.QuestLog = Frame(), Frame()
map.minimizedWidth, map.questLogWidth = 702, 333
local lay = Frame()
local entry = { key = "map", quests = true }
local onEvent, made = nil, 0
local ns = {
    MapFight = {
        Map = function() return map end,
        Layout = function() return lay end,
        EraStyle = function() return "classic" end,
        Size = function(_, pane) return pane and 1361 or 1024, 768 end,
        WindowedBase = function() return 0.7 end,
        FullScale = function() return 1.1 end,
    },
    windowEdit = {
        ByKey = { map = entry },
        Worn = function() return true end,
        Scales = function() return { map = 1.05 } end,
        SizeKey = function() return "map" end,
        PlaceOf = function() return 16, 740 end,
    },
    SetAttributeIf = function(frame, key, value) frame:SetAttribute(key, value) end,
    MoverHolds = function() return false end,
    GameHome = function() return 16, 740 end,
    NewFrame = function(kind, name, parent) made = made + 1 local f = CreateFrame(kind, name, parent) f.parent = parent return f end,
    EventFrame = function(_, fn) onEvent = fn end,
    OnToggle = function() end,
}
assert(loadfile(ROOT .. "/Map/WorldMapFight.lua"))("ClassicUIForever", ns)
assert(onEvent, "the fight layer listens for the fight's start")

onEvent(nil, "PLAYER_ENTERING_WORLD")
local k = lay:GetAttribute("k")
Check(k and math.abs(k - 0.735) < 0.001, "the fight's scale is the player's size on the style's own: 1.05 x 0.7, got " .. tostring(k))
Check(lay:GetAttribute("w1") == 1361 and lay:GetAttribute("h1") == 768, "the box with the pane open is the style's")
Check(lay:GetAttribute("cw1") == 1035, "the game's own width with the pane is read from the map")
Check(made == 4, "a shelf and three watchers: map, toggle and quest pane (made " .. made .. ")")
local watchers = ns.MapFight.Watchers()
local pane = false
for _, parent in pairs(watchers) do
    if parent == map.QuestLog then pane = true end
end
Check(pane, "one watcher hangs under the quest pane")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("map_fight_scale_test: ok")
