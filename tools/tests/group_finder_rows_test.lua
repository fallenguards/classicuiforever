-- Offline test under Lua 5.4 for the two "Group finder" options (Options/Toggles.lua). All windows' row dresses only the
-- game's window and yields to Social's (Windows/Panels.lua off = "groupFinder"), which holds the whole window: unchecking
-- the first with the second on left the classic finder up (his snip 17:50). The first is hidden while Social's is on, as
-- Collections' is while our collections window is.
-- Run from the addon root: lua tools/tests/group_finder_rows_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local StubMT = {}
local function Stub() return setmetatable({}, StubMT) end
StubMT.__index = function() return function() return Stub() end end
StubMT.__call = function() return Stub() end

local L = setmetatable({}, { __index = function(_, key) return key end })
local ns = setmetatable({ L = L, ART = { CHECK = "check" }, EMPTY = {}, db = {}, ENGLISH_CLIENT = true },
    { __index = function() return function() return Stub() end end })
ns.OnForever = function() return true end
ns.NewFrame = function() return Stub() end
ns.PACKAGE = false
GameTooltip, MenuUtil, SOUNDKIT = Stub(), Stub(), {}
assert(loadfile(ROOT .. "/Options/Toggles.lua"))("ClassicUIForever", ns)

local row
for _, entry in ipairs(ns.TOGGLES) do
    if entry[1] == "panelGroupFinder" then row = entry end
end
Check(row ~= nil, "All windows has its Group finder row")
local function Hidden() return row ~= nil and row.hideIf ~= nil and row.hideIf() == true end
ns.db.groupFinder = nil
Check(Hidden(), "hidden while Social's Group finder is on by default")
ns.db.groupFinder = true
Check(Hidden(), "hidden while Social's Group finder is checked")
ns.db.groupFinder = false
Check(row ~= nil and not Hidden(), "shown once Social's Group finder is off: it dresses the game's window then")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("group_finder_rows_test: ok")
