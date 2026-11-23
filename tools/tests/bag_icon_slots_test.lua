-- Offline test under Lua 5.4 for the one bag's empty slots (Windows/BagEmptySlots.lua ns.BagEmptyLook). Forever's combined bag shows
-- each empty slot with its bag's icon, faded (EmptyBagIcon), so a hunter sees which slots are the quiver's (#334); we
-- hid it on every update. Unchecked Plain empty slots, the icon shows as the game's; checked, every empty slot is the
-- sheet's socket alone. Separate bags never show it (the game asks only its combined bag).
-- Run from the addon root: lua tools/tests/bag_icon_slots_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
local bags = Source("Windows/Bags.lua")

local db = {}
local ns = { db = db }
assert(loadfile(ROOT .. "/Windows/BagEmptySlots.lua"))("ClassicUIForever", ns)
local EmptyLook = ns.BagEmptyLook
Check(bags:find("local EmptyLook = ns.BagEmptyLook", 1, true) ~= nil
    and bags:find('hooksecurefunc(button, "SetItemButtonTexture", EmptyLook)', 1, true) ~= nil,
    "the bags hook every slot's paint with it")

-- Textures as the game's: shown flag, file, alpha.
local function Texture()
    local t = { shown = true, alpha = 1 }
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:SetShown(on) self.shown = on and true or false end
    function t:IsShown() return self.shown end
    function t:SetTexture(file) self.file = file end
    function t:GetTexture() return self.file end
    function t:SetAlpha(a) self.alpha = a end
    function t:SetVertexColor() end
    function t:SetDesaturation() end
    return t
end

-- ContainerFrameItemButtonMixin's empty slot path, as Forever's Mainline ContainerFrame.lua (1940-1970) with the Camelot
-- override (ShouldUseBagIconForEmptySlot is IsCombined); the update sets hasItem, then paints, then syncs (1214-1219).
local function Slot(combined, bagFile)
    local b = { icon = Texture(), EmptyBagIcon = Texture(), combined = combined }
    b.EmptyBagIcon.shown = false
    function b:ShouldUseBagIconForEmptySlot() return self.combined end
    function b:SetItemButtonTexture(file) self.icon:SetTexture(file) end
    function b:SetAppearanceToEmptyBagSlot()
        local use = self:ShouldUseBagIconForEmptySlot()
        self.EmptyBagIcon:SetShown(use)
        if use then self.EmptyBagIcon:SetTexture(bagFile) end
        self:SetItemButtonTexture(nil)
    end
    function b:SyncAppearanceWithHasItem()
        if self.hasItem then self.EmptyBagIcon:Hide() else self:SetAppearanceToEmptyBagSlot() end
    end
    function b:Update(itemFile)
        self.hasItem = itemFile and 1 or nil
        self:SetItemButtonTexture(itemFile)
        self:SyncAppearanceWithHasItem()
    end
    -- Our hook, as SlotArt installs it (hooksecurefunc: after the game's own).
    local paint = b.SetItemButtonTexture
    b.SetItemButtonTexture = function(self, ...)
        paint(self, ...)
        EmptyLook(self)
    end
    return b
end

local QUIVER = "Interface\\Icons\\INV_Misc_Quiver_09"

-- The one bag, option unchecked: an empty quiver slot shows the quiver.
local slot = Slot(true, QUIVER)
slot:Update(nil)
Check(slot.EmptyBagIcon:IsShown() and slot.EmptyBagIcon:GetTexture() == QUIVER,
    "one bag: an empty quiver slot shows the quiver's icon, as the game's combined bag")
Check(slot.icon.alpha == 0, "one bag: the empty slot's item icon unseen (the sheet's socket under it)")

-- An arrow goes in: the bag icon goes, the item shows.
slot:Update("Interface\\Icons\\INV_Ammo_Arrow_02")
Check(not slot.EmptyBagIcon:IsShown() and slot.icon.alpha == 1, "an item in the slot: its own icon, no bag icon")
slot:Update(nil)
Check(slot.EmptyBagIcon:IsShown(), "emptied again: the quiver's icon back")

-- Plain empty slots: every empty slot alike, through the game's own updates.
db.oneBagPlainSlots = true
EmptyLook(slot)
Check(not slot.EmptyBagIcon:IsShown(), "Plain empty slots checked: the open bag's icon goes at once")
slot:Update(nil)
Check(not slot.EmptyBagIcon:IsShown(), "Plain empty slots: the game's next update keeps it off")

-- Unchecked with the bag open: our pass shows it again, as the game would, without waiting for a bag change.
db.oneBagPlainSlots = false
EmptyLook(slot)
Check(slot.EmptyBagIcon:IsShown(), "unchecked with the bag open: the quiver's icon back at once")
slot:Update("Interface\\Icons\\INV_Ammo_Arrow_02")
db.oneBagPlainSlots = false
EmptyLook(slot)
Check(not slot.EmptyBagIcon:IsShown(), "a filled slot: our pass never shows the bag icon over the item")

-- Separate bags: the game asks only its combined bag, and so do we.
local single = Slot(false, QUIVER)
single:Update(nil)
EmptyLook(single)
Check(not single.EmptyBagIcon:IsShown(), "separate bags: no bag icon on an empty slot")

-- The option row, its default and its live reskin.
local toggles, defaults = Source("Options/Toggles.lua"), Source("Core/Defaults.lua")
Check(toggles:find('{ "oneBagPlainSlots", L["OPT_oneBagPlainSlots"], L["OPT_oneBagPlainSlots_TIP"], parent = "oneBag"', 1,
    true) ~= nil, "Plain empty slots sits under One bag")
Check(defaults:find("oneBagPlainSlots = false", 1, true) ~= nil, "off by default: the bag icons show")
Check(bags:find("oneBagBagSlots = true, oneBagPlainSlots = true }", 1, true) ~= nil, "the option reskins open bags at once")
for _, lc in ipairs({ "enUS", "deDE", "esES", "frFR", "itIT" }) do
    local text = Source("Locales/" .. lc .. "_Windows.lua")
    Check(text:find('L["OPT_oneBagPlainSlots"]', 1, true) ~= nil and text:find('L["OPT_oneBagPlainSlots_TIP"]', 1, true) ~= nil,
        lc .. ": the option's name and tip")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bag_icon_slots_test: ok")
