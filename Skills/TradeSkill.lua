local _, ns = ...

-- The old trade skill window: rank bar, recipes under folding headers in difficulty colours, the pick's icon, needs and reagents,
-- then Create All, count, Create, Exit. Hosted in the client's ProfessionsFrame (title, close, tabs), whose crafting page is parked
-- unseen and kept running: the window opens and closes the trade skill around it. Public calls only; that page is never called or written.

local active = false
local panel
local WINDOW_W, WINDOW_H = 338, 424
-- Forever: the small book's size, the page 2 in, so its border lands on the book's and a page turn moves nothing.
local FOREVER_W, FOREVER_H, PAGE_X = 339, 425, 2
local LIST_ROWS = 8
local REAGENTS_MAX = 8
-- Era's detail spots, in its scroll's content.
local ICON_TOP, LABEL_TOP = 3, 47
local REAGENT_W, REAGENT_PITCH = 147, 43
-- List rows as wide as Era's highlight: narrower while its scroll bar shows.
local LIST_W, LIST_W_BAR = 316, 293

local IsSecret = ns.IsSecret
local SkillList = ns.SkillList
local EMPTY = ns.EMPTY
local R = ns.tradeReagents

local selected          -- recipe id
local collapsed = {}    -- category id -> true
local lines = {}        -- the list as drawn: headers and recipes

local DIFFICULTY = {
    [0] = { 1.00, 0.50, 0.25 },   -- optimal: orange
    [1] = { 1.00, 1.00, 0.00 },   -- medium: yellow
    [2] = { 0.25, 0.75, 0.25 },   -- easy: green
    [3] = { 0.50, 0.50, 0.50 },   -- trivial: gray
}

function ns.TradeSkillActive() return active end

-- A recipe's needs (R.Read) never change; false: unreadable.
local reagentsOf = {}

-- Craftable count from reagents in reach. The client's numAvailable is empty on Forever (no counts, Create grey): fallback only.
local function Craftable(info)
    if not info or not info.recipeID then return 0 end
    local best = info.numAvailable or 0
    local needs = reagentsOf[info.recipeID]
    if needs == nil then
        needs = R.Read(info.recipeID) or false
        reagentsOf[info.recipeID] = needs
    end
    if not needs then return best end
    local count
    for _, need in ipairs(needs) do
        if need[2] > 0 then
            local makes = math.floor(R.Have(need[3]) / need[2])
            if not count or makes < count then count = makes end
        end
    end
    return count or best
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

local function CategoryOf(id, cache)
    if cache[id] == nil then
        local info = C_TradeSkillUI.GetCategoryInfo and C_TradeSkillUI.GetCategoryInfo(id)
        cache[id] = info or false
    end
    return cache[id] or nil
end

local function GroupOrder(a, b)
    if a.sort ~= b.sort then return a.sort < b.sort end
    return a.name < b.name
end

local function RecipeOrder(a, b)
    -- Not learned (retail, on request): after the rest.
    local da, db = a.learned == false and 4 or a.relativeDifficulty or 3, b.learned == false and 4 or b.relativeDifficulty or 3
    if da ~= db then return da < db end
    return (a.name or "") < (b.name or "")
end

-- Search text: lists matching recipes even under folded headers.
local query = ""
local wanted   -- a recipe asked for (public API): unfolded and picked once listed

