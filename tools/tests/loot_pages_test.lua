-- Offline test under Lua 5.4 for the classic loot window's whole pages (Windows/LootRows.lua ns.LootPageOf): four rows
-- a page, three once the arrows are needed, the page clamped to the last, and a page with nothing left on it turning to
-- the next after a slot was looted, as Era's did.
-- Run from the addon root: lua tools/tests/loot_pages_test.lua (CI runs every tools/tests/*_test.lua).
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

local ns = {}
assert(loadfile(ROOT .. "/Windows/LootRows.lua"))("ClassicUIForever", ns)

local taken = {}
local function HasItem(slot) return not taken[slot] end
local function Pages(total, page, cleared)
    return ns.LootPageOf(total, page, cleared, HasItem)
end

local _
local page, rows, last, paged = Pages(3, 0, false)
Check(page == 0 and rows == 4 and last == 0 and paged == false, "three items: one page of four rows, no arrows")
rows, last, paged = select(2, Pages(4, 0, false))
Check(rows == 4 and last == 0 and paged == false, "four items fill the page without arrows")
rows, last, paged = select(2, Pages(5, 0, false))
Check(rows == 3 and last == 1 and paged == true, "five items: three a page with the arrows, two pages")
page, _, last = Pages(7, 5, false)
Check(page == 2 and last == 2, "a page past the end clamps to the last")
page = Pages(7, -1, false)
Check(page == 0, "a page before the first clamps to the first")
page, rows, last, paged = Pages(0, 3, false)
Check(page == 0 and rows == 4 and last == 0 and paged == false, "an empty loot: the first page, no arrows")

-- Slots 1 to 3 looted on a five-item loot: the first page is empty, so it turns to the second.
taken = { true, true, true }
page = Pages(5, 0, true)
Check(page == 1, "the first page with nothing left turns to the next, got " .. tostring(page))
taken = { true, true }
page = Pages(5, 0, true)
Check(page == 0, "one item left on the page: it stays")
taken = { true, true, true }
page = Pages(5, 0, false)
Check(page == 0, "no slot just looted: the page stays even when empty")
taken = { false, false, false, true, true }
page = Pages(5, 1, true)
Check(page == 1, "the last page empty stays: nothing past it")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("loot_pages_test: all checks passed")
