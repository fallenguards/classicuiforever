local _, ns = ...

-- Old trainer window on the skill shell, inside the client's; its list, button and money stay under ours.

local active = false
local panel
local LIST_ROWS = 9
local lines, collapsed = {}, {}
local selected
local query = ""

local SkillList = ns.SkillList
local SetAlphaIf, SetScaleIf, SetLevelIf, SetPointIf = ns.SetAlphaIf, ns.SetScaleIf, ns.SetLevelIf, ns.SetPointIf
local IsSecret = ns.IsSecret

local KIND_COLOR = {
    available = { 0.1, 1, 0.1 },
    unavailable = { 1, 0.1, 0.1 },
    used = { 0.5, 0.5, 0.5 },
}

-- Client pieces ours stands in for
local CLIENT_PIECES = { "FilterDropdown", "FilterInputHint", "TrainButton", "trainingPoints", "skillStepButton",
    "bottomInset", "BG", "Inset" }
local CLIENT_SHRUNK = { "ScrollBox", "ScrollBar" }
local CHANGED = { changed = true }
local FOOT_EDGE = { "TopEdge", "TopLeftCorner", "TopRightCorner" }
local TRAINER_EVENTS = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "TRAINER_DESCRIPTION_UPDATE",
    "TRAINER_SERVICE_INFO_NAME_UPDATE", "PLAYER_MONEY" }
local POINTS_EVENTS = { "UNIT_PET_TRAINING_POINTS" }

