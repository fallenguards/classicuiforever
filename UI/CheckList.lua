local _, ns = ...

-- A long list of boxes on Era's drop down art (the windows under Classic style windows): a search box over one column
-- that scrolls with the classic bar. A tick redraws its own box; nothing else moves.

local ROW_H, VISIBLE, TICK, GAP, BAR_ROOM, SEARCH_H, MIN_W = 20, 12, 20, 2, 24, 28, 200

local function RowTip(button)
    local row = button.row
    if not (row and row.tip) then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, row.label)
    GameTooltip_AddNormalLine(GameTooltip, row.tip, true)
    GameTooltip:Show()
end

-- rows: { key, label, tip } each; isOn(key) and flip(key). Returns the list; list:Toggle(owner) opens it under owner.
function ns.CheckList(rows, isOn, flip)
    local list, inset = ns.IronList()
    local shown, buttons, offset = {}, {}, 0

    local probe = list:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    local widest = 0
    for _, row in ipairs(rows) do
        probe:SetText(row.label)
        widest = math.max(widest, probe:GetStringWidth() or 0)
    end
    probe:Hide()
    local innerW = math.max(MIN_W, math.ceil(widest) + TICK + GAP + BAR_ROOM)
    list:SetSize(innerW + inset[1] + inset[3], SEARCH_H + VISIBLE * ROW_H + inset[2] + inset[4])

    local search = ns.SearchBox(list, innerW - 8, _G.SEARCH or "")
    search:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1] + 6, -inset[2] - 2)
    local area = ns.NewFrame("Frame", nil, list)
    area:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1], -inset[2] - SEARCH_H)
    area:SetSize(innerW - BAR_ROOM, VISIBLE * ROW_H)

    local function Draw()
        for i, button in ipairs(buttons) do
            local row = shown[offset + i]
            button.row = row
            if row then
                button.label:SetText(row.label)
                button.tick:SetAlpha(isOn(row.key) and 1 or 0)
            end
            button:SetShown(row ~= nil)
        end
    end

    local bar = ns.ClassicScrollBar(list, area, function(value)
        offset = math.floor(value + 0.5)
        Draw()
    end)

    local function Filter()
        local text = search:GetText():lower()
        wipe(shown)
        for _, row in ipairs(rows) do
            if text == "" or row.label:lower():find(text, 1, true) then shown[#shown + 1] = row end
        end
        offset = 0
        bar:SetValue(0)
        bar:SetRange(#shown - VISIBLE)
        Draw()
    end

    for i = 1, VISIBLE do
        local button = ns.NewFrame("Button", nil, area)
        button:SetSize(innerW - BAR_ROOM, ROW_H)
        button:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -(i - 1) * ROW_H)
        button.tick = button:CreateTexture(nil, "ARTWORK")
        ns.IronTick(button.tick)
        button.tick:SetPoint("LEFT", button, "LEFT", 0, 0)
        button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        button.label:SetPoint("LEFT", button.tick, "RIGHT", GAP, 0)
        ns.MenuHighlight(button)
        button:SetScript("OnClick", function(self)
            if not self.row then return end
            flip(self.row.key)
            self.tick:SetAlpha(isOn(self.row.key) and 1 or 0)
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        end)
        button:SetScript("OnEnter", RowTip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        buttons[i] = button
    end

    search:HookScript("OnTextChanged", function(self)
        local empty = self:GetText() == ""
        self.hint:SetShown(empty)
        self.clear:SetShown(not empty)
        Filter()
    end)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta) end)

    function list:Toggle(owner)
        if self:IsShown() then self:Hide() return end
        self.owner = owner
        search:SetText("")
        Filter()
        ns.SetPointOnce(self, "TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
        self:Show()
        self:Raise()
    end
    return list
end
