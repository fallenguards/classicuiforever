-- Offline test under Lua 5.4 for a bag slot's marks (Windows/Bags.lua ns.QuestItemLook): the quest border, the quality
-- border and a vendor's junk coin each fade by their own option and come back without it; a slot missing one is fine.
-- Run from the addon root: lua tools/tests/slot_marks_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(what, got, want)
    if got ~= want then
        failed = failed + 1
        print(string.format("FAIL %s: got %s, want %s", what, tostring(got), tostring(want)))
    end
end

local source = assert(io.open(ROOT .. "/Windows/Bags.lua")):read("a")
local first = source:find("local function Mark(region, off)", 1, true)
local last = first and select(2, source:find("\nend\n", source:find("function ns.QuestItemLook", first, true), true))
assert(first and last, "the slot marks are in Windows/Bags.lua")
local ns = { db = {} }
ns.SetAlphaIf = function(region, alpha) region.alpha = alpha end
assert(load(source:sub(first, last), "marks", "t", setmetatable({ ns = ns }, { __index = _G })))()

local function Region() return { alpha = 1 } end
local slot = { IconQuestTexture = Region(), IconBorder = Region(), JunkIcon = Region() }

ns.QuestItemLook(slot)
Check("by default the quality border shows", slot.IconBorder.alpha, 1)
Check("and the junk coin", slot.JunkIcon.alpha, 1)
ns.db.hideItemQuality = true
ns.QuestItemLook(slot)
Check("Hide quality borders fades it", slot.IconBorder.alpha, 0)
Check("the junk coin keeps its own option", slot.JunkIcon.alpha, 1)
ns.db.hideJunkCoin, ns.db.plainQuestItems = true, true
ns.QuestItemLook(slot)
Check("Hide junk coin fades it", slot.JunkIcon.alpha, 0)
Check("Plain quest items fades the quest border", slot.IconQuestTexture.alpha, 0)
ns.db.hideItemQuality = false
ns.QuestItemLook(slot)
Check("off again, the quality border is back", slot.IconBorder.alpha, 1)
ns.QuestItemLook({ IconBorder = Region() })
Check("a slot with only some marks", failed, 0)

if failed > 0 then os.exit(1) end
print("slot_marks_test: ok")
