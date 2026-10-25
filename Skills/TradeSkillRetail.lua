local _, ns = ...
if ns.OnForever() then return end

-- Retail's crafting window: the old trade skill window (Skills/TradeSkill.lua) as its Recipes page; the game's own page
-- for what 1.x never had (the other tabs, runeforging, an NPC's crafts, a recipe opened there till the window shuts).
-- Watched from our child under the window, never hooked; nothing of the game's page is called.

local L = ns.L
local R = ns.tradeReagents

local GAME_W, GAME_H = 942, 658
local PARK_X = 6000
-- Our page hangs this far past the window's foot: its border wears the tab row's lift (5, Windows/Panels.lua), 5 less
-- than Forever's window (1 past its page), so its foot line stands where Forever's does, under the page's buttons.
local FOOT_DROP = 4
local state = { ours = false, game = false }

-- The game's page width for its tab, as it last set it.
local function GameWidth(frame)
    local width = frame.currentPageWidth
    return type(width) == "number" and width or GAME_W
end

-- Ours stands for the Recipes tab of a profession the player crafts from.
local function Wanted(page)
    if not ns.TradeSkillActive() or state.game or not page:IsShown() then return false end
    return not (C_TradeSkillUI.IsRuneforging() or C_TradeSkillUI.IsNPCCrafting())
end

-- The game's page out of sight and still running, or back in its window at the game's size.
local function Park(frame, page, on)
    if on then
        page:SetSize(GameWidth(frame), GAME_H)
        ns.SetPointOnce(page, "TOPLEFT", frame, "TOPLEFT", PARK_X, 0)
    else
        page:ClearAllPoints()
        page:SetAllPoints(frame)
        frame:SetSize(GameWidth(frame), GAME_H)
    end
    ns.SetAlphaIf(page, on and 0 or 1)
end

local function Fit(frame)
    local width, height = ns.TradeSkillWindowSize()
    height = height - FOOT_DROP
    if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
        frame:SetSize(width, height)
    end
end

-- The game lays this window for its own 658 tall page, raised by its fit to stay on screen; ours is shorter and stands on
-- the row's line as the game's other windows do (profwin read -55 against the line's -116). Out of a fight, by snippet.
local function OnLine(frame)
    if ns.MoverHolds(frame) or (ns.WindowMoving and ns.WindowMoving(frame)) then return end
    if ns.Safe(frame:GetNumPoints()) ~= 1 then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    x, y = ns.Safe(x), ns.Safe(y)
    if point ~= "TOPLEFT" or relPoint ~= "TOPLEFT" or not (x and y) then return end
    if rel and rel ~= UIParent and rel ~= ns.windowParts.eraHost then return end
    local _, top = ns.GameRow()
    local want = top / (ns.WindowRatio(frame) or 1)
    if math.abs(y - want) > 0.5 then ns.windowParts.TopLeft(frame, x, want) end
end

-- Every frame the window shows. In a fight a protected window keeps the page it has.
local function Tick()
    local frame = ProfessionsFrame
    local page = frame.CraftingPage
    local panel = ns.TradeSkillPage()
    if not page or not panel then return end
    local locked = InCombatLockdown() and (ns.Safe(frame:IsProtected(), true) or ns.Safe(page:IsProtected(), true))
    local ours = Wanted(page)
    if ours ~= state.ours and not locked then
        state.ours = ours
        Park(frame, page, ours)
    end
    if state.ours and not locked then
        Fit(frame)
        OnLine(frame)
    end
    ns.SetShownIf(panel, state.ours)
    -- The game's size button belongs to its own page: on ours it is gone, not faded (faded, it still took the click).
    local own = frame.MaximizeMinimize
    if own and not locked then ns.SetShownIf(own, not state.ours) end
end

ns.EventFrame({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD" }, function(self)
    if not ProfessionsFrame then return end
    self:UnregisterAllEvents()
    ns.Sched.Attach(ProfessionsFrame, { name = "tradeskill.retail", every = 0, fn = Tick })
    ns.Sched.OnVisible(ProfessionsFrame, "tradeskill.game", function(shown) if not shown then state.game = false end end)
end)

------------------------------------------------------------------ the page's retail pieces

-- A recipe in the game's own page, till the window shuts: the game opens it there on its own answer to this ask.
local function OpenInGame(recipeID)
    state.game = true
    C_TradeSkillUI.OpenRecipe(recipeID)
end

-- Called once as the page is built: the best quality check and the line that opens the game's page, laid per recipe
-- through panel.LayRetail. The expansion pick is in the Filter menu (Skills/TradeSkillExtras.lua).
function ns.TradeSkillRetailParts(panel, refresh, selectedInfo)
    local detail = panel.detail
    R.Changed = refresh
    panel:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "BOTTOMRIGHT", 0, -FOOT_DROP)
    local best = ns.SmallCheck(detail, _G.PROFESSIONS_USE_BEST_QUALITY_REAGENTS or "", 1, 0.82, 0)
    best:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -14 - math.ceil(best.label:GetStringWidth() or 120), -22)
    best:SetScript("OnClick", function(self) ns.CheckSound(self) end)
    panel.best = best

    local more = ns.NewFrame("Button", nil, detail)
    more:SetHeight(14)
    more:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -14, -50)
    local text = more:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("RIGHT", more, "RIGHT", 0, 0)
    more:SetHighlightTexture(ns.ART.HILIGHT, "ADD")
    more:SetScript("OnClick", function()
        local info = selectedInfo()
        if info then OpenInGame(info.recipeID) end
    end)

    function panel.LayRetail(info, schematic, gameOnly)
        best:SetShown(R.Tiered(schematic) and not gameOnly)
        -- A gathering profession's journal has nothing to make.
        local extras = (gameOnly and not info.isGatheringRecipe) or R.HasExtras(info, schematic)
        more:SetShown(extras)
        if extras then
            text:SetText(gameOnly and L["SKILL_MADE_IN_THE_GAME_WINDOW"] or L["SKILL_MORE_IN_THE_GAME_WINDOW"])
            more:SetWidth(math.ceil(text:GetStringWidth() or 100))
        end
    end
end
