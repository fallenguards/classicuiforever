-- Offline test under Lua 5.4 for the bars the game holds (B.GameHolds, Bar/BandPins.lua): outside edit mode a bar at
-- its default spot is the game's, which re-stacks it on every stance, target and fight change. A band pass that put
-- its empty frame back each time cost 10 to 20 ms per stance change and moved the game's right container, and the
-- objective tracker with it (#149). The band's writes to a bar frame and the watch's call for a pass skip such bars.
-- Run from the addon root: lua tools/tests/game_holds_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Read(file)
    local handle = assert(io.open(ROOT .. "/" .. file, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end

-- One function's text: from its header to the first end at the line's start.
local function Body(text, header)
    local from = text:find(header, 1, true)
    if not from then return nil end
    local to = text:find("\nend\n", from, true)
    return to and text:sub(from, to + 4) or nil
end

------------------------------------------------------------------ the rule, run

local pins = Read("Bar/BandPins.lua")
local holds = Body(pins, "function B.GameHolds(bar)")
Check(holds ~= nil, "B.GameHolds is in Bar/BandPins.lua")
local live, default = false, true
local B = {}
local env = setmetatable({
    B = B,
    ns = { EditMode = { Live = function() return live end } },
    InDefaultPosition = function() return default end,
}, { __index = _G })
local run = holds and load(holds, "game holds", "t", env)
if run then run() end
local Holds = B.GameHolds or function() return nil end
local bar = { actionButtons = {} }

Check(Holds(bar) == true, "a bar at its default spot, edit mode shut: the game's")
default = false
Check(Holds(bar) == false, "a bar the layout places (our pin or the player's): ours to lay")
default = nil
Check(Holds(bar) == false, "a bar edit mode cannot answer for: ours to lay")
default, live = true, true
Check(Holds(bar) == false, "edit mode open: ours, so its boxes are the bars")
live = false
Check(Holds({}) == false, "a frame with no buttons (the XP holders): ours, drawn pieces ride it")
Check(Holds(nil) == false, "no frame: not held")

------------------------------------------------------------------ every write to a bar frame asks first

local bars = Read("Bar/BandBars.lua")
local layout = Body(bars, "local function LayoutButtons(")
Check(layout and layout:find("local held = B.GameHolds(bar)", 1, true), "LayoutButtons asks whether the game holds the bar")
Check(layout and layout:find("if not held then MatchScale(bar, 1) end", 1, true), "LayoutButtons leaves a held bar's scale")
Check(layout and layout:find("if not held and (math.abs((bar:GetWidth()", 1, true), "LayoutButtons leaves a held bar's size")
local row = Body(bars, "local function BandRow(")
Check(row and row:find("if not B.GameHolds(bar) then Anchor(bar", 1, true), "BandRow leaves a held bar's anchor")
local side = Body(bars, "local function SideColumn(")
Check(side and side:find("if not B.GameHolds(bar) then", 1, true), "SideColumn leaves a held bar's scale and anchor")
local classic = Read("Bar/ClassicBar.lua")
Check(classic:find("if not moved and not B.GameHolds(bar) then", 1, true), "bar 1 at its default spot is left to the game")
Check(classic:find("pcall(B.HoldBandBoxes, not ns.EditMode.Live())", 1, true),
    "after each pass a held bar's box and mouse stay off the band outside edit mode")

------------------------------------------------------------------ the watch lets the game move what it holds

local watch = Read("Bar/BandWatch.lua")
local moved = Body(watch, "local function Moved(list)")
Check(moved and moved:find("and not B.GameHolds(frame)", 1, true), "the watch calls for no pass when the game moves a bar it holds")
Check(moved and moved:find("frame ~= holders[1] and frame ~= holders[2]", 1, true),
    "the game moving an XP holder calls for no full pass (its run found 14 to 25 ms of passes it called for)")
local place = Body(watch, "local function PlaceNow(fromLane)")
Check(place and place:find("if StatusMoved() then StatusBack() end", 1, true),
    "the XP holders go back on their own path, before the frame draws")
local list = Body(watch, "local function WatchList()")
Check(list and not list:find("RightManagedFrameContainer", 1, true),
    "the game's right container is not watched: nothing of ours stands on it")
Check(watch:find("if editing and B.active and not InCombatLockdown() then", 1, true),
    "opening edit mode lays the held bars under our buttons, so its boxes are the bars")

------------------------------------------------------------------ the rest of a stance change's cost

local status = Read("Bar/BandStatus.lua")
local back = Body(status, "function B.StatusBack()")
Check(back and back:find("if OnlyCarried(list) then", 1, true),
    "an XP holder only carried off goes back to its spot, its bars not dressed again (a millisecond each re-stack)")
local stats = Read("Character/CharacterStats.lua")
local queue = Body(stats, "local function QueueStats(_, event, unit)")
Check(queue and queue:find("if not PaperDollFrame:IsVisible() then", 1, true),
    "a shut character window is not refreshed on every aura (Stealth's, every buff in a fight)")
Check(queue and queue:find("PLAYER_REGEN_DISABLED", 1, true) and stats:find("ns.Sched.AfterShow(doll", 1, true),
    "a stale sheet is laid as a fight begins and as the window opens")

local cast = Read("Bar/CastAnim.lua")
local onCast = Body(cast, "local function OnCastEvent(_, event, slot)")
Check(onCast and onCast:find("StripCastingAll()", 1, true) and onCast:find('AfterPerFrame("castAnim.strip", 0, StripCastingAll)', 1, true),
    "a cast writes only the buttons playing its animation (every button's swipe on each cast slowed Stealth's frame)")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("game_holds_test: ok")
