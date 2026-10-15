local _, ns = ...

-- The book's flyouts (Group Similar Spells on Flyouts): a flyout entry opens a row of its known spells beside it. The rows
-- are ours, armed with the page out of combat and opened by a secure click, so they open and cast in a fight; the game's
-- own pop-out would run in our name off our button and be blocked there. One open at a time on a page.

local SIZE, GAP, PAD = 30, 4, 6
local ROW_LOOK = { bg = { 0.05, 0.05, 0.05, 0.92 }, bgFirst = true, base = { 0.6, 0.6, 0.6, 1 } }
local header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
local rows = setmetatable({}, { __mode = "k" })    -- book casting button -> its row
local hosts = setmetatable({}, { __mode = "k" })   -- page layer -> the protected holder of its rows

-- Release over a flyout entry: the page's rows shut and its own opens unless it was open; the entry casts nothing.
local TOGGLE = [[
    if down or not self:GetAttribute("flyout") then return end
    local own = self:GetFrameRef("row")
    local was = own and own:IsShown()
    for _, row in ipairs(self:GetFrameRef("host"):GetChildList(newtable())) do row:Hide() end
    if own and not was then own:Show() end
    return false
]]
-- A cast from a row shuts it.
local CAST_PRE = [[ if not down then return nil, true end ]]
local CAST_POST = [[ self:GetParent():Hide() ]]
-- A row's spell drags by its id, the game picking it up itself, in a fight too (as the book's own buttons).
local DRAG = [[
    local id = self:GetAttribute("dragspell")
    if id then return "spell", id end
]]

local function SpellTip(self)
    if not self.spellID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.spellID)
    GameTooltip:Show()
end

-- The rows of a page under one protected holder; a book that shuts out of a fight shuts them.
local function Host(layer)
    local host = hosts[layer]
    if host then return host end
    host = ns.NewFrame("Frame", nil, layer, "SecureFrameTemplate")
    host:SetAllPoints(layer)
    layer:HookScript("OnHide", function()
        if InCombatLockdown() then return end
        for _, row in pairs(rows) do
            if row:GetParent() == host then row:Hide() end
        end
    end)
    hosts[layer] = host
    return host
end

local function Row(btn)
    local row = rows[btn]
    if row then return row end
    local host = Host(btn:GetParent())
    row = ns.NewFrame("Frame", nil, host, "SecureFrameTemplate, BackdropTemplate")
    ns.Backdrop(row, ns.BACKDROP.TIP12, ROW_LOOK)
    row:SetFrameLevel(btn:GetFrameLevel() + 6)
    row:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    row:EnableMouse(true)
    row:Hide()
    row.buttons = {}
    SecureHandlerSetFrameRef(btn, "row", row)
    SecureHandlerSetFrameRef(btn, "host", host)
    SecureHandlerWrapScript(btn, "OnClick", header, TOGGLE)
    rows[btn] = row
    return row
end

local function SpellButton(row, i)
    local button = row.buttons[i]
    if button then return button end
    button = ns.NewFrame("Button", nil, row, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:SetPoint("LEFT", row, "LEFT", PAD + (i - 1) * (SIZE + GAP), 0)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetAttribute("useOnKeyDown", false)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", SpellTip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    SecureHandlerWrapScript(button, "OnDragStart", header, DRAG)
    SecureHandlerWrapScript(button, "OnClick", header, CAST_PRE, CAST_POST)
    row.buttons[i] = button
    return button
end

-- Out of combat, as the page is laid: flyoutID arms btn's row with that flyout's known spells; nil leaves btn a plain
-- entry, its row shut.
function ns.ArmBookFlyout(btn, flyoutID)
    btn:SetAttribute("flyout", flyoutID and true or nil)
    local row = rows[btn]
    if row then row:Hide() end
    if not flyoutID then return end
    row = Row(btn)
    local _, _, slots = GetFlyoutInfo(flyoutID)
    local count = 0
    for slot = 1, slots or 0 do
        local spellID, _, known = GetFlyoutSlotInfo(flyoutID, slot)
        if known and spellID then
            count = count + 1
            local button = SpellButton(row, count)
            button.spellID = spellID
            button:SetAttribute("type1", "spell")
            button:SetAttribute("spell", spellID)
            button:SetAttribute("dragspell", spellID)
            button.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
            button:Show()
        end
    end
    for i = count + 1, #row.buttons do
        local button = row.buttons[i]
        button.spellID = nil
        button:SetAttribute("type1", nil)
        button:SetAttribute("dragspell", nil)
        button:Hide()
    end
    row:SetSize(PAD * 2 + count * SIZE + math.max(0, count - 1) * GAP, SIZE + PAD * 2)
end

-- For the dev probe (bookopts): each armed book button and its row.
function ns.BookFlyoutRows() return rows end

-- The game's flyout arrow on a book entry's icon, pointing where its row opens.
local arrows = setmetatable({}, { __mode = "k" })
function ns.BookFlyoutArrow(btn, on)
    local arrow = arrows[btn]
    if not arrow and on then
        arrow = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        arrow:SetAtlas("UI-HUD-ActionBar-Flyout")
        arrow:SetSize(16, 8)
        arrow:SetRotation(-math.pi / 2)
        arrow:SetPoint("RIGHT", btn, "RIGHT", 4, 0)
        arrows[btn] = arrow
    end
    if arrow then arrow:SetShown(on) end
end
