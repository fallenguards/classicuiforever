local _, ns = ...

-- Which pieces a theme paints (the Parts drop down under the theme): a piece's part by the frames it sits in, anything
-- else the other windows'. Parchment is a kind, not a place: its layers and pages ask for it by name.

local weak = { __mode = "k" }
local DEPTH = 16

-- A finder of a piece's part (roots: part -> frame names; names: { pattern, part } families by frame name; other: the
-- part of anything else; orphan: of a piece hanging from no window, as the game's menus), worked out once a piece and
-- again after an addon loads (its frames are new).
function ns.PartFinder(roots, names, other, orphan)
    local parts, rootPart = setmetatable({}, weak), setmetatable({}, weak)
    local stale = true
    ns.EventFrame("ADDON_LOADED", function() stale = true end)
    local function Named(frame)
        local name = names and frame.GetName and frame:GetName()
        if type(name) ~= "string" or ns.IsSecret(name) then return nil end
        for _, family in ipairs(names) do
            if name:find(family[1]) then return family[2] end
        end
    end
    return function(region)
        if stale then
            stale = false
            wipe(parts)
            for part, list in pairs(roots) do
                for _, name in ipairs(list) do
                    if _G[name] then rootPart[_G[name]] = part end
                end
            end
        end
        local part = parts[region]
        if part then return part end
        local frame = region
        for _ = 1, DEPTH do
            if not frame or frame == UIParent or ns.IsForbidden(frame) then break end
            part = rootPart[frame] or Named(frame)
            if part then break end
            local parent = frame:GetParent()
            if not parent then
                part = orphan
                break
            end
            frame = parent
        end
        part = part or other
        parts[region] = part
        return part
    end
end

-- The band's frames; Textured color's Bar art part reads them too (Art/ThemeFlat.lua).
ns.BAR_ROOTS = { "ForeverClassicUIBar", "ForeverClassicUIMicroGroup", "ForeverClassicUIBagsExtra", "MainActionBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
    "StanceBar", "PetActionBar", "PossessActionBar", "BagsBar", "MicroMenuContainer", "StatusTrackingBarManager" }
local OTHER = "themePartWindows"
-- A bag bar button's picture (Forever's backpack and key ring, the bags, the reagent bag): Bag icons, apart from its
-- border. Art/GameArt.lua too.
ns.BAG_ICONS = { "Bag%dSlotIconTexture$", "^MainMenuBarBackpackButtonIconTexture$", "^KeyRingButtonIconTexture$" }
-- Every bag, chat window with its tab and box, nameplate; the micro and bag buttons the band takes onto its art.
local FAMILIES = { { ns.BAG_ICONS[1], "themePartBagIcons" }, { ns.BAG_ICONS[2], "themePartBagIcons" },
    { ns.BAG_ICONS[3], "themePartBagIcons" }, { "^ContainerFrame%d", "themePartBags" }, { "^ChatFrame%d", "themePartChat" },
    { "^NamePlate%d", "themePartNameplates" }, { "MicroButton", "themePartMicroMenu" },
    { "^CharacterBag%dSlot", "themePartBagBar" }, { "^CharacterReagentBag%dSlot", "themePartBagBar" },
    { "^MainMenuBarBackpackButton", "themePartBagBar" }, { "^KeyRingButton", "themePartBagBar" },
    { "^BagBarExpandToggle", "themePartBagBar" } }
-- The band's action bars: its frames but the micro menu, bag bar and XP bars, each a part of its own.
local OWN_PART = { BagsBar = true, MicroMenuContainer = true, StatusTrackingBarManager = true,
    ForeverClassicUIMicroGroup = true, ForeverClassicUIBagsExtra = true }
local ACTION_ROOTS = {}
for _, name in ipairs(ns.BAR_ROOTS) do
    if not OWN_PART[name] then ACTION_ROOTS[#ACTION_ROOTS + 1] = name end
end
-- The nearest root up a piece's frames wins: a target's cast bar before its unit frame.
local PartOf = ns.PartFinder({
    themePartUnits = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "TargetFrameToT",
        "FocusFrameToT", "BossTargetFrameContainer" },
    themePartCastBars = { "PlayerCastingBarFrame", "PetCastingBarFrame", "TargetFrameSpellBar", "FocusFrameSpellBar",
        "OverlayPlayerCastingBarFrame" },
    themePartMinimap = { "MinimapCluster", "Minimap", "QueueStatusButton", "ForeverClassicUIMinimapBag", "GameTimeFrame",
        "TimeManagerClockButton" },
    themePartBars = ACTION_ROOTS,
    themePartMicroMenu = { "MicroMenuContainer", "ForeverClassicUIMicroGroup" },
    themePartBagBar = { "BagsBar", "ForeverClassicUIBagsExtra" },
    themePartXPBars = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" },
    themePartBags = { "ContainerFrameCombinedBags", "BankFrame" },
    themePartTooltips = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" },
    themePartChat = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" },
    themePartQuestTracker = { "ObjectiveTrackerFrame", "ForeverClassicUIQuestWatch" },
}, FAMILIES, OTHER, "themePartMenus")
-- A piece of ours in another part than where it hangs (the backpack's bag picture, Bag icons on its button).
local pinned = setmetatable({}, weak)
function ns.PinThemePart(region, part) pinned[region] = part end
-- Read by the dev addon's theme probes.
function ns.ThemePartOf(region) return pinned[region] or PartOf(region) end

-- Each part's row; a theme change repaints on it as on any theme setting.
local PART_KEYS = { themePartParchment = true, themePartUnits = true, themePartCastBars = true,
    themePartNameplates = true, themePartMinimap = true, themePartBars = true, themePartMicroMenu = true,
    themePartBagBar = true, themePartBagIcons = true, themePartXPBars = true, themePartBags = true,
    themePartTooltips = true, themePartMenus = true, themePartChat = true, themePartQuestTracker = true, [OTHER] = true }
for key in pairs(PART_KEYS) do ns.bronze.THEME_KEYS[key] = true end
function ns.IsThemePart(key) return PART_KEYS[key] == true end

-- dbVersion 29: the parts split finer; each new one starts as the part it came out of.
local SPLIT_FROM = { themePartMicroMenu = "themePartBars", themePartBagBar = "themePartBars",
    themePartXPBars = "themePartBars", themePartCastBars = "themePartUnits", themePartNameplates = "themePartUnits",
    themePartMenus = "themePartTooltips", themePartQuestTracker = "themePartWindows" }
local function Split(db)
    for new, old in pairs(SPLIT_FROM) do
        if db[new] == nil and db[old] == false then db[new] = false end
    end
end
function ns.SplitThemeParts()
    local db = ns.db
    Split(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Split(shot) end
    end
    db.dbVersion = 29
end

-- where: a region, or a part's key (a module that paints no region of its own: menus, chat buttons); nil: any part.
function ns.ThemePartOn(where)
    local db = ns.db
    if not db or where == nil then return true end
    if type(where) == "string" then return db[where] ~= false end
    return db[ns.ThemePartOf(where)] ~= false
end

-- The theme on for this piece, or nil: none picked, or its part left out. No piece: the theme on at all.
function ns.ThemeFor(where)
    local name = ns.ThemeName()
    if name and ns.ThemePartOn(where) then return ns.bronze.THEMES[name] end
end
