local _, ns = ...

-- Era's Skills tab from Classic Era's own SkillFrame.xml and .lua, at Era's measures and in its art (the same files on
-- Forever), on a 384 x 512 window of ours: sheets, All tab, twelve rows of section labels and skill bars, scroll tracks,
-- divider bar, the detail's bar, cost, words and unlearn button, and Close. The owner feeds it lines and takes its clicks.

local ES = {}
ns.eraSkills = ES

local ROWS = 12
local ROW_PITCH = 18
local MINUS, PLUS = "Interface\\Buttons\\UI-MinusButton-Up", "Interface\\Buttons\\UI-PlusButton-Up"
local LABEL_HILITE = "Interface\\Buttons\\UI-PlusButton-Hilight"
local CANCEL = "Interface\\Buttons\\CancelButton-"
-- Era's scroll arrows and knob as its scroll bar template crops them.
local ARROW_COORDS = { 0.2, 0.8, 0.25, 0.75 }
local KNOB_COORDS = { 0.2, 0.8, 0.125, 0.875 }
local ARROW_STATES = { "Up", "Down", "Disabled", "Highlight" }
-- Bar colors (SkillFrame_SetStatusBar): a normal skill's bar and backing, a proficiency's (rank out of 1).
local BAR_BLUE, BACK_BLUE = { 0, 0, 1, 0.5 }, { 0, 0, 0.75, 0.5 }
local BAR_GREY, BACK_WHITE = { 0.5, 0.5, 0.5, 1 }, { 1, 1, 1, 0.5 }
local DETAIL_STEP = 15
-- Bar and border widths: a list row's, the detail's.
local BAR_W, BORDER_W = 271, 281
local DETAIL_W, DETAIL_BORDER_W = 211, 220
-- The name's inset, the gap before the rank (Era's), and room kept at the bar's end.
local NAME_X, RANK_GAP, END_PAD = 6, 13, 6

-- The window's sheets: the general top and the Skills tab's bottom, on the window's corners as its other pages' art.
-- Era hangs them 2 right and 1 down of its window: the page stands PAGE_X, PAGE_Y off instead, everything on it with it,
-- so the window's border and X stand still between pages.
local PAGE_X, PAGE_Y = -2, 1
local SHEETS = {
    { "charGeneralTopLeft", "TOPLEFT", 256 }, { "charGeneralTopRight", "TOPRIGHT", 128 },
    { "skillFrameBotLeft", "BOTTOMLEFT", 256 }, { "skillFrameBotRight", "BOTTOMRIGHT", 128 },
}

local function Tex(parent, layer, key, w, h)
    local tex = parent:CreateTexture(nil, layer)
    if key then ns.SetTex(tex, key) end
    if w then tex:SetSize(w, h) end
    return tex
end

local function Crop(tex, c) tex:SetTexCoord(c[1], c[2], c[3], c[4]) end

-- The scroll track of an Era scroll frame: top and foot pieces of the trainer's sheet, against the frame's right edge.
local function Track(frame, h, topCut, footFrom)
    local top = Tex(frame, "ARTWORK", "trainerScrollBar", 30, h)
    top:SetPoint("TOPLEFT", frame, "TOPRIGHT", -3, 5)
    top:SetTexCoord(0, 0.46875, 0, topCut)
    local foot = Tex(frame, "ARTWORK", "trainerScrollBar", 30, h)
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -3, -2)
    foot:SetTexCoord(0.53125, 1, footFrom, 1)
end

local function Arrow(bar, kind, point, relPoint)
    local button = ns.NewFrame("Button", nil, bar)
    button:SetSize(18, 16)
    button:SetPoint(point, bar, relPoint, 0, 0)
    for _, state in ipairs(ARROW_STATES) do
        local tex = Tex(button, state == "Highlight" and "HIGHLIGHT" or "ARTWORK", "scroll" .. kind .. "Button" .. state)
        tex:SetAllPoints(button)
        Crop(tex, ARROW_COORDS)
        if state == "Highlight" then tex:SetBlendMode("ADD") end
        button[state] = tex
    end
    button:SetNormalTexture(button.Up)
    button:SetPushedTexture(button.Down)
    button:SetDisabledTexture(button.Disabled)
    button:SetHighlightTexture(button.Highlight)
    return button
