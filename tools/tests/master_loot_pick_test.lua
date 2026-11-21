-- Offline test under Lua 5.4 for a master looter's click on the classic loot window (Windows/LootRows.lua). The game's
-- list of who may take an item reads the clicked slot, row and item off its loot window, as its own rows leave them
-- (GroupLootFrame.lua: GetMasterLootCandidate(LootFrame.selectedSlot, i)); ours left none, so the names never showed
-- (CurseForge reports, 2026-11-21). A click sets them before looting, as the game's own row does.
-- Run from the addon root: lua tools/tests/master_loot_pick_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Region()
    local r = {}
    setmetatable(r, { __index = function() return function() end end })
    return r
end
local function Row()
    local row = { scripts = {} }
    function row.SetScript(self, name, fn) self.scripts[name] = fn end
    function row.CreateFontString() return Region() end
    function row.CreateTexture() return Region() end
    setmetatable(row, { __index = function() return function() end end })
    return row
end

local SLOTS = {
    { "icon1", "Linen Cloth", 2, nil, 1 },
    { "icon2", "Thunderfury", 1, nil, 5 },
}
local calls = {}
local function Note(what) calls[#calls + 1] = what end
local modified = false
local pickedAtLoot

LootFrame = {}
GetNumLootItems = function() return #SLOTS end
GetLootSlotInfo = function(slot) local s = SLOTS[slot] if s then return s[1], s[2], s[3], s[4], s[5] end end
GetLootSlotLink = function(slot) return "link" .. slot end
SetItemButtonTexture, SetItemButtonCount, SetItemButtonQuality = function() end, function() end, function() end
SetItemButtonTextureVertexColor, SetItemButtonNormalTextureVertexColor = function() end, function() end
ColorManager = { GetColorDataForItemQuality = function() return nil end }
Enum = { ItemQuality = { Common = 1 }, LootSlotType = { Item = 1 } }
IsModifiedClick = function() return modified end
HandleModifiedItemClick = function(link) Note("modified " .. link) end
StaticPopup_Hide = function(which) Note("hide " .. which) end
LootSlot = function(slot)
    pickedAtLoot = LootFrame.selectedSlot
    Note("loot " .. slot)
end
GameTooltip = { IsOwned = function() return false end }
local assignShown = true
MasterLooterFrame = { IsShown = function() return assignShown end, Hide = function() assignShown = false Note("assign closed") end }

local made = {}
local ns = {
    NewFrame = function()
        local row = Row()
        made[#made + 1] = row
        return row
    end,
    DressNew = function() end,
}
assert(loadfile(ROOT .. "/Windows/LootRows.lua"))("ClassicUIForever", ns)
ns.FillLootRows({}, 0, 4)

local row = made[2]
Check(row ~= nil and row.slot == 2, "the second row holds slot 2")
local click = row and row.scripts.OnClick
Check(type(click) == "function", "a row answers a click")
if type(click) ~= "function" then
    print(failed .. " check(s) failed")
    os.exit(1)
end

click(row, "LeftButton")
Check(LootFrame.selectedSlot == 2 and LootFrame.selectedLootFrame == row, "the clicked slot and row are on the loot window")
Check(LootFrame.selectedItemName == "Thunderfury" and LootFrame.selectedQuality == 5
    and LootFrame.selectedTexture == "icon2" and LootFrame.selectedItemLink == "link2",
    "the item's name, quality, icon and link are there for the Assign Loot window")
Check(pickedAtLoot == 2, "they are set before looting (the server's list answers the loot)")
Check(table.concat(calls, "|") == "hide CONFIRM_LOOT_DISTRIBUTION|loot 2|assign closed",
    "as the game's row: the confirm box closes, the slot is looted, the last Assign Loot window closes")

-- A modified click links the item and picks nothing.
calls = {}
modified = true
made[1].scripts.OnClick(made[1], "LeftButton")
Check(table.concat(calls, "|") == "modified link1", "a modified click links the item, nothing looted")
Check(LootFrame.selectedSlot == 2, "a modified click leaves the last pick")

-- The Assign Loot window hangs on the loot window (GroupLootFrame.xml parent="LootFrame"): our skin's fade of the
-- game's art on that window and its children kept it unseen, the first name blank (the probe's empty click, 2026-11-21).
local loot = assert(io.open(ROOT .. "/Windows/Loot.lua")):read("a")
local skin = loot:match("local function SkinLoot%(frame%)\n(.-)\nend\n") or ""
local kept = skin:find("local assign = _G.MasterLooterFrame", 1, true)
local guard = skin:find("if assign then keep[assign] = true end", 1, true)
local fade = skin:find("FadeBlizzardArt(frame, keep)", 1, true)
Check(kept and guard and fade and kept < guard and guard < fade, "the loot skin keeps the Assign Loot window out of its fade")

-- Era's Assign Loot window (LootFrame.xml): a tooltip box, no title, the item 13 down, the first name 53 down, under
-- the clicked row; Forever's titled panel showed over it (2026-11-21).
local era = loot:match("local function EraAssignLoot%(%)\n(.-)\nend\n") or ""
Check(loot:find("local ASSIGN_ITEM_X, ASSIGN_ITEM_Y, ASSIGN_ITEM_RIGHT = -9, -13, -30", 1, true) ~= nil
    and loot:find("local ASSIGN_FIRST_X, ASSIGN_FIRST_Y = 8, -53", 1, true) ~= nil, "the item and first name at Era's spots")
Check(era:find("ns.TipRim(assign, 0, 0, 0, 0)", 1, true) ~= nil, "the window is Era's tooltip box, with the theme")
Check(loot:find('local ASSIGN_PANEL = { "NineSlice", "Bg", "TopTileStreaks", "TitleContainer" }', 1, true) ~= nil,
    "Forever's panel art and title are faded")
Check(era:find('ns.HookGlobal("MasterLooterFrame_Show", AssignUnderRow)', 1, true) ~= nil
    and loot:find('ns.SetPointIf(assign, "TOPLEFT", row, "BOTTOMLEFT", 0, 0)', 1, true) ~= nil,
    "the window opens under the clicked row")
Check(skin:find("EraAssignLoot()", 1, true) ~= nil, "the loot skin dresses it")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("master_loot_pick_test: ok")
