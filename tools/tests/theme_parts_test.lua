-- Offline test under Lua 5.4 for the theme's parts (Art/ThemeParts.lua): which part a piece belongs to by the frames it
-- sits in, and that a part left out of the theme keeps the classic look while the others keep the theme.
-- Run from the addon root: lua tools/tests/theme_parts_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(what, got, want)
    if got ~= want then
        failed = failed + 1
        print(string.format("FAIL %s: got %s, want %s", what, tostring(got), tostring(want)))
    end
end

local function Frame(name, parent)
    local frame = { name = name, parent = parent }
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    if name then _G[name] = frame end
    return frame
end
local function Piece(parent) return Frame(nil, parent) end

UIParent = Frame("UIParent")
wipe = function(t) for k in pairs(t) do t[k] = nil end end
local DARK = { tint = { 0.4, 0.4, 0.4 } }
local ns = {
    db = {},
    bronze = { THEMES = { dark = DARK }, THEME_KEYS = {} },
    EventFrame = function() end,
    IsSecret = function() return false end,
    IsForbidden = function() return false end,
    ThemeName = function() return "dark" end,
}
assert(loadfile(ROOT .. "/Art/ThemeParts.lua"))("ClassicUIForever", ns)

local player = Piece(Frame("Portrait", Frame("PlayerFrame", UIParent)))
local chat = Piece(Frame("ChatFrame3", UIParent))
local tab = Piece(Frame("ChatFrame3Tab", UIParent))
local bag = Piece(Frame("ContainerFrame5", UIParent))
local ring = Piece(Frame(nil, Frame("Minimap", Frame("MinimapCluster", UIParent))))
local tip = Piece(Frame("GameTooltip", UIParent))
local bar = Piece(Frame("MultiBarLeftButton3", Frame("MultiBarLeft", UIParent)))
local window = Piece(Frame("MerchantFrame", UIParent))
local menu = Piece(Frame(nil, nil))
local micro = Piece(Frame("CharacterMicroButton", Frame("MicroMenuContainer", UIParent)))
local bandMicro = Piece(Frame("SpellbookMicroButton", Frame(nil, Frame("ForeverClassicUIBar", UIParent))))
local bagButton = Piece(Frame("CharacterBag2Slot", Frame(nil, Frame("ForeverClassicUIBar", UIParent))))
local xp = Piece(Frame(nil, Frame("MainStatusTrackingBarContainer", Frame("StatusTrackingBarManager", UIParent))))
local cast = Piece(Frame("TargetFrameSpellBar", _G.TargetFrame or Frame("TargetFrame", UIParent)))
local plate = Piece(Frame(nil, Frame("NamePlate4", UIParent)))
local tracker = Piece(Frame(nil, Frame("ObjectiveTrackerFrame", UIParent)))
local bagsBar = Piece(Frame(nil, Frame("BagsBar", UIParent)))
local microGroup = Piece(Frame(nil, Frame("ForeverClassicUIMicroGroup", UIParent)))
local bagSlot = Frame("CharacterBag1Slot", _G.BagsBar)
local bagIcon, slotRing = Frame("CharacterBag1SlotIconTexture", bagSlot), Piece(bagSlot)
local reagentIcon = Frame("CharacterReagentBag0SlotIconTexture", Frame("CharacterReagentBag0Slot", _G.BagsBar))
local packButton = Frame("MainMenuBarBackpackButton", _G.BagsBar)
local packBag, packIcon = Piece(packButton), Frame("MainMenuBarBackpackButtonIconTexture", packButton)
ns.PinThemePart(packBag, "themePartBagIcons")

