local _, ns = ...

-- The client's profession extras on the old trade skill window (Skills/TradeSkill.lua): its filters as Era's checkbox
-- menu, the slots in a submenu, and Wrath's chain link beside the title.

-- Normal on the top half, its glow on the bottom.
local LINK_ART = "Interface\\TradeSkillFrame\\UI-TradeSkill-LinkButton"

-- The client's slot filter, as its own menu has it: Check All, Uncheck All, then each slot this profession makes.
local function SetAllSlots(shown)
    local api = C_TradeSkillUI
    for i = 1, api.GetAllFilterableInventorySlotsCount() do api.SetInventorySlotFilter(i, shown) end
end

local function SlotEntries()
    local api = C_TradeSkillUI
    local entries = {
        { CHECK_ALL or "Check All", click = function() SetAllSlots(true) end },
        { UNCHECK_ALL or "Uncheck All", click = function() SetAllSlots(false) end },
    }
    for i = 1, api.GetAllFilterableInventorySlotsCount() do
        entries[#entries + 1] = { api.GetFilterableInventorySlotName(i),
            check = function() return not api.IsInventorySlotFiltered(i) end,
            toggle = function() api.SetInventorySlotFilter(i, api.IsInventorySlotFiltered(i)) end }
    end
    return entries
end