end

local function ArrowClick(bar, sign)
    return function()
        bar:SetValue(bar:GetValue() + sign * bar.step)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
    end
end

-- UIPanelScrollBarTemplate's slider beside a scroll frame: 6 right, 16 in from each end, arrows past them.
local function ScrollBar(frame, onValue)
    local bar = ns.NewFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 6, 16)
    local knob = Tex(bar, "OVERLAY", "scrollKnob", 18, 24)
    Crop(knob, KNOB_COORDS)
    bar:SetThumbTexture(knob)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar.step = 1
    bar.up = Arrow(bar, "Up", "BOTTOM", "TOP")
    bar.down = Arrow(bar, "Down", "TOP", "BOTTOM")
    bar.up:SetScript("OnClick", ArrowClick(bar, -1))
    bar.down:SetScript("OnClick", ArrowClick(bar, 1))
    bar:SetScript("OnValueChanged", function(self, value)
        local _, most = self:GetMinMaxValues()
        self.up:SetEnabled(value > 0)
        self.down:SetEnabled(value < most)
        onValue(value)
    end)
    return bar
end

-- SkillStatusBarTemplate: backing, bar, name and rank, the rounded border button with its hover border.
local function SkillBar(parent, width, borderWidth)
    local bar = ns.NewFrame("StatusBar", nil, parent)
    bar:SetSize(width, 15)
    bar:SetStatusBarTexture((ns.TexPath("skillsBar")))
    bar:GetStatusBarTexture():SetDrawLayer("BACKGROUND", 1)
    bar.back = bar:CreateTexture(nil, "BACKGROUND")
    bar.back:SetAllPoints(bar)
    bar.back:SetColorTexture(1, 1, 1, 0.2)
    bar.name = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bar.name:SetPoint("LEFT", bar, "LEFT", NAME_X, 1)
    bar.name:SetWordWrap(false)
    bar.rank = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bar.rank:SetWidth(128)
    bar.rank:SetPoint("LEFT", bar.name, "RIGHT", RANK_GAP, 0)
    bar.rank:SetJustifyH("LEFT")
    local border = ns.NewFrame("Button", nil, bar)
    border:SetSize(borderWidth, 32)
    border:SetPoint("LEFT", bar, "LEFT", -5, 0)
    border:SetHitRectInsets(0, 0, 7, 7)
    local normal = Tex(border, "ARTWORK", "skillsBarBorder")
    normal:SetAllPoints(border)
    border:SetNormalTexture(normal)
    local hover = Tex(border, "HIGHLIGHT", "skillsBarBorderHighlight")
    hover:SetAllPoints(border)
    border:SetHighlightTexture(hover)
    bar.border = border
    return bar
end

local function Tint(region, c) region:SetVertexColor(c[1], c[2], c[3], c[4]) end

-- Name, gap and rank: the room a bar's words take.
local function WordsWidth(bar)
    return NAME_X + bar.name:GetStringWidth() + RANK_GAP + bar.rank:GetStringWidth() + END_PAD
end

-- A name too long for the bar is cut short, so its rank stays inside.
local function FitName(bar)
    bar.name:SetWidth(0)
    local over = WordsWidth(bar) - bar:GetWidth()
    if over > 0 then bar.name:SetWidth(math.max(1, bar.name:GetStringWidth() - over)) end
end