Check("a unit frame's piece", ns.ThemePartOf(player), "themePartUnits")
Check("a chat window's piece", ns.ThemePartOf(chat), "themePartChat")
Check("its tab, by name", ns.ThemePartOf(tab), "themePartChat")
Check("a bag's piece", ns.ThemePartOf(bag), "themePartBags")
Check("a minimap button", ns.ThemePartOf(ring), "themePartMinimap")
Check("a tooltip", ns.ThemePartOf(tip), "themePartTooltips")
Check("an action bar button", ns.ThemePartOf(bar), "themePartBars")
Check("any other window", ns.ThemePartOf(window), "themePartWindows")
Check("a menu, hanging from no window", ns.ThemePartOf(menu), "themePartMenus")
Check("a micro button", ns.ThemePartOf(micro), "themePartMicroMenu")
Check("a micro button on the band's art, by name", ns.ThemePartOf(bandMicro), "themePartMicroMenu")
Check("a bag button on the band's art, by name", ns.ThemePartOf(bagButton), "themePartBagBar")
Check("an XP bar", ns.ThemePartOf(xp), "themePartXPBars")
Check("a target's cast bar, before its unit frame", ns.ThemePartOf(cast), "themePartCastBars")
Check("a nameplate", ns.ThemePartOf(plate), "themePartNameplates")
Check("the quest tracker", ns.ThemePartOf(tracker), "themePartQuestTracker")
Check("the bag bar's own art, never the action bars'", ns.ThemePartOf(bagsBar), "themePartBagBar")
Check("the band's micro group, never the action bars'", ns.ThemePartOf(microGroup), "themePartMicroMenu")
Check("a bag's picture, by name", ns.ThemePartOf(bagIcon), "themePartBagIcons")
Check("the reagent bag's picture", ns.ThemePartOf(reagentIcon), "themePartBagIcons")
Check("a bag slot's ring", ns.ThemePartOf(slotRing), "themePartBagBar")
Check("the backpack's bag piece, pinned", ns.ThemePartOf(packBag), "themePartBagIcons")
Check("Forever's backpack picture, by name", ns.ThemePartOf(packIcon), "themePartBagIcons")

Check("every part takes the theme by default", ns.ThemeFor(player) == DARK and ns.ThemeFor(window) == DARK, true)
ns.db.themePartUnits = false
Check("unit frames left out keep the classic look", ns.ThemeFor(player), nil)
Check("the other parts keep the theme", ns.ThemeFor(chat), DARK)
ns.db.themePartBagIcons = false
Check("Bag icons out: a bag's picture as drawn", ns.ThemeFor(bagIcon), nil)
Check("Bag icons out: the backpack's bag as drawn", ns.ThemeFor(packBag), nil)
Check("Bag icons out: the borders keep the theme", ns.ThemeFor(slotRing), DARK)
ns.db.themePartWindows = false
Check("asked of no piece: the theme is on at all", ns.ThemeFor(nil), DARK)
ns.db.themePartParchment = false
Check("parchment asked for by name", ns.ThemePartOn("themePartParchment"), false)
Check("a part's row is a theme setting", ns.bronze.THEME_KEYS.themePartChat, true)
ns.ThemeName = function() return nil end
Check("no theme picked: nothing takes it", ns.ThemeFor(chat), nil)

-- dbVersion 29: a part left out before the split leaves its new parts out too; one kept in keeps them at default.
ns.db = { themePartBars = false, themePartTooltips = true, profiles = { one = { themePartUnits = false } } }
ns.SplitThemeParts()
Check("bars out: the micro menu out", ns.db.themePartMicroMenu, false)
Check("bars out: the bag buttons out", ns.db.themePartBagBar, false)
Check("bars out: the XP bars out", ns.db.themePartXPBars, false)
Check("tooltips in: menus at their default", ns.db.themePartMenus, nil)
Check("a profile's unit frames out: its cast bars out", ns.db.profiles.one.themePartCastBars, false)
Check("a profile's unit frames out: its nameplates out", ns.db.profiles.one.themePartNameplates, false)
Check("the migration's version", ns.db.dbVersion, 29)

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("theme_parts_test: all checks passed")
