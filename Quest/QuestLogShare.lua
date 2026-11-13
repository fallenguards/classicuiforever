local _, ns = ...
local L = ns.L

-- The quest log's Share Quest: a secure pad presses the client's own share, our click only explains.

local QL = ns.QL

-- QuestLogPushQuest is protected; the map's Share reads its quest off a row the game fills only as its quest pane shows.
-- One press, one run: map and pane open, Back drops old details and draws the list, the header unfolds, Back draws the
-- rows again, row and Share are pressed, the map shuts by the game's toggle rules (details left up; its next open resets).
local STEPS = { "Open", "AimPane", "Pane", "AimReset", "Reset", "AimHeader", "Header", "Rebuild", "AimRow", "Row", "Share",
    "AimShut", "Shut", "AimFix1", "Fix1", "AimFix2", "Fix2", "AimFix3", "Fix3" }
-- Only what the press aims: Open stays aimed while a share is possible.
local AIMED = { "Pane", "Reset", "Header", "Rebuild", "Row", "Share", "Shut", "Fix1", "Fix2", "Fix3" }
local proxies, macro
local armedID          -- the quest the pad shares
local wantedLog        -- the pane's saved wish (questLogOpen) as the press began
local pressed, shared  -- a press ran its aims; it reached the row

local function Aim(step, target)
    ns.SetAttributeIf(proxies[step], "clickbutton", target or nil)
end

local function Disarm()
    for _, step in ipairs(AIMED) do Aim(step, nil) end
end

-- Every aim needs the map this press opened: with a modifier held the open is skipped and nothing is pressed.
local function MapUp()
    return armedID ~= nil and not InCombatLockdown() and WorldMapFrame:IsShown()
end

local function PaneUp()
    return MapUp() and QuestMapFrame:IsShown()
end

local function BackButton()
    local details = QuestMapFrame.DetailsFrame
    return details and details.BackFrame and details.BackFrame.BackButton
end

local function AimPane()
    -- A modifier skips the map's clicks: that press is no failed share.
    pressed, shared = not IsModifierKeyDown(), false
    wantedLog = ns.GetCVar("questLogOpen") == "1"
    Disarm()
    if not MapUp() then return end
    -- Shut, or hidden by a maximized map: its toggle shows it and draws its rows.
    local toggle = WorldMapFrame.SidePanelToggle
    Aim("Pane", not QuestMapFrame:IsShown() and toggle and toggle.OpenButton or nil)
end

-- Back with no details up: the list drawn again at once, any left-over details and their map put away first.
local function AimReset()
    if PaneUp() then Aim("Reset", BackButton()) end
end

-- The header the quest sits under, by the log's own order; nil unless it is folded and has its button.
local function FoldedHeader(questID)
    local header, found
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            header = info.isCollapsed and i or nil
        elseif info and info.questID == questID then
            found = true
            break
        end
    end
    local pool = found and header and QuestScrollFrame and QuestScrollFrame.headerFramePool
    if not pool then return nil end
    for button in pool:EnumerateActive() do
        if button.questLogIndex == header then return button end
    end
end

-- The game folds every header but the map's own as the map opens: the quest's unfolds, and Back draws the rows again.
local function AimHeader()
    if not PaneUp() then return end
    Aim("Header", FoldedHeader(armedID))
    Aim("Rebuild", BackButton())
end

-- The quest's row, with a questID only client code wrote; reads only.
local function AimRow()
    if not PaneUp() then return end
    local find = _G.QuestLogQuests_GetQuestButton
    local row = find and find(armedID)
    local details = QuestMapFrame.DetailsFrame
    if not (row and issecurevariable(row, "questID") and details and details.ShareButton) then return end
    shared = true
    Aim("Row", row)
    Aim("Share", details.ShareButton)
end

-- The pane as its saved wish had it: shown by this press against a saved "closed", its toggle shuts it (and writes 0).
local function AimShut()
    local toggle = WorldMapFrame.SidePanelToggle
    if PaneUp() and not wantedLog and toggle then Aim("Shut", toggle.CloseButton) end
end

local function Rule(name)
    local rules = C_GameRules and Enum and Enum.GameRule
    return rules ~= nil and rules[name] ~= nil and C_GameRules.IsGameRuleActive(rules[name]) == true
end

