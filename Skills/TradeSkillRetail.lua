local _, ns = ...
if ns.OnForever() then return end

-- Retail's crafting window: the old trade skill window (Skills/TradeSkill.lua) as its Recipes page, the game's own page
-- behind the size button and for what 1.x never had (the other tabs, runeforging, an NPC's crafts).
-- Watched from our child under the window, never hooked; nothing of the game's page is called.

local L = ns.L
local R = ns.tradeReagents

local GAME_W, GAME_H = 942, 658
local PARK_X = 6000
-- This window's border is not lifted (its tab row): our page hangs this far past its foot instead, the window that much shorter.
local FOOT_DROP = 10
local DROP_ARROW = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-"
local DROP_HOW = { set = "file", highlightSet = "raw", add = true }
local state = { ours = false }
local sizer

local function Full() return ns.db.tradeSkillFull == true end

-- The game's page width for its tab, as it last set it.
local function GameWidth(frame)
    local width = frame.currentPageWidth
    return type(width) == "number" and width or GAME_W
end

-- Ours stands for the Recipes tab of a profession the player crafts from.
local function Wanted(page)
    if not ns.TradeSkillActive() or Full() or not page:IsShown() then return false end
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

local function PickFull(full)
    if Full() == full then return end
    ns.db.tradeSkillFull = full
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

-- Ours beside the X, over the game's own (faded): our window or the game's page. On the game's page it stands left of the
-- game's, which keeps its own small view.
local function SizeButton(frame, page)
    local own = frame.MaximizeMinimize
    if not sizer then
        local ok, button = pcall(ns.NewFrame, "Frame", nil, frame, "MaximizeMinimizeButtonFrameTemplate")
        if not ok or not button then return end
        sizer = button
        button:SetOnMaximizedCallback(function() PickFull(true) end)
        button:SetOnMinimizedCallback(function() PickFull(false) end)
    end
    local shown = ns.TradeSkillActive() and page:IsShown() and (state.ours or Full())
    ns.SetShownIf(sizer, shown)
    if not shown then
        if own then ns.SetAlphaIf(own, 1) end
        return
    end
    local close = frame.CloseButton
    if state.side ~= state.ours then
        state.side = state.ours
        ns.panels.MaxMinBeside(sizer, state.ours and close or own or close, state.ours and 8 or 2)
    end
    if close then ns.SetLevelIf(sizer, close:GetFrameLevel() + 2) end
    if state.ours then sizer:SetMaximizedLook() else sizer:SetMinimizedLook() end
    if own then ns.SetAlphaIf(own, state.ours and 0 or 1) end
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
    if state.ours and not locked then Fit(frame) end
    ns.SetShownIf(panel, state.ours)
    SizeButton(frame, page)
end

ns.EventFrame({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD" }, function(self)
    if not ProfessionsFrame then return end
    self:UnregisterAllEvents()
    ns.Sched.Attach(ProfessionsFrame, { name = "tradeskill.retail", every = 0, fn = Tick })
end)

------------------------------------------------------------------ the page's retail pieces

-- A recipe in the game's own page: the game opens it there on its own answer to this ask.
local function OpenInGame(recipeID)
    PickFull(true)
    C_TradeSkillUI.OpenRecipe(recipeID)
end

local function LineEntries(refresh)
    local entries = {}
    for _, line in ipairs(R.Lines()) do
        local id = line.professionID
        entries[#entries + 1] = { line.expansionName or line.professionName or "", function()
            R.PickLine(id)
            refresh()
        end, function()
            local now = R.Line()
            return now ~= nil and now.professionID == id
        end }
    end
    return entries
end

-- Called once as the page is built: the expansion drop at the rank bar's end, the best quality check and the line that
-- opens the game's page, laid per recipe through panel.LayRetail.
function ns.TradeSkillRetailParts(panel, refresh, selectedInfo)
    local rank, detail = panel.rank, panel.detail
    R.Changed = refresh
    panel:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "BOTTOMRIGHT", 0, -FOOT_DROP)
    rank:SetPoint("RIGHT", panel, "RIGHT", -64, 0)
    local drop = ns.NewFrame("Button", nil, panel)
    drop:SetSize(24, 24)
    drop:SetPoint("LEFT", rank, "RIGHT", 5, -1)
    ns.DressStates(drop, DROP_ARROW .. "Up", DROP_ARROW .. "Down", DROP_ARROW .. "Disabled", ns.ART.HILIGHT, DROP_HOW)
    local lists = {}   -- base profession -> its drop list
    drop:SetScript("OnClick", function(self)
        local base = C_TradeSkillUI.GetBaseProfessionInfo()
        local key = base and base.professionID or 0
        if not lists[key] then
            lists[key] = ns.DropList(LineEntries(refresh))
            lists[key]:Follow(panel)
        end
        lists[key]:Toggle(self)
    end)
    ns.AttachTip(drop, { text = function() return _G.EXPANSION_FILTER_TEXT or "" end })

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
        drop:SetShown(#R.Lines() > 1)
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