-- A line on a bar as SkillFrame_SetStatusBar draws a skill: line { name, rank, most, modifier }; count: never a
-- proficiency, a rank out of 1 included.
local function DrawBar(bar, line)
    bar.name:SetText(line.name or "")
    local most, rank = line.most or 0, line.rank or 0
    if most == 1 and not line.count then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetStatusBarColor(BAR_GREY[1], BAR_GREY[2], BAR_GREY[3], BAR_GREY[4])
        Tint(bar.back, BACK_WHITE)
        bar.rank:SetText("")
        FitName(bar)
        return
    end
    bar:SetStatusBarColor(BAR_BLUE[1], BAR_BLUE[2], BAR_BLUE[3], BAR_BLUE[4])
    Tint(bar.back, BACK_BLUE)
    bar:SetMinMaxValues(0, math.max(most, 1))
    bar:SetValue(rank)
    local modifier = line.modifier or 0
    if modifier == 0 then
        bar.rank:SetFormattedText("%d/%d", rank, most)
    else
        local color = modifier > 0 and (GREEN_FONT_COLOR_CODE .. "+") or RED_FONT_COLOR_CODE
        bar.rank:SetText(rank .. " (" .. color .. modifier .. FONT_COLOR_CODE_CLOSE .. ")/" .. most)
    end
    FitName(bar)
end

-- SkillLabelTemplate: a fold button with its word.
local function Label(parent)
    local label = ns.NewFrame("Button", nil, parent)
    label:SetSize(285, 14)
    label.icon = label:CreateTexture(nil, "ARTWORK")
    label.icon:SetSize(16, 16)
    label.icon:SetPoint("LEFT", label, "LEFT", 3, 0)
    local glow = label:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(LABEL_HILITE)
    glow:SetBlendMode("ADD")
    glow:SetSize(16, 16)
    glow:SetPoint("LEFT", label, "LEFT", 3, 0)
    label.text = label:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label.text:SetPoint("LEFT", label, "LEFT", 25, 0)
    return label
end

-- The All tab over the list's top left: the quest log's sort tab round a fold button and its word.
local function AllTab(page, onClick)
    local holder = ns.NewFrame("Frame", nil, page)
    holder:SetHeight(32)
    holder:SetPoint("TOPLEFT", page, "TOPLEFT", 70, -49)
    local left = Tex(holder, "BACKGROUND", "questLogTabLeft", 8, 32)
    left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 6)
    local right = Tex(holder, "BACKGROUND", "questLogTabRight", 8, 32)
    right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 6)
    local middle = Tex(holder, "BACKGROUND", "questLogTabMiddle")
    middle:SetPoint("LEFT", left, "RIGHT")
    middle:SetPoint("RIGHT", right, "LEFT")
    middle:SetHeight(32)
    local all = Label(holder)
    all:SetSize(40, 22)
    all:SetPoint("LEFT", left, "RIGHT", -3, -3)
    all.text:SetText(ALL or "All")
    all:SetScript("OnClick", onClick)
    holder:SetWidth(all.text:GetStringWidth() + 45)
    return all
end

-- The window's own regions, shown with the page, as Era's tab draws them; the trainer's bar between list and detail.
local function Sheets(page, window)
    page.sheets = {}
    for i, sheet in ipairs(SHEETS) do
        local tex = Tex(window, "BORDER", sheet[1], sheet[3], 256)
        tex:SetPoint(sheet[2], window, sheet[2], 0, 0)
        tex:Hide()
        page.sheets[i] = tex
    end
    page:SetScript("OnShow", function() for _, tex in ipairs(page.sheets) do tex:Show() end end)
    page:SetScript("OnHide", function() for _, tex in ipairs(page.sheets) do tex:Hide() end end)
    local left = Tex(page, "ARTWORK", "trainerBar", 256, 16)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -290)
    left:SetTexCoord(0, 1, 0, 0.25)
    local right = Tex(page, "ARTWORK", "trainerBar", 75, 16)
    right:SetPoint("LEFT", left, "RIGHT", 0, 0)
    right:SetTexCoord(0, 0.29296875, 0.25, 0.5)
end