-- The map's toggle (QuestLogOwnerMixin:HandleUserActionToggleSelf) shuts a maximized map, or a minimized one whose
-- pane agrees with its saved wish; a map that wants to be big maximizes first, a pane at odds with its wish is
-- toggled into agreement first. Three steps, each aimed from the live state, cover every path; a shut map aims none.
local function AimFix(step)
    if not MapUp() then Aim(step, nil) return end
    local map = WorldMapFrame
    local wantsBig = not Rule("MaximizeWorldMapDisabled") and ns.GetCVar("miniWorldMap") ~= "1"
    if (map.IsMaximized and map:IsMaximized()) or wantsBig then
        Aim(step, MinimapCluster.ZoneTextButton)
        return
    end
    local wantsLog = not Rule("QuestLogPanelDisabled") and ns.GetCVar("questLogOpen") == "1"
    if wantsLog ~= QuestMapFrame:IsShown() then
        local toggle = map.SidePanelToggle
        Aim(step, toggle and (QuestMapFrame:IsShown() and toggle.CloseButton or toggle.OpenButton) or nil)
        return
    end
    Aim(step, MinimapCluster.ZoneTextButton)
end

local AIMS = { AimPane = AimPane, AimReset = AimReset, AimHeader = AimHeader, AimRow = AimRow, AimShut = AimShut,
    AimFix1 = function() AimFix("Fix1") end, AimFix2 = function() AimFix("Fix2") end, AimFix3 = function() AimFix("Fix3") end }

local function Build()
    if proxies then return end
    proxies = {}
    local lines = {}
    for i, step in ipairs(STEPS) do
        -- Lettered, short names: the game cuts macro text at 255 characters.
        proxies[step] = ns.ClickProxy("FCQ" .. string.char(96 + i))
        if AIMS[step] then proxies[step]:SetScript("PreClick", AIMS[step]) end
        -- [nomod] on the map's open: shift on a map row toggles tracking and the chat-link modifier links it.
        lines[i] = string.format(step == "Open" and "/click [nomod] %s" or "/click %s", proxies[step]:GetName())
    end
    macro = table.concat(lines, "\n")
end

-- The quest to share while the pad may act: our Share lit, the world map shut, the game's pieces there.
local function Wanted()
    local frame, selectedID = QL.Frame(), QL.SelectedID()
    if not (selectedID and frame.share:IsVisible() and frame.share:IsEnabled()) then return nil end
    if not (WorldMapFrame and QuestMapFrame and MinimapCluster and MinimapCluster.ZoneTextButton) then return nil end
    if WorldMapFrame:IsShown() then return nil end
    return selectedID
end

-- Arms the pad for the picked quest out of combat, or disarms it so a stale pad presses nothing.
function QL.PointShare()
    if InCombatLockdown() then return nil end
    local questID = Wanted()
    if not questID and not proxies then return nil end
    Build()
    armedID = questID
    Aim("Open", questID and MinimapCluster.ZoneTextButton or nil)
    Disarm()
    return questID
end

-- Called by the pad's placer; nil hides the pad so our own click explains.
function QL.ShareMacro()
    return QL.PointShare() and macro or nil
end

-- After each press: nothing stays aimed, and a press that found no row says where to share instead.
function QL.SharePadAfter()
    if not pressed then return end
    pressed = false
    if not InCombatLockdown() then Disarm() end
    if not shared then UIErrorsFrame:AddMessage(L["QUEST_SHARE_FROM_THE_MAP"], 1, 0.1, 0.1) end
end

-- Reached only with the pad away: in combat, or with the map open.
function QL.ShareClick()
    local selectedID = QL.SelectedID()
    local info = selectedID and QL.QuestInLog(selectedID)
    if not info then return end
    if not IsInGroup() then
        UIErrorsFrame:AddMessage(L["QUEST_YOU_ARE_NOT_IN_A"], 1, 0.1, 0.1)
        return
    end
    if InCombatLockdown() then
        ns.SayNotInCombat()
    elseif WorldMapFrame and WorldMapFrame:IsShown() then
        -- Our log shares only with the map shut (both stay up only when opened in combat).
        UIErrorsFrame:AddMessage(L["QUEST_CLOSE_THE_WORLD_MAP_THEN"], 1, 0.1, 0.1)
    end
end
