-- Offline test under Lua 5.4: the FAQ is per client (Options/HelpPanes.lua). Each entry marked on = "forever" or
-- on = "retail" is left out on the other client, and every entry's question and answer take exactly the values its
-- functions hand them, in every locale (a count off by one is a format error in game).
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
local from = assert(source:find("local FAQ = {", 1, true), "the list is in the file")
local to = assert(source:find("local function Pane", from, true), "the filter ends before the pane")
local chunk = source:sub(from, to - 1)

local function Load(forever)
    local L = setmetatable({}, { __index = function(_, key) return key end })
    local env = { L = L, ns = { OnForever = function() return forever end }, table = table, _G = {},
        KeyOf = function() return "key" end, RecentAllies = function() return "allies" end,
        G = function(name) return name end, Before = function(text) return text end, After = function(text) return text end }
    return assert(load(chunk .. "\nreturn FAQ", "faq", "t", env))()
end

local function Keys(list)
    local seen = {}
    for _, item in ipairs(list) do seen[item[2]] = item end
    return seen
end
local forever, retail = Keys(Load(true)), Keys(Load(false))

-- What each client must and must not show.
Check(forever.FAQ_LEGACY_A and not retail.FAQ_LEGACY_A, "the Legacy button is Forever's alone")
Check(forever.FAQ_FOREVER_A and not retail.FAQ_FOREVER_A, "Forever's own look is asked on Forever alone")
Check(retail.FAQ_OWNLOOK_A and not forever.FAQ_OWNLOOK_A, "the game's own look is asked on retail alone")
Check(retail.FAQ_QUICKJOIN_A and not forever.FAQ_QUICKJOIN_A, "the Quick Join tab is retail's alone")
Check(retail.FAQ_RETAILBUTTONS_A and not forever.FAQ_RETAILBUTTONS_A, "retail's own micro buttons are retail's alone")
Check(forever.FAQ_LFG_A and not retail.FAQ_LFG_A and retail.FAQ_LFG_RETAIL_A, "each client has its own group finder answer")
Check(forever.FAQ_REAGENT_A and not retail.FAQ_REAGENT_A and retail.FAQ_REAGENT_RETAIL_A, "each client has its own reagent bag answer")
for _, shared in ipairs({ "FAQ_PROFESSIONS_A", "FAQ_COLLECTIONS_A", "FAQ_BARS_A", "FAQ_MOVE_A", "FAQ_SETTING_A", "FAQ_OTHER_ADDON_A",
    "FAQ_TENBUTTONS_A", "FAQ_GRYPHONS_A", "FAQ_XPBAR_A", "FAQ_SIZE_A", "FAQ_GLOW_A", "FAQ_TRACKER_A", "FAQ_PLATES_A" }) do
    Check(forever[shared] and retail[shared], shared .. " shows on both clients")
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
    for _, list in ipairs({ Load(true), Load(false) }) do
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