-- Forever's hunter pet training opens this window too: its costs are the pet's training points (#243).
local pet = false
local function PetTraining()
    local trainer, types = C_Trainer, Enum and Enum.TrainerType
    return trainer and trainer.GetTrainerType and types and types.Pet ~= nil and trainer.GetTrainerType() == types.Pet
        or false
end

local function FreePoints()
    local get = C_PetInfo and C_PetInfo.GetPetTrainingPoints
    if not get then return 0 end
    local total, used = get()
    if type(total) ~= "number" or ns.AnySecret(total, used) then return 0 end
    return math.max(total - (used or 0), 0)
end

-- Money, or the pet's training points while pet training; and whether it opens a profession.
local function ServiceCost(index)
    if not GetTrainerServiceCost then return 0, false end
    local ok, value, isProfession = pcall(GetTrainerServiceCost, index)
    if not ok or type(value) ~= "number" or IsSecret(value) then return 0, false end
    return value, isProfession and true or false
end

local function Services()
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    local order, groups = {}, {}
    for index = 1, count do
        local name, kind, texture, level, sub, category = GetTrainerServiceInfo(index)
        if name and (query == "" or name:lower():find(query, 1, true)) then
            if not category or category == "" then category = OTHER or "Other" end
            if not groups[category] then
                groups[category] = {}
                order[#order + 1] = category
            end
            local group = groups[category]
            group[#group + 1] = { index = index, name = name, kind = kind, texture = texture, level = level, sub = sub }
        end
    end
    return order, groups
end

-- The trainer's rows and verdicts as one string. Its answer can change with no event after (pet training listed
-- known ranks as learnable until asked again): the open window asks twice a second and redraws on a change.
local seen, parts = "", {}
local function Verdicts()
    wipe(parts)
    for index = 1, GetNumTrainerServices and GetNumTrainerServices() or 0 do
        local name, kind = GetTrainerServiceInfo(index)
        parts[#parts + 1] = (name or "") .. ":" .. (kind or "")
    end
    return table.concat(parts, "|")
end

local function Collect()
    wipe(lines)
    seen = Verdicts()
    local order, groups = Services()
    for _, category in ipairs(order) do
        -- Pet training lists flat, as the game's own window does: its skills carry no category.
        if not pet then lines[#lines + 1] = { header = true, id = category, name = category } end
        if pet or query ~= "" or not collapsed[category] then
            for _, service in ipairs(groups[category]) do lines[#lines + 1] = service end
        end
    end
end

local function ServiceByIndex(index)
    for _, line in ipairs(lines) do
        if not line.header and line.index == index then return line end
    end
end

local UpdateDetail

-- Era's detail scrolls: a long description runs past the pane, and the bar on the pane's right edge, like the list's,
-- shows only then. The content is as tall as the text; a line is the wheel's step.
local DETAIL_TEXT_TOP, DETAIL_LINE = 62, 14
local function FitDetail()
    local detail, scroll = panel.detail, panel.detailScroll
    if not scroll then return end
    local room = scroll:GetHeight() or 0
    detail:SetWidth(scroll:GetWidth() or 1)
    local bottom = DETAIL_TEXT_TOP + (detail.cost:GetStringHeight() or 0) + 6 + (detail.text:GetStringHeight() or 0) + 8
    local height = math.max(room, bottom)
    detail:SetHeight(height)
    panel.detailBar:SetRange(height - room, DETAIL_LINE)
end

-- The detail pane runs to the window's edge and under the foot: the scroll stops short of both, its bar in the list
-- bar's column (the list pane ends panel.listRight in from the edge), above the foot's buttons.
local DETAIL_FOOT = 17
local function DetailScroll()
    local box = panel.detail
    local scroll = ns.NewFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", panel.listRight - 14, DETAIL_FOOT)
    local content = ns.NewFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = ns.ShellScrollBar(panel, scroll, function(value) scroll:SetVerticalScroll(value) end)
    bar.hideWhenIdle = true
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", panel.detailBox, "TOPRIGHT", panel.listRight - 9, -27)
    bar:SetPoint("BOTTOMLEFT", panel.detailBox, "BOTTOMRIGHT", panel.listRight - 9, DETAIL_FOOT + 2)
    bar:SetFrameLevel(panel.detailBox:GetFrameLevel() + 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * DETAIL_LINE) end)
    scroll:SetScript("OnSizeChanged", FitDetail)
    panel.detailScroll, panel.detailBar, panel.detail = scroll, bar, content
    return content
end

-- Scroll column only when the list overflows, as Era's
local function FitList()
    local over = math.max(0, #lines - LIST_ROWS)
    panel.bar:SetRange(over)
    panel.listBox:SetPoint("RIGHT", panel, "RIGHT", over > 0 and panel.listRight or 0, 0)
end

-- A class trainer's names two spaces past its headers' (21); pet training has no headers, its names at the row's edge.
local ITEM_X, PET_ITEM_X = 33, 6

local function DrawItem(row, line)
    row.toggle:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", pet and PET_ITEM_X or ITEM_X, 0)
    local label = line.name
    if line.sub and line.sub ~= "" then label = label .. " (" .. line.sub .. ")" end
    row.text:SetText(label)
    local color = KIND_COLOR[line.kind] or KIND_COLOR.used
    local picked = line.index == selected
    if picked then
        row.selectedTex:SetVertexColor(unpack(color))
        row.selectedTex:Show()
        row.text:SetTextColor(1, 1, 1)
    else
        row.selectedTex:Hide()
        row.text:SetTextColor(unpack(color))
    end
    -- Era's Beast Training: the points on the row's right in its color; red here when the pet is short of them.
    local cost = pet and ServiceCost(line.index) or 0
    if cost > 0 then
        row.cost = row.cost or row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.cost:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.cost:SetText(string.format(TRAINING_POINTS_ABBREV or "%s TP", cost))
        if cost > FreePoints() then
            row.cost:SetTextColor(unpack(KIND_COLOR.unavailable))
        elseif picked then
            row.cost:SetTextColor(1, 1, 1)
        else
            row.cost:SetTextColor(unpack(color))
        end
        row.cost:Show()
        row.text:SetPoint("RIGHT", row.cost, "LEFT", -4, 0)
    else
        if row.cost then row.cost:Hide() end
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end
end

local function UpdateRows()
    if not panel then return end
    SkillList.Draw(panel, lines, collapsed, DrawItem)
    SkillList.FoldIcon(panel, lines, collapsed)
end

-- BuyTrainerService is refused to addons: a pad clicks the client's row for our pick, then its Train.
local TRAIN_ROW, TRAIN_GO = "ClassicUIForeverTrainRow", "ClassicUIForeverTrainGo"
local TRAIN_MACRO = "/click " .. TRAIN_ROW .. "\n/click " .. TRAIN_GO
local trainProxies, listWrap

-- Rows exist only inside the client's 330-tall list: the press stretches it in its own secure run,
-- so the client builds our pick's row itself. Release or leave puts the height back.
local LIST_TALL = [[
    if not down then return nil, "back" end
    local list, tall = control:GetFrameRef("list"), control:GetAttribute("tall")
    if not (list and tall) or PlayerInCombat() then return end
    if not control:GetAttribute("listh") then control:SetAttribute("listh", list:GetHeight()) end
    list:SetHeight(tall)
    list:GetHeight() -- measured here, so the rows are built in this run
]]
local LIST_BACK = [[
    local list, h = control:GetFrameRef("list"), control:GetAttribute("listh")
    if not (list and h) or PlayerInCombat() then return end
    list:SetHeight(h)
    list:GetHeight()
    control:SetAttribute("listh", nil)
]]

local function ClientSelection()
    local frame = ClassTrainerFrame
    local shown = frame and frame.selectedService
    if not shown then return nil end
    local map = frame.displayIndexToSkillIndex
    return (map and map[shown]) or shown
end

local wantedRow, foundRow
-- Forever marks a row with its display index; retail's rows only carry the service's index as their ID.
local function MatchRow(row)
    if foundRow then return end
    if row.displayIndex ~= nil then
        if row.displayIndex == wantedRow and issecurevariable(row, "displayIndex") then foundRow = row end
    elseif row.GetID and row:GetID() == wantedRow then
        foundRow = row
    end
end

-- The client's row for our pick (its list is shrunk, not hidden, so rows stand)
local function ClientRow()
    local frame = ClassTrainerFrame
    local box = frame and frame.ScrollBox
    if not (selected and box and box.ForEachFrame) then return nil end
    -- A profession's next rank sits on the client's step button, not in its list.
    local step, stepIndex = frame.skillStepButton, _G.GetTrainerServiceStepIndex
    if step and stepIndex and stepIndex() == selected then
        if step:IsShown() and issecurevariable(step, "displayIndex") then return step end
        return nil
    end
    local map = frame.skillIndexToDisplayIndex
    wantedRow, foundRow = (map and map[selected]) or selected, nil
    box:ForEachFrame(MatchRow)
    return foundRow
end

-- The client's Train button and money: Forever keys them, retail only names them.
local function ClientTrain()
    return ClassTrainerFrame and (ClassTrainerFrame.TrainButton or _G.ClassTrainerTrainButton)
end
local function ClientMoney()
    return ClassTrainerFrame and (ClassTrainerFrame.money or _G.ClassTrainerFrameMoneyFrame)
end

local function TrainWanted()
    return active and selected ~= nil and panel ~= nil and panel.train:IsEnabled()
end

-- Room for every service and header at the client's row height.
local function TallHeight()
    return (2 * GetNumTrainerServices() + 1) * (_G.CLASS_TRAINER_SKILL_HEIGHT or 47)
end

-- Row, then Train. No clicks without the row; no pad unless our pick can train.
local function TrainMacro()
    if not TrainWanted() then return nil end
    local row, go = ClientRow(), ClientTrain()
    if not (row and go) then return "" end
    trainProxies = trainProxies or { ns.ClickProxy(TRAIN_ROW), ns.ClickProxy(TRAIN_GO) }
    ns.SetAttributeIf(trainProxies[1], "clickbutton", row)
    ns.SetAttributeIf(trainProxies[2], "clickbutton", go)
    return TRAIN_MACRO
end

-- Down: does this press need the tall list. Up: aim again, on the rows the down built.
local function Pad_PreClick(pad, _, down)
    if InCombatLockdown() then return end
    if down then
        listWrap:SetAttribute("tall", TrainWanted() and not ClientRow() and TallHeight() or false)
    else
        ns.SetAttributeIf(pad, "macrotext", TrainMacro() or "")
    end
end

-- Wrapped on its first look, out of combat: a pad made after a fight exists no sooner
local function PadMacro()
    local pad = ns.PadOf(panel.train)
    if pad and not listWrap then
        listWrap = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        listWrap:SetFrameRef("list", ClassTrainerFrame.ScrollBox)
        SecureHandlerWrapScript(pad, "OnClick", listWrap, LIST_TALL, LIST_BACK)
        SecureHandlerWrapScript(pad, "OnLeave", listWrap, LIST_BACK)
        pad:SetScript("PreClick", Pad_PreClick)
    end
    return TrainMacro()
end

-- Read by the dev addon's train probe.
function ns.TrainerState()
    local tall = listWrap and listWrap:GetAttribute("tall")
    local held = listWrap and listWrap:GetAttribute("listh")
    return selected, ClientSelection(), ClientRow() ~= nil, panel and panel.train, tall, held
end

-- Public API (Core/API.lua): the window while built, and its row for a service (the game's index) brought into view.
function ns.TrainerPanel() return panel end
function ns.TrainerRowFor(index)
    if not (active and panel and panel:IsShown()) or type(index) ~= "number" or not GetTrainerServiceInfo then return nil end
    -- A search could hide it: cleared, the list redraws whole.
    if query ~= "" then panel.search:SetText("") end
    local category = select(6, GetTrainerServiceInfo(index))
    if not category or category == "" then category = OTHER or "Other" end
    if collapsed[category] then
        collapsed[category] = nil
        panel.refresh()
    end
    return SkillList.RowFor(panel, lines, function(line) return line.index == index end, UpdateRows)
end

local function TrainRefused()
    if InCombatLockdown() then ns.SayNotInCombat() end
end

local function NoOp() end

local function Select(index)
    selected = index
    if index and SelectTrainerService then pcall(SelectTrainerService, index) end
    UpdateRows()
    UpdateDetail()
end

local function Row_OnClick(self)
    local line = self.line
    if not line then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if line.header then
        collapsed[line.id] = (not collapsed[line.id]) or nil
        -- Full refresh: a folded header can take the chosen service with it.
        panel.refresh()
    else
        Select(line.index)
    end
end

local function CreateRow(parent, index)
    return ns.SkillListRow(parent, index, Row_OnClick)
end

local function Coins(amount) return ns.CoinText(amount) end

local WHITE, RED = "|cffffffff", "|cffff2020"

-- The client's wording without its colors
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- White text, only an unmet number red ("Mining (50)", the 50 red)
local function AddNeed(parts, text, met)
    text = Plain(text)
    if not met then
        text = text:gsub("(%d+)", RED .. "%1|r" .. WHITE, 1)
    end
    parts[#parts + 1] = WHITE .. text .. "|r"
end

-- What a service needs, the unmet parts in red.
local function Requirements(line)
    local parts = {}
    if line.level and line.level > 1 then
        -- A pet skill asks the pet's level, as Era's Beast Training did.
        local level = UnitLevel(pet and "pet" or "player")
        if IsSecret(level) then level = nil end
        AddNeed(parts, string.format(TRAINER_REQ_LEVEL or "Level %d", line.level), (level or 0) >= line.level)
    end
    if GetTrainerServiceSkillReq then
        local ok, skill, rank, has = pcall(GetTrainerServiceSkillReq, line.index)
        if ok and skill and rank and rank > 0 then
            AddNeed(parts, string.format(TRAINER_REQ_SKILL_RANK or "%s (%d)", skill, rank), has and true or false)
        end
    end
    if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        local okCount, count = pcall(GetTrainerServiceNumAbilityReq, line.index)
        for i = 1, (okCount and count or 0) do
            local ok, ability, has = pcall(GetTrainerServiceAbilityReq, line.index, i)
            -- A needed spell has no number to mark: all of it.
            if ok and ability then
                parts[#parts + 1] = ((has and WHITE) or RED) .. Plain(ability) .. "|r"
            end
        end
    end
    return table.concat(parts, ", ")
end

-- The foot: money, or Era's "Training Points:" with the pet's free points while pet training.
local function UpdateFoot()
    panel.oval:SetShown(not pet)
    panel.points:SetShown(pet)
    if not pet then return end
    local points = WHITE .. FreePoints() .. "|r"
    local shape = TRAINING_POINTS and TRAINING_POINTS:find("%s", 1, true) and TRAINING_POINTS
    panel.points:SetText(shape and string.format(shape, points)
        or ((TRAINING_POINTS_LABEL or "Training Points") .. ": " .. points))
end

UpdateDetail = function()
    if not panel then return end
    UpdateFoot()
    local detail = panel.detail
    local line = selected and ServiceByIndex(selected)
    local money = GetMoney and GetMoney() or 0
    if not line then
        detail.iconButton:Hide()
        detail.name:SetText("")
        detail.sub:SetText("")
        detail.requires:SetText("")
        detail.cost:SetText("")
        detail.text:SetText("")
        FitDetail()
        panel.train:Disable()
        return
    end
    detail.iconButton:Show()
    detail.icon:SetTexture(line.texture)
    detail.name:SetText(line.name)
    detail.sub:SetText((line.sub and line.sub ~= "") and ("(" .. line.sub .. ")") or "")
    local needs = Requirements(line)
    detail.requires:SetText(needs ~= "" and ((REQUIRES_LABEL or "Requires:") .. " " .. needs) or "")
    local cost, profession = ServiceCost(line.index)
    -- Pet training pays in the pet's points: Era's "Cost: 3 Training Points", the number red when short.
    local purse = pet and FreePoints() or money
    if cost > 0 then
        local price = pet and (cost .. "|r " .. WHITE .. (TRAINING_POINTS_LABEL or "Training Points")) or Coins(cost)
        detail.cost:SetText((COSTS_LABEL or "Cost:") .. " " .. (cost > purse and RED or WHITE) .. price .. "|r")
    else
        detail.cost:SetText("")
    end
    local words = ""
    if GetTrainerServiceDescription then
        local ok, text = pcall(GetTrainerServiceDescription, line.index)
        if ok and type(text) == "string" then words = text end
    end
    detail.text:SetText(words)
    -- Another service: read from its top.
    if detail.shownIndex ~= line.index then
        detail.shownIndex = line.index
        panel.detailBar:SetValue(0)
    end
    FitDetail()
    -- A new profession with both slots taken: Train grays out, as Era's and the game's own do.
    local noSlot = profession and GetProfessions and select(2, GetProfessions()) ~= nil
    panel.train:SetEnabled(line.kind == "available" and cost <= purse and not noSlot)
end

local function Refresh()
    if not panel or not active then return end
    pet = PetTraining()
    Collect()
    FitList()
    -- Keep the pick while listed; else the first learnable, as Era opens; else the first.
    if not (selected and ServiceByIndex(selected)) then
        selected = nil
        for _, line in ipairs(lines) do
            if not line.header and line.kind == "available" then selected = line.index break end
        end
        if not selected then
            for _, line in ipairs(lines) do
                if not line.header then selected = line.index break end
            end
        end
        if selected and SelectTrainerService then pcall(SelectTrainerService, selected) end
    end
    local greeting = GetTrainerGreetingText and GetTrainerGreetingText() or ""
    panel.greeting:SetText(greeting or "")
    UpdateRows()
    UpdateDetail()
end

-- From past the All tab to the filter, its middle on the filter's (the input's art 5 out on the left).
local function BuildSearch()
    local search = ns.ShellSearch(panel, function(text)
        if text == query then return end
        query = text
        panel.bar:SetValue(0)
        Refresh()
    end)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 90, -60)
    search:SetPoint("RIGHT", panel.filter, "LEFT", -9, 0)
    ns.ShellSearchShown(panel, ns.db and ns.db.trainerSearch ~= false)
end
ns.RegisterModule("trainerSearch", {
    apply = function() ns.ShellSearchShown(panel, true) end,
    restore = function() ns.ShellSearchShown(panel, false) end,
})

local function SetWidthIf(region, width)
    local current = region:GetWidth()
    if not IsSecret(current) and not IsSecret(width) and current == width then return end
    region:SetWidth(width)
end

local moneyBg
local function HideClientPieces(hide)
    local host = ClassTrainerFrame
    if not host then return end
    local alpha = hide and 0 or 1
    ns.FadeKeys(host, CLIENT_PIECES, alpha, CHANGED)
    local go = ClientTrain()
    if go then SetAlphaIf(go, alpha) end
    -- The client's rank bar, by name only; the old window had none.
    if ClassTrainerStatusBar then SetAlphaIf(ClassTrainerStatusBar, alpha) end
    -- Our skin's inset floor read as an empty bar under the tab.
    local floor = host.fcui and host.fcui.insetFloor
    if floor then SetAlphaIf(floor, alpha) end
    -- The client's money oval stays, six higher, inside the foot border.
    moneyBg = moneyBg or _G["ClassTrainerFrameMoneyBg"]
    local oval = moneyBg
    if oval then
        SetPointIf(oval, "BOTTOMLEFT", host, "BOTTOMLEFT", hide and 4 or 5, hide and -3 or -9)
        SetAlphaIf(oval, alpha)
        if hide and panel and panel.oval then
            local width = panel.oval:GetWidth()
            if width and width > 0 then SetWidthIf(oval, width) end
        elseif not hide then
            SetWidthIf(oval, 148)
        end
    end
    -- The client's money over our page, which is drawn above it.
    local money = ClientMoney()
    if money and panel then
        SetLevelIf(money, panel:GetFrameLevel() + (hide and 8 or 0))
    end
    -- Client list and bar sit over ours and relayout on each update: shrink, not move.
    for _, key in ipairs(CLIENT_SHRUNK) do
        local piece = host[key]
        if piece and piece.SetScale then
            SetScaleIf(piece, hide and 0.01 or 1)
            SetAlphaIf(piece, alpha)
        end
    end
end

local function RehideTick()
    if active then HideClientPieces(true) end
end

local function Service_OnEnter(self)
    if not selected or not GameTooltip.SetTrainerService then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetTrainerService, GameTooltip, selected)
    GameTooltip:Show()
end

local function Build()
    local host = ClassTrainerFrame
    if panel or not host then return panel end
    panel = ns.ShellPage("ClassicUIForeverTrainer", host)
    panel:EnableMouse(true)

    -- Greeting on its own frame: the stone cut off its second line.
    local words = ns.NewFrame("Frame", nil, panel)
    words:SetAllPoints(panel)
    words:SetFrameLevel(panel:GetFrameLevel() + 3)
    panel.greeting = words:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.greeting:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -30)
    panel.greeting:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.greeting:SetHeight(36)
    panel.greeting:SetJustifyH("LEFT")
    panel.greeting:SetJustifyV("TOP")

    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = UpdateRows })
    -- Stone from the title band to the list: the darker backing read as a bar.
    local gap = ns.NewFrame("Frame", nil, panel)
    gap:SetFrameLevel(panel:GetFrameLevel() + 1)
    gap:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -50)
    gap:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    gap:SetPoint("BOTTOM", panel.listBox, "TOP", 0, -8)
    local gapStone = gap:CreateTexture(nil, "BACKGROUND")
    gapStone:SetAllPoints(gap)
    ns.TileTex(gapStone, "rockBg")
    panel.collapseAll:SetScript("OnClick", function()
        SkillList.FoldAll(lines, collapsed)
        panel.refresh()
    end)
    panel.filter:SetScript("OnClick", function(self)
        if not panel.filterList then
            local function Item(label, kind)
                return { label, function()
                    local on = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind)
                    if SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter(kind, not on) end
                    Refresh()
                end, function() return GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind) and true or false end }
            end
            panel.filterList = ns.DropList({
                Item(AVAILABLE or "Available", "available"),
                Item(UNAVAILABLE or "Unavailable", "unavailable"),
                Item(USED or "Already Known", "used"),
            })
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)
    BuildSearch()

    -- The chosen service, in its scroll.
    local detail = DetailScroll()
    detail.iconButton = ns.ShellDetailHeader(detail, Service_OnEnter)
    detail.sub = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.sub:SetPoint("LEFT", detail.name, "RIGHT", 4, 0)
    detail.cost = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.cost:SetPoint("TOPLEFT", detail, "TOPLEFT", 21, -DETAIL_TEXT_TOP)
    detail.cost:SetJustifyH("LEFT")
    detail.text = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.text:SetPoint("TOPLEFT", detail.cost, "BOTTOMLEFT", 0, -6)
    detail.text:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
    detail.text:SetJustifyH("LEFT")
    detail.text:SetJustifyV("TOP")

    -- The foot: money in its own thin border, Train, Exit.
    local exit = ns.ShellExitButton(panel, "ClassTrainerFrame", 84)
    local train = ns.PanelButton(panel, TRAIN or "Train", 84)
    train:SetPoint("RIGHT", exit, "LEFT", -3, 0)
    -- Reached only with no pad over it: the pad hides in a fight.
    train:SetScript("OnClick", TrainRefused)
    panel.train = train
    -- HIGH, a strata over the window: at the window's strata the button kept the mouse.
    ns.MapPad(train, "HIGH", NoOp, PadMacro, TrainWanted)
    -- The money's border, clear of its oval all the way round.
    local moneyBox = ns.SkillInsetBox(panel, 16, true)
    moneyBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 4)
    moneyBox:SetPoint("RIGHT", train, "LEFT", 1, 0)
    moneyBox:SetHeight(32)
    -- Pet training's points in the money's place (UpdateFoot): Era's gold label, the number white.
    panel.points = moneyBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.points:SetPoint("LEFT", moneyBox, "LEFT", 12, 0)
    panel.points:Hide()
    -- Train and Exit in the same thin border, level with the money's.
    for _, button in ipairs({ train, exit }) do
        local box = ns.SkillInsetBox(panel, 16, true)
        box:SetPoint("TOP", moneyBox, "TOP", 0, 0)
        box:SetPoint("BOTTOM", moneyBox, "BOTTOM", 0, 0)
        box:SetPoint("LEFT", button, "LEFT", -4, 0)
        box:SetPoint("RIGHT", button, "RIGHT", 4, 0)
        box:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    end
    -- Our own gold oval; the client's, dull under the silver, stays unseen for its money to hang from.
    local oval = panel:CreateTexture(nil, "ARTWORK")
    oval:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame-Border")
    oval:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, -3)
    oval:SetPoint("RIGHT", train, "LEFT", -5, 0)
    oval:SetHeight(34)
    panel.oval = oval
    -- Detail pane's bottom edge under the foot's top: side by side they read double.
    panel.detailBox:ClearAllPoints()
    panel.detailBox:SetPoint("TOPLEFT", panel.listBox, "BOTTOMLEFT", 0, 12)
    panel.detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 25)
    panel.footBox:ClearAllPoints()
    panel.footBox:SetPoint("TOPLEFT", panel.detailBox, "BOTTOMLEFT", 0, 11)
    panel.footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    panel.footBox:SetFrameLevel(panel.detailBox:GetFrameLevel() + 1)
    -- The foot keeps its sides and bottom; its top edge drew a double line.
    ns.FadeKeys(panel.footBox, FOOT_EDGE)

    panel.bar.hideWhenIdle = true
    panel.refresh = Refresh
    -- Client pieces appear after opening (the inset floor); never slept: the panel has regions.
    ns.Sched.OnFrame(panel, { name = "trainer.panel", every = 0.2, fn = RehideTick })
    panel:SetScript("OnShow", Refresh)
    return panel
