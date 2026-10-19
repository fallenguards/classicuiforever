local _, ns = ...
local L = ns.L

-- Addon buttons' drop down (#194): Shown, On hover or Hidden for all of them, then under Override every button seen on
-- the ring, ours too, with a pick of its own over that; kept in the profile (minimapButtonPicks: key -> "show", "hover"
-- or "hide"; none: the button follows the rest).

local MM = ns.MM

local ROW_H, VISIBLE, GAP, BAR_ROOM, SEARCH_H, NAME_MAX, MIN_W = 24, 10, 8, 24, 28, 200, 200
local DROP_PAD = 40           -- a row's drop down past its text: the arrow and the art's ends
local RADIO_ROOM = 18
local VALUES = { "show", "hover", "hide" }    -- the three overall rows' order (Options/Toggles.lua)
local SAME = ""

-- The one panel (the options' Addon buttons row): its frames, words and rows.
local P = { buttons = {}, shown = {}, lines = {}, overall = {}, offset = 0 }

local function Picks()
    local picks = ns.db.minimapButtonPicks
    return type(picks) == "table" and picks or nil
end

local function PickOf(key)
    local picks = Picks()
    return picks and picks[key] or SAME
end

-- SAME: the button follows Addon buttons again.
local function Pick(key, value)
    local picks = Picks()
    if not picks then
        if value == SAME then return end
        picks = {}
        ns.db.minimapButtonPicks = picks
    end
    if value == SAME then picks[key] = nil else picks[key] = value end
    if next(picks) == nil then ns.db.minimapButtonPicks = nil end
    ns.ToggleChanged("minimapButtonPicks")
end

local function Width(text)
    P.probe:SetText(text)
    return math.ceil(P.probe:GetStringWidth() or 0)
end

local function Draw()
    for _, item in ipairs(P.overall) do ns.IronRadioOn(item.mark, P.isOn(item.key)) end
    for i, line in ipairs(P.lines) do
        local row = P.shown[P.offset + i]
        line.row = row
        if row then
            line.label:SetText(row.label)
            line.drop:OverrideText(P.words[PickOf(row.key)] or P.words[SAME])
        end
        line:SetShown(row ~= nil)
    end
    P.empty:SetShown(#P.buttons == 0)
end

local function DrawAt(offset)
    P.offset = offset
    Draw()
end

-- The three rows for all of them, as radios; top: their foot.
local function Overall(rows, pick)
    local list, inset = P.list, P.inset
    for i, row in ipairs(rows) do
        local item = ns.NewFrame("Button", nil, list)
        item:SetHeight(ns.MENU_ROW)
        item:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1], -inset[2] - (i - 1) * ns.MENU_ROW)
        item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -inset[3], -inset[2] - (i - 1) * ns.MENU_ROW)
        item.mark = item:CreateTexture(nil, "ARTWORK")
        ns.IronRadio(item.mark)
        item.mark:SetPoint("LEFT", item, "LEFT", 0, 0)
        local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", item.mark, "RIGHT", 2, 0)
        label:SetText(row.label)
        ns.MenuHighlight(item)
        item:SetScript("OnClick", function()
            pick(row.key)
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            Draw()
        end)
        item.key = row.key
        P.overall[i] = item
    end
    return -inset[2] - #rows * ns.MENU_ROW
end

-- The divider, Override's head and the search box under top; returns their foot.
local function OverrideHead(top)
    local list, inset = P.list, P.inset
    local divider = ns.IronDivider(list)
    divider:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1], top)
    divider:SetPoint("TOPRIGHT", list, "TOPRIGHT", -inset[3], top)
    top = top - ns.MENU_DIVIDER
    local head = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    head:SetHeight(ns.MENU_ROW)
    head:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1], top)
    head:SetText(L["MAP_PICKS_OVERRIDE"])
    top = top - ns.MENU_ROW
    P.search = ns.SearchBox(list, MIN_W, _G.SEARCH or "")
    P.search:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1] + 6, top - 2)
    P.search:SetPoint("TOPRIGHT", list, "TOPRIGHT", -inset[3] - 2, top - 2)
    return top - SEARCH_H
end

-- One shared list of a button's four picks, opened from its row's drop down.
local function Choices()
    local entries = {}
    for _, value in ipairs({ SAME, VALUES[1], VALUES[2], VALUES[3] }) do
        entries[#entries + 1] = { P.words[value], function()
            Pick(P.editing, value)
            Draw()
        end, function() return PickOf(P.editing) == value end }
    end
    local choices = ns.DropList(entries)
    ns.NestList(P.list, choices)
    return function(drop)
        local row = drop.line.row
        if not row then return end
        if choices:IsShown() and choices.owner ~= drop then choices:Hide() end
        P.editing = row.key
        choices:Toggle(drop)
    end
