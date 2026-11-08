-- Offline test under Lua 5.4: What's New is per client (Options/WhatsNewList.lua, filtered in Options/Welcome.lua).
-- An entry marked on = "forever" or on = "retail" shows on that client alone, and a version with no entry for a
-- client is skipped whole there: no chat line, no section. The list is cut out of its file and run with the filter.
-- Run from the addon root: lua tools/tests/whats_new_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Source(path)
    local handle = assert(io.open(ROOT .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
local list, welcome = Source("/Options/WhatsNewList.lua"), Source("/Options/Welcome.lua")

-- The list from its file, then the filter after the list's handle, as the files have them.
local listFrom = assert(list:find("ns.WHATSNEW = {", 1, true), "the list is in its file")
local from = assert(welcome:find("local WHATSNEW = ns.WHATSNEW", 1, true), "the filter takes the list")
local to = assert(welcome:find("local GOLD, GREY", from, true), "the filter ends before the colours")
local chunk = list:sub(listFrom) .. "\n" .. welcome:sub(from, to - 1)

local function Load(forever)
    local L = setmetatable({}, { __index = function(_, key) return key end })
    local ns = { OnForever = function() return forever end }
    local run = assert(load(chunk .. "\nreturn WHATSNEW, NEWS, LATEST", "whatsnew", "t", { L = L, ns = ns, ipairs = ipairs }))
    return run()
end

-- Every mark in the real list names a client.
local all = Load(true)
for _, section in ipairs(all) do
    for index, entry in ipairs(section) do
        Check(entry.on == nil or entry.on == "forever" or entry.on == "retail",
            string.format("%s entry %d: on is forever, retail or absent (%s)", section.version, index, tostring(entry.on)))
    end
end

-- The filter, on a list of its own: three versions, the newest retail only, the middle one Forever only.
local sample = [[
local WHATSNEW = {
    { id = 3, version = "3", { "a", "b", on = "retail" } },
    { id = 2, version = "2", { "c", "d", on = "forever" }, { "e", "f" } },
    { id = 1, version = "1", { "g", "h" } },
}
]]
local filter = chunk:sub((chunk:find("local LATEST", 1, true)))
local function Sample(forever)
    local ns = { OnForever = function() return forever end }
    return assert(load(sample .. filter .. "\nreturn NEWS, LATEST", "sample", "t", { ns = ns, ipairs = ipairs }))()
end
local forever, latest = Sample(true)
Check(latest == 3, "the newest id is the same on both clients")
Check(#forever == 2 and forever[1].id == 2, "Forever skips a version that is retail only")
Check(#forever[1] == 2, "Forever keeps its own entry and the shared one")
local retail = Sample(false)
Check(#retail == 3 and retail[1].id == 3, "retail shows its own version")
Check(#retail[2] == 1 and retail[2][1][1] == "e", "retail drops the Forever entry of a shared version")

print(failures == 0 and "whats_new_test: ok" or ("whats_new_test: " .. failures .. " failed"))
if failures > 0 then os.exit(1) end
