-- Offline test under Lua 5.4: a window is either our full Era version or the game's own, never the game's window in our
-- frame art beside an Era version (his word, 2026-11-24: "they should all either be full era or not. UNLESS we don't
-- have an era version"). Collections, Legacy and the group finder have ours: All windows lists no frame-only row for
-- them (Options/Toggles.lua) and the window frames module dresses none of them (Windows/Panels.lua). Windows with no Era
-- version of ours (the auction house) keep their frame row.
-- Run from the addon root: lua tools/tests/era_only_windows_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
AnyMT.__concat = function() return "" end

-- Our full Era windows and the game windows they stand for.
local OURS = {
    { module = "collectionsWindow", frameRow = "panelCollections", frame = "CollectionsJournal" },
    { module = "legacyWindow", frameRow = "panelLegacy", frame = "LegacySystemFrame" },
    { module = "groupFinder", frameRow = "panelGroupFinder", frame = "LFGWhoListFrame", frame2 = "LFGParentFrame" },
}

-- The options' rows.
local L = setmetatable({}, { __index = function(_, key) return key end })
local ns = setmetatable({ L = L, ART = { CHECK = "check" }, EMPTY = {}, db = {}, ENGLISH_CLIENT = true },
    { __index = function() return function() return Any() end end })
ns.OnForever = function() return true end
ns.NewFrame = function() return Any() end
ns.PACKAGE = false
GameTooltip, MenuUtil, SOUNDKIT = Any(), Any(), {}
assert(loadfile(ROOT .. "/Options/Toggles.lua"))("ClassicUIForever", ns)
local rows, listed = {}, {}
for _, entry in ipairs(ns.TOGGLES) do
    rows[entry[1]] = entry
    for _, key in ipairs(type(entry.windows) == "table" and entry.windows or {}) do listed[key] = true end
end
for _, w in ipairs(OURS) do
    Check(rows[w.frameRow] == nil and not listed[w.frameRow], "All windows has no frame-only row for " .. w.frame)
    Check(listed[w.module] == true, "All windows lists our own " .. w.module)
end
Check(rows.panelAuction ~= nil, "the auction house (no Era version of ours) keeps its frame row")

-- The window frames module's list.
local pns = Any()
local P = { after = setmetatable({}, { __index = function() return function() end end }) }
rawset(pns, "panels", P)
rawset(pns, "OnForever", function() return true end)
local env = setmetatable({}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local handle = assert(io.open(ROOT .. "/Windows/Panels.lua", "r"))
local source = handle:read("a")
handle:close()
pcall(assert(load(source, "@Windows/Panels.lua", "t", env)), "ClassicUIForever", pns)
local dressed = {}
for _, entry in ipairs(type(P.WINDOWS) == "table" and P.WINDOWS or {}) do dressed[entry[1]] = entry end
Check(next(dressed) ~= nil, "the window frames module's list is read")
for _, w in ipairs(OURS) do
    Check(dressed[w.frame] == nil and (not w.frame2 or dressed[w.frame2] == nil),
        "the window frames module leaves " .. w.frame .. " to ours or the game")
end
Check(dressed.AuctionHouseFrame ~= nil, "it still frames the auction house")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("era_only_windows_test: ok")