local function Collect()
    wipe(lines)
    local api = C_TradeSkillUI
    if not api or not api.GetFilteredRecipeIDs then return end
    local ids = api.GetFilteredRecipeIDs() or {}
    local groups, order, cache = {}, {}, {}
    -- Retail lists every expansion's recipes: the picked one's only.
    local era = R.Line()
    local unlearned = R.Unlearned()
    local types, seenType = R.types, {}
    wipe(types)
    for _, id in ipairs(ids) do
        local info = api.GetRecipeInfo(id)
        local named = query == "" or (info and type(info.name) == "string" and info.name:lower():find(query, 1, true) ~= nil)
        local listed = info and (info.learned ~= false or unlearned) and named and (not era or api.IsRecipeInSkillLine(id, era.professionID))
        local itemType = listed and R.TypeOf(id)
        if itemType and not seenType[itemType] then
            seenType[itemType] = true
            types[#types + 1] = itemType
        end
        if listed and R.TypeShown(itemType) then
            local cat = info.categoryID or 0
            if id == wanted then collapsed[cat] = nil end
            local group = groups[cat]
            if not group then
                local catInfo = CategoryOf(cat, cache)
                local parent = catInfo and catInfo.parentCategoryID and CategoryOf(catInfo.parentCategoryID, cache)
                group = {
                    id = cat,
                    name = catInfo and catInfo.name or (OTHER or "Other"),
                    sort = (parent and parent.uiOrder or 0) * 1000 + (catInfo and catInfo.uiOrder or 0),
                    recipes = {},
                }
                groups[cat] = group
                order[#order + 1] = group
            end
            group.recipes[#group.recipes + 1] = info
        end
    end
    table.sort(types)
    table.sort(order, GroupOrder)
    local first
    for _, group in ipairs(order) do
        table.sort(group.recipes, RecipeOrder)
        lines[#lines + 1] = { header = true, id = group.id, name = group.name }
        if query ~= "" or not collapsed[group.id] then
            for _, info in ipairs(group.recipes) do
                lines[#lines + 1] = { info = info }
                first = first or info.recipeID
            end
        end
    end
    -- The chosen recipe stays chosen while it is still listed; one asked for is chosen once listed.
    local still = false
    for _, line in ipairs(lines) do
        local id = line.info and line.info.recipeID
        if id and id == wanted then selected, wanted = id, nil end
        if id and id == selected then still = true end
    end
    if not still then selected = first end
end

local UpdateDetail

local function DrawItem(row, line)
    local info = line.info
    row.toggle:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", 26, 0)
    local name = info.name or ""
    local count = Craftable(info)
    if count > 0 and info.learned ~= false then name = name .. " [" .. count .. "]" end
    row.text:SetText(name)
    SkillList.Paint(row, info.recipeID == selected, DIFFICULTY[info.relativeDifficulty or 3] or DIFFICULTY[3])
end

local function UpdateRows()
    if not panel then return end
    SkillList.Draw(panel, lines, collapsed, DrawItem)
    panel.bar:SetRange(math.max(0, #lines - LIST_ROWS))
    panel.list:SetWidth(panel.bar:IsShown() and LIST_W_BAR or LIST_W)
    if panel.collapseAll then SkillList.FoldIcon(panel, lines, collapsed) end
end

local function Row_OnClick(self, button)
    local line = self.line
    if not line then return end
    if SkillList.Fold(line, collapsed) then
        Collect()
        UpdateRows()
        UpdateDetail()
        return
    end
    local info = line.info
    if button == "LeftButton" and IsModifiedClick and IsModifiedClick("CHATLINK") then
        local link = C_TradeSkillUI.GetRecipeLink and C_TradeSkillUI.GetRecipeLink(info.recipeID)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
    end
    selected = info.recipeID
    panel.count:SetNumber(1)
    UpdateRows()
    UpdateDetail()
end

local function CreateRow(parent, index)
    return ns.SkillListRow(parent, index, Row_OnClick, 0.6)
end

---------------------------------------------------------------------------
-- The chosen recipe
---------------------------------------------------------------------------

local function ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return name
end

local function ItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
    if GetItemIcon then return GetItemIcon(itemID) end
end

-- Reagent names load a beat after first request, so first picks showed blank plates: every listed recipe's
-- reagents are requested up front, ten recipes a tick.
local warmed, warmQueue = {}, {}

local function WarmTick(job)
    for _ = 1, 10 do
        local id = table.remove(warmQueue)
        if not id then
            job:Sleep()
            return
        end
        local list = reagentsOf[id]
        if not list then
            -- Read again after a failed read, but a failure stays Craftable's to record.
            list = R.Read(id)
            if list and reagentsOf[id] == nil then reagentsOf[id] = list end
        end
        for _, need in ipairs(list or EMPTY) do
            if not C_Item.GetItemNameByID(need[1]) then C_Item.RequestLoadItemDataByID(need[1]) end
        end
    end
end
-- Asleep while the queue is empty.
local warmJob = ns.Sched.Job({ name = "trade.warm", every = 0.02, awake = false, fn = WarmTick })

local function WarmReagents()
    local api = C_TradeSkillUI
    if not (api and api.GetRecipeSchematic and C_Item and C_Item.RequestLoadItemDataByID) then return end
    for _, line in ipairs(lines) do
        local id = line.info and line.info.recipeID
        if id and not warmed[id] then
            warmed[id] = true
            warmQueue[#warmQueue + 1] = id
        end
    end
    if #warmQueue > 0 then warmJob:Wake() end
end

local function SelectedInfo()
    if not selected then return nil end
    return C_TradeSkillUI.GetRecipeInfo(selected)
end

-- The content as tall as its reagents; the bar shows only when they run past the pane.
local function FitDetail()
    local detail, scroll = panel.detail, panel.detailScroll
    local bottom = ICON_TOP + 37
    local rows = math.ceil((detail.shownReagents or 0) / 2)
    if rows > 0 then
        bottom = LABEL_TOP + (detail.reagentLabel:GetStringHeight() or 10) + 3 + rows * REAGENT_PITCH - 2
    end
    local room = scroll:GetHeight() or 0
    local height = math.max(room, bottom + 4)
    detail:SetSize(scroll:GetWidth() or 1, height)
    panel.detailBar:SetRange(height - room, REAGENT_PITCH)
end

UpdateDetail = function()
    if not panel then return end
    local detail = panel.detail
    local info = SelectedInfo()
    detail:SetShown(info ~= nil)
    if not info then
        detail.shownReagents = 0
        FitDetail()
        panel.create:Disable()
        panel.createAll:Disable()
        return
    end
    local api = C_TradeSkillUI
    local schematic = api.GetRecipeSchematic and api.GetRecipeSchematic(info.recipeID, false)
    detail.icon:SetTexture(info.icon or (schematic and schematic.icon))
    local name = info.name or ""
    local made = schematic and schematic.quantityMax or 1
    detail.made:SetText(made and made > 1 and made or "")
    detail.name:SetText(name)

    -- Track Recipe, as on the client's page: the tracker lists its reagents. Not on a linked or guild list.
    local track = detail.track
    if track then
        local tracked = api.IsRecipeTracked(info.recipeID, false) and true or false
        track:SetChecked(tracked)
        local foreign = (api.IsTradeSkillLinked and api.IsTradeSkillLinked())
            or (api.IsTradeSkillGuild and api.IsTradeSkillGuild())
        track:SetEnabled(not foreign)
        if foreign then track.label:SetTextColor(0.5, 0.5, 0.5) else track.label:SetTextColor(1, 0.82, 0) end
    end

    -- What it needs beside the reagents: tools, a forge, an anvil.
    local needs = {}
    local requirements = api.GetRecipeRequirements and api.GetRecipeRequirements(info.recipeID)
    for _, requirement in ipairs(requirements or {}) do
        local color = requirement.met and "|cffffffff" or "|cffff2020"
        needs[#needs + 1] = color .. (requirement.name or "") .. "|r"
    end
    -- Not learned: where it comes from, in the requirement line.
    local source = info.learned == false and api.GetRecipeSourceText and api.GetRecipeSourceText(info.recipeID)
    if source then
        detail.requires:SetText(source)
        detail.requires:Show()
    elseif #needs > 0 then
        detail.requires:SetText((REQUIRES_LABEL or "Requires:") .. " " .. table.concat(needs, ", "))
        detail.requires:Show()
    else
        detail.requires:SetText("")
        detail.requires:Hide()
    end

    local cooldown = api.GetRecipeCooldown and api.GetRecipeCooldown(info.recipeID)
    if cooldown and cooldown > 0 then
        detail.cooldown:SetText((COOLDOWN_REMAINING or "Cooldown remaining:") .. " " .. SecondsToTime(cooldown))
        detail.cooldown:Show()
    else
        detail.cooldown:Hide()
    end

    local shown = 0
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local basic = R.IsBasic(slot)
        local reagent = slot.reagents and slot.reagents[1]
        if basic and reagent and reagent.itemID and shown < REAGENTS_MAX then
            shown = shown + 1
            local button = detail.reagents[shown]
            local need = slot.quantityRequired or 1
            local have = R.Have(slot)
            button.itemID = reagent.itemID
            button.slotIndex = slot.dataSlotIndex or slot.slotIndex
            button.icon:SetTexture(ItemIcon(reagent.itemID))
            button.name:SetText(ItemName(reagent.itemID) or "")
            button.count:SetText(have .. "/" .. need)
            if have < need then
                button.icon:SetVertexColor(0.5, 0.5, 0.5)
                button.name:SetTextColor(0.5, 0.5, 0.5)
            else
                button.icon:SetVertexColor(1, 1, 1)
                button.name:SetTextColor(1, 1, 1)
            end
            button:Show()
        end
    end
    for i = shown + 1, REAGENTS_MAX do detail.reagents[i]:Hide() end
    detail.reagentLabel:SetShown(shown > 0)
    detail.shownReagents = shown
    -- A new recipe opens at the top.
    if detail.recipeShown ~= info.recipeID then
        detail.recipeShown = info.recipeID
        panel.detailBar:SetValue(0)
    end
    FitDetail()

    local gameOnly = R.GameOnly(info, schematic)
    local can = Craftable(info) > 0 and not info.disabled and not gameOnly and info.learned ~= false
    panel.create:SetEnabled(can)
    panel.createAll:SetEnabled(can)
    if panel.LayRetail then panel.LayRetail(info, schematic, gameOnly) end
end

-- Whether an item is on the chosen recipe's plates; an unreadable id counts as yes.
local function OnPlates(itemID)
    if IsSecret(itemID) or itemID == nil then return true end
    local reagents = panel.detail.reagents
    for i = 1, REAGENTS_MAX do
        local button = reagents[i]
        if button:IsShown() and button.itemID == itemID then return true end
    end
    return false
end

local function Reagent_OnEnter(self)
    if not selected or not self.slotIndex then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    local ok = GameTooltip.SetRecipeReagentItem and pcall(GameTooltip.SetRecipeReagentItem, GameTooltip, selected, self.slotIndex)
    if not ok and self.itemID and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
    GameTooltip:Show()
end

local function Reagent_OnClick(self)
    if not self.itemID or not (IsModifiedClick and IsModifiedClick()) then return end
    local _, link = C_Item.GetItemInfo(self.itemID)
    if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
end

local function ReagentButton(parent, index)
    local button = ns.NewFrame("Button", nil, parent)
    button:SetSize(REAGENT_W, 41)
    local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
    button:SetPoint("TOPLEFT", parent.reagentLabel, "BOTTOMLEFT", column * REAGENT_W - 5, -3 - line * REAGENT_PITCH)
    local plate = button:CreateTexture(nil, "BACKGROUND")
    ns.SetFile(plate, "Interface\\QuestFrame\\UI-QuestItemNameFrame")
    plate:SetSize(128, 64)
    plate:SetPoint("LEFT", button, "LEFT", 30, 0)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(39, 39)
    icon:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.icon = icon
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    button.count = count
    local name = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetSize(98, 36)
    name:SetJustifyH("LEFT")
    button.name = name
    button:SetScript("OnEnter", Reagent_OnEnter)
    button:SetScript("OnLeave", ns.HideTip)
    button:SetScript("OnClick", Reagent_OnClick)
    return button
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local api = C_TradeSkillUI
    local era = R.Line()
    local prof = era or (api.GetChildProfessionInfo and api.GetChildProfessionInfo())
    if not prof or not prof.maxSkillLevel or prof.maxSkillLevel == 0 then
        prof = api.GetBaseProfessionInfo and api.GetBaseProfessionInfo() or prof
    end
    Collect()
    -- Opened in a rush (two professions as the window shows, above all in combat)
    -- the trade skill may lack name and rank: take them from the first recipe's skill.
    if (not prof or (prof.maxSkillLevel or 0) == 0) and api.GetTradeSkillLineForRecipe and GetProfessions and GetProfessionInfo then
        local first
        for _, line in ipairs(lines) do
            if line.info then first = line.info.recipeID break end
        end
        local lineID, _, parentID
        if first then lineID, _, parentID = api.GetTradeSkillLineForRecipe(first) end
        -- The professions list has gaps for the ones not learned.
        local known = { GetProfessions() }
        for slot = 1, 8 do
            local index = known[slot]
            if index then
                local name, _, rank, maxRank, _, _, skillLine, modifier = GetProfessionInfo(index)
                if name and skillLine and (skillLine == lineID or skillLine == parentID) then
                    prof = { professionName = name, skillLevel = rank, maxSkillLevel = maxRank, skillModifier = modifier }
                    break
                end
            end
        end
    end
    local title = ProfessionsFrame and ProfessionsFrame.TitleContainer and ProfessionsFrame.TitleContainer.TitleText
    if title and prof and prof.professionName and (title:GetText() or "") == "" then title:SetText(prof.professionName) end
    ns.PlaceTradeSkillLink(panel.link, title)
    if ns.OnForever() then ns.ProfessionPortrait() end
    if prof then
        local rank, maxRank = prof.skillLevel or 0, prof.maxSkillLevel or 0
        panel.rank:SetMinMaxValues(0, math.max(1, maxRank))
        panel.rank:SetValue(rank)
        local modifier = prof.skillModifier or 0
        if modifier > 0 then
            panel.rank.text:SetFormattedText("%d (+%d)/%d", rank, modifier, maxRank)
        else
            panel.rank.text:SetFormattedText("%d/%d", rank, maxRank)
        end
        -- Retail: the picked expansion in the profession's place.
        panel.rank.name:SetText(era and era.expansionName or prof.professionName or "")
    end
    UpdateRows()
    UpdateDetail()
    WarmReagents()
end

local function Craft(all)
    local info = SelectedInfo()
    if not info then return end
    local count = 1
    if all then
        count = Craftable(info)
    elseif panel.count then
        count = panel.count:GetNumber() or 1
    end
    count = math.max(1, math.min(count, math.max(1, Craftable(info))))
    panel.count:ClearFocus()
    -- The count runs down as each is made, as the old window's did.
    panel.count:SetNumber(count)
    panel.making = { recipe = info.recipeID, left = count }
    local best = panel.best and panel.best:GetChecked()
    C_TradeSkillUI.CraftRecipe(info.recipeID, count, R.Infos(reagentsOf[info.recipeID] or nil, best))
end

local CAST_STOPPED = { "UPDATE_TRADESKILL_CAST_STOPPED" }
local CAST_BROKEN = { "UNIT_SPELLCAST_INTERRUPTED" }

-- One made: the box shows what is left. A run that ends or breaks off leaves it at one.
local function RunWatch()
    local watch = CreateFrame("Frame")
    watch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ns.RegisterEvents(watch, CAST_STOPPED)
    ns.RegisterEvents(watch, CAST_BROKEN, "player")
    watch:SetScript("OnEvent", function(_, event, unit, _, spellID)
        local making = panel and panel.making
        if not making then return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if IsSecret(spellID) or spellID ~= making.recipe then return end
            making.left = making.left - 1
            if making.left <= 0 then
                panel.making = nil
                panel.count:SetNumber(1)
            else
                panel.count:SetNumber(making.left)
            end
        elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" or unit == "player" then
            panel.making = nil
            panel.count:SetNumber(1)
        end
    end)
end

-- Search toggle; off clears any search.
local function SearchShown(on)
    if not panel or not panel.search then return end
    if not on then panel.search:SetText("") end
    panel.search:SetShown(on)
    panel.searchBox:SetShown(on)
end
ns.RegisterModule("tradeSkillSearch", {
    apply = function() SearchShown(true) end,
    restore = function() SearchShown(false) end,
})

local function Result_OnEnter(self)
    if not selected then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = GameTooltip.SetRecipeResultItem and pcall(GameTooltip.SetRecipeResultItem, GameTooltip, selected, {}, nil, nil, nil)
    if not ok and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(selected) end
    GameTooltip:Show()
end

local TRADE_EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_DETAILS_UPDATE", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "SKILL_LINES_CHANGED",
    "UPDATE_TRADESKILL_CAST_STOPPED", "TRADE_SKILL_ITEM_CRAFTED_RESULT", "TRACKED_RECIPE_UPDATE" }

-- One pass per event burst, next frame; item data alone only touches the detail plates.
local detailOnly = true
local function RunRefresh()
    if detailOnly then
        if panel and panel:IsShown() then UpdateDetail() end
    else
        Refresh()
    end
    detailOnly = true
end

-- Era's detail scrolls: its scroll frame's spot, the bar beside it in the list's column; the content becomes panel.detail.
local function DetailScroll()
    local scroll = ns.NewFrame("ScrollFrame", nil, panel.detail)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -221)
    scroll:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", 305, -397)
    local content = ns.NewFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = ns.ShellScrollBar(panel, scroll, function(value) scroll:SetVerticalScroll(value) end,
        ns.TradeSkillColumns.detail)
    bar.hideWhenIdle = true
    bar:SetFrameLevel(panel.detailBox:GetFrameLevel() + 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * REAGENT_PITCH) end)
    panel.detailScroll, panel.detailBar, panel.detail = scroll, bar, content
    scroll:SetScript("OnSizeChanged", FitDetail)
    return content
end

local function Build()
    local host = ProfessionsFrame
    if panel or not host then return panel end
    panel = ns.ShellPage("ClassicUIForeverTradeSkill", host)
    if ns.OnForever() then
        ns.SetPointOnce(panel, "TOPLEFT", host, "TOPLEFT", PAGE_X, 0)
        panel:SetSize(WINDOW_W, WINDOW_H)
    end
    panel:Hide()

    -- Era's rank bar in its strip under the title, all the way across: the profession, then the rank.
    local rank = ns.NewFrame("StatusBar", nil, panel)
    rank:SetPoint("TOPLEFT", panel, "TOPLEFT", 61, -24)
    rank:SetPoint("RIGHT", panel, "RIGHT", -9, 0)
    rank:SetHeight(15)
    ns.SetBarFill(rank, "skillsBar")
    -- Era's colors as it draws them: the fill blue at half; the backing its faint white, tinted half blue.
    rank:SetStatusBarColor(0, 0, 1, 0.5)
    local rankBg = rank:CreateTexture(nil, "BACKGROUND")
    rankBg:SetAllPoints(rank)
    rankBg:SetColorTexture(1, 1, 1, 0.2)
    rankBg:SetVertexColor(0, 0, 0.75, 0.5)
    local rankBorder = rank:CreateTexture(nil, "OVERLAY")
    ns.SetTex(rankBorder, "skillsBarBorder")
    rankBorder:SetSize(281, 32)
    rankBorder:SetPoint("LEFT", rank, "LEFT", -5, 0)
    rank.name = rank:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank.name:SetPoint("LEFT", rank, "LEFT", 6, 1)
    rank.text = rank:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rank.text:SetPoint("LEFT", rank.name, "RIGHT", 13, 0)
    panel.rank = rank

    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = UpdateRows, era = true,
        listColumn = ns.TradeSkillColumns.list })
    ns.TradeSkillEraArt(panel)
    -- Era's spots: rows from 83 down, its list bar beside them, the All button in its tab, the filter on its drop down.
    ns.SetPointOnce(panel.list, "TOPLEFT", panel, "TOPLEFT", 10, -83)
    panel.list:SetSize(LIST_W, LIST_ROWS * 16)
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 311, -99)
    panel.bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 311, -197)
    panel.collapseAll:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -62)
    panel.filter:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -11, -52)
    local all, filter, detail = panel.collapseAll, panel.filter, DetailScroll()
    all:SetScript("OnClick", function()
        SkillList.FoldAll(lines, collapsed)
        Collect()
        UpdateRows()
        UpdateDetail()
    end)
    filter:SetScript("OnClick", function(self)
        if not panel.filterList then
            panel.filterList = ns.TreeMenu(ns.TradeSkillFilterEntries)
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)

    -- Beside the title, placed each Refresh (Skills/TradeSkillExtras.lua).
    panel.link = ns.TradeSkillLink(panel)

    -- Search box between the All tab and the filter (the old window had none), in
    -- the count's thin border.
    local search = ns.NewFrame("EditBox", nil, panel)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 75, -57)
    search:SetPoint("RIGHT", panel.filter, "LEFT", -14, 0)
    search:SetHeight(16)
    search:SetFrameLevel(panel:GetFrameLevel() + 13)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetMaxLetters(40)
    search:SetTextInsets(2, 20, 0, 0)
    local searchBox = ns.SkillInsetBox(panel, 16, true, 0.5)
    searchBox:SetPoint("TOPLEFT", search, "TOPLEFT", -7, 5)
    searchBox:SetPoint("BOTTOMRIGHT", search, "BOTTOMRIGHT", 5, -5)
    searchBox:SetFrameLevel(panel:GetFrameLevel() + 12)
    local searchHint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", search, "LEFT", 3, 0)
    searchHint:SetText(SEARCH or "Search")
    local clear = ns.SearchClear(search)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        local text = (self:GetText() or ""):lower()
        searchHint:SetShown(text == "")
        clear:SetShown(text ~= "")
        if text ~= query then
            query = text
            panel.bar:SetValue(0)
            Collect()
            UpdateRows()
            UpdateDetail()
        end
    end)
    local shown = not (ns.db and ns.db.tradeSkillSearch == false)
    search:SetShown(shown)
    searchBox:SetShown(shown)
    panel.search, panel.searchBox = search, searchBox

    local iconButton = ns.ShellDetailHeader(detail, Result_OnEnter)
    iconButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -ICON_TOP)
    detail.name:SetPoint("TOPLEFT", detail, "TOPLEFT", 50, -5)
    detail.made = iconButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    detail.made:SetPoint("BOTTOMRIGHT", iconButton, "BOTTOMRIGHT", -2, 2)
    iconButton:SetScript("OnClick", function()
        if not selected or not (IsModifiedClick and IsModifiedClick()) then return end
        local link = C_TradeSkillUI.GetRecipeItemLink and C_TradeSkillUI.GetRecipeItemLink(selected)
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)
    detail.name:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    -- Top right of the detail, its label ending at the inset's edge; the name stops short of it.
    if C_TradeSkillUI.SetRecipeTracked and C_TradeSkillUI.IsRecipeTracked then
        local track = ns.SmallCheck(detail, PROFESSIONS_TRACK_RECIPE or TRACK_RECIPE or "Track Recipe", 1, 0.82, 0)
        track:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -14 - math.ceil(track.label:GetStringWidth() or 60), 2 - ICON_TOP)
        track:SetScript("OnClick", function(self)
            ns.CheckSound(self)
            if selected then C_TradeSkillUI.SetRecipeTracked(selected, self:GetChecked() and true or false, false) end
        end)
        detail.track = track
        detail.name:SetPoint("RIGHT", track, "LEFT", -4, 0)
    end
    detail.cooldown = detail:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
    detail.cooldown:SetPoint("TOPLEFT", detail.requires, "BOTTOMLEFT", 0, -2)
    detail.reagentLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.reagentLabel:SetText(SPELL_REAGENTS or "Reagents:")
    detail.reagentLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -LABEL_TOP)
    detail.reagents = {}
    for i = 1, REAGENTS_MAX do detail.reagents[i] = ReagentButton(detail, i) end

    ns.TradeSkillFoot(panel, Craft, function(by)
        local most = math.max(1, Craftable(SelectedInfo()))
        panel.count:SetNumber(math.max(1, math.min(most, (panel.count:GetNumber() or 1) + by)))
    end)

    if ns.TradeSkillRetailParts then ns.TradeSkillRetailParts(panel, Refresh, SelectedInfo) end
    panel:SetScript("OnShow", Refresh)
    R.Changed = Refresh
    RunWatch()

    local events = CreateFrame("Frame")
    ns.RegisterEvents(events, TRADE_EVENTS)
    -- Hidden, nothing is drawn: OnShow refreshes the page as it opens.
    events:SetScript("OnEvent", function(_, event, itemID)
        -- A profession opening lists every type again, as Era's does.
        if event == "TRADE_SKILL_SHOW" then R.ClearTypes() end
        if not active or not panel:IsShown() then return end
        if event == "GET_ITEM_INFO_RECEIVED" then
            if not OnPlates(itemID) then return end
        else
            detailOnly = false
        end
        ns.Sched.NextFrame("tradeskill.refresh", RunRefresh)
    end)
    return panel
