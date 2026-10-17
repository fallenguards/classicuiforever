local _, ns = ...
local L = ns.L

-- The options window's rows (ticked is the classic look): boxes, drop downs, number rows, and every row of ns.TOGGLES
-- built once with its page (its group's title) for OptionsWindow.lua to lay out.

local O = ns.options
local ROW, INDENT = 24, 22
local C = ns.ART.CHECK
local BTN = "Interface\\Buttons\\UI-"
-- Raw paths: no bronze swap.
local OPTION_BOX = { set = "raw", checked = C .. "Check", disabledChecked = C .. "Check-Disabled", add = true }
-- UI-RadioButton's cells: ring, gold dot, glow, grey dot; 16 across in the 24 row.
local RADIO = BTN .. "RadioButton"
local OPTION_RADIO = { set = "raw", checked = RADIO, disabledChecked = RADIO, add = true, center = { 16, 16 },
    states = { "Normal", "Highlight", "Checked", "DisabledChecked" },
    coords = { Normal = { 0, 0.25, 0, 1 }, Checked = { 0.25, 0.5, 0, 1 }, Highlight = { 0.5, 0.75, 0, 1 },
        DisabledChecked = { 0.75, 1, 0, 1 } } }
O.RADIO, O.OPTION_RADIO = RADIO, OPTION_RADIO
O.ROW, O.INDENT = ROW, INDENT
local RAW_ADD = { set = "raw", add = true }

local function TipLabel(self) return self.label end
local function TipBody(self) return self.tooltip end
local function TipHeld(self) return self.key and ns.BarRowHeld(self.key) and L["BARS_TAKEN_TIP"] or nil end
-- Grayed for a toggle on another page (needs): which one turns it back on.
local function TipNeeds(self)
    local need = self.needs
    if not (need and ns.db[need] == false) then return nil end
    for _, entry in ipairs(ns.TOGGLES) do
        if entry[1] == need then return L["OPT_NEEDS_TIP"]:format(entry[2]) end
    end
end
-- White title, wrapped body, and why it is grayed (another addon holds the bars, or a toggle it needs is off).
local OPTION_TIP = { when = TipBody, text = TipLabel, r = 1, g = 1, b = 1,
    lines = { { TipBody, nil, nil, nil, true }, { TipHeld, 1, 0.82, 0, true }, { TipNeeds, 1, 0.82, 0, true } } }
O.OPTION_TIP = OPTION_TIP

-- Not part of the classic look, so Toggle none leaves them (the minimap button leads back here), nor the radio picks,
-- nor a parent's boxes in a drop down (its windows, its frames): the parent off turns them off, and on again finds them.
local NOT_IN_NONE = { minimapButton = true, welcomeNote = true, barsTakenNote = true, questLevels = true }
local picks
function O.InNone(key)
    if not picks then
        picks = {}
        for _, entry in ipairs(ns.TOGGLES) do
            if entry.checks and entry.parent then picks[entry[1]] = true end
        end
    end
    return not NOT_IN_NONE[key] and not ns.TOGGLE_RADIO[key] and not picks[key]
end
-- A radio pick that is a classic piece: Toggle none picks the game's own choice instead.
O.NONE_PICKS = { "gameObjectiveTracker", "buffArrowShown" }

-- Our standalone dialog shell, hidden: strata nil is DIALOG; opts.toplevel. Welcome and Status share it.
function O.DialogWindow(name, y, strata, opts)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    ns.Backdrop(frame, ns.BACKDROP.DIALOG)
    frame:SetFrameStrata(strata or "DIALOG")
    if opts and opts.toplevel then frame:SetToplevel(true) end
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, y or 0)
    ns.MakeDraggable(frame)
    frame:Hide()
    return frame
end