-- Era's checkbox menu over the client's filters; Slots only where this profession makes gear.
function ns.TradeSkillFilterEntries()
    local api = C_TradeSkillUI
    local entries = {
        { CRAFT_IS_MAKEABLE or "Have Materials", check = api.GetOnlyShowMakeableRecipes,
            toggle = function() api.SetOnlyShowMakeableRecipes(not api.GetOnlyShowMakeableRecipes()) end },
        { TRADESKILL_FILTER_HAS_SKILL_UP or "Has Skill Up", check = api.GetOnlyShowSkillUpRecipes,
            toggle = function() api.SetOnlyShowSkillUpRecipes(not api.GetOnlyShowSkillUpRecipes()) end },
    }
    local slots = api.GetAllFilterableInventorySlotsCount and api.GetAllFilterableInventorySlotsCount() or 0
    if slots > 0 then entries[#entries + 1] = { TRADESKILL_FILTER_SLOTS or "Slots", sub = SlotEntries } end
    local R = ns.tradeReagents
    if not ns.OnForever() then
        entries[#entries + 1] = { _G.PROFESSION_RECIPES_SHOW_UNLEARNED or "", check = R.Unlearned, toggle = R.ToggleUnlearned }
    end
    -- Era's subclasses: each type the profession makes; ticked ones alone are listed.
    if #R.types > 0 then
        entries[#entries + 1] = { divider = true }
        for _, itemType in ipairs(R.types) do
            entries[#entries + 1] = { itemType, check = function() return R.TypePicked(itemType) end,
                toggle = function() R.ToggleType(itemType) end }
        end
    end
    return entries
end

-- Era's window art under the page. Era's window spans its art's x 12 to 350 and y 13 to 437, as ours does; spots
-- below are in that art's pixels, so the page's own are 12 left and 13 up.
local ERA_X, ERA_Y = 12, 13
local TOP_LEFT = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopLeft"
local TOP_RIGHT = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopRight"
local BOT_LEFT = "Interface\\TradeSkillFrame\\UI-TradeSkill-BotLeft"
local BOT_RIGHT = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-BotRight"

-- A piece of a file laid at file's own spot (fx, fy, fw wide, 256 tall): art rect x0..x1, y0..y1.
local function EraPiece(file, fx, fy, fw, x0, y0, x1, y1, layer)
    return { key = file, set = "raw", layer = layer or "BACKGROUND", w = x1 - x0, h = y1 - y0,
        coords = { (x0 - fx) / fw, (x1 - fx) / fw, (y0 - fy) / 256, (y1 - fy) / 256 },
        point = "TOPLEFT", x = x0 - ERA_X, y = ERA_Y - y0 }
end

-- Forever: Era's whole window, title strip, portrait ring and border too, laid 12 left and 13 up of ours, the window's
-- own border hidden (Skills/ProfessionsBookFrame.lua), as the book wears the spellbook's.
ns.TradeSkillFrameArt = {
    { key = TOP_LEFT, set = "raw", layer = "BACKGROUND", w = 256, h = 256, point = "TOPLEFT" },
    { key = TOP_RIGHT, set = "raw", layer = "BACKGROUND", w = 128, h = 256, point = "TOPLEFT", x = 256 },
    { key = BOT_LEFT, set = "raw", layer = "BACKGROUND", w = 256, h = 256, point = "TOPLEFT", y = -256 },
    { key = BOT_RIGHT, set = "raw", layer = "BACKGROUND", w = 128, h = 256, point = "TOPLEFT", x = 256, y = -256 },
}
-- Retail, under the window's own border: from under Era's title strip (34) down; its portrait ring (to 67 across and
-- down) is left to the window's own.
local WINDOW_ART = {
    EraPiece(TOP_LEFT, 0, 0, 256, 68, 34, 256, 256),
    EraPiece(TOP_LEFT, 0, 0, 256, 12, 67, 68, 256),
    EraPiece(TOP_RIGHT, 256, 0, 128, 256, 34, 350, 256),
    EraPiece(BOT_LEFT, 0, 256, 256, 12, 256, 256, 437),
    EraPiece(BOT_RIGHT, 256, 256, 128, 256, 256, 350, 437),
}
-- The rank strip's line and the list's All tab, as Era's frame lays them.
local SKILL_LINE = "Interface\\TradeSkillFrame\\UI-TradeSkill-SkillBorder"
local OVERLAYS = {
    { key = SKILL_LINE, set = "raw", layer = "ARTWORK", coords = { 0, 1, 0, 0.25 }, w = 256, h = 8, point = "TOPLEFT", x = 51, y = -37 },
    { key = SKILL_LINE, set = "raw", layer = "ARTWORK", coords = { 0, 0.109375, 0.25, 0.5 }, w = 28, h = 8, point = "TOPLEFT",
        x = 307, y = -37 },
    { key = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-ExpandTab-Left", set = "raw", layer = "ARTWORK", w = 8, h = 32,
        point = "TOPLEFT", x = 3, y = -58 },
    { key = "Interface\\QuestFrame\\UI-QuestLogSortTab-Middle", set = "raw", layer = "ARTWORK", w = 38, h = 32,
        point = "TOPLEFT", x = 11, y = -52 },
    { key = "Interface\\QuestFrame\\UI-QuestLogSortTab-Right", set = "raw", layer = "ARTWORK", w = 8, h = 32,
        point = "TOPLEFT", x = 49, y = -52 },
}
-- Between list and detail: the trainer's bar, run and end (its own bronze copy on the theme).
local DIVIDER = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar"
local DIVIDER_ART = {
    { key = DIVIDER, set = "raw", layer = "ARTWORK", coords = { 0, 1, 0, 0.25 }, w = 256, h = 16, point = "TOPLEFT", x = 3, y = -208 },
    { key = DIVIDER, set = "raw", layer = "ARTWORK", coords = { 0, 0.29296875, 0.25, 0.5 }, w = 75, h = 16, point = "TOPLEFT",
        x = 259, y = -208 },
}
-- Each scroll bar's column, its two halves round the bar and its arrows, as Era's list and detail templates hang them.
local COLUMN_TOP, COLUMN_FOOT = { 0, 0.46875, 0, 0.9609375 }, { 0.53125, 1, 0.03125, 1 }
ns.TradeSkillColumns = {
    list = {
        { key = "trainerScrollBar", layer = "BACKGROUND", coords = { 0, 0.46875, 0.0234375, 0.9609375 }, w = 30, h = 120,
            point = "TOPLEFT", x = -9, y = 18 },
        { key = "trainerScrollBar", layer = "BACKGROUND", coords = COLUMN_FOOT, w = 30, h = 123, point = "BOTTOMLEFT", x = -9, y = -18 },
    },
    detail = {
        { key = "trainerScrollBar", layer = "BACKGROUND", coords = COLUMN_TOP, w = 30, h = 123, point = "TOPLEFT", x = -8, y = 21 },
        { key = "trainerScrollBar", layer = "BACKGROUND", coords = COLUMN_FOOT, w = 30, h = 123, point = "BOTTOMLEFT", x = -8, y = -17 },
    },
}

-- The window's inside as Era draws it, under the page's rows and buttons.
-- Kept on the page for the double pane to hide (Skills/TradeSkillDual.lua).
function ns.TradeSkillEraArt(panel)
    if not ns.OnForever() then
        panel.eraWindow = ns.DressPieces(panel, WINDOW_ART, nil, true)
        for _, tex in ipairs(panel.eraWindow) do ns.BronzeTint(tex) end
    end
    panel.eraOverlays = ns.DressPieces(panel, OVERLAYS, nil, true)
    for _, tex in ipairs(panel.eraOverlays) do ns.BronzeTint(tex) end
    for _, tex in ipairs(ns.DressPieces(panel, DIVIDER_ART, nil, true)) do panel.eraOverlays[#panel.eraOverlays + 1] = tex end
end

local INPUT = "Interface\\Common\\Common-Input-Border"
-- Era's count box: its border 5 past the box's left, flush with its right.
local COUNT_BORDER = {
    { key = INPUT, set = "raw", layer = "BACKGROUND", coords = { 0, 0.0625, 0, 0.625 }, w = 8, h = 20, point = "TOPLEFT", x = -5 },
    { key = INPUT, set = "raw", layer = "BACKGROUND", coords = { 0.0625, 0.9375, 0, 0.625 }, w = 19, h = 20, point = "TOPLEFT", x = 3 },
    { key = INPUT, set = "raw", layer = "BACKGROUND", coords = { 0.9375, 1, 0, 0.625 }, w = 8, h = 20, point = "TOPRIGHT" },
}
local PREV, NEXT = ns.ART.PAGE_PREV, ns.ART.PAGE_NEXT
local PAGE_ARROW = { set = "file", highlightSet = "raw", add = true }

local function PageArrow(parent, art)
    local arrow = ns.NewFrame("Button", nil, parent)
    arrow:SetSize(23, 22)
    ns.DressStates(arrow, art .. "Up", art .. "Down", art .. "Disabled", ns.ART.HILIGHT, PAGE_ARROW)
    return arrow
end

-- In Era's foot boxes: Create All, the count between its arrows, Create and Exit where Era has them.
-- craft(all) makes one or all, step(by) moves the count.
function ns.TradeSkillFoot(panel, craft, step)
    local foot = ns.NewFrame("Frame", nil, panel)
    foot:SetAllPoints(panel)
    foot:SetFrameLevel(panel.detailBox:GetFrameLevel() + 8)

    local createAll = ns.PanelButton(foot, CREATE_ALL or "Create All", 80)
    createAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 4)
    createAll:SetScript("OnClick", function() craft(true) end)
    local dec = PageArrow(foot, PREV)
    dec:SetPoint("LEFT", createAll, "RIGHT", 3, 0)
    local count = ns.NewFrame("EditBox", nil, foot)
    count:SetSize(30, 20)
    count:SetPoint("LEFT", dec, "RIGHT", 4, 0)
    count:SetFontObject("ChatFontNormal")
    count.Left, count.Middle, count.Right = unpack(ns.DressPieces(count, COUNT_BORDER, nil, true))
    count:SetAutoFocus(false)
    count:SetNumeric(true)
    ns.DrainInput(count)
    count:SetMaxLetters(3)
    count:SetNumber(1)
    count:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    count:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local exit = ns.ShellExitButton(foot, "ProfessionsFrame", 80)
    exit:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 4)
    local create = ns.PanelButton(foot, CREATE_PROFESSION or CREATE or "Create", 80)
    create:SetPoint("RIGHT", exit, "LEFT", -1, 0)
    create:SetScript("OnClick", function() craft(false) end)
    local inc = PageArrow(foot, NEXT)
    inc:SetPoint("RIGHT", create, "LEFT", -3, 0)
    dec:SetScript("OnClick", function() step(-1) end)
    inc:SetScript("OnClick", function() step(1) end)
    panel.createAll, panel.create, panel.count = createAll, create, count
    panel.dec, panel.inc, panel.exit = dec, inc, exit
end

-- The profession's link in chat, the chat opened if shut.
function ns.TradeSkillLink(panel)
    local link = ns.NewFrame("Button", nil, panel)
    link:SetSize(32, 16)
    link:SetFrameLevel(panel:GetFrameLevel() + 13)
    link:SetNormalTexture(LINK_ART)
    link:GetNormalTexture():SetTexCoord(0, 1, 0, 0.5)
    link:SetHighlightTexture(LINK_ART, "ADD")
    link:GetHighlightTexture():SetTexCoord(0, 1, 0.5, 1)
    link:SetScript("OnClick", function()
        local text = C_TradeSkillUI.GetTradeSkillListLink and C_TradeSkillUI.GetTradeSkillListLink()
        if text and not ChatFrameUtil.InsertLink(text) then ChatFrameUtil.OpenChat(text) end
    end)
    link:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(LINK_TRADESKILL_TOOLTIP or "", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    link:SetScript("OnLeave", GameTooltip_Hide)
    link:Hide()
    return link
end

-- Just right of the title's words (centred text), on the player's own professions only.
function ns.PlaceTradeSkillLink(link, title)
    local api = C_TradeSkillUI
    local own = not (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) and not (api.IsTradeSkillGuild and api.IsTradeSkillGuild())
        and not (api.IsNPCCrafting and api.IsNPCCrafting())
    local linkable = own and title ~= nil and api.CanTradeSkillListLink and api.CanTradeSkillListLink() and true or false
    ns.SetShownIf(link, linkable)
    if linkable then ns.SetPointOnce(link, "LEFT", title, "CENTER", math.floor((title:GetStringWidth() or 0) / 2) + 5, 0) end
end
