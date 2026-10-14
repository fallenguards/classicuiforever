-- Offline tests for Map/MinimapMicro.lua under Lua 5.4: micro buttons as minimap icons, each on its own checkbox with
-- the micro button hidden or not; Legacy on by default; an install from before keeps its screen.
-- Run from the addon root: lua tools/tests/minimap_micro_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

for _, name in ipairs({ "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "ProfessionMicroButton",
    "QuestLogMicroButton", "LegacyMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton",
    "HelpMicroButton", "MainMenuMicroButton", "StoreMicroButton", "HousingMicroButton" }) do
    _G[name] = { name = name }
end
MinimapCluster = { ZoneTextButton = { name = "ZoneTextButton" } }
Enum = { GameRule = { StoreDisabled = 7, FinderPanelDisabled = 8, HousingDashboardDisabled = 9 } }
local ruleOn = {}
C_GameRules = { IsGameRuleActive = function(rule) return ruleOn[rule] == true end }
function InCombatLockdown() return false end
function SetPortraitTexture() end
-- The game's queue eye: shown while queued.
local queued = false
QueueStatusButton = { IsShown = function() return queued end }

local shown, pads, apply, restore, soon = {}, {}, nil, nil, {}
local eyeEdge, editEdge
local questPad = { name = "quest log pad" }
local noop = function() end
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    RING_ICON_FACE = { x = 0, y = 0 },
    RingButton = function(spec)
        _G[spec.name] = { name = spec.name }
        return function() shown[spec.name] = true end, function() shown[spec.name] = nil end
    end,
    RegisterModule = function(_, spec) apply, restore = spec.apply, spec.restore end,
    -- The quest log's micro button sits under its own pad.
    PressTarget = function(button) return button == QuestLogMicroButton and questPad or button end,
    PadOf = function(button) return pads[button] end,
    MapPad = function(button, _, _, target) pads[button] = { clickbutton = target } end,
    SetAttributeIf = function(pad, key, value) pad[key] = value end,
    Sched = { NextFrame = function(_, fn) soon[#soon + 1] = fn end,
        OnVisible = function(_, _, fn) eyeEdge = fn end },
    EditMode = { state = false },
    OnEditMode = function(fn) editEdge = fn end,
    IsSecret = function() return false end,
    -- Retail: its own two icons are made.
    OnForever = function() return false end,
    Dress = noop, OnToggle = noop, EventFrame = noop, WhenCalm = noop, OnGameSpellsRoom = noop,
}
assert(loadfile(ROOT .. "/Map/MinimapMicro.lua"))("ClassicUIForever", ns)

local function Pass()
    apply()
    for _, fn in ipairs(soon) do fn() end
    soon = {}
end

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end
local EYE, LEGACY, QUEST, SHOP, MAP = "ForeverClassicUIGroupFinderButton", "ForeverClassicUIMinimapLegacyButton",
    "ForeverClassicUIMinimapQuestLogButton", "ForeverClassicUIMinimapShopButton", "ForeverClassicUIMinimapWorldMapButton"

-- The defaults: Legacy and the group finder, hidden from the micro menu or not.
ns.db = { microMinimapButtons = true, lfgMinimapButton = true, legacyMinimapButton = true, hideMicroButtons = true,
    hideMicroGroupFinder = false }
Pass()
Check(shown[EYE] and shown[LEGACY], "Legacy and the eye show by default, the micro button shown or not")
Check(not shown[QUEST] and not shown[SHOP], "the rest stay off until checked")
Check(pads[_G[LEGACY]].clickbutton == LegacyMicroButton, "the Legacy icon presses the Legacy micro button")

-- A button whose micro button opens a window of ours through its own pad: the icon presses that pad.
ns.db.questLogMinimapButton, ns.db.worldMapMinimapButton = true, true
Pass()
Check(shown[QUEST] and pads[_G[QUEST]].clickbutton == questPad, "the quest log icon presses the quest log's own pad")
Check(shown[MAP] and pads[_G[MAP]].clickbutton == MinimapCluster.ZoneTextButton, "the map icon presses the zone name")

