-- Offline test under Lua 5.4 for ClassicUI Forever Windows (UI/WindowsEditMode.lua): windows that share one place and
-- size (the spellbook's pages, an NPC's quest, gossip, merchant and trainer windows) are one row and one box, named as
-- a list of the windows ours now; that row takes a whole line after the others; a window sharing only the place (the
-- group finder) keeps its own row. The code is cut out of the files and run.
-- Run from the addon root: lua tools/tests/edit_mode_shared_rows_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
local function Cut(text, from, to)
    local first = assert(text:find(from, 1, true), "in the file: " .. from)
    local last = assert(text:find(to, first, true), "in the file: " .. to)
    return text:sub(first, last - 1)
end

local dressed, modules = {}, {}
local L = setmetatable({ UI_NAMES_JOIN = ", " }, { __index = function(_, k) return k end })
local ns = { L = L, OnForever = function() return true end, db = { worldMap = true },
    ModuleInForce = function(key) return modules[key] == true end,
    panels = { Dressing = function(key) return dressed[key] == true end } }
assert(loadfile(ROOT .. "/UI/WindowList.lua"))("ClassicUIForever", ns)
local WINDOWS = ns.WINDOW_LIST

local handles = Source("UI/WindowHandles.lua")
local mode = Source("UI/WindowsEditMode.lua")
local code = "local W = {}\n" .. Cut(handles, "local byKey = {}", "-- Its top left in UIParent units")
    .. Cut(handles, "local function Worn(entry)", "-- A choice's rows")
    .. "W.Leader, W.Worn = Leader, Worn\n"
    .. Cut(mode, "local Leader, Worn = W.Leader, W.Worn", "local function ShowPicked")
    .. Cut(mode, "local function Slots(entries)", "-- top: in the window's units")
    .. "\nreturn Folded, Leads, Label, Slots, byKey"
local env = setmetatable({ ns = ns, WINDOWS = WINDOWS, L = L, wipe = function(t) for k in pairs(t) do t[k] = nil end end },
    { __index = _G })
local Folded, Leads, Label, Slots, byKey = assert(load(code, "shared rows", "t", env))()

-- Every NPC window ours: one row listing all four.
dressed = { panelQuest = true, panelGossip = true, panelMerchant = true }
modules = { trainer = true }
Check(Label(byKey.questGiver) == "UI_QUEST_GIVER, UI_GOSSIP, UI_MERCHANT, UI_TRAINER", "the quest giver's row names all four")
for _, key in ipairs({ "gossip", "merchant", "trainer", "collections" }) do
    Check(Folded(byKey[key]), key .. ": no row or box of its own")
end
Check(not Folded(byKey.questGiver) and not Folded(byKey.spellBook), "the leaders keep their rows")
Check(Leads(byKey.questGiver) and Leads(byKey.spellBook), "the leaders take a whole line")
Check(not Leads(byKey.social) and not Folded(byKey.groupFinder), "the group finder, sharing the place alone, keeps its row")

-- A window whose restyle is off is the game's: not in the list.
dressed.panelMerchant = nil
Check(Label(byKey.questGiver) == "UI_QUEST_GIVER, UI_GOSSIP, UI_TRAINER", "the merchant's restyle off: not named")

-- The professions page follows the spellbook only with the classic professions book on.
ns.db.professionsBook = false
Check(not Folded(byKey.professions), "professions book off: professions keeps its own row")
Check(Label(byKey.spellBook) == "UI_SPELLBOOK, UI_COLLECTIONS", "professions book off: the spellbook's row names collections")
ns.db.professionsBook = true
Check(Folded(byKey.professions), "professions book on: professions shares the spellbook's row")

-- The rows: two to a line, the shared ones on whole lines after them, no two on one spot.
local listed = {}
for _, entry in ipairs(WINDOWS) do
    if not entry.section and not entry.gameEdit and not Folded(entry) then listed[#listed + 1] = entry end
end
local slots, lines = Slots(listed)
local taken, lastNarrow, firstWide = {}, -1, math.huge
for _, entry in ipairs(listed) do
    local slot = slots[entry]
    Check(slot ~= nil, entry.key .. ": has a spot")
    if slot then
        for col = slot[1], slot[3] and 1 or slot[1] do
            local spot = col .. ":" .. slot[2]
            Check(not taken[spot], entry.key .. ": its spot is free")
            taken[spot] = true
        end
        if slot[3] then firstWide = math.min(firstWide, slot[2]) else lastNarrow = math.max(lastNarrow, slot[2]) end
        Check(slot[2] < lines, entry.key .. ": within the lines counted")
    end
end
Check(lastNarrow < firstWide, "the shared rows come after the others")

-- A whole line holds the longest list in every language: about 430 of the mode window's units, kept under 60 letters.
for _, file in ipairs({ "enUS_Windows", "deDE", "esES", "frFR", "itIT" }) do
    local text = Source("Locales/" .. file .. ".lua")
    local function Word(key)
        local value = text:match('L%["' .. key .. '"%] = "(.-)"\n')
        return value or ""
    end
    local npc = table.concat({ Word("UI_QUEST_GIVER"), Word("UI_GOSSIP"), Word("UI_MERCHANT"), Word("UI_TRAINER") },
        Word("UI_NAMES_JOIN"))
    Check(Word("UI_NAMES_JOIN") == ", ", file .. ": the names joined with a comma")
    Check(#npc < 60, file .. ": the NPC windows' row fits its line (" .. #npc .. " letters)")
end

if failed > 0 then
    print(string.format("edit mode shared rows: %d failed", failed))
    os.exit(1)
end
print("edit mode shared rows: ok")
