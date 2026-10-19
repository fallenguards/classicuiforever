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
-- Every bag, every chat window with its tab and box, every nameplate.
local FAMILIES = { { "^ContainerFrame%d", "themePartBags" }, { "^ChatFrame%d", "themePartChat" },
    { "^NamePlate%d", "themePartUnits" } }
local PartOf = ns.PartFinder({
    themePartUnits = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "TargetFrameToT",
        "FocusFrameToT", "BossTargetFrameContainer", "PlayerCastingBarFrame", "PetCastingBarFrame" },
    themePartMinimap = { "MinimapCluster", "Minimap", "QueueStatusButton", "ForeverClassicUIMinimapBag", "GameTimeFrame",
        "TimeManagerClockButton" },
    themePartBars = ns.BAR_ROOTS,
    themePartBags = { "ContainerFrameCombinedBags", "BankFrame" },
    themePartTooltips = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" },
    themePartChat = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" },
}, FAMILIES, OTHER, "themePartTooltips")
-- Read by the dev addon's theme probes.
ns.ThemePartOf = PartOf

-- Each part's row; a theme change repaints on it as on any theme setting.
local PART_KEYS = { themePartParchment = true, themePartUnits = true, themePartMinimap = true, themePartBars = true,
    themePartBags = true, themePartTooltips = true, themePartChat = true, [OTHER] = true }
for key in pairs(PART_KEYS) do ns.bronze.THEME_KEYS[key] = true end
function ns.IsThemePart(key) return PART_KEYS[key] == true end

-- where: a region, or a part's key (a module that paints no region of its own: menus, chat buttons); nil: any part.
function ns.ThemePartOn(where)
    local db = ns.db
    if not db or where == nil then return true end
    if type(where) == "string" then return db[where] ~= false end
    return db[PartOf(where)] ~= false
end

-- The theme on for this piece, or nil: none picked, or its part left out. No piece: the theme on at all.
function ns.ThemeFor(where)
    local name = ns.ThemeName()
    if name and ns.ThemePartOn(where) then return ns.bronze.THEMES[name] end
end