end

-- The buttons' rows in area: a name, and its pick in a drop down.
local function Lines(area, dropW, open)
    for i = 1, VISIBLE do
        local line = ns.NewFrame("Frame", nil, area)
        line:SetHeight(ROW_H)
        line:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -(i - 1) * ROW_H)
        line:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -(i - 1) * ROW_H)
        local drop = ns.NewFrame("DropdownButton", nil, line, "WowStyle1DropdownTemplate")
        ns.SkinDropdown(drop)
        drop:SetWidth(dropW)
        drop:SetPoint("RIGHT", line, "RIGHT", 0, 0)
        drop:HookScript("OnMouseDown", open)
        drop.line = line
        local label = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", line, "LEFT", 0, 0)
        label:SetPoint("RIGHT", drop, "LEFT", -GAP, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        line.label, line.drop = label, drop
        P.lines[i] = line
    end
end

-- As it opens: the buttons on the ring now, the list sized to their longest name (cut past NAME_MAX), up to VISIBLE rows.
local function Refill(list)
    wipe(P.buttons)
    for _, row in ipairs(ns.AddonRingButtons()) do P.buttons[#P.buttons + 1] = row end
    local nameW = 0
    for _, row in ipairs(P.buttons) do nameW = math.max(nameW, Width(row.label)) end
    local innerW = math.max(MIN_W, P.baseW, math.min(nameW, NAME_MAX) + GAP + P.dropW + BAR_ROOM)
    local count = math.min(math.max(#P.buttons, 1), VISIBLE)
    P.area:SetHeight(count * ROW_H)
    list:SetSize(innerW + P.inset[1] + P.inset[3], -P.top + count * ROW_H + P.inset[4])
    P.search:SetShown(#P.buttons > 0)
end

-- rows: the three overall picks ({ key, label } each, in VALUES' order); pick(key) and isOn(key) set and read them.
-- Returns the list; list:Toggle(owner) opens it under owner.
function ns.MinimapButtonPicksPanel(rows, pick, isOn)
    local list, inset = ns.IronList()
    P.list, P.inset, P.isOn = list, inset, isOn
    P.words = { [SAME] = L["MAP_PICKS_SAME"] }
    for i, row in ipairs(rows) do P.words[VALUES[i]] = row.label end
    P.probe = list:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    P.probe:Hide()
    P.dropW, P.baseW = 0, Width(L["MAP_PICKS_OVERRIDE"])
    for _, text in pairs(P.words) do
        P.dropW = math.max(P.dropW, Width(text) + DROP_PAD)
        P.baseW = math.max(P.baseW, Width(text) + RADIO_ROOM)
    end

    P.top = OverrideHead(Overall(rows, pick))
    local area = ns.NewFrame("Frame", nil, list)
    area:SetPoint("TOPLEFT", list, "TOPLEFT", inset[1], P.top)
    area:SetPoint("TOPRIGHT", list, "TOPRIGHT", -inset[3] - BAR_ROOM, P.top)
    P.area = area
    P.empty = area:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    P.empty:SetPoint("LEFT", area, "TOPLEFT", 0, -ROW_H / 2)
    P.empty:SetText(L["MAP_NO_ADDON_BUTTONS"])
    Lines(area, P.dropW, Choices())

    local bar = ns.ListSearch(list, area, P.search, P.buttons, P.shown, VISIBLE, DrawAt)
    bar.hideWhenIdle = true
    list.OnOpen = Refill
    return list
end

-- A pick changed: the ring's buttons take it at once, in a fight too.
ns.OnToggle(function(key)
    if key == "minimapButtonPicks" and MM.active and ns.ShowAddonRingButtons then ns.ShowAddonRingButtons() end
end)

-- The options button's own pick (always or on hover) became its pick among the addon buttons: one that differed from
-- Addon buttons' is kept over it, in the account and every profile. Runs before the defaults fill.
function ns.KeepOptionsButtonPick()
    local function Keep(t)
        local ours = t.hoverOptionsButton == true and "hover" or "show"
        local all = t.hideMinimapAddonButtons == true and "hide" or t.hoverMinimapAddonButtons == true and "hover" or "show"
        if ours ~= all then
            local picks = type(t.minimapButtonPicks) == "table" and t.minimapButtonPicks or {}
            picks[MM.OUR_BUTTON] = picks[MM.OUR_BUTTON] or ours
            t.minimapButtonPicks = picks
        end
        t.showOptionsButton, t.hoverOptionsButton = nil, nil
    end
    local db = ns.db
    Keep(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Keep(shot) end
    end
    db.dbVersion = 20
end
