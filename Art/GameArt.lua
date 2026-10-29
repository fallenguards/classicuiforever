local _, ns = ...

-- The theme on the game's own art: each piece walked whole, every texture of frame metal (by atlas, or file for the
-- old art) tinted like ours (ns.TintGameArt), dressed windows too for what our dress leaves (tabs, scroll bars, search
-- boxes); walked again as a window opens.

local held = setmetatable({}, { __mode = "k" })   -- texture -> tinted by this pass
local want = {}                                  -- this pass's textures, refilled
-- Each root's textures as its last walk found them: a root hidden since keeps
-- them instead of a walk each pass (every window's tree walked on each
-- settings change was the stutter), and its next showing walks it (Watch).
local found = setmetatable({}, { __mode = "k" })
local walking   -- the root's finds being filled
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

-- Broad (a package's broad flag: Fallen's UI Color Picker): frames the theme's colour, panes (parchment, backgrounds)
-- a lighter colour so they stand apart, pictures, icons, light, masks and bar fills as drawn. A window is walked as it
-- first exists, as it opens and as it is clicked (a new tab), never on a beat.
local BROAD = ns.PACKAGE ~= nil and ns.PACKAGE.broad == true
-- A pane: painted in the pane colour, the theme's lifted toward white (Art/Bronze.lua PaneTint).
local PANE = { pane = true }
-- A tooltip's center: shaded from the game's own tooltip dark, not the theme's color (Art/Bronze.lua Paint).
local TIP_PANE = { pane = true, tip = true }
-- Pictures and light by their own names (the Adventure Guide's raid buttons: bgImage).
local KEEP_NAMES = { "icon", "portrait", "cooldown", "flash", "glow", "highlight", "model", "image", "splash", "preview",
    "thumbnail", "illustration", "picture" }
-- The curated metal list (METAL) wins over these.
local KEEP_ATLAS = { "icon", "portrait", "mask", "glow", "highlight", "shadow", "sheen", "shine", "flash", "spark",
    "particle", "animation", "swirl", "^talents%-background", "^talents%-node", "^spec%-", "poi", "waypoint",
    "warmode%-swords", "splash", "preview", "thumbnail", "illustration", "tutorial", "loadingscreen", "^ui%-ej%-" }
-- Panes by atlas, and the plain parchment by name or file (the spellbook's, the professions book's page). The quest
-- log's campaign headers (campaign_sky) and a quest's campaign parchment (questbg-) are parchment too.
local PANE_ATLAS = { "background", "parchment", "paper", "%-bg$", "%-bg%-", "center$", "%-fill", "^campaign", "^questbg" }
-- A quest's campaign parchment gets its art only as a campaign quest opens, after the walks: a pane, art or not.
local LATE_PANES = { SealMaterialBG = true }
local PANE_FILES = { [383588] = true, [383589] = true }
-- Bigger than this by file (both sides): art behind a window's content, a pane; borders and strips are thinner.
local PANE_W, PANE_H = 96, 64

local function Listed(list, name)
    for i = 1, #list do
        if name:find(list[i]) then return true end
    end
    return false
end

local atlasKind = {}   -- atlas -> "keep", "pane" or "frame", worked out once
local function AtlasKind(atlas)
    local known = atlasKind[atlas]
    if known then return known end
    local name = atlas:lower():gsub("^[_!]+", "")
    if IsMetal(atlas) then
        known = "frame"
    elseif Listed(KEEP_ATLAS, name) then
        known = "keep"
    elseif Listed(PANE_ATLAS, name) then
        known = "pane"
    else
        known = "frame"
    end
    atlasKind[atlas] = known
    return known
end

local function NamedKeep(name)
    if type(name) ~= "string" or ns.IsSecret(name) then return false end
    name = name:lower()
    for i = 1, #KEEP_NAMES do
        if name:find(KEEP_NAMES[i], 1, true) then return true end
    end
    return false
end

-- A mask, light, a bar's fill, or a picture by its own name. A hover image on the highlight layer takes the theme
-- with its button (the micro menu's); light is the added blend.
local function Kept(region)
    if region:IsObjectType("MaskTexture") then return true end
    local blend = region:GetBlendMode()
    if ns.IsSecret(blend) or blend ~= "BLEND" then return true end
    local parent = region:GetParent()
    if parent and parent.GetStatusBarTexture and parent:GetStatusBarTexture() == region then return true end
    return NamedKeep(region:GetName()) or NamedKeep(region.GetParentKey and region:GetParentKey())
end

-- Frames never walked: models, cooldown sweeps, the map's canvas, ours.
local function Skipped(frame)
    if ns.IsForbidden(frame) or frame:IsObjectType("Model") or frame:IsObjectType("ModelScene")
        or frame:IsObjectType("Cooldown") then return true end
    if frame == (WorldMapFrame and WorldMapFrame.ScrollContainer) then return true end
    local name = frame:GetName()
    return type(name) == "string" and not ns.IsSecret(name) and (name:find("^ForeverClassicUI") ~= nil
        or name:find("^ClassicUIForever") ~= nil)
end

-- A picture by file that reads as an icon: a button's own picture, the icon crop, or a small square.
local ICON_KEYS = { "icon", "Icon", "IconTexture", "Texture" }
local function IconLike(region, w, h)
    local parent = region:GetParent()
    if parent and parent.IsObjectType and parent:IsObjectType("Button") then
        for i = 1, #ICON_KEYS do
            if parent[ICON_KEYS[i]] == region then return true end
        end
    end
    local left, top = region:GetTexCoord()
    if not ns.IsSecret(left) and left > 0.04 and left < 0.15 and top > 0.04 and top < 0.15 then return true end
    return w >= 12 and w <= 80 and math.abs(w - h) <= 1
end

-- The backpack's art is one picture, its ring with the bag drawn over: hidden for our two pieces of it, the ring in
-- Bag borders, the bag in Bag icons (media/BackpackParts: ring left, bag right, 96 square each).
local BACKPACK = ns.bronze.BUNDLED .. "BackpackParts"
local BACKPACK_CELLS = { { 0, 96 / 256 }, { 0.5, 224 / 256 } }
local backpack = setmetatable({}, { __mode = "k" })   -- button -> its ring and bag
local function SplitBackpack(region)
    local button = region:GetParent()
    local pieces = backpack[button]
    if not pieces then
        local layer, sub = region:GetDrawLayer()
        if ns.AnySecret(layer, sub) then return end
        pieces = {}
        for i, cell in ipairs(BACKPACK_CELLS) do
            pieces[i] = button:CreateTexture(nil, layer, nil, sub)
            ns.SetFile(pieces[i], BACKPACK)
            pieces[i]:SetTexCoord(cell[1], cell[2], 0, 96 / 128)
            pieces[i]:SetAllPoints(button)
        end
        ns.PinThemePart(pieces[2], "themePartBagIcons")
        backpack[button] = pieces
    end
    ns.SetAlphaIf(region, 0)
    want[pieces[1]], want[pieces[2]] = true, true
end

local function BroadMatch(region, atlas)
    local B = ns.bronze
    if B.tinted[region] or B.swapped[region] or B.clientWas[region] then return end
    -- The micro menu's character button wears the player's portrait as its icon: in the theme as the other icons are.
    if region:GetParent() == _G.CharacterMicroButton and not region:IsObjectType("MaskTexture") then
        want[region] = true
        return
    end
    -- A bag's picture: in the theme with Bag icons, never kept as a picture.
    local name = region:GetName()
    if type(name) == "string" and not ns.IsSecret(name) and Listed(ns.BAG_ICONS, name) then
        want[region] = true
        return
    end
    if atlas == "bag-main" then return SplitBackpack(region) end
    local key = region.GetParentKey and region:GetParentKey()
    if type(key) == "string" and not ns.IsSecret(key) and LATE_PANES[key] then
        want[region] = PANE
        return
    end
    local kind
    if atlas then
        kind = AtlasKind(atlas)
        if kind == "frame" and KeptDragon(atlas, region) then kind = "keep" end
    else
        -- A colour texture has no file; our own art goes by its path.
        local file = region:GetTexture()
        if ns.IsSecret(file) or type(file) ~= "number" then return end
        local w, h = region:GetWidth(), region:GetHeight()
        if ns.IsSecret(w) or ns.IsSecret(h) then return end
        if METAL_FILES[file] then
            kind = "frame"
        elseif PANE_FILES[file] then
            kind = "pane"
        elseif IconLike(region, w, h) then
            kind = "keep"
        else
            kind = (w > PANE_W and h > PANE_H) and "pane" or "frame"
        end
    end
    if kind == "keep" or Kept(region) then return end
    if kind == "pane" and atlas and atlas:lower():find("^tooltip%-nineslice%-center") then
        want[region] = TIP_PANE
        return
    end
    want[region] = kind == "pane" and PANE or true
end

-- A nameplate's art can come back secret: never a table key.
local function Match(region)
    if not (region.IsObjectType and region:IsObjectType("Texture")) then return end
    local atlas = region:GetAtlas()
    if ns.IsSecret(atlas) then return end
    if BROAD then return BroadMatch(region, atlas) end
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

-- addon: inside another addon's frame (walked only with Other addons themed), what it takes marked.
local function MatchIn(region, addon)
    Match(region)
    if not want[region] then return end
    if addon then ns.MarkAddonPiece(region) end
    if walking then walking[region] = want[region] end
end
local Walk
local function Child(child, depth, addon)
    if not isRoot[child] and not ns.bronze.PlainTree(child) and not (BROAD and Skipped(child)) then
        Walk(child, depth, addon)
    end
end
Walk = function(frame, depth, addon)
    addon = addon or ns.bronze.AddonFrame(frame)
    ns.EachRegion(frame, MatchIn, addon)
    if depth < DEPTH then ns.EachChild(frame, Child, depth + 1, addon) end
end

local function Tint()
    ns.HoldThemeName(true)
    for texture, kind in pairs(want) do
        held[texture] = true
        -- A pane (broad): the lighter pane colour; anything else the theme's colour whole.
        ns.TintGameArt(texture, kind ~= true and kind or nil)
    end
    ns.HoldThemeName(false)
end

-- A root's tree walked and its finds kept; hidden, its last finds stand in.
local function WalkRoot(frame)
    local kept = found[frame]
    if kept and frame.IsShown and not frame:IsShown() then
        for texture, kind in pairs(kept) do want[texture] = kind end
        return
    end
    kept = {}
    found[frame], walking = kept, kept
    Walk(frame, 0)
    walking = nil
end

-- A window builds rows as it opens: walked again then.
local watched = setmetatable({}, { __mode = "k" })
local function Watch(frame)
    if watched[frame] or not frame.IsObjectType then return end
    watched[frame] = true
    ns.Sched.OnVisible(frame, "gameArt", function(shown)
        if not shown then return end
        wipe(want)
        WalkRoot(frame)
        Tint()
    end)
end

-- Broad: every window of the game's as it first exists (UIParent's children), walked once, then as it opens.
local broadRoots = setmetatable({}, { __mode = "k" })
local function BroadRoot(frame)
    -- Only the game's own named windows: an unnamed one's maker cannot be told, another addon's is its own.
    if ns.IsForbidden(frame) then return end
    local name = frame:GetName()
    if type(name) ~= "string" or isRoot[frame] or Skipped(frame) or ns.bronze.PlainTree(frame) then return end
    isRoot[frame], broadRoots[frame] = true, true
    Walk(frame, 0)
    Watch(frame)
end

local function Root(frame)
    isRoot[frame] = true
    WalkRoot(frame)
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
    if BROAD and ns.ThemeFor() then ns.EachChild(UIParent, BroadRoot) end
    Tint()
    -- Broad keeps what it painted: its windows are walked once, not each pass, and the paint itself follows the theme
    -- and its parts (ns.ThemeFor); a package's other modules never come on to take a window over.
    if BROAD then return end
    for texture in pairs(held) do
        if not want[texture] then
            held[texture] = nil
            ns.UntintGameArt(texture)
        end
    end
end

-- Broad: a click inside a walked window (a tab, a page) walks it again a frame later, its new rows in place.
if BROAD then
    local clicked
    local function WalkClicked()
        if not clicked then return end
        wipe(want)
        Walk(clicked, 0)
        Tint()
        clicked = nil
    end
    ns.EventFrame("GLOBAL_MOUSE_UP", function()
        if not ns.ThemeFor() then return end
        local foci = GetMouseFoci and GetMouseFoci()
        local frame = foci and foci[1]
        for _ = 1, 20 do
            if not frame or ns.IsForbidden(frame) or watched[frame] then break end
            frame = frame.GetParent and frame:GetParent()
        end
        if frame and watched[frame] then
            clicked = frame
            ns.Sched.NextFrame("gameArt.click", WalkClicked)
        end
    end)
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