end

local function Open()
    if not active or not ClassTrainerFrame then return end
    Build()
    if ns.Once(panel, "fresh") then
        ns.Sched.Attach(panel, { name = "trainer.fresh", every = 0.5, fn = function()
            if active and Verdicts() ~= seen then panel.refresh() end
        end })
    end
    HideClientPieces(true)
    -- A Show that makes the page visible has run Refresh through OnShow.
    local wasShown = panel:IsShown()
    panel:Show()
    if wasShown or not panel:IsVisible() then Refresh() end
end

-- Trainer events come in bursts: one Open in this frame's pass.
local openWanted = false
local function OpenNow()
    if not openWanted then return end
    openWanted = false
    Open()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if not active then return end
    if event == "TRAINER_CLOSED" or event == "PLAYER_MONEY" or event == "UNIT_PET_TRAINING_POINTS" then
        -- A pending Open lands first, as when it ran at once.
        OpenNow()
        if event == "TRAINER_CLOSED" then
            selected = nil
            -- The next trainer opens on its whole list.
            if query ~= "" and panel then panel.search:SetText("") end
        elseif panel and panel:IsVisible() then
            UpdateRows()
            UpdateDetail()
        end
        return
    end
    openWanted = true
    ns.Sched.Soon("trainer.open", OpenNow)
end)

local function Apply()
    active = true
    ns.RegisterEvents(events, TRAINER_EVENTS)
    ns.RegisterEvents(events, POINTS_EVENTS, "player", "pet")
    if ClassTrainerFrame and ClassTrainerFrame:IsShown() then Open() end
end

local function Restore()
    active = false
    events:UnregisterAllEvents()
    if panel then panel:Hide() end
    HideClientPieces(false)
end

ns.RegisterModule("trainer", { apply = Apply, restore = Restore })
