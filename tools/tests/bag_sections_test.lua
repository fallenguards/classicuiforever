-- Offline test under Lua 5.4 for the one bag's sections (Windows/BagSections.lua): by bag type, the key ring is a
-- section of its own though the game gives it a plain bag's type (#201, it shared the last bag's rows); by bag too.
-- Run from the addon root: lua tools/tests/bag_sections_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
Enum = { BagIndex = { ReagentBag = 5, Keyring = -2 } }
-- Every bag a plain one (family 0), the key ring included, as Forever answers.
C_Container = { GetContainerNumFreeSlots = function() return 0, 0 end }

local ns = { db = {}, bags = { BagSlotButtons = function() return {} end } }
assert(loadfile(ROOT .. "/Windows/BagSections.lua"))("ClassicUIForever", ns)
local B = ns.bags

local function Slot(bag) return { GetBagID = function() return bag end } end

-- The slot list runs foot to top: the key ring's first, then the bags'.
local function List()
    local list = { Slot(-2), Slot(-2) }
    for _ = 1, 6 do list[#list + 1] = Slot(1) end
    return list, #list
end

ns.db.oneBagSplitType = true
local list, count = List()
Check(B.SectionRows(list, count, 4) == 3, "by bag type: six bag slots and two keys in four columns take 3 rows "
    .. "(the keys a row of their own)")

ns.db.oneBagSplitType, ns.db.oneBagSplitBag = false, true
list, count = List()
Check(B.SectionRows(list, count, 4) == 3, "by bag: the keys a row of their own")

ns.db.oneBagSplitBag = false
list, count = List()
Check(B.SectionRows(list, count, 4) == 2, "no sections: the keys follow the last bag's slots")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bag_sections_test: all checks passed")
