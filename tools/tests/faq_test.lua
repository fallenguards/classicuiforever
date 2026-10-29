-- Offline test under Lua 5.4: the FAQ is per client and per copy (Options/HelpPanes.lua). An entry marked on = "forever"
-- or on = "retail" is left out on the other client; a standalone package shows only answers whose settings it keeps,
-- the first fitting answer to each question; every entry's question and answer take exactly the values its functions
-- hand them, in every locale (a count off by one is a format error in game).
-- Run from the addon root: lua tools/tests/faq_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

local function Read(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end

-- A locale file's FAQ strings.
local function Strings(path)
    local out = {}
    for key, value in Read(path):gmatch('L%["(FAQ_[%w_]+)"%] = "(.-)"\r?\n') do out[key] = value end
    return out
end

local source = Read("Options/HelpPanes.lua")
local from = assert(source:find("local function MicroKey", 1, true), "the list's helpers are in the file")
local to = assert(source:find("local function Pane", from, true), "the filter ends before the pane")
local chunk = source:sub(from, to - 1)

-- The shown list on a client, for the full addon (kept nil) or a package keeping these settings and modules.
local function Load(forever, kept, piece)
    local L = setmetatable({}, { __index = function(_, key) return key end })
    local ns = { OnForever = function() return forever end, EMPTY = {} }
    if kept then
        local set = {}
        for _, key in ipairs(kept) do set[key] = true end
        ns.PACKAGE = { piece = piece }
        ns.PackageRuns = function(key) return set[key] == true end
    else
        ns.PackageRuns = function() return true end
    end
    local env = { L = L, ns = ns, table = table, ipairs = ipairs, _G = {},
        KeyOf = function() return "key" end, RecentAllies = function() return "allies" end,
        G = function(name) return name end, Before = function(text) return text end, After = function(text) return text end }
    return assert(load(chunk .. "\nreturn Shown()", "faq", "t", env))()
end

-- Question to answer.
local function Answers(list)
    local out = {}
    for _, item in ipairs(list) do
        Check(out[item[1]] == nil, item[1] .. " asked once")
        out[item[1]] = item[2]
    end
    return out
end

local ACTION_BARS = { "classicBar", "classicBarSize", "hideGryphonLeft", "hideMicroButtons", "hideMicroGroupFinder",
    "hideMicroLegacy", "hideProfessionsButton", "hideMicroCollections", "hideMicroAchievements", "minimapButton", "showBags",
    "reagentBagSlot", "hideBagsArt", "classicFonts" }
local loads = {}
local function Copy(name, forever, kept, piece)
    local list = Load(forever, kept, piece)
    loads[#loads + 1] = list
    return Answers(list), name
end

local forever = Copy("full forever", true)
local retail = Copy("full retail", false)

-- The full addon: each client's own answers, no standalone question.
Check(forever.FAQ_LEGACY_Q == "FAQ_LEGACY_A" and not retail.FAQ_LEGACY_Q, "the Legacy button is Forever's alone")
Check(forever.FAQ_FOREVER_Q and not retail.FAQ_FOREVER_Q, "Forever's own look is asked on Forever alone")
Check(retail.FAQ_OWNLOOK_Q and not forever.FAQ_OWNLOOK_Q, "the game's own look is asked on retail alone")
Check(retail.FAQ_QUICKJOIN_Q and not forever.FAQ_QUICKJOIN_Q, "the Quick Join tab is retail's alone")
Check(retail.FAQ_RETAILBUTTONS_Q == "FAQ_RETAILBUTTONS_A" and not forever.FAQ_RETAILBUTTONS_Q,
    "retail's own micro buttons are retail's alone")
Check(forever.FAQ_LFG_Q == "FAQ_LFG_A" and retail.FAQ_LFG_Q == "FAQ_LFG_RETAIL_A", "each client has its own group finder answer")
Check(forever.FAQ_REAGENT_Q == "FAQ_REAGENT_A" and retail.FAQ_REAGENT_Q == "FAQ_REAGENT_RETAIL_A",
    "each client has its own reagent bag answer")
Check(not forever.FAQ_SUITE_Q and not retail.FAQ_SUITE_Q, "the full addon does not ask what it is")
Check(not forever.FAQ_BARS_Q, "bars 6 to 8 are the game's own, no question")
for _, shared in ipairs({ "PROFESSIONS", "COLLECTIONS", "MOVE", "MOVERS", "SETTING", "OTHER_ADDON", "TENBUTTONS",
    "GRYPHONS", "XPBAR", "SIZE", "SCALE", "SCALEBACK", "GLOW", "TRACKER", "PLATES" }) do
    local q = "FAQ_" .. shared .. "_Q"
    Check(forever[q] == "FAQ_" .. shared .. "_A" and retail[q] == forever[q], q .. " shows its full answer on both clients")
end

-- Action Bars: the bar's own questions; micro buttons answered with their keys alone (no minimap or spellbook here).
for _, client in ipairs({ true, false }) do
    local bars = Copy("action bars", client, ACTION_BARS, true)
    local name = client and "forever" or "retail"
    Check(bars.FAQ_SUITE_Q == "FAQ_SUITE_A", name .. " action bars: says what ClassicUI Forever is")
    for _, q in ipairs({ "FAQ_LFG_Q", "FAQ_PROFESSIONS_Q", "FAQ_COLLECTIONS_Q" }) do
        Check(bars[q] == "FAQ_MICRO_KEY_A", name .. " action bars: " .. q .. " answered by its key")
    end
    Check(bars.FAQ_LEGACY_Q == (client and "FAQ_MICRO_OFF_A" or nil), name .. " action bars: Legacy without the minimap")
    Check(bars.FAQ_RETAILBUTTONS_Q == (not client and "FAQ_RETAILBUTTONS_KEY_A" or nil),
        name .. " action bars: retail's buttons by their keys")
    for _, q in ipairs({ "FAQ_TENBUTTONS_Q", "FAQ_GRYPHONS_Q", "FAQ_XPBAR_Q", "FAQ_SCALE_Q", "FAQ_SCALEBACK_Q",
        "FAQ_SETTING_Q", "FAQ_OTHER_ADDON_Q", "FAQ_REAGENT_Q" }) do
        Check(bars[q], name .. " action bars: asks " .. q)
    end
    for _, q in ipairs({ "FAQ_GLOW_Q", "FAQ_TRACKER_Q", "FAQ_PLATES_Q", "FAQ_MOVE_Q", "FAQ_MOVERS_Q", "FAQ_SIZE_Q",
        "FAQ_QUICKJOIN_Q" }) do
        Check(not bars[q], name .. " action bars: no " .. q)
    end
end

-- A piece with no question of its own: what it is, and the general ones.
local function Only(answers, want, name)
    local got = {}
    for q in pairs(answers) do got[#got + 1] = q end
    table.sort(got)
    table.sort(want)
    Check(table.concat(got, " ") == table.concat(want, " "), name .. " shows " .. table.concat(want, " ") .. ", got "
        .. table.concat(got, " "))
end
Only(Copy("chat", true, { "classicChat", "minimapButton" }, true),
    { "FAQ_SUITE_Q", "FAQ_SETTING_Q", "FAQ_FOREVER_Q", "FAQ_OTHER_ADDON_Q" }, "chat")
Only(Copy("quests", false, { "questLog", "questTracker", "panelQuest", "panelGossip", "minimapButton" }, true),
    { "FAQ_SUITE_Q", "FAQ_MOVE_Q", "FAQ_TRACKER_Q", "FAQ_SETTING_Q", "FAQ_OWNLOOK_Q", "FAQ_OTHER_ADDON_Q" }, "quests")
-- The color picker: its own answer, nothing about classic pieces.
local picker = Copy("picker", true, { "bronzeTheme", "minimapButton" }, false)
Only(picker, { "FAQ_SUITE_Q", "FAQ_SETTING_Q", "FAQ_OTHER_ADDON_Q" }, "picker")
Check(picker.FAQ_SUITE_Q == "FAQ_SUITE_PICKER_A", "the picker says where it was first made")

-- Every setting or module an answer depends on exists.
local known = {}
for key in Read("Options/Toggles.lua"):gmatch('{ "(%w+)", L%[') do known[key] = true end
for file in Read("ClassicUIForever.toc"):gmatch("([%w\\/_]+%.lua)") do
    local ok, text = pcall(Read, (file:gsub("\\", "/")))
    if ok then
        for name in text:gmatch('ns%.RegisterModule%("(%w+)"') do known[name] = true end
    end
end
for list in chunk:gmatch("needs = (%b{})") do
    for key in list:gmatch('"(%w+)"') do Check(known[key], "needs " .. key .. " is a setting or module") end
end
for key in chunk:match("local LOCKED = (%b{})"):gmatch('"(%w+)"') do
    Check(known[key], "LOCKED " .. key .. " is a setting or module")
end

-- Every string takes as many values as its entry hands it.
local function Count(text)
    local n = 0
    for _ in text:gmatch("%%s") do n = n + 1 end
    return n
end
local english = Strings("Locales/enUS_Help.lua")
for _, path in ipairs({ "Locales/enUS_Help.lua", "Locales/deDE_Help.lua", "Locales/esES_Help.lua", "Locales/frFR_Help.lua",
    "Locales/itIT_Help.lua" }) do
    local strings = Strings(path)
    for _, list in ipairs(loads) do
        for _, item in ipairs(list) do
            local question, answer = strings[item[1]], strings[item[2]]
            Check(question ~= nil and answer ~= nil, path .. " has " .. item[1] .. " and " .. item[2])
            if question and answer then
                local asked = item.ask and select("#", item.ask()) or Count(english[item[1]])
                local given = item[3] and select("#", item[3]()) or 0
                Check(Count(question) == asked, path .. " " .. item[1] .. " takes " .. asked .. " values")
                Check(Count(answer) == given, path .. " " .. item[2] .. " takes " .. given .. " values")
            end
        end
    end
end

print(failures == 0 and "faq_test: ok" or ("faq_test: " .. failures .. " failed"))
if failures > 0 then os.exit(1) end