-- The housing button: both clients have the frame; Forever holds it off by a game rule, and the icon goes with it.
local HOUSING = "ForeverClassicUIMinimapHousingButton"
ns.db.housingMinimapButton = true
ruleOn[Enum.GameRule.HousingDashboardDisabled] = true
Pass()
Check(not shown[HOUSING], "no housing icon while the game has housing off (Forever)")
ruleOn[Enum.GameRule.HousingDashboardDisabled] = nil
Pass()
Check(shown[HOUSING] and pads[_G[HOUSING]].clickbutton == HousingMicroButton, "the housing icon presses the housing button (retail)")
ns.db.housingMinimapButton = false
Pass()
Check(not shown[HOUSING], "unchecked, the housing icon goes")

-- Retail's achievements and adventure guide buttons, off its micro menu by default: an icon each, pressing the button.
AchievementMicroButton, EJMicroButton = { name = "achievements" }, { name = "adventure guide" }
local ACHIEVEMENTS, JOURNAL = "ForeverClassicUIMinimapAchievementsButton", "ForeverClassicUIMinimapJournalButton"
ns.db.achievementsMinimapButton, ns.db.journalMinimapButton = true, true
Pass()
Check(shown[ACHIEVEMENTS] and pads[_G[ACHIEVEMENTS]].clickbutton == AchievementMicroButton,
    "the achievements icon presses the achievements button (retail)")
Check(shown[JOURNAL] and pads[_G[JOURNAL]].clickbutton == EJMicroButton, "the adventure guide icon presses its button (retail)")
ns.db.achievementsMinimapButton, ns.db.journalMinimapButton = false, false
Pass()
Check(not shown[ACHIEVEMENTS] and not shown[JOURNAL], "unchecked, both icons go")

-- A game rule that takes the button away takes its icon.
ns.db.shopMinimapButton = true
ruleOn[Enum.GameRule.StoreDisabled] = true
Pass()
Check(not shown[SHOP], "no shop icon while the game has the shop off")
ruleOn[Enum.GameRule.StoreDisabled] = nil
Pass()
Check(shown[SHOP], "the shop icon once the game allows it")

-- Queued, the game's eye shows and ours gives way; in edit mode the game's eye is the box placed, ours stays hidden.
queued = true
eyeEdge(true)
Pass()
Check(not shown[EYE], "queued: the game's eye shows, ours goes")
ns.EditMode.state = true
editEdge()
Pass()
Check(not shown[EYE], "in edit mode: the game's eye is the box, ours stays hidden")
ns.EditMode.state = false
queued = false
eyeEdge(false)
Pass()
Check(shown[EYE], "out of the queue: ours is back")

-- Unchecked, the block's switch, the module off.
ns.db.legacyMinimapButton = false
Pass()
Check(not shown[LEGACY] and shown[EYE], "unchecked, that icon goes")
ns.db.microMinimapButtons = false
Pass()
Check(next(shown) == nil, "the block's switch off: no icons")
ns.db.microMinimapButtons = true
Pass()
restore()
Check(next(shown) == nil, "the module off: no icons")

-- Upgraders: an icon that would be new beside a showing micro button stays off; one replacing a hidden button comes.
ns.db = {
    hideMicroGroupFinder = false, hideMicroLegacy = false, dbVersion = 7,
    profiles = { showing = { hideMicroButtons = false }, hidden = {} },
}
ns.KeepGroupFinderEye()
Check(ns.db.lfgMinimapButton == false and ns.db.profiles.showing.lfgMinimapButton == false, "eye off where the button shows")
Check(ns.db.profiles.hidden.lfgMinimapButton == nil and ns.db.dbVersion == 8, "eye default where it is hidden; dbVersion 8")
ns.KeepLegacyIcon()
Check(ns.db.legacyMinimapButton == false and ns.db.profiles.showing.legacyMinimapButton == false, "no Legacy icon where the button shows")
Check(ns.db.profiles.hidden.legacyMinimapButton == nil, "Legacy icon by default where the button is hidden")
Check(ns.db.dbVersion == 10, "writes dbVersion 10")

if failures > 0 then
    print(string.format("minimap micro: %d failed", failures))
    os.exit(1)
end
print("minimap micro: ok")