end

-- From the professions watcher: whether a profession's crafting page is up.
function ns.ShowTradeSkill(up)
    if not active then
        if panel then panel:Hide() end
        return
    end
    if not panel and ProfessionsFrame then Build() end
    if not panel then return end
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    -- Park the page as soon as it exists, open or not: in combat it may be
    -- immovable, and ours over a page still in place shows both.
    if page and not page.fcuiAway and not (InCombatLockdown() and page:IsProtected()) then
        -- The client's page, out of sight and still running.
        page.fcuiAway = true
        local w, h = page:GetWidth(), page:GetHeight()
        page:SetSize(math.max(600, w or 0), math.max(500, h or 0))
        ns.SetPointOnce(page, "TOPLEFT", ProfessionsFrame, "TOPLEFT", 6000, 0)
        page:SetAlpha(0)
    end
    local show = up and page and page.fcuiAway and true or false
    ns.SetShownIf(panel, show)
end

function ns.TradeSkillWindowSize()
    if ns.OnForever() then return FOREVER_W, FOREVER_H end
    return WINDOW_W, WINDOW_H
end

-- Public API (Core/API.lua): the window while built; a recipe unfolded and picked as the list fills; its row in view.
function ns.TradeSkillPanel() return panel end
function ns.TradeSkillWant(recipeID)
    wanted = recipeID
    if panel and panel:IsShown() then ns.Sched.NextFrame("tradeskill.refresh", RunRefresh) end
end
function ns.TradeSkillRowFor(recipeID)
    if not (active and panel and panel:IsShown()) or type(recipeID) ~= "number" then return nil end
    return SkillList.RowFor(panel, lines, function(line) return line.info and line.info.recipeID == recipeID end, UpdateRows)
end

-- Retail's driver (Skills/TradeSkillRetail.lua) parks the game's page and shows ours itself.
function ns.TradeSkillPage()
    if not panel and ProfessionsFrame then Build() end
    return panel
end

local function Apply()
    active = true
    if ns.OnForever() then ns.StartProfessionsWatch() end
end

local function Restore()
    if not active then return end
    active = false
    if panel then panel:Hide() end
    if not ns.OnForever() then return end
    ns.needsReload = true
    -- The running watch takes a full pass for the face without us.
    ns.StartProfessionsWatch()
end

ns.RegisterModule("tradeSkill", { apply = Apply, restore = Restore })
