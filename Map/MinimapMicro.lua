local _, ns = ...
local L = ns.L

-- Micro buttons as icons on the minimap ring, hidden from the micro menu or not: Classic's group finder eye, the player's
-- portrait, and for the rest the icon off the button's own 1.x sheet. A click goes through a secure pad onto what the micro
-- button presses (its own pad where it opens a window of ours), so the window opens in the player's name.

local FACE = ns.RING_ICON_FACE
local EYE = { layer = "ARTWORK", coords = { 0.019, 0.106, 0.0375, 0.2125 }, w = 24, h = 24, point = "CENTER", relPoint = "TOPLEFT",
    x = FACE.x, y = FACE.y }
-- The icon on a 32 x 64 micro sheet: 22 square, 5 in and 32 down.
local SHEET = { layer = "ARTWORK", coords = { 5 / 32, 27 / 32, 32 / 64, 54 / 64 }, w = 24, h = 24, point = "CENTER",
    relPoint = "TOPLEFT", x = FACE.x, y = FACE.y }

-- Each icon: its toggle, the micro button it presses (none: the zone name, which opens the map), its face, frame name,
-- edit mode entry, ring angle (free: the nearest clear spot to it; Legacy's is under the mail icon), name, and the game
-- rule that takes the button away. Names match UI/WindowList.lua.
local MICROS = {
    { toggle = "characterMinimapButton", micro = "CharacterMicroButton", face = "portrait", id = "Character", angle = 232, free = true,
        label = L["OPT_hideMicroCharacter"], rule = "CharacterPanelDisabled" },
    { toggle = "spellbookMinimapButton", micro = "SpellbookMicroButton", ours = "ForeverClassicUISpellbookMicroButton", face = "Spellbook", id = "Spellbook", angle = 232, free = true,
        label = L["OPT_hideMicroSpellbook"] },
    { toggle = "talentsMinimapButton", micro = "TalentMicroButton", face = "Talents", id = "Talents", angle = 232, free = true,
        label = L["OPT_hideMicroTalents"] },
    { toggle = "professionsMinimapButton", micro = "ProfessionMicroButton", face = "Professions", id = "Professions", angle = 232, free = true,
        label = L["OPT_hideProfessionsButton"], rule = "ProfessionsPanelDisabled" },
    { toggle = "questLogMinimapButton", micro = "QuestLogMicroButton", face = "Quest", id = "QuestLog", angle = 232, free = true,
        label = L["OPT_hideMicroQuestLog"], rule = "QuestLogMicrobuttonDisabled" },
    { toggle = "legacyMinimapButton", micro = "LegacyMicroButton", face = "Achievement", id = "Legacy", angle = 347, free = true,
        label = L["OPT_hideMicroLegacy"] },
    { toggle = "worldMapMinimapButton", face = "World", id = "WorldMap", angle = 232, free = true, label = L["OPT_hideMicroWorldMap"] },
    { toggle = "guildMinimapButton", micro = "GuildMicroButton", face = "Socials", id = "Guild", angle = 232, free = true,
        label = L["OPT_hideMicroGuild"], rule = "CommunitiesPanelDisabled" },
    -- Era's eye while not queued: it rides the game's queue eye, which the game's edit mode places (Map/MinimapEye.lua).
    -- Its frame and entry keep their first names.
    { toggle = "lfgMinimapButton", micro = "LFDMicroButton", face = "eye", id = "GroupFinder", angle = 137,
        name = "ForeverClassicUIGroupFinderButton", entry = "minimapGroupFinder", angleKey = "lfgButtonAngle",
        ride = function() return QueueStatusButton end,
        -- Retail's edit mode has no box for the eye: a Shift-drag of the icon slides eye and icon round the rim.
        dragHost = not ns.OnForever() and function(angle) ns.MM.EyeDragTo(angle) end or nil,
        label = L["OPT_hideMicroGroupFinder"], rule = "FinderPanelDisabled" },
    { toggle = "collectionsMinimapButton", micro = "CollectionsMicroButton", face = "Mounts", id = "Collections", angle = 232, free = true,
        label = L["OPT_hideMicroCollections"], rule = "CollectionsPanelDisabled" },
    { toggle = "helpMinimapButton", micro = "HelpMicroButton", face = "Help", id = "Help", angle = 232, free = true,
        label = L["OPT_hideMicroHelp"], rule = "HelpPanelDisabled" },
    { toggle = "gameMenuMinimapButton", micro = "MainMenuMicroButton", face = "MainMenu", id = "GameMenu", angle = 232, free = true,
        label = L["OPT_hideMicroGameMenu"] },
    { toggle = "shopMinimapButton", micro = "StoreMicroButton", face = "BStore", id = "Shop", angle = 232, free = true,
        label = L["OPT_hideMicroShop"], rule = "StoreDisabled" },
    -- Forever has the button too, held off by its game rule; 1.x has no sheet for it, so the icon is the game's own micro art.
    { toggle = "housingMinimapButton", micro = "HousingMicroButton", atlas = "UI-HUD-MicroMenu-Housing-Up", id = "Housing",
        angle = 232, free = true, label = L["OPT_hideMicroHousing"], rule = "HousingDashboardDisabled" },
}
-- Retail's own buttons 1.x never had: off the micro menu by default, each with its way in on the ring. Achievements
-- wears the 1.x achievement face (Forever's Legacy icon there); the adventure guide has no 1.x sheet.
if not ns.OnForever() then
    MICROS[#MICROS + 1] = { toggle = "achievementsMinimapButton", micro = "AchievementMicroButton", face = "Achievement",
        id = "Achievements", angle = 232, free = true, label = L["OPT_hideMicroAchievements"] }
    MICROS[#MICROS + 1] = { toggle = "journalMinimapButton", micro = "EJMicroButton", atlas = "UI-HUD-MicroMenu-AdventureGuide-Up",
        id = "Journal", angle = 232, free = true, label = L["OPT_hideMicroJournal"] }
end
local byToggle = {}

local function Face(spec, icon)
    if spec.face == "eye" then
        ns.Dress(icon, "lfgEye", EYE)
    elseif spec.face == "portrait" then
        ns.Dress(icon, nil, FACE)
        SetPortraitTexture(icon, "player")
    elseif spec.atlas then
        ns.Dress(icon, nil, FACE)
        icon:SetAtlas(spec.atlas)
    else
        ns.Dress(icon, "micro" .. spec.face .. "Up", SHEET)
    end
end

-- The micro button's own tooltip line (its name and key), or our name for it.
local function TipText(spec)
    local micro = spec.micro and _G[spec.micro]
    local text = micro and micro.tooltipText
    if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then return text end
    return spec.label
end

-- What the icon presses: nil while this client has no such button, or a game rule holds it off.
local function Target(spec)
    local rule = spec.rule and Enum.GameRule and Enum.GameRule[spec.rule]
    if rule and C_GameRules and C_GameRules.IsGameRuleActive and C_GameRules.IsGameRuleActive(rule) then return nil end
    if not spec.micro then return MinimapCluster and MinimapCluster.ZoneTextButton end
    -- ours: the button we build where the client has none (retail's spellbook).
    local micro = _G[spec.micro] or (spec.ours and _G[spec.ours])
    return micro and ns.PressTarget(micro)
end

-- Queued, the game's own eye shows: ours gives way to it (both show in edit mode, to be placed).
local function QueueEyeShown()
    local eye = QueueStatusButton
    return eye ~= nil and eye:IsShown() and not ns.EditMode.state
end

local function Chosen(spec)
    local db = ns.db
    return db and db.microMinimapButtons ~= false and db[spec.toggle] == true and Target(spec) ~= nil
end

-- Queued, the game's eye shows instead; in edit mode too, as its box.
local function Wanted(spec)
    if spec.face == "eye" and (QueueEyeShown() or ns.EditMode.state) then return false end
    return Chosen(spec)
end

for _, spec in ipairs(MICROS) do
    byToggle[spec.toggle] = spec
    spec.show, spec.hide = ns.RingButton({
        name = spec.name or ("ForeverClassicUIMinimap" .. spec.id .. "Button"),
        key = spec.entry or ("minimap" .. spec.id),
        angleKey = spec.angleKey or ("minimap" .. spec.id .. "Angle"),
        angle = spec.angle,
        free = spec.free,
        ride = spec.ride,
        dragHost = spec.dragHost,
        piece = true,
        show = "GroupFinderButton",
        face = function(icon) Face(spec, icon) end,
        tip = { anchor = "ANCHOR_LEFT", text = function() return TipText(spec) end, r = 1, g = 1, b = 1,
            lines = (not spec.ride or spec.dragHost) and { { L["MAP_DRAG_TO_MOVE_AROUND_THE"], 0.8, 0.8, 0.8 } } or nil },
    })
    spec.frame = spec.name or ("ForeverClassicUIMinimap" .. spec.id .. "Button")
end

-- Each shown icon's pad on what its micro button presses now: a window module turned on or off changes it.
local function Aim()
    if InCombatLockdown() then
        ns.WhenCalm("minimapMicro.aim", Aim)
        return
    end
    for _, spec in ipairs(MICROS) do
        local button = spec.shown and _G[spec.frame]
        local target = button and Target(spec)
        if target then
            local pad = ns.PadOf(button)
            if pad then
                ns.SetAttributeIf(pad, "clickbutton", target)
            else
                ns.MapPad(button, "MEDIUM", nil, target)
            end
        end
    end
end

local on, watching = false, false
local Sync

-- The game's eye showing or hiding (inside its show pass: only asks for the next frame), and edit mode's edges.
local function WatchQueueEye()
    local function Again()
        if on then ns.Sched.NextFrame("minimapMicro.sync", Sync) end
    end
    if QueueStatusButton then ns.Sched.OnVisible(QueueStatusButton, "minimapMicro.queue", Again) end
    ns.OnEditMode(Again)
end

Sync = function()
    on = true
    if not watching then
        watching = true
        WatchQueueEye()
    end
    for _, spec in ipairs(MICROS) do
        local want = Wanted(spec)
        if want then spec.show() elseif spec.shown then spec.hide() end
        spec.shown = want
    end
    -- After the pass: a window's pad made later in it is the target.
    ns.Sched.NextFrame("minimapMicro.aim", Aim)
    if ns.EyeFollows then ns.EyeFollows() end
end

-- Era's eye and the icon the game's eye rides while queued (Map/MinimapEye.lua): one button, one spot.
function ns.EraEyeFace(icon) ns.Dress(icon, "lfgEye", EYE) end
ns.ERA_EYE = EYE
function ns.GroupFinderIcon()
    local spec = byToggle.lfgMinimapButton
    return on and Chosen(spec) and _G[spec.frame] or nil
end

local function Restore()
    on = false
    for _, spec in ipairs(MICROS) do
        if spec.shown then spec.hide() end
        spec.shown = false
    end
end

-- The eye showed only with the micro button hidden: an install from before with that button showing keeps no eye, in the
-- account and every profile. Runs before the defaults fill.
function ns.KeepGroupFinderEye()
    local db = ns.db
    local function Keep(t)
        if t.hideMicroButtons == false or t.hideMicroGroupFinder == false then t.lfgMinimapButton = false end
    end
    Keep(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Keep(shot) end
    end
    db.dbVersion = 8
end

-- Legacy on the minimap by default, where its micro button is hidden (it had no other way in): an install from before
-- with that button showing gets no icon, in the account and every profile. Runs before the defaults fill.
function ns.KeepLegacyIcon()
    local db = ns.db
    local function Keep(t)
        if t.hideMicroButtons == false or t.hideMicroLegacy == false then t.legacyMinimapButton = false end
    end
    Keep(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Keep(shot) end
    end
    db.dbVersion = 10
end

ns.RegisterModule("microMinimapButtons", { apply = Sync, restore = Restore })

-- Seen at once in a fight; a new icon's pad comes when it ends.
ns.OnToggle(function(key)
    if key == "microMinimapButtons" or byToggle[key] then Sync() else ns.Sched.NextFrame("minimapMicro.aim", Aim) end
end)
ns.EventFrame({ "PLAYER_ENTERING_WORLD" }, function() ns.Sched.NextFrame("minimapMicro.aim", Aim) end)
-- The game's spell window in the way or not: a closer's pad or the micro button itself (ns.PressTarget).
ns.OnGameSpellsRoom(Aim)

-- Public API (Core/API.lua): where a micro button stands now: the button (or ours standing in for it on the band) while
-- seen, else its icon on the minimap ring while seen; nil while neither is.
local STAND_INS = { SpellbookMicroButton = "ForeverClassicUISpellbookMicroButton",
    HelpMicroButton = "ForeverClassicUIHelpMicroButton", WorldMapMicroButton = "ForeverClassicUIWorldMapMicroButton" }
-- Forever's talents button has the ring icon talents' button has.
local RING_ALIASES = { PlayerSpellsMicroButton = "TalentMicroButton" }

-- Shown, not faded, and placed: a micro button hidden from the bar keeps its shown state with no point.
local function Seen(frame)
    if type(frame) ~= "table" or not frame.IsVisible or not frame:IsVisible() or not ns.Safe(frame:GetLeft()) then
        return false
    end
    local alpha = ns.Safe(frame:GetEffectiveAlpha())
    return alpha == nil or alpha > 0
end

function ns.MicroButtonNow(name)
    if type(name) ~= "string" then return nil end
    if Seen(_G[name]) then return _G[name] end
    local standIn = STAND_INS[name] and _G[STAND_INS[name]]
    if Seen(standIn) then return standIn end
    local micro = RING_ALIASES[name] or name
    for _, spec in ipairs(MICROS) do
        if spec.micro == micro or (spec.id == "WorldMap" and name == "WorldMapMicroButton") then
            local icon = _G[spec.name or ("ForeverClassicUIMinimap" .. spec.id .. "Button")]
            if Seen(icon) then return icon end
        end
    end
end