-- Lowercased once for the search: the name side (label, keywords, its section's title) and the tooltip.
local function Describe(row, key, label, tooltip)
    row.key, row.label, row.tooltip = key, label, tooltip
    row.keyLow, row.tipLow = label:lower(), (tooltip or ""):lower()
    ns.AttachTip(row, OPTION_TIP)
end
O.Describe = Describe

-- A soft gold bar behind a matching row's label; the rest of its section is dimmed.
local matchBar = setmetatable({}, { __mode = "k" })
function O.ShowMatch(box, on)
    local bar = matchBar[box]
    if not bar and on then
        bar = box:CreateTexture(nil, "BACKGROUND")
        bar:SetColorTexture(1, 0.82, 0, 0.16)
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", -2, -2)
        bar:SetPoint("BOTTOMRIGHT", box.text, "BOTTOMRIGHT", 4, -4)
        matchBar[box] = bar
    end
    if bar then bar:SetShown(on) end
end

local function Arrow(row, kind, x)
    local button = ns.NewFrame("Button", nil, row)
    button:SetSize(16, 16)
    button:SetPoint("LEFT", row, "LEFT", x, 0)
    ns.DressStates(button, BTN .. kind .. "Button-Up", BTN .. kind .. "Button-Down", BTN .. kind .. "Button-Disabled", ns.ART.PLUS_GLOW, RAW_ADD)
    return button
end

-- Number row (minus, value, plus, label) with the checkbox methods, so the list treats it alike.
local function Stepper(parent, key, label, tooltip, low, high, apply)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    row.minus = Arrow(row, "Minus", 4)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
    row.value:SetWidth(20)
    row.value:SetJustifyH("CENTER")
    row.plus = Arrow(row, "Plus", 42)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", row.plus, "RIGHT", 4, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    function row:Sync()
        local value = tonumber(ns.db[key]) or low
        self.value:SetText(value)
        self.minus:SetEnabled(self.on ~= false and value > low)
        self.plus:SetEnabled(self.on ~= false and value < high)
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled(on)
        self.on = on and true or false
        self:Sync()
    end
    local function Step(by)
        return function()
            apply(math.max(low, math.min(high, (tonumber(ns.db[key]) or low) + by)))
            row:Sync()
        end
    end
    row.minus:SetScript("OnClick", Step(-1))
    row.plus:SetScript("OnClick", Step(1))
    row:EnableMouse(true)
    -- Its page's Reset toggles puts it back through the same setter.
    row.reset = function() apply(ns.DB_DEFAULTS[key] or low) end
    Describe(row, key, label, tooltip)
    return row
end

-- A button for a mode that lasts while the options are open, not a saved setting; Done while on.
-- check: { key, label, tooltip, set } for a saved box beside it.
local function ButtonRow(parent, key, label, tooltip, press, isOn, check)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    local button = ns.PanelButton(row, label, check and 130 or 150)
    button:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.button, row.text = button, button:GetFontString()
    local box
    if check then
        box = ns.NewFrame("CheckButton", nil, row)
        box:SetSize(24, 24)
        box:SetPoint("LEFT", button, "RIGHT", 4, 0)
        ns.DressStates(box, C .. "Up", C .. "Down", nil, C .. "Highlight", OPTION_BOX)
        box.label, box.tooltip = check[2], check[3]
        ns.AttachTip(box, OPTION_TIP)
        box:SetScript("OnClick", function(self) check[4](check[1], self:GetChecked() and true or false) end)
    end
    function row.SetChecked()
        local on = isOn()
        button:SetText(on and (DONE or "Done") or label)
        button:SetButtonState(on and "PUSHED" or "NORMAL", on)
        if box then box:SetChecked(ns.db[check[1]] ~= false) end
    end
    function row.SetEnabled(_, on)
        button:SetEnabled(on)
        if box then box:SetEnabled(on) end
    end
    button:SetScript("OnClick", function() press() row:SetChecked() end)
    Describe(row, key, label, tooltip)
    return row
end

-- ToggleChanged refreshes the window; a radio row only turns on.
local function BoxClick(self)
    ns.db[self.key] = (self.radio or self:GetChecked()) and true or false
    ns.ToggleChanged(self.key)
end

local function Checkbox(parent, key, label, tooltip, radio)
    local box = ns.NewFrame("CheckButton", nil, parent)
    box:SetSize(24, 24)
    if radio then
        box.radio = true
        ns.DressStates(box, RADIO, nil, nil, RADIO, OPTION_RADIO)
    else
        ns.DressStates(box, C .. "Up", C .. "Down", nil, C .. "Highlight", OPTION_BOX)
    end
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    box.text = text
    box.toggle = true
    Describe(box, key, label, tooltip)
    box:SetScript("OnClick", BoxClick)
    return box
end

local DROP_W = 112
local SWING_HANDS = { { "swingColorMain", L["OPTWIN_MAIN_HAND"] }, { "swingColorOff", L["OPTWIN_OFF_HAND"] }, { "swingColorRanged", L["OPTWIN_RANGED"] } }

-- Label, then the old drop down box; items(root) fills its menu.
local function DropShell(parent, label, items)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", row, "LEFT", 4, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    local dropdown = ns.NewFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(DROP_W)
    dropdown:SetPoint("LEFT", text, "RIGHT", 4, -1)
    ns.SkinDropdown(dropdown)
    if items then dropdown:SetupMenu(function(_, root) items(root) end) end
    row.dropdown = dropdown
    function row:SetChecked() self.dropdown:GenerateMenu() end
    function row:SetEnabled(on) self.dropdown:SetEnabled(on) end
    return row
end

local function PickToggle(key)
    ns.db[key] = true
    ns.ToggleChanged(key)
end

local function ToggleOn(key) return ns.db[key] == true end

local function ChoiceTip(tip, choice)
    GameTooltip_SetTitle(tip, choice.label)
    GameTooltip_AddNormalLine(tip, choice.tip, true)
end

-- A drop group's rows, label and tooltip. A row's "Label: item" names the group and the item; the first entry's dropLabel
-- and dropTip name and describe a group of plain labels. An item with words of its own shows them as its tooltip.
local function DropGroup(field, group)
    local rows, words, keys, first = {}, {}, {}, nil
    for _, entry in ipairs(ns.TOGGLES) do
        if entry[field] == group then
            first = first or entry
            local item = entry[2]:match(":%s*(.+)$") or entry[2]
            rows[#rows + 1] = { key = entry[1], label = (item:gsub("^%l", string.upper)), tip = entry[3] }
            words[#words + 1] = item .. " " .. (entry.search or "")
            keys[#keys + 1] = entry[1]
        end
    end
    -- dropAlso: toggles of other pages shown here too, as themselves (a box flips that toggle); sorted in with the rest.
    if first and first.dropAlso then
        for _, entry in ipairs(ns.TOGGLES) do
            for _, key in ipairs(first.dropAlso) do
                if entry[1] == key then
                    rows[#rows + 1] = { key = key, label = entry[2], tip = entry[3] }
                    words[#words + 1] = entry[2]
                end
            end
        end
        table.sort(rows, function(a, b) return a.label < b.label end)
    end
    local label = first and (first.dropLabel or first[2]:match("^(.-):")) or group
    local tip = first and (first.dropTip or first[3])
    for _, choice in ipairs(rows) do
        if choice.tip == tip then choice.tip = nil end
    end
    return rows, label, tip, table.concat(words, " "):lower(), keys
end

local function ItemTip(item, choice)
    if not (choice.tip and item and item.SetOnEnter) then return end
    item:SetOnEnter(function(button) MenuUtil.ShowTooltipEx(button, item:GetTooltipFrame(), ChoiceTip, choice) end)
end

-- A drop radio group as one row; keys: the toggles it holds (a page's Toggle none and Reset toggles reach them).
local function DropRow(parent, group)
    local rows, label, tip, words, keys = DropGroup("radio", group)
    local row = DropShell(parent, label, function(root)
        for _, choice in ipairs(rows) do ItemTip(root:CreateRadio(choice.label, ToggleOn, PickToggle, choice.key), choice) end
    end)
    Describe(row, group, label, tip)
    row.keyLow = row.keyLow .. " " .. words
    row.keys = keys
    return row
end

local function FlipToggle(key)
    ns.db[key] = ns.db[key] ~= true
    ns.ToggleChanged(key)
end

-- Past this many boxes a group opens our scrolling list with a search (UI/CheckList.lua) in place of the game's menu:
-- the game's scrolling menu stacked its rows at its top on a tick, and columns made a wall.
local DROP_LIST_ROWS = 17

-- The long group's row: the same drop down box, its count of ticks, our list under it.
local function CheckListRow(parent, rows, label)
    local row = DropShell(parent, label)
    local dropdown = row.dropdown
    local function Count()
        local on = 0
        for _, choice in ipairs(rows) do
            if ToggleOn(choice.key) then on = on + 1 end
        end
        dropdown:OverrideText(L["OPTWIN_N_OF_N"]:format(on, #rows))
    end
    local list
    dropdown:HookScript("OnMouseDown", function(self)
        if not self:IsEnabled() then return end
        if not list then
            list = ns.CheckList(rows, ToggleOn, function(key)
                FlipToggle(key)
                Count()
            end)
            list:Follow(row)
        end
        list:Toggle(self)
    end)
    row.SetChecked = Count
    Count()
    return row
end

-- Several toggles picked in one drop down, as checks (entries with checks = group).
local function DropCheckRow(parent, group)
    local rows, label, tip, words, keys = DropGroup("checks", group)
    if #rows > DROP_LIST_ROWS then
        local row = CheckListRow(parent, rows, label)
        Describe(row, group, label, tip)
        row.keyLow = row.keyLow .. " " .. words
        row.keys = keys
        return row
    end
    local row = DropShell(parent, label, function(root)
        for _, choice in ipairs(rows) do ItemTip(root:CreateCheckbox(choice.label, ToggleOn, FlipToggle, choice.key), choice) end
    end)
    Describe(row, group, label, tip)
    row.keyLow = row.keyLow .. " " .. words
    row.keys = keys
    return row
end

-- A setting holding one of a list's keys (choices: { key, label, tip }); apply(key, pick) saves and shows it.
-- preview(key) shows a choice while it is hovered, preview(nil) the setting again once the menu shuts.
local function ValueDropRow(parent, key, label, tooltip, choices, apply, preview)
    local row, shut
    local function Hover(choice)
        preview(choice)
        shut = shut or ns.Sched.Job({ name = "options.preview." .. key, every = 0.2, awake = false, fn = function()
            if row.dropdown:IsMenuOpen() then return end
            preview(nil)
            shut:Sleep()
        end })
        shut:Wake()
    end
    row = DropShell(parent, label, function(root)
        for _, choice in ipairs(choices) do
            local item = root:CreateRadio(choice.label, function(pick) return ns.db[key] == pick end,
                function(pick) apply(key, pick) end, choice.key)
            if (preview or choice.tip) and item and item.SetOnEnter then
                item:SetOnEnter(function(button)
                    if preview then Hover(choice.key) end
                    if choice.tip then MenuUtil.ShowTooltipEx(button, item:GetTooltipFrame(), ChoiceTip, choice) end
                end)
                if preview then item:SetOnLeave(function() preview(nil) end) end
            end
        end
    end)
    Describe(row, key, label, tooltip)
    return row
end

-- A page's title over its rows in search results, in the old gold.
local function GroupHead(parent, title, width)
    local head = ns.NewFrame("Frame", nil, parent)
    head:SetSize(width, ROW)
    local text = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 2, 4)
    text:SetText(title)
    head:Hide()
    return head
end

-- A sub-heading inside a page (an entry's sub): a gold label row over its run of rows, never a search match itself.
local function SubHead(parent, title)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", row, "LEFT", 4, 1)
    text:SetText(title)
    row.text, row.font, row.sub = text, "GameFontNormal", true
    row.key, row.label, row.keyLow, row.tipLow = "sub:" .. title, title, "", ""
    function row.SetChecked() end
    function row.SetEnabled() end
    return row
end

-- Rows that are not toggles hang under their toggle; colW: a column's width, for the labels.
local function Extras(entry, child, colW, add)
    local function Step(parent, key, label, tip, low, high, apply, words)
        local row = Stepper(child, key, label, tip, low, high, apply)
        row.text:SetWidth(colW - 70 - INDENT)
        if words then row.keyLow = row.keyLow .. " " .. words end
        add(row, parent)
    end
    local function Drop(parent, key, label, tip, choices, apply, words, depth, preview)
        local row = ValueDropRow(child, key, label, tip, choices, apply, preview)
        row.text:SetWidth(colW - 14 - DROP_W - (depth or 1) * INDENT)
        row.keyLow = row.keyLow .. " " .. words
        add(row, parent)
    end
    local key = entry[1]
    if key == "oneBag" then
        Step("oneBag", "oneBagColumns", L["OPTWIN_COLUMNS"], L["OPTWIN_HOW_MANY_SLOTS_ACROSS_THE"],
            ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16, ns.SetOneBagColumns)
    elseif key == "hideKeyText" then
        Step("buttons", "keyTextSize", L["OPTWIN_KEY_TEXT_SIZE"], L["OPTWIN_HOW_BIG_THE_KEY_NAMES"],
            ns.KEY_TEXT_MIN or 8, ns.KEY_TEXT_MAX or 20, ns.SetKeyTextSize, "keybind font hotkey")
    elseif key == "themeDark" then
        add(O.DarknessRow(child, colW - 2 * INDENT - 14), "themeDark")
    -- The Other page's last row: the camera block after it.
    elseif key == "leaveGameWindows" then
        local head, camera = O.CameraRow(child, colW - 2 * INDENT - 14)
        head.text:SetWidth(colW - 30)
        add(head)
        add(camera, head.key)
    elseif key == "themeCustom" then
        local color = O.ColorRow(child, "themeColor", L["OPTWIN_COLOUR"], L["OPTWIN_THE_CUSTOM_THEME_S_COLOUR"])
        color.text:SetWidth(colW - 40 - INDENT)
        color.keyLow = color.keyLow .. " rgb hex color theme"
        add(color, "themeCustom")
    elseif key == "damageMeter" and ns.METER_BACKGROUNDS then
        Drop("damageMeter", "meterBackground", L["OPTWIN_BACKGROUND"], L["OPTWIN_THE_METER_S_BACK_THE"],
            ns.METER_BACKGROUNDS, ns.SetMeterBackground, "talent tree damage meter", nil, ns.PreviewMeterBackground)
        Step("damageMeter", "meterHeader", L["OPTWIN_HEADER_HEIGHT"], L["OPTWIN_EXTRA_HEIGHT_OVER_THE_METER"],
            ns.METER_HEADER_MIN or 0, ns.METER_HEADER_MAX or 16, ns.SetMeterHeader, "damage meter title")
        local pan = ButtonRow(child, "meterPanArt", L["OPT_meterPanArt"], L["OPT_meterPanArt_TIP"],
            function() ns.SetMeterPanning(not ns.MeterPanning()) end, ns.MeterPanning,
            { "meterPanPreview", L["OPT_meterPanPreview"], L["OPT_meterPanPreview_TIP"], ns.SetMeterBackground })
        pan.keyLow = pan.keyLow .. " drag align background art whole preview"
        add(pan, "damageMeter")
    elseif key == "thickHealthMana" and ns.ENEMY_HEALTH_COLORS then
        Drop("thickHealth", "thickEnemyColor", L["OPTWIN_ENEMY_HEALTH"], L["OPTWIN_THE_COLOUR_OF_AN_ENEMY"],
            ns.ENEMY_HEALTH_COLORS, ns.SetEnemyHealthColor, "colour color hostile red neutral yellow reaction aggro", 2)
    elseif key == "unitFrames" and ns.SetUnitNameSize then
        Step("unitFrames", "unitNameSize", L["OPTWIN_NAME_SIZE"], L["OPTWIN_TEXT_SIZE_OF_THE_PLAYER"],
            ns.UNIT_NAME_MIN or 8, ns.UNIT_NAME_MAX or 16, ns.SetUnitNameSize, "font unit frame name text")
    elseif key == "resourceDisplay" and ns.SetPrdGap then
        Step("resourceDisplay", "prdGap", L["OPTWIN_BAR_GAP"], L["OPTWIN_SPACE_BETWEEN_THE_HEALTH_AND"],
            ns.PRD_GAP_MIN or 0, ns.PRD_GAP_MAX or 20, ns.SetPrdGap, "personal resource padding spacing")
    elseif key == "swingTimers" and ns.SWING_COLORS then
        for _, hand in ipairs(SWING_HANDS) do
            Drop("swingTimers", hand[1], hand[2], L["OPTWIN_THE_SWING_BAR_S_COLOUR"], ns.SWING_COLORS,
                ns.SetSwingLook, "swing colour color")
        end
        Step("swingTimers", "swingBorder", L["OPTWIN_BORDER_THICKNESS"], L["OPTWIN_HOW_THICK_THE_SWING_BARS"],
            ns.SWING_BORDER_MIN or -1, ns.SWING_BORDER_MAX or 5, ns.SetSwingBorder, "swing")
    elseif key == "classColorPlates" then
        Step("namePlates", "plateNameSize", L["OPTWIN_NAME_TEXT_SIZE"], L["OPTWIN_POINTS_BIGGER_OR_SMALLER_THAN"],
            ns.PLATE_NAME_MIN or -6, ns.PLATE_NAME_MAX or 6, ns.SetPlateNameSize, "font")
    end
end

-- Every row of ns.TOGGLES on child, in list order. Returns the rows and their tree: rows[i], kids[key] (rows under that
-- key), parentOf[key], heads[page] (a page's title row for search results).
function O.BuildRows(child, colW)
    local rows, kids, parentOf, depthOf, heads = {}, {}, {}, {}, {}
    local page, dropped = nil, {}
    local function Add(row, parent)
        row.parent, row.page = parent, page
        row.depth = parent and ((depthOf[parent] or 0) + 1) or 0
        if page then row.keyLow = row.keyLow .. " " .. page:lower() end
        parentOf[row.key], depthOf[row.key] = parent, row.depth
        rows[#rows + 1] = row
        if parent then
            kids[parent] = kids[parent] or {}
            table.insert(kids[parent], row)
        end
    end
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.group then
            page = entry.group
            heads[page] = heads[page] or GroupHead(child, page, colW - 8)
        end
        if entry.sub then
            local head = SubHead(child, entry.sub)
            Add(head, entry.parent)
            head.keyLow, head.tipLow = "", ""
        end
        local dropGroup = entry.checks or entry.radio
        if entry.drop and not dropped[dropGroup] then
            dropped[dropGroup] = true
            local row = entry.checks and DropCheckRow(child, dropGroup) or DropRow(child, dropGroup)
            Add(row, entry.parent)
            row.text:SetWidth(colW - 14 - DROP_W - row.depth * INDENT)
        elseif not entry.drop then
            local box = Checkbox(child, entry[1], entry[2], entry[3], entry.radio)
            box.needs = entry.needs
            if entry.search then box.keyLow = box.keyLow .. " " .. entry.search:lower() end
            Add(box, entry.parent)
            box.text:SetWidth(colW - 30 - box.depth * INDENT)
        end
        Extras(entry, child, colW, Add)
    end
    return { rows = rows, kids = kids, parentOf = parentOf, heads = heads }
end
