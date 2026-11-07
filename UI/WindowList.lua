local _, ns = ...
local L = ns.L

-- Every piece ClassicUI Forever Windows moves and sizes (UI/WindowHandles.lua), one entry each.

-- w, h: box before made; cut: old frame's bare edges; stripRight, stripH: strip; toggle: unlock key; quests: the map; section;
-- piece: laid by ns.LayPiece; ringKey: minimap angle (while ringIf, a ring icon's Stay on minimap switch); stays: fixed at its
-- minimap spot while its switch is on; fixedIf: no drag; choice; switch; client; follows (while followIf), followSize; gameEdit; row; page.
local SNAP = L["MAP_EYE_SNAP"]
ns.WINDOW_LIST = {
    -- Where every window that opens side by side starts (UI/Windows.lua RowStart, UI/GameSpot.lua for the game's own): one
    -- box moves them all (#162). No frame of its own: its box stands at the row's start, one window's size.
    { key = "windowRow", label = L["UI_WINDOW_ROW"], name = "ForeverClassicUIWindowRow", w = 350, h = 433, row = true,
        tipSpec = { text = L["UI_WINDOW_ROW"], r = 1, g = 1, b = 1, lines = { { L["UI_WINDOW_ROW_TIP"], nil, nil, nil, true } } } },
    -- dressed: a game window is ours while its restyle is on; off, nothing of ours goes on it (#192).
    { key = "character", label = L["UI_CHARACTER"], name = "CharacterFrame", w = 354, h = 467, cut = { 30, 45 }, client = true,
        dressed = function() return ns.ModuleInForce("characterSheet") end },
    -- The classic professions book wears the spellbook's frame, its corner on the book's art (homes 0, -104 and 12, -118);
    -- zoom: full size draws it bigger (Skills/ProfessionsBook.lua).
    { key = "professions", label = L["UI_PROFESSIONS"], name = ns.OnForever() and "ProfessionsFrame" or "ProfessionsBookFrame",
        w = 339, h = 425, client = true, zoom = function() return ns.ProfessionsZoom and ns.ProfessionsZoom() or 1 end,
        dressed = function() return ns.ModuleInForce("professionsBook") or ns.ModuleInForce("tradeSkill") end,
        follows = "spellBook", followIf = "professionsBook", followX = 12, followY = -14, followSize = true, page = true },
    { key = "talents", label = L["UI_TALENTS"], name = "ClassicUIForeverTalents", w = 354, h = 467, cut = { 30, 45 } },
    { key = "legacy", label = L["UI_LEGACY"], name = "ClassicUIForeverLegacy", w = 354, h = 467, cut = { 30, 45 } },
    -- A page of the spellbook: on its spot, at its size, moved with it; page: no box of its own while it follows.
    { key = "collections", label = L["UI_COLLECTIONS"], name = "ClassicUIForeverCollections", w = 350, h = 433, cut = { 34, 79 },
        follows = "spellBook", followX = 0, followY = 0, followSize = true, page = true },
    { key = "questLog", label = L["UI_QUEST_LOG"], name = "ForeverClassicUIQuestLog", w = 349, h = 437, cut = { 35, 75 } },
    { key = "map", label = L["UI_WORLD_MAP"], name = "WorldMapFrame", w = 1035, h = 534, stripH = 24, toggle = "mapUnlocked",
        quests = true, dressed = function() return ns.db.worldMap ~= false end },
    { key = "calendar", label = L["UI_CALENDAR"], name = "ForeverClassicUICalendarHome", w = 28, h = 28, section = L["UI_MINIMAP"],
        piece = true, ringKey = "calendarAngle", ringIf = "calendarRing", fixedIf = "calendarBehind", choice = "calendarSpot",
        choiceLabel = L["UI_MODE"], stays = true, switch = "calendarSnap", switchLabel = SNAP },
    -- The spellbook art ends 34 short of its frame's right and 79 short of its foot (its foot tabs hang there).
    { key = "spellBook", label = L["UI_SPELLBOOK"], name = "ForeverClassicUISpellBook", w = 350, h = 433, cut = { 34, 79 },
        calm = true },
    { key = "minimapZone", label = L["UI_ZONE_NAME"], name = "ForeverClassicUIMinimapZoneHome", w = 140, h = 12,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapZoneShow", choiceLabel = L["UI_SHOW"], stays = true,
        switch = "minimapZoneSnap", switchLabel = SNAP },
    { key = "minimapTracking", label = L["UI_TRACKING"], name = "ForeverClassicUIMinimapTrackingHome", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapTrackingShow", choiceLabel = L["UI_SHOW"], stays = true,
        switch = "minimapTrackingSnap", switchLabel = SNAP },
    -- The tracking spell's icon: Era's spot until dragged round the ring (Map/Minimap.lua).
    { key = "minimapTrackingIcon", label = L["OPT_classicTracking"], name = "ForeverClassicUIMinimapTrackingIcon", w = 32,
        h = 32, section = L["UI_MINIMAP"], piece = true, ringKey = "trackingIconAngle", ringIf = "minimapTrackingIconSnap",
        switch = "minimapTrackingIconSnap", switchLabel = SNAP },
    { key = "minimapMail", label = L["UI_MAIL"], name = "ForeverClassicUIMinimapMailHome", w = 33, h = 33,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapMailShow", choiceLabel = L["UI_SHOW"], stays = true,
        switch = "minimapMailSnap", switchLabel = SNAP },
    { key = "minimapZoomIn", label = L["UI_ZOOM_IN"], name = "ForeverClassicUIMinimapZoomInHome", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "zoomInAngle", choice = "minimapZoomInShow", choiceLabel = L["UI_SHOW"],
        ringIf = "minimapZoomInSnap", switch = "minimapZoomInSnap", switchLabel = SNAP },
    { key = "minimapZoomOut", label = L["UI_ZOOM_OUT"], name = "ForeverClassicUIMinimapZoomOutHome", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "zoomOutAngle", choice = "minimapZoomOutShow", choiceLabel = L["UI_SHOW"],
        ringIf = "minimapZoomOutSnap", switch = "minimapZoomOutSnap", switchLabel = SNAP },
    { key = "minimapClock", label = L["UI_CLOCK"], name = "ForeverClassicUIMinimapClockHome", w = 60, h = 28,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapClockShow", choiceLabel = L["UI_SHOW"], stays = true,
        switch = "minimapClockSnap", switchLabel = SNAP },
    { key = "minimapDiel", label = L["UI_DAY_AND_NIGHT"], name = "ForeverClassicUIMinimapDielHome", w = 40, h = 40,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapDielShow", choiceLabel = L["UI_SHOW"], stays = true,
        switch = "minimapDielSnap", switchLabel = SNAP },
    { key = "minimapCoords", label = L["UI_COORDINATES"], name = "ForeverClassicUIMinimapCoordsHome", w = 90, h = 10,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapCoordsShow", choiceLabel = L["UI_SHOW"], stays = true,
        switch = "minimapCoordsSnap", switchLabel = SNAP },
    -- Our buttons on the ring (Map/MinimapButton.lua); the options button is fixed while the addon bag holds it.
    { key = "minimapOptionsButton", label = L["OPT_minimapButton"], name = "ForeverClassicUIMinimapButton", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "minimapButtonAngle", fixedIf = "minimapCollector",
        ringIf = "minimapButtonSnap", switch = "minimapButtonSnap", switchLabel = SNAP },
    { key = "minimapAddonBag", label = L["MAP_ADDON_BUTTONS"], name = "ForeverClassicUIMinimapCollector", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "minimapCollectorAngle", choice = "addonBagShow", choiceLabel = L["UI_SHOW"],
        ringIf = "minimapCollectorSnap", switch = "minimapCollectorSnap", switchLabel = SNAP },
    -- Era's quest watch (Quest/QuestWatch.lua), under the minimap until placed.
    { key = "questWatch", label = L["UI_QUEST_WATCH"], name = "ForeverClassicUIQuestWatch", w = 200, h = 80, piece = true,
        section = L["UI_QUEST_WATCH"] },
    -- The classic bar's gryphons (Bar/BandArt.lua), on the band ends until placed.
    { key = "gryphonLeft", label = L["UI_GRYPHON_LEFT"], name = "ForeverClassicUIGryphonLeft", w = 128, h = 128,
        piece = true, gameEdit = true, choice = "gryphonLeftShow", choiceLabel = L["UI_SHOW"] },
    { key = "gryphonRight", label = L["UI_GRYPHON_RIGHT"], name = "ForeverClassicUIGryphonRight", w = 128, h = 128,
        piece = true, gameEdit = true, choice = "gryphonRightShow", choiceLabel = L["UI_SHOW"] },
    -- Its status row hangs 26 under the title: the drag strip is the title bar alone, or it took the status button's clicks.
    { key = "social", label = L["UI_SOCIAL"], name = "FriendsFrame", w = 338, h = 424, client = true,
        stripH = function() return ns.db.socialTitleDrag == true and 24 or nil end,
        over = { "FriendsFrameStatusDropdown", "FriendsFrameBattlenetFrame" },   -- lifted over the drag strip, so they keep their clicks
        dressed = function() return ns.panels and ns.panels.Dressing("panelSocial") end },
    -- Dressed as the social window, the group finder stands in its place at its size.
    { key = "groupFinder", label = L["OPT_groupFinder"], name = "LFGParentFrame", w = 338, h = 424, client = true,
        follows = "social", followIf = "groupFinder", followX = 0, followY = 0,
        dressed = function() return ns.ModuleInForce("groupFinder") or (ns.panels and ns.panels.Dressing("panelGroupFinder")) end },
    -- The NPC's quest and gossip windows open on one spot: one place, lock and size.
    { key = "questGiver", label = L["UI_QUEST_GIVER"], name = "QuestFrame", w = 338, h = 427, client = true,
        dressed = function() return ns.panels and ns.panels.Dressing("panelQuest") end },
    { key = "gossip", label = L["UI_GOSSIP"], name = "GossipFrame", w = 338, h = 427, client = true,
        follows = "questGiver", followX = 0, followY = 0, followSize = true,
        dressed = function() return ns.panels and ns.panels.Dressing("panelGossip") end },
}

-- The other micro buttons on the minimap ring: Map/MinimapMicro.lua names its frames and angles the same way.
local RING_MICROS = { { "Character", L["OPT_hideMicroCharacter"] }, { "Spellbook", L["OPT_hideMicroSpellbook"] },
    { "Talents", L["OPT_hideMicroTalents"] }, { "Professions", L["OPT_hideProfessionsButton"] },
    { "QuestLog", L["OPT_hideMicroQuestLog"] }, { "Legacy", L["OPT_hideMicroLegacy"] },
    { "WorldMap", L["OPT_hideMicroWorldMap"] }, { "Guild", L["OPT_hideMicroGuild"] },
    { "Collections", L["OPT_hideMicroCollections"] }, { "Help", L["OPT_hideMicroHelp"] },
    { "GameMenu", L["OPT_hideMicroGameMenu"] }, { "Shop", L["OPT_hideMicroShop"] },
    { "Housing", L["OPT_hideMicroHousing"] } }
-- Retail's alone (Map/MinimapMicro.lua makes them only there). The queue eye too: retail's game edit mode has no box
-- for it (Forever's has), so ours holds its Stay on minimap and drags it round the ring; off the rim it stays put.
if not ns.OnForever() then
    RING_MICROS[#RING_MICROS + 1] = { "Achievements", L["OPT_hideMicroAchievements"] }
    RING_MICROS[#RING_MICROS + 1] = { "Journal", L["OPT_hideMicroJournal"] }
    local function OnRim() return ns.EyeOnRing ~= nil and ns.EyeOnRing() end
    ns.WINDOW_LIST[#ns.WINDOW_LIST + 1] = { key = "minimapEye", label = L["OPT_hideMicroGroupFinder"],
        name = "ForeverClassicUIEyeSize", w = 32, h = 32, section = L["UI_MINIMAP"], piece = true, ringKey = "lfgButtonAngle",
        switch = "eyeSnapMinimap", switchLabel = L["MAP_EYE_SNAP"], fixedIf = function() return not OnRim() end,
        dressed = function() return ns.MM ~= nil and ns.MM.active end,
        sizeBase = function() return OnRim() and Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1 end }
end
for _, micro in ipairs(RING_MICROS) do
    ns.WINDOW_LIST[#ns.WINDOW_LIST + 1] = { key = "minimap" .. micro[1], label = micro[2],
        name = "ForeverClassicUIMinimap" .. micro[1] .. "Button", w = 32, h = 32, section = L["UI_MINIMAP"], piece = true,
        ringKey = "minimap" .. micro[1] .. "Angle", choice = "groupFinderButtonShow", choiceLabel = L["UI_SHOW"],
        ringIf = "minimap" .. micro[1] .. "Snap", switch = "minimap" .. micro[1] .. "Snap", switchLabel = SNAP }
end

-- An entry's window; none for a padHost one inside the game's spell window (gamepad on at login), which places it.
function ns.WindowFrame(entry)
    if entry.padHost and ns.padSession then return nil end
    return _G[entry.name]
end
