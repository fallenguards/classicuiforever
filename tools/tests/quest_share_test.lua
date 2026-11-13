-- Offline tests for Quest/QuestLogShare.lua under Lua 5.4: one press of the quest log's Share runs the whole macro against
-- a stub of the game's map as the client behaves: the map opens in its saved mode, every map open folds the headers of
-- other zones, a header's click only marks it, the Back button draws the rows again at once, and the map's toggle shuts
-- it only from a state the game agrees to. Run from the addon root: lua tools/tests/quest_share_test.lua.
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

-- The game: its saved map mode and pane wish, the map, its pane, folded headers, the rows of the last draw.
local game = { map = false, maximized = false, pane = false, folded = {}, rows = {}, details = nil, shared = {},
    combat = false, grouped = true, cleanRows = true, cvars = { questLogOpen = "0", miniWorldMap = "1" } }
-- Header 1 (log index 1) holds the zone the player stands in; header 2 (log index 4) another zone, a dungeon's.
local QUESTS = { { header = 1, id = 11 }, { header = 1, id = 12 }, { header = 2, id = 21 } }
local HEADER_INDEX = { [1] = 1, [4] = 2 }
local zone, openButton, closeButton, shareButton, backButton = {}, {}, {}, {}, {}
local headerButtons = { { questLogIndex = 1 }, { questLogIndex = 4 } }

local function BuildRows()
    game.rows = {}
    for _, quest in ipairs(QUESTS) do
        if not game.folded[quest.header] then game.rows[quest.id] = { questID = quest.id } end
    end
end

-- The game's refresh as the map opens or changes (QuestLogMixin:Refresh): other zones' headers fold, rows are drawn.
local function Refresh()
    if not (game.map and game.pane) then return end
    game.folded[1], game.folded[2] = false, true
    BuildRows()
end

local function WantsBig() return game.cvars.miniWorldMap ~= "1" end
local function WantsLog() return game.cvars.questLogOpen == "1" end

-- Details of a quest from another zone close as the map returns to the player's zone.
local function ShowMap(maximized, pane)
    game.map, game.maximized, game.pane = true, maximized, pane
    game.sortedFor = "the player's zone"
    if game.detailsMap ~= game.sortedFor then game.details, game.detailsMap = nil, nil end
    Refresh()
end

-- The map's toggle (QuestLogOwnerMixin:HandleUserActionToggleSelf); the pane's shown flag outlives a shut map.
local function ToggleMap()
    if not game.map then
        if WantsBig() then ShowMap(true, false) else ShowMap(false, WantsLog()) end
    elseif game.maximized then
        game.map = false
    elseif WantsLog() == game.pane then
        if WantsBig() then game.maximized, game.pane = true, false else game.map = false end
    elseif WantsBig() then
        game.maximized, game.pane = true, false
    else
        game.pane = false
    end
end

-- The pane's toggle (HandleUserActionToggleSidePanel): either of its two buttons.
local function TogglePane()
    if not game.map then return end
    if game.pane then
        game.cvars.questLogOpen, game.pane = "0", false
    else
        game.cvars.questLogOpen, game.maximized, game.pane = "1", false, true
        Refresh()
    end
end