local function Rows(page, owner)
    page.labels, page.bars = {}, {}
    for i = 1, ROWS do
        local label = Label(page)
        if i == 1 then
            label:SetPoint("LEFT", page, "TOPLEFT", 22, -86)
        else
            label:SetPoint("LEFT", page.labels[i - 1], "LEFT", 0, -ROW_PITCH)
        end
        label:SetScript("OnClick", function(self) if self.line then owner.onLabel(self.line) end end)
        page.labels[i] = label
        local bar = SkillBar(page, BAR_W, BORDER_W)
        if i == 1 then
            bar:SetPoint("TOPLEFT", page, "TOPLEFT", 38, -79)
        else
            bar:SetPoint("TOPLEFT", page.bars[i - 1], "BOTTOMLEFT", 0, -3)
        end
        bar.border:SetScript("OnClick", function() if bar.line then owner.onBar(bar.line) end end)
        if owner.onEnter then
            bar.border:SetScript("OnEnter", function(self) if bar.line then owner.onEnter(bar.line, self) end end)
            bar.border:SetScript("OnLeave", ns.HideTip)
        end
        page.bars[i] = bar
    end
end

-- The list's scroll frame (Era's FauxScrollFrame): its track and bar, shown while the list runs past twelve rows.
local function ListScroll(page)
    local list = ns.NewFrame("Frame", nil, page)
    list:SetSize(296, 220)
    list:SetPoint("TOPRIGHT", page, "TOPRIGHT", -67, -75)
    list:EnableMouseWheel(true)
    Track(list, 128, 1, 0)
    page.list = list
    page.scroll = ScrollBar(list, function() page:Draw() end)
    list:SetScript("OnMouseWheel", function(_, delta)
        page.scroll:SetValue(page.scroll:GetValue() - delta)
    end)
end

local function Unlearn(bar, detail, owner)
    local unlearn = ns.NewFrame("Button", nil, bar)
    unlearn:SetSize(32, 32)
    unlearn:SetPoint("LEFT", bar.border, "RIGHT", -2, -1)
    unlearn:SetHitRectInsets(9, 7, -7, 10)
    unlearn:SetNormalTexture(CANCEL .. "Up")
    unlearn:SetPushedTexture(CANCEL .. "Down")
    unlearn:SetHighlightTexture(CANCEL .. "Highlight", "ADD")
    unlearn:SetScript("OnClick", function() if detail.info then owner.onUnlearn(detail.info) end end)
    unlearn:SetScript("OnEnter", function(self)
        if not (detail.info and detail.info.unlearnTip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(detail.info.unlearnTip)
    end)
    unlearn:SetScript("OnLeave", ns.HideTip)
    return unlearn
end

-- The detail's scroll frame under the list: the picked line's bar, its cost and its words.
local function Detail(page, owner)
    local frame = ns.NewFrame("ScrollFrame", nil, page)
    frame:SetSize(296, 107)
    frame:SetPoint("TOPLEFT", page.list, "BOTTOMLEFT", 0, -8)
    Track(frame, 100, 0.78125, 0.21875)
    local child = ns.NewFrame("Frame", nil, frame)
    child:SetSize(320, 50)
    frame:SetScrollChild(child)
    local detail = { frame = frame, child = child }
    detail.scroll = ScrollBar(frame, function(value) frame:SetVerticalScroll(value) end)
    detail.scroll.step = DETAIL_STEP
    detail.scroll:Hide()
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local bar = detail.scroll
        if bar:IsShown() then bar:SetValue(bar:GetValue() - delta * bar.step) end
    end)
    detail.bar = SkillBar(child, DETAIL_W, DETAIL_BORDER_W)
    detail.bar:SetPoint("CENTER", child, "TOP", -10, -20)
    detail.bar.border:EnableMouse(false)
    detail.unlearn = Unlearn(detail.bar, detail, owner)
    detail.cost = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.cost:SetWidth(200)
    detail.cost:SetJustifyH("CENTER")
    detail.cost:SetPoint("CENTER", child, "TOP", -10, -40)
    detail.words = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.words:SetWidth(275)
    detail.words:SetJustifyH("LEFT")
    detail.words:SetJustifyV("TOP")
    page.detail = detail
end

