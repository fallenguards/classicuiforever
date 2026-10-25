local _, ns = ...

-- The theme on the game's own art: each piece walked whole, every texture of frame metal (by atlas, or file for the
-- old art) tinted like ours (ns.TintGameArt), dressed windows too for what our dress leaves (tabs, scroll bars, search
-- boxes); walked again as a window opens.

local held = setmetatable({}, { __mode = "k" })   -- texture -> tinted by this pass
local want = {}                                  -- this pass's textures, refilled
local DEPTH = 10

-- Frame metal by atlas (lower case, its tiling mark dropped): frames, borders, rings, tabs, slots, headers, dividers.
local METAL = {
    "^ui%-frame%-metal", "^ui%-frame%-portraitmetal", "^ui%-frame%-inner", "^ui%-frame%-diamondmetal", "^ui%-frame%-bot",
    "^ui%-frame%-title", "^ui%-frame%-btndiv", "^uiframe%-tab", "^uiframe%-activetab", "^ui%-hud%-minimap%-frame", "^ui%-hud%-minimap%-zoom%-", "^ui%-hud%-minimap%-button", "^ui%-hud%-minimap%-guildbanner%-border",
    "^ui%-hud%-unitframe%-smallcircle$", "portraiton$", "portraiton%-vehicle$", "portraiton%-classresource$",
    "^ui%-hud%-unitframe%-target%-portraiton%-boss%-gold", "^ui%-hud%-unitframe%-target%-portraiton%-boss%-rare%-silver",
    "^ui%-hud%-actionbar%-iconframe$", "^ui%-hud%-actionbar%-iconframe%-border$", "^ui%-hud%-actionbar%-iconframe%-small$",
    "^ui%-hud%-actionbar%-iconframe%-bags$", "^ui%-hud%-actionbar%-iconframe%-slot", "^ui%-hud%-actionbar%-iconframe%-down$",
    "^ui%-hud%-actionbar%-frame", "^ui%-hud%-actionbar%-page%a+arrow%-", "^ui%-hud%-actionbar%-flyout$", "^bag%-arrow",
    "^ui%-hud%-actionbar%-iconframe%-addrow", "^ui%-hud%-actionbar%-gryphon", "^ui%-hud%-actionbar%-wyvern",
    "^minimal%-scrollbar%-track", "^minimal%-scrollbar%-small%-thumb", "^minimal%-scrollbar%-thumb", "^minimal%-scrollbar%-arrow",
    "^ui%-character%-info%-line%-bounce", "^ui%-character%-info%-itemlevel%-bounce",
    "^ui%-hud%-nameplates%-levelindicator$", "^ui%-hud%-nameplates%-levelindicator%-rectangle", "^nameplates%-icon%-elite%-",
    "^ui%-hud%-micromenu%-buttonbg", "^ui%-hud%-experiencebar%-frame", "^ui%-hud%-experiencebar%-divider",
    "^ui%-castingbar%-frame", "^ui%-castingbar%-textbox", "^ui%-swingtimerbar%-frame",
    "^ui%-questtracker%-.+%-header$", "^ui%-questtrackerbutton%-",
    "^common%-search%-border", "^common%-coinbox", "^common%-sidetab", "^common%-insideframe", "^common%-framedivider",
    "^ui%-character%-info%-gearslot", "^ui%-character%-info%-button%-pull", "^ui%-character%-info%-stattab",
    "^ui%-character%-info%-title", "^ui%-character%-info%-scrollline",
    "^questlog%-frame", "^storyheader%-bg", "^questlog%-reward%-header", "^questlog%-reward%-top%-frame",
    "^options_tab", "^options_categoryheader", "^options_innerframe", "^options_horizontaldivider",
    "^spellbook%-item%-iconframe", "^spellbook%-rotationhelper%-iconframe", "^spellbook%-divider", "^spec%-thumbnailborder",
    "^groupfinder%-button%-cover$", "^groupfinder%-scrollline", "^common%-button%-list%-large$", "^common%-button%-list%-mid2$",
    "^professions%-recipe%-header", "^profession%-square%-frame", "^professions%-slot%-frame", "^professions%-skillbar%-frame",
    "^tab%-divider%-top$", "^ui%-merchant%-botframe", "^common%-dropdown%-textholder", "^common%-dropdown%-a%-button",
    "^communities%-guildbanner%-border",
}
-- Light, not metal: a state's hover or glow over the art.
local NOT_METAL = { "mouseover", "highlight", "glow", "hover", "mask", "shadow" }
-- The old art by file: the calendar's frame, button borders and divider, the skill line tabs; the column tabs and the
-- rock and marble behind lists (the guild roster's header strip); the communities chat box's border.
local METAL_FILES = { [235431] = true, [235430] = true, [235418] = true, [131074] = true, [136831] = true,
    [131139] = true, [374155] = true, [374154] = true, [375507] = true, [375508] = true, [389190] = true }

local metalAtlas = {}   -- atlas -> metal or not, worked out once
local function IsMetal(atlas)
    local known = metalAtlas[atlas]
    if known ~= nil then return known end
    local name = atlas:lower():gsub("^[_!]+", "")
    local metal = false
    for i = 1, #METAL do
        if name:find(METAL[i]) then
            metal = true
            break
        end
    end
    for i = 1, #NOT_METAL do
        if metal and name:find(NOT_METAL[i], 1, true) then metal = false end
    end
    metalAtlas[atlas] = metal
    return metal
end

-- The game's elite and rare dragons: as drawn with Ignore theme for elite frames.
local DRAGONS = { "portraiton%-boss%-gold", "portraiton%-boss%-rare%-silver" }
local dragonAtlas = {}
local function KeptDragon(atlas, region)
    if not (ns.db and ns.db.themeIgnoreElite == true and ns.bronze.EliteFrameKept(region)) then return false end
    local known = dragonAtlas[atlas]
    if known == nil then
        local name = atlas:lower()
        known = false
        for i = 1, #DRAGONS do
            if name:find(DRAGONS[i]) then known = true end
        end
        dragonAtlas[atlas] = known
    end
    return known
end

-- A nameplate's art can come back secret: never a table key.
local function Match(region)
    if not (region.IsObjectType and region:IsObjectType("Texture")) then return end
    local atlas = region:GetAtlas()
    if ns.IsSecret(atlas) then return end
    if atlas then
        if IsMetal(atlas) and not KeptDragon(atlas, region) then want[region] = true end
    else
        local file = region:GetTexture()
        if not ns.IsSecret(file) and type(file) == "number" and METAL_FILES[file] then want[region] = true end
    end
end

-- By the row whose replacement covers them (false: never ours). A frame listed here is left out of the others' walks.
local ROOTS = {
    { "minimap", "MinimapCluster" },
    { "unitFramePlayer", "PlayerFrame" },
    { "unitFrameTarget", "TargetFrame" },
    { "unitFrameFocus", "FocusFrame" },
    { "unitFramePet", "PetFrame" },
    { "unitFrameParty", "PartyFrame" },
    { "classicBar", "MainActionBar", "BagsBar", "MicroMenuContainer", "StatusTrackingBarManager" },
    { "castBars", "PlayerCastingBarFrame", "PetCastingBarFrame", "TargetFrameSpellBar", "FocusFrameSpellBar" },
    { "mirrorTimers", "MirrorTimerContainer" },
    { "swingTimers", "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" },
    { "buttons", "StanceBar", "PetActionBar", "PossessActionBar" },
    { "questTracker", "ObjectiveTrackerFrame" },
    { "questMapPane", "QuestMapFrame" },
    { "groupFinder", "PVEFrame", "LFGParentFrame" },
    { "bags", "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
        "ContainerFrame5", "ContainerFrame6", "ContainerFrame7", "ContainerFrame8", "ContainerFrame9", "ContainerFrame10",
        "ContainerFrame11", "ContainerFrame12", "ContainerFrame13", "BagItemSearchBox" },
    { "characterSheet", "CharacterFrame" },
    { "gameMenu", "GameMenuFrame" },
    { "settingsPanel", "SettingsPanel" },
    { false, "PlayerSpellsFrame" },
    -- The social window's raid tab: parented to it only as the tab first opens, so walked as it shows.
    { false, "RaidFrame" },
}
-- Windows walked while dressed too: our dress leaves some of the game's metal (search box, money box, tabs).
local DRESSED_WALKED = { bags = true, groupFinder = true, characterSheet = true, gameMenu = true, settingsPanel = true,
    questMapPane = true }
local isRoot = setmetatable({}, { __mode = "k" })

local Walk
local function Child(child, depth)
    if not isRoot[child] and not ns.bronze.PlainTree(child) then Walk(child, depth) end
end
Walk = function(frame, depth)
    ns.EachRegion(frame, Match)
    if depth < DEPTH then ns.EachChild(frame, Child, depth + 1) end
end

local function Tint()
    for texture in pairs(want) do
        held[texture] = true
        ns.TintGameArt(texture)
    end
end

-- A window builds rows as it opens: walked again then.
local watched = setmetatable({}, { __mode = "k" })
local function Watch(frame)
    if watched[frame] or not frame.IsObjectType then return end
    watched[frame] = true
    ns.Sched.OnVisible(frame, "gameArt", function(shown)
        if not shown then return end
        wipe(want)
        Walk(frame, 0)
        Tint()
    end)
end

local function Root(frame)
    isRoot[frame] = true
    Walk(frame, 0)
    Watch(frame)
end

local function ButtonArt(button) ns.EachRegion(button, Match) end
local function PlateArt(plate) Walk(plate, 0) end

-- Plates come and go: each new one walked as it shows, while the game's own plates are up.
local function NewPlates()
    if ns.ModuleInForce("namePlates") then return end
    wipe(want)
    ns.NP.EachPlate(PlateArt)
    Tint()
end

-- The pet's happiness face has its frame drawn into the one picture, so a tint would grey the face too. With a theme
-- on, our copy of the sheet (only the frame recoloured) covers the game's on the same face: happy, mad, neutral.
local FACES = ns.bronze.BUNDLED .. "PetHappinessFaces"
local FACE_CELL, SHEET_W, SHEET_H = 130, 512, 256
local FACE_COLUMN = { 1, 2, 0 }   -- the game's mad, neutral, happy -> the sheet's column
local FACE_EVENTS = { "UNIT_HAPPINESS", "UNIT_PET" }
local face, faceEvents
local function PetFace()
    local host = _G.PetFrameHappiness
    local game = host and host.Texture
    if not game then return end
    local on = ns.ThemeFor(game) ~= nil
    if on and not face then
        face = host:CreateTexture(nil, "BACKGROUND", nil, 1)
        face:SetAllPoints(game)
        faceEvents = ns.EventFrame(FACE_EVENTS, PetFace, "pet", "player")
    end
    ns.SetAlphaIf(game, on and 0 or 1)
    if not face then return end
    ns.SetShownIf(face, on)
    if on then
        ns.RegisterEvents(faceEvents, FACE_EVENTS, "pet", "player")
    else
        faceEvents:UnregisterAllEvents()
        return
    end
    local happiness = C_PetInfo and C_PetInfo.GetPetHappiness and C_PetInfo.GetPetHappiness()
    local column = FACE_COLUMN[ns.Safe(happiness, 3)] or 0
    ns.SetFile(face, FACES)
    face:SetTexCoord(column * FACE_CELL / SHEET_W, (column + 1) * FACE_CELL / SHEET_W, 0, FACE_CELL / SHEET_H)
end

local function Sync()
    PetFace()
    wipe(want)
    for _, root in ipairs(ROOTS) do
        for i = 2, #root do
            if _G[root[i]] then isRoot[_G[root[i]]] = true end
        end
    end
    for _, root in ipairs(ROOTS) do
        if root[1] == false or DRESSED_WALKED[root[1]] or not ns.ModuleInForce(root[1]) then
            for i = 2, #root do
                if _G[root[i]] then Root(_G[root[i]]) end
            end
        end
    end
    -- The window frames row dresses the rest of the game's windows (Windows/Panels.lua).
    local P = ns.panels
    for _, entry in ipairs(P and P.WINDOWS or {}) do
        local frame = _G[entry[1]]
        if frame and entry.child then frame = frame[entry.child] end
        if frame then Root(frame) end
    end
    if not ns.ModuleInForce("buttons") and ns.ForEachActionButton then ns.ForEachActionButton(ButtonArt) end
    if not ns.ModuleInForce("namePlates") then ns.NP.EachPlate(PlateArt) end
    Tint()
    for texture in pairs(held) do
        if not want[texture] then
            held[texture] = nil
            ns.UntintGameArt(texture)
        end
    end
end

-- Windows that load later, and party frames as a group forms.
ns.EventFrame({ "ADDON_LOADED", "GROUP_ROSTER_UPDATE" }, function()
    if ns.ready then ns.Sched.NextFrame("gameArt", Sync) end
end)
ns.EventFrame("NAME_PLATE_UNIT_ADDED", function()
    if ns.ready then ns.Sched.NextFrame("gameArt.plates", NewPlates) end
end)

-- After every other module (last in ns.MODULE_ORDER), in a fight too: only colours change.
ns.RegisterModule("bronzeTheme", { id = "gameArt", apply = Sync, restore = Sync, inFight = true })

-- Ignore theme for elite frames or one of its frames: the walk again at once, in a fight too.
ns.OnToggle(function(key)
    if (key == "themeIgnoreElite" or ns.bronze.ELITE_FRAME_KEYS[key] or ns.IsThemePart(key)) and ns.ready then Sync() end
end)
