-- Offline test under Lua 5.4 for the spellbook's options arrow (Spells/SpellBook.lua ns.SpellBookOptionsSpot). It stood
-- left of the search box; with the search hidden (its option off, or What's Training's page up) it floated mid-page
-- (his snip 17:09). Beside a shown search box; at the box's right end while it is hidden.
-- Run from the addon root: lua tools/tests/book_options_spot_test.lua (CI runs every tools/tests/*_test.lua).
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

local ns = Any()
rawset(ns, "SetPointOnce", function(f, point, rel, relPoint, x, y) f.point = { point, rel, relPoint, x, y } end)
local env = setmetatable({}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local handle = assert(io.open(ROOT .. "/Spells/SpellBook.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Spells/SpellBook.lua", "t", env))("ClassicUIForever", ns)

local search = { shown = true }
function search:IsShown() return self.shown end
local options = {}
local spot = rawget(ns, "SpellBookOptionsSpot")
Check(type(spot) == "function", "the options arrow's spot is laid by one function")
if type(spot) == "function" then
    spot(options, search)
    local p = options.point
    Check(p and p[1] == "RIGHT" and p[2] == search and p[3] == "LEFT", "beside a shown search box")
    search.shown = false
    spot(options, search)
    p = options.point
    Check(p and p[1] == "RIGHT" and p[2] == search and p[3] == "RIGHT" and p[4] == 0,
        "at the search box's right end while it is hidden, not mid-page")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("book_options_spot_test: ok")