-- page:Draw(): page.lines, each { header = true, name, expanded } or a bar line { name, rank, most, modifier, selected }.
local function Draw(page)
    local offset = math.floor((page.scroll:GetValue() or 0) + 0.5)
    local allOpen = true
    for _, line in ipairs(page.lines) do
        if line.header and not line.expanded then allOpen = false end
    end
    page.all.icon:SetTexture(allOpen and MINUS or PLUS)
    for i = 1, ROWS do
        local line = page.lines[offset + i]
        local label, bar = page.labels[i], page.bars[i]
        label.line, bar.line = nil, nil
        label:Hide()
        bar:Hide()
        if line and line.header then
            label.line = line
            label.text:SetText(line.name or "")
            label.icon:SetTexture(line.expanded and MINUS or PLUS)
            label:Show()
        elseif line then
            bar.line = line
            DrawBar(bar, line)
            if line.selected then bar.border:LockHighlight() else bar.border:UnlockHighlight() end
            bar:Show()
        end
    end
    page.empty:SetShown(#page.lines == 0)
    local most = math.max(0, #page.lines - ROWS)
    page.list:SetShown(most > 0)
    page.scroll:SetMinMaxValues(0, most)
    if offset > most then page.scroll:SetValue(most) end
end

-- page:DrawDetail(info), as SkillDetailFrame_SetStatusBar: info { name, rank, most, modifier, cost, words, unlearn,
-- unlearnTip } or nil for an empty pane.
local function DrawDetail(page, info)
    local detail = page.detail
    detail.info = info
    detail.bar:SetShown(info ~= nil)
    detail.words:SetShown(info ~= nil)
    if not info then
        detail.cost:Hide()
        detail.scroll:Hide()
        return
    end
    -- Era's width, grown up to a list row's for words that would run out of it.
    local bar = detail.bar
    bar:SetWidth(BAR_W)
    DrawBar(bar, info)
    local width = math.min(BAR_W, math.max(DETAIL_W, math.ceil(WordsWidth(bar))))
    bar:SetWidth(width)
    bar.border:SetWidth(width + DETAIL_BORDER_W - DETAIL_W)
    detail.unlearn:SetShown(info.unlearn and true or false)
    detail.cost:SetText(info.cost or "")
    detail.cost:SetShown(info.cost ~= nil)
    detail.words:ClearAllPoints()
    if info.cost then
        detail.words:SetPoint("TOP", detail.cost, "BOTTOM", 0, -10)
    else
        detail.words:SetPoint("TOP", detail.cost, "TOP", 0, 0)
    end
    detail.words:SetText(info.words or "")
    local top, bottom = detail.child:GetTop(), detail.words:GetBottom()
    detail.child:SetHeight(math.max(50, (top and bottom) and (top - bottom + 8) or 50))
    local over = math.max(0, detail.child:GetHeight() - detail.frame:GetHeight())
    detail.scroll:SetShown(over > 0)
    detail.scroll:SetMinMaxValues(0, over)
    if over == 0 then detail.frame:SetVerticalScroll(0) end
end

-- page = ES.Build(window, owner): owner.onLabel(line), onBar(line), onAll(), onClose(), onUnlearn(info), and
-- onEnter(line, region) for a bar's tooltip if wanted; page.empty holds the words for an empty list.
function ES.Build(window, owner)
    local page = ns.NewFrame("Frame", nil, window)
    page:SetPoint("TOPLEFT", window, "TOPLEFT", PAGE_X, PAGE_Y)
    page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", PAGE_X, PAGE_Y)
    page:Hide()
    Sheets(page, window)
    page.all = AllTab(page, function() owner.onAll() end)
    Rows(page, owner)
    ListScroll(page)
    -- The owner's words for an empty list, in the list's middle.
    page.empty = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.empty:SetWidth(260)
    page.empty:SetPoint("CENTER", page, "TOPLEFT", 169, -185)
    Detail(page, owner)
    page.close = ns.PanelButton(page, CLOSE or "Close", 80)
    page.close:SetPoint("CENTER", page, "TOPLEFT", 305, -422)
    page.close:SetScript("OnClick", function() owner.onClose() end)
    page.lines = {}
    page.Draw, page.DrawDetail = Draw, DrawDetail
    return page
end