-- What each of the game's own buttons does when the macro's click reaches it.
local function Press(target)
    if target == zone then
        ToggleMap()
    elseif target == openButton or target == closeButton then
        TogglePane()
    elseif target == shareButton then
        if game.details then game.shared[#game.shared + 1] = game.details end
    elseif target == backButton then
        -- Back: the map returns to where the details came from, they close, the list is drawn again at once.
        if game.details then game.sortedFor = "the player's zone" end
        game.details, game.detailsMap = nil, nil
        if game.map and game.pane then BuildRows() end
        return
    end
    for _, button in ipairs(headerButtons) do
        -- A header's click only marks it: the rows follow an event after the press.
        if button == target and game.pane then
            local h = HEADER_INDEX[button.questLogIndex]
            game.folded[h] = not game.folded[h]
        end
    end
    for id, row in pairs(game.rows) do
        if row == target then
            -- The row's click shows its details and moves the map to the quest's zone, which refreshes the pane.
            game.details, game.detailsMap, game.sortedFor = id, "the quest's zone", "the quest's zone"
            Refresh()
        end
    end
end

WorldMapFrame = { IsShown = function() return game.map end, IsMaximized = function() return game.maximized end,
    SidePanelToggle = { OpenButton = openButton, CloseButton = closeButton } }
QuestMapFrame = { IsShown = function() return game.pane end,
    DetailsFrame = { ShareButton = shareButton, BackFrame = { BackButton = backButton } } }
QuestScrollFrame = { headerFramePool = { EnumerateActive = function()
    local i = 0
    return function()
        if not game.pane then return nil end
        i = i + 1
        return headerButtons[i]
    end
end } }
MinimapCluster = { ZoneTextButton = zone }
QuestLogQuests_GetQuestButton = function(id) return game.rows[id] end
C_QuestLog = {
    GetNumQuestLogEntries = function() return 5 end,
    GetInfo = function(i)
        local header = HEADER_INDEX[i]
        if header then return { isHeader = true, isCollapsed = game.folded[header] == true } end
        local quest = QUESTS[i <= 3 and i - 1 or 3]
        return { questID = quest.id }
    end,
}
function InCombatLockdown() return game.combat end
function IsModifierKeyDown() return game.modifier == true end
function IsInGroup() return game.grouped end
function issecurevariable() return game.cleanRows end
local errors = {}
UIErrorsFrame = { AddMessage = function(_, text) errors[#errors + 1] = text end }

------------------------------------------------------------------ the stub addon

local proxies = {}
local selected, shareLit = 11, true
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    QL = {
        Frame = function() return { share = { IsVisible = function() return true end, IsEnabled = function() return shareLit end } } end,
        SelectedID = function() return selected end,
        QuestInLog = function(id) return { questID = id } end,
    },
    ClickProxy = function(name)
        local proxy = { name = name, attrs = {}, scripts = {} }
        function proxy:SetScript(script, fn) self.scripts[script] = fn end
        function proxy:GetName() return self.name end
        proxies[name] = proxy
        return proxy
    end,
    SetAttributeIf = function(proxy, key, value) proxy.attrs[key] = value end,
    GetCVar = function(name) return game.cvars[name] end,
    SayNotInCombat = function() errors[#errors + 1] = "not in combat" end,
}
assert(loadfile(ROOT .. "/Quest/QuestLogShare.lua"))("ClassicUIForever", ns)
local QL = ns.QL

-- One press of the pad: the placer's macro text, each /click in order, then the pad's after.
local function PressPad(modifier)
    local text = QL.ShareMacro()
    if not text then return false end
    game.modifier = modifier
    for line in text:gmatch("[^\n]+") do
        local nomod, name = line:match("^/click (%[nomod%] )(%S+)$")
        if not name then name = line:match("^/click (%S+)$") end
        local proxy = assert(proxies[name], "the macro clicks a proxy that exists: " .. line)
        if not (nomod and modifier) then
            if proxy.scripts.PreClick then proxy.scripts.PreClick() end
            if proxy.attrs.clickbutton then Press(proxy.attrs.clickbutton) end
        end
    end
    QL.SharePadAfter()
    game.modifier = nil
    return true
end
local function Aimed()
    local n = 0
    for _, proxy in pairs(proxies) do
        if proxy.attrs.clickbutton and proxy.attrs.clickbutton ~= zone then n = n + 1 end
    end
    return n
end
local function Last() return game.shared[#game.shared] end

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

-- Fresh login, the pane's wish "closed": one press shares and leaves everything as it was. The quest's details stay
-- up in the shut map, as the game leaves them: its next open lands on the player's zone and closes them.
Check(PressPad() == true, "a pad stands over Share for a shareable quest")
Check(#game.shared == 1 and Last() == 11, "the picked quest is shared with no row beforehand")
Check(game.map == false and game.pane == false and game.cvars.questLogOpen == "0", "the map shuts, the pane and its wish as before")
Check(Aimed() == 0 and #errors == 0, "nothing stays aimed, no error line")
Check(#QL.ShareMacro() <= 255, "the macro fits the game's 255 characters of macro text (" .. #QL.ShareMacro() .. ")")

-- Another quest picked: that one, not the last one's stale row.
selected = 12
PressPad()
Check(Last() == 12, "a newly picked quest is the one shared")

-- A quest of another zone: the map's own open folds its header, the press unfolds it and draws the rows again.
selected = 21
PressPad()
Check(Last() == 21 and game.map == false, "a dungeon quest, under a header the map folds, is shared and the map shuts")

-- The player keeps the pane open: it stays open and its wish stays.
game.cvars.questLogOpen, game.pane = "1", true
PressPad()
Check(Last() == 21 and game.pane == true and game.cvars.questLogOpen == "1" and game.map == false, "a pane the player keeps open stays open")

-- The player's map is the big one: shared, and the map shuts, big as before.
game.cvars.miniWorldMap = "0"
PressPad()
Check(Last() == 21 and #game.shared == 5 and game.map == false, "with a maximized map the quest is shared and the map shuts")
Check(game.cvars.miniWorldMap == "0" and game.cvars.questLogOpen == "1", "the player's map mode and pane wish are kept")
game.cvars.questLogOpen = "0"
PressPad()
Check(#game.shared == 6 and game.map == false and game.cvars.questLogOpen == "0", "a big map with the pane's wish closed: shared, shut, wish kept")
game.cvars.miniWorldMap, game.pane = "1", false

-- Details of a quest of this zone left open in the map: put away first, the picked quest shared.
game.details, game.detailsMap = 11, "the player's zone"
PressPad()
Check(Last() == 21, "left-over quest details are put away and the picked quest is shared")

-- A modifier held: the map's own clicks are skipped, so nothing at all is pressed.
local before, detailsBefore = #game.shared, game.details
PressPad(true)
Check(#game.shared == before and game.map == false and game.details == detailsBefore, "with a modifier held nothing is pressed")
Check(#errors == 0, "and no error line: the modifier was the player's")

-- Rows the game did not fill (tainted) are never pressed; the press says where to share instead, and the map shuts.
game.cleanRows = false
PressPad()
Check(#game.shared == before and #errors == 1 and errors[1] == "QUEST_SHARE_FROM_THE_MAP", "a row not filled by the game is not pressed")
Check(game.map == false, "the map shuts after a press that found no row")
game.cleanRows, errors = true, {}

-- No pad while Share is unlit, the map is open, or in a fight; a stale pad's macro presses nothing.
shareLit = false
Check(QL.ShareMacro() == nil and proxies.FCQa.attrs.clickbutton == nil, "Share unlit: no pad, the map's click unaimed")
shareLit, game.map = true, true
Check(QL.ShareMacro() == nil, "the world map open: no pad")
QL.ShareClick()
Check(errors[1] == "QUEST_CLOSE_THE_WORLD_MAP_THEN", "our own click says to close the map")
game.map, errors = false, {}
game.combat = true
Check(QL.ShareMacro() == nil, "in a fight: no pad")
QL.ShareClick()
Check(errors[1] == "not in combat", "our own click says not in combat")
game.combat, errors = false, {}
game.grouped = false
QL.ShareClick()
Check(errors[1] == "QUEST_YOU_ARE_NOT_IN_A", "alone: our own click says so")

-- Retail has no row finder: the row comes from the rows' pool.
QuestLogQuests_GetQuestButton = nil
QuestScrollFrame.titleFramePool = { EnumerateActive = function()
    local id
    return function()
        id = next(game.rows, id)
        return id and game.rows[id]
    end
end }
game.grouped, game.map, game.pane, shareLit = true, false, false, true
before = #game.shared
PressPad()
Check(#game.shared == before + 1 and game.map == false, "without the game's row finder the row is found in the rows' pool")

if failures > 0 then
    print(string.format("quest share: %d failed", failures))
    os.exit(1)
end
print("quest share: ok")
