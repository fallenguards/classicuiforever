local _, ns = ...
local L = ns.L

-- Fallen's UI Color Picker's own windows (the full addon's options are not its): the look pick at first login and on its
-- minimap button's right-click, and its settings on /fcui, its minimap button and the game's AddOns list. The game's own
-- frame and controls; a look recolors the interface at once, so the interface itself is the preview.

local O = ns.options
local PICKER = ns.PACKAGE and not ns.PACKAGE.piece
local PAD, ROW_H, CHECK_H, SLIDER_W, GAP = 20, 26, 24, 160, 12
local LOOKS = {
    { label = "LOOKPICK_OWN" },
    { key = "themeDark" },
    { key = "themeBronze" },
    { key = "themeCustom" },
}
local syncs = {}   -- every built part's refresh
local byKey        -- the package's rows by key, read once its list is trimmed
local pick, settings, content, canvas

-- The look showing now: false while the theme is off.
local function Current()
    local db = ns.db
    if not db.bronzeTheme then return false end
    for _, look in ipairs(LOOKS) do
        if look.key and db[look.key] then return look.key end
    end
    return false
end

local function SyncAll()
    for _, sync in ipairs(syncs) do sync() end
end

-- The theme on with one look (the radio's others off), or off, in one pass.
local function Pick(key)
    local db = ns.db
    db.bronzeTheme = key and true or false
    if key then
        for _, look in ipairs(LOOKS) do
            if look.key then db[look.key] = look.key == key end
        end
    end
    ns.TogglesChanged(key and { "bronzeTheme", key } or { "bronzeTheme" })
    SyncAll()
end

-- The four looks from top down at y in host: the game's radios, Dark's slider and the custom color's swatch beside
-- their names. Returns the height and the widest row's need.
local function LookRows(host, y, prefix)
    local rows, need = {}, 0
    for i, look in ipairs(LOOKS) do
        local row = ns.NewFrame("Button", nil, host)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, y - (i - 1) * ROW_H)
        local radio = ns.NewFrame("CheckButton", prefix .. i, row, "UIRadioButtonTemplate")
        radio:SetPoint("LEFT")
        local text = radio:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", radio, "RIGHT", 6, 0)
        text:SetText(L[look.label or ("OPT_" .. look.key)])
        local function Choose() Pick(look.key or false) end
        row:SetScript("OnClick", Choose)
        radio:SetScript("OnClick", Choose)
        row.radio, row.text, row.key = radio, text, look.key or false
        rows[i] = row
        need = math.max(need, 22 + text:GetStringWidth())
    end
    local dark, custom = rows[2], rows[4]
    local darkness = O.DarknessRow(dark, SLIDER_W)
    darkness:SetPoint("LEFT", dark.text, "RIGHT", 12, 0)
    need = math.max(need, 22 + dark.text:GetStringWidth() + 12 + SLIDER_W)
    -- The custom color's swatch: a click picks the look and opens the game's color picker.
    local chip = ns.NewFrame("Button", nil, custom)
    chip:SetSize(18, 18)
    chip:SetPoint("LEFT", custom.text, "RIGHT", 10, 0)
    local rim = chip:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(0, 0, 0, 1)
    local swatch = chip:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)
    chip:SetScript("OnClick", function()
        Pick("themeCustom")
        O.EditThemeColor(SyncAll)
    end)
    syncs[#syncs + 1] = function()
        local now = Current()
        for _, row in ipairs(rows) do row.radio:SetChecked(row.key == now) end
        -- Dark's slider, the settings' own row: live while Dark is the look, as there.
        darkness:SetEnabled(now == "themeDark")
        local r, g, b = ns.HexColor(ns.db.themeColor)
        swatch:SetColorTexture(r or 1, g or 1, b or 1)
    end
    return #LOOKS * ROW_H, need
end

-- A setting's row is live while every setting above it is on.
local function Live(key)
    local entry = byKey[key]
    local parent = entry and entry.parent
    if not parent then return true end
    return ns.db[parent] == true and Live(parent)
end

local checks = 0
-- The game's check box for a row of the package's list, its label on it and its tip on hover. Returns it and its width.
local function Check(host, entry)
    local key = entry[1]
    checks = checks + 1
    local check = ns.NewFrame("CheckButton", "FallensUIColorPickerCheck" .. checks, host, "UICheckButtonTemplate")
    check:SetSize(CHECK_H, CHECK_H)
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 2, 1)
    text:SetText(entry[2])
    check:SetHitRectInsets(0, -text:GetStringWidth() - 4, 0, 0)
    check:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked() and true or false
        ns.ToggleChanged(key)
        SyncAll()
    end)
    if entry[3] then ns.AttachTip(check, { text = entry[2], r = 1, g = 1, b = 1, lines = { { entry[3], nil, nil, nil, true } } }) end
    syncs[#syncs + 1] = function()
        local live = Live(key)
        check:SetChecked(ns.db[key] == true)
        check:SetEnabled(live)
        text:SetTextColor(live and 1 or 0.5, live and 1 or 0.5, live and 1 or 0.5)
    end
    return check, CHECK_H + 4 + text:GetStringWidth()
end

-- The rows the package's list groups under one check list (checks = name), in list order.
local function Group(name)
    local list = {}
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.checks == name and not (entry.hideIf and entry.hideIf()) then list[#list + 1] = entry end
    end
    return list
end

-- Checks side by side from x at y, each as wide as the widest. Returns the row's width.
local function Inline(host, entries, x, y)
    local made, widest = {}, 0
    for i, entry in ipairs(entries) do
        local check, w = Check(host, entry)
        made[i], widest = check, math.max(widest, w)
    end
    for i, check in ipairs(made) do check:SetPoint("TOPLEFT", host, "TOPLEFT", x + (i - 1) * (widest + GAP), y) end
    return x + #made * (widest + GAP)
end

local function Heading(host, text, y)
    local head = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
    head:SetText(text)
    return head:GetStringHeight()
end

-- The settings, top down: the looks, Textured color and its parts, the themed parts in columns, the background shade,
-- the elite and nameplate dragons, the minimap button. Built once, shown in our window or the game's AddOns list.
local function Content()
    byKey = {}
    for _, entry in ipairs(ns.TOGGLES) do byKey[entry[1]] = entry end
    local host = ns.NewFrame("Frame", nil, UIParent)
    local h, need = LookRows(host, 0, "FallensUIColorPickerSet")
    local y = -h - 6
    if byKey.themeTextured then
        local check, cw = Check(host, byKey.themeTextured)
        check:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
        need = math.max(need, cw)
        y = y - CHECK_H
        need = math.max(need, Inline(host, Group("texturedParts"), 24, y))
        y = y - CHECK_H - GAP
    end
    y = y - Heading(host, L["OPT_DROP_THEMED"], y) - 6
    local parts, partW, made = Group("themeParts"), 0, {}
    for i, entry in ipairs(parts) do
        local check, cw = Check(host, entry)
        made[i], partW = check, math.max(partW, cw)
    end
    local cols = 3
    for i, check in ipairs(made) do
        local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
        check:SetPoint("TOPLEFT", host, "TOPLEFT", col * (partW + GAP), y - line * CHECK_H)
    end
    need = math.max(need, cols * (partW + GAP))
    y = y - math.ceil(#made / cols) * CHECK_H - GAP
    if ns.PACKAGE and ns.PACKAGE.broad then
        local head, row = O.PaneRow(host, SLIDER_W + 140)
        head:SetPoint("TOPLEFT", host, "TOPLEFT", -4, y)
        row:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
        syncs[#syncs + 1] = function() row:SetEnabled(ns.db.bronzeTheme == true) end
        y = y - 48 - GAP
    end
    if byKey.themeIgnoreElite then
        local check, cw = Check(host, byKey.themeIgnoreElite)
        check:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
        need = math.max(need, Inline(host, Group("themeIgnoreEliteFrames"), cw + GAP, y))
        y = y - CHECK_H
    end
    for _, key in ipairs({ "themeIgnorePlateDragon", "minimapButton" }) do
        if byKey[key] then
            local check, cw = Check(host, byKey[key])
            check:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
            need, y = math.max(need, cw), y - CHECK_H
        end
    end
    host:SetSize(need, -y)
    return host
end

-- Our content into a holder at its top left.
local function Hold(holder, x, y)
    content = content or Content()
    content:SetParent(holder)
    ns.SetPointOnce(content, "TOPLEFT", holder, "TOPLEFT", x, y)
    content:Show()
    SyncAll()
end

-- The game's own window: its title, close button and Escape, draggable.
local function Window(name)
    local frame = ns.NewFrame("Frame", name, UIParent, "DefaultPanelFlatTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    ns.MakeDraggable(frame)
    frame:Hide()
    frame.TitleContainer.TitleText:SetText(O.TITLE)
    local close = ns.NewFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    ns.CloseOnEscape(frame, function() frame:Hide() end)
    return frame
end

local function DoneButton(frame)
    local done = ns.NewFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetText(_G.DONE or "Done")
    done:SetSize(math.max(90, done:GetFontString():GetStringWidth() + 30), 22)
    done:SetScript("OnClick", function() frame:Hide() end)
    return done
end

-- The first login's pick: the looks, where to change them later, Done on a line of its own.
local function BuildPick()
    local frame = Window("FallensUIColorPickerLookPick")
    local looks = ns.NewFrame("Frame", nil, frame)
    looks:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -30)
    local h, need = LookRows(looks, 0, "FallensUIColorPickerLook")
    local width = math.max(280, need + 2 * PAD)
    looks:SetSize(width - 2 * PAD, h)
    frame:SetWidth(width)
    -- Its width now: a text measured before its anchored width exists is cut to one line.
    local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("TOPLEFT", looks, "BOTTOMLEFT", 0, -12)
    foot:SetWidth(width - 2 * PAD)
    foot:SetJustifyH("LEFT")
    foot:SetSpacing(2)
    foot:SetText(L["LOOKPICK_FOOT"]:format(ns.SLASH))
    local done = DoneButton(frame)
    done:SetPoint("TOPRIGHT", foot, "BOTTOMRIGHT", 4, -10)
    frame:SetHeight(30 + h + 12 + foot:GetStringHeight() + 10 + 22 + 14)
    frame:SetScript("OnShow", SyncAll)
    return frame
end

local function BuildSettings()
    local frame = Window("FallensUIColorPickerSettings")
    content = content or Content()
    frame:SetSize(content:GetWidth() + 2 * PAD, 30 + content:GetHeight() + 14 + 22 + 14)
    DoneButton(frame):SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD + 4, 14)
    frame:SetScript("OnShow", function() Hold(frame, PAD, -30) end)
    return frame
end

function ns.ShowLookPick()
    pick = pick or BuildPick()
    pick:Show()
end

if PICKER then
    -- Every way into the full addon's options opens these settings instead.
    local function ShowSettings()
        settings = settings or BuildSettings()
        settings:SetShown(not settings:IsShown())
    end
    ns.OpenOptions, ns.OpenOptionsAt, ns.OpenOptionsRow = ShowSettings, ShowSettings, ShowSettings
    -- The game's AddOns list shows the same content on its page.
    function ns.PickerCanvas()
        canvas = canvas or ns.NewFrame("Frame", nil, UIParent)
        canvas:SetScript("OnShow", function(self) Hold(self, 16, -16) end)
        return canvas
    end
end
