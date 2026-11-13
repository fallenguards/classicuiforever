local _, ns = ...
local L = ns.L

-- The raid manager at the left edge in Era's look (its Classic CompactRaidFrameManager): the raid panel border over
-- rock, the members header, silver buttons, the 1.x target icons and toggle tab. Every control is still the game's
-- own, moved and dressed; what Era lacked (the party or raid pick, ping limits, leave buttons, clear all) wears it too.

local UF = ns.UF
local STATES = ns.KEYS.STATES
local IsSecret = ns.IsSecret
local IsRaidMarkerActive, GetRaidTargetIndex = _G.IsRaidMarkerActive, _G.GetRaidTargetIndex
local SetPointIf, SetSizeIf, SetAlphaIf, SetShownIf = ns.SetPointIf, ns.SetSizeIf, ns.SetAlphaIf, ns.SetShownIf

local RAID_ART, BUTTONS = "Interface\\RaidFrame\\", "Interface\\Buttons\\"
local EDGE_TOP, EDGE_BOTTOM = RAID_ART .. "RaidPanel-UpperMiddle", RAID_ART .. "RaidPanel-BottomMiddle"
local SILVER, SILVER_GLOW = BUTTONS .. "UI-Silver-Button-Up", BUTTONS .. "UI-Silver-Button-Highlight"
local YELLOW = BUTTONS .. "UI-Panel-Button-YellowHighlight"
local ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CHECK = ns.ART.CHECK

-- Era's spots: 200 wide, 140 down, open at -7 and shut at -182 (its right edge and the toggle stay on screen).
local PANEL_W, OPEN_X, SHUT_X, PANEL_Y = 200, -7, -182, -140
-- Its rows from 10 left of the panel, 29 down (under the header line); the panel ends 11 under the last row.
local ROW_X, FIRST_Y, FOOT = -10, -29, 11
-- The old panel's icon slots by marker number, star to skull: five, then three, its X at the end; the game's
-- clear-all between them.
local MARK_SPOTS = { { 25, 0 }, { 57, 0 }, { 89, 0 }, { 121, 0 }, { 153, 0 }, { 25, -26 }, { 57, -26 }, { 89, -26 } }
local REMOVE_SPOT, RESET_SPOT = { 153, -26 }, { 121, -26 }
-- UIMenuButtonStretchTemplate's nine pieces of its 64x32 sheet: key, left, right, top, bottom.
local SILVER_PIECES = {
    { "TL", 0, 0.09375, 0, 0.1875 }, { "TR", 0.53125, 0.625, 0, 0.1875 },
    { "BL", 0, 0.09375, 0.625, 0.8125 }, { "BR", 0.53125, 0.625, 0.625, 0.8125 },
    { "TM", 0.09375, 0.53125, 0, 0.1875 }, { "BM", 0.09375, 0.53125, 0.625, 0.8125 },
    { "ML", 0, 0.09375, 0.1875, 0.625 }, { "MR", 0.53125, 0.625, 0.1875, 0.625 },
    { "MM", 0.09375, 0.53125, 0.1875, 0.625 },
}
local EVENTS = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_ACTIVE_BATTLEFIELD",
    "PLAYER_ROLES_ASSIGNED", "PLAYER_DIFFICULTY_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "CVAR_UPDATE" }
-- Divider lines hang on the manager, not on the part collapsing hides.
local DIVIDER_POOLS = { "dividerHorizontalPool", "dividerVerticalPool" }

local era = { on = false, labels = {}, icons = {}, placed = {}, lit = {}, small = setmetatable({}, { __mode = "k" }) }

local function SetStateAlpha(tex, _, alpha) tex:SetAlpha(alpha) end

-- The client's hover repaint (SetAtlas) keeps the alpha, so its art stays hidden without a hook.
local function FadeStates(button)
    ns.EachState(button, STATES, SetStateAlpha, 0)
end

local function FileTex(owner, key, layer, sublevel, path, tiled)
    local tex = ns.OwnTexture(owner, key, layer, sublevel)
    if tiled then
        ns.SetFile(tex, path, "REPEAT", "REPEAT")
        if tiled == "h" then tex:SetHorizTile(true) else tex:SetVertTile(true) end
    else
        ns.SetFile(tex, path)
    end
    return tex
end

local function Corner(manager, key, file, point, x)
    local tex = FileTex(manager, key, "ARTWORK", 0, RAID_ART .. file)
    tex:SetSize(32, 32)
    tex:SetPoint(point, manager, point, x, 0)
    return tex
end

-- Era's border and rock, on the manager itself: its right edge shows while shut.
local function PanelArt(manager)
    local tl = Corner(manager, "eraTL", "RaidPanel-UpperLeft", "TOPLEFT", -5)
    local tr = Corner(manager, "eraTR", "RaidPanel-UpperRight", "TOPRIGHT", 0)
    local bl = Corner(manager, "eraBL", "RaidPanel-BottomLeft", "BOTTOMLEFT", -5)
    local br = Corner(manager, "eraBR", "RaidPanel-BottomRight", "BOTTOMRIGHT", 0)
    local top = FileTex(manager, "eraTop", "ARTWORK", 0, EDGE_TOP, "h")
    top:SetHeight(16)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 1)
    top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 1)
    local bottom = FileTex(manager, "eraBottom", "ARTWORK", 0, EDGE_BOTTOM, "h")
    bottom:SetHeight(16)
    bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, -4)
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, -4)
    local right = FileTex(manager, "eraRight", "ARTWORK", 0, RAID_ART .. "RaidPanel-Right", "v")
    right:SetWidth(16)
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 2, 0)
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 2, 0)
    -- Era's rock, our copy: Forever's file of that name is another stone.
    local rock = ns.TileTex(ns.OwnTexture(manager, "eraRock", "BACKGROUND", 0), "rockBg")
    rock:SetPoint("TOPLEFT", tl, "TOPLEFT", 7, -6)
    rock:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", -7, 7)
    era.edge = { tl, tr, bl, br, top, bottom, right, rock }
end

-- The header: a dark band, the members label, the line under it. Shown with the open panel (Relay).
local function HeaderArt(manager)
    local band = ns.OwnTexture(manager, "eraBand", "ARTWORK", 1)
    band:SetColorTexture(0, 0, 0, 0.93)
    band:SetHeight(17)
    band:SetPoint("TOPLEFT", manager, "TOPLEFT", 7, -6)
    band:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -9, -6)
    local line = FileTex(manager, "eraLine", "ARTWORK", 2, EDGE_TOP, "h")
    line:SetHeight(12)
    line:SetPoint("TOPLEFT", manager, "TOPLEFT", 0, -21)
    line:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -9, -21)
    local label = ns.OwnFontString(manager, "eraLabel", "OVERLAY", "GameFontNormalMed3")
    label:SetPoint("TOPLEFT", manager, "TOPLEFT", 10, -8)
    era.header = { band, line, label }
    era.label = label
end

-- Era's silver button round one of the game's: nine pieces, the glow, and our label unless an icon stands in.
local function Silver(button, text)
    local pieces = {}
    for _, spec in ipairs(SILVER_PIECES) do
        local tex = FileTex(button, "silver" .. spec[1], "BACKGROUND", 1, SILVER)
        tex:SetTexCoord(spec[2], spec[3], spec[4], spec[5])
        pieces[spec[1]] = tex
    end
    for _, key in ipairs({ "TL", "TR", "BL", "BR" }) do pieces[key]:SetSize(12, 6) end
    pieces.TL:SetPoint("TOPLEFT")
    pieces.TR:SetPoint("TOPRIGHT")
    pieces.BL:SetPoint("BOTTOMLEFT")
    pieces.BR:SetPoint("BOTTOMRIGHT")
    pieces.TM:SetPoint("TOPLEFT", pieces.TL, "TOPRIGHT")
    pieces.TM:SetPoint("BOTTOMRIGHT", pieces.TR, "BOTTOMLEFT")
    pieces.BM:SetPoint("TOPLEFT", pieces.BL, "TOPRIGHT")
    pieces.BM:SetPoint("BOTTOMRIGHT", pieces.BR, "BOTTOMLEFT")
    pieces.ML:SetPoint("TOPRIGHT", pieces.TL, "BOTTOMRIGHT")
    pieces.ML:SetPoint("BOTTOMLEFT", pieces.BL, "TOPLEFT")
    pieces.MR:SetPoint("TOPRIGHT", pieces.TR, "BOTTOMRIGHT")
    pieces.MR:SetPoint("BOTTOMLEFT", pieces.BR, "TOPLEFT")
    pieces.MM:SetPoint("TOPLEFT", pieces.TL, "BOTTOMRIGHT")
    pieces.MM:SetPoint("BOTTOMRIGHT", pieces.BR, "TOPLEFT")
    local glow = FileTex(button, "silverGlow", "HIGHLIGHT", 0, SILVER_GLOW)
    glow:SetTexCoord(0, 1, 0.03, 0.7175)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(button)
    if text == nil then return end
    local label = ns.OwnFontString(button, "eraText", "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, -1)
    label:SetText(text)
    era.labels[button] = label
end

-- The game's icon button as one of Era's text ones.
local function TextButton(button, text)
    if not button then return end
    if button.GetNormalTexture and button:GetNormalTexture() then button:GetNormalTexture():SetAlpha(0) end
    for _, key in ipairs({ "Background", "Arrow", "Text" }) do
        if button[key] then button[key]:SetAlpha(0) end
    end
    Silver(button, text or "")
end

-- The filters' yellow lit face when picked, Era's small white text, the game's tertiary art faded.
local function FilterButton(button)
    FadeStates(button)
    Silver(button)
    local lit = FileTex(button, "eraLit", "OVERLAY", 0, YELLOW)
    lit:SetTexCoord(0, 0.625, 0, 0.6875)
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.7)
    lit:SetAllPoints(button)
    era.lit[button] = lit
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
end

-- Era's filter block: roles 58 wide from 19 in and 4 up, the groups 41 wide in two rows of four under them.
local function Filters(filters)
    local tank, healer, damager = filters.filterRoleTank, filters.filterRoleHealer, filters.filterRoleDamager
    for _, button in ipairs({ tank, healer, damager }) do
        FilterButton(button)
        button:SetSize(58, 24)
    end
    ns.SetPointOnce(tank, "TOPLEFT", filters, "TOPLEFT", 19, 4)
    ns.SetPointOnce(healer, "LEFT", tank, "RIGHT", 0, 0)
    ns.SetPointOnce(damager, "LEFT", healer, "RIGHT", 0, 0)
    local groups = filters.filterGroupButtons or {}
    for i, button in ipairs(groups) do
        FilterButton(button)
        button:SetSize(41, 24)
        if i == 1 then
            ns.SetPointOnce(button, "TOPLEFT", tank, "BOTTOMLEFT", 0, 0)
        elseif i == 5 then
            ns.SetPointOnce(button, "TOPLEFT", groups[1], "BOTTOMLEFT", 0, 0)
        else
            ns.SetPointOnce(button, "LEFT", groups[i - 1], "RIGHT", 2, 0)
        end
    end
    local foot = FileTex(filters, "eraFoot", "BACKGROUND", 0, EDGE_TOP, "h")
    foot:SetHeight(12)
    foot:SetPoint("BOTTOMLEFT", filters, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", filters, "BOTTOMRIGHT", 2, 0)
end

local function IconCoords(tex, index)
    local left = ((index - 1) % 4) * 0.25
    local top = math.floor((index - 1) / 4) * 0.25
    tex:SetTexCoord(left, left + 0.25, top, top + 0.25)
end

-- One of the game's marker buttons at an Era slot, its own art faded under ours.
local function MarkButton(marks, button, spot, file, index)
    if not button then return end
    button:SetSize(24, 24)
    ns.SetPointOnce(button, "TOPLEFT", marks, "TOPLEFT", spot[1], spot[2])
    if button.backgroundTexture then button.backgroundTexture:SetAlpha(0) end
    if button.markerTexture then button.markerTexture:SetAlpha(0) end
    local icon = FileTex(button, "eraIcon", "ARTWORK", 1, file)
    icon:SetAllPoints(button)
    if index then IconCoords(icon, index) end
    era.icons[button] = icon
    if not index then return end
    local placed = FileTex(button, "eraPlaced", "OVERLAY", 2, CHECK .. "Check")
    placed:SetSize(16, 16)
    placed:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 5, -5)
    era.placed[button] = placed
end

local function Tip(button, text)
    ns.Sched.OnHover(button, function(over)
        if over then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(type(text) == "function" and text() or text)
            GameTooltip:Show()
        elseif GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)
end

local function Ground(marks)
    return marks.activeTab ~= nil and marks.activeTab == marks.raidMarkerGroundTab
end

-- Era's icons for unit markers; its world marker button switches them to the ground and the lit one back.
local function Markers(marks)
    if marks.BG then marks.BG:SetAlpha(0) end
    for i = 1, 8 do
        local button = marks["raidMarker" .. i]
        if button then MarkButton(marks, button, MARK_SPOTS[button:GetID()], ICONS, button:GetID()) end
    end
    MarkButton(marks, marks.raidMarkerRemove, REMOVE_SPOT, BUTTONS .. "UI-GroupLoot-Pass-Up")
    -- A flat arrow: the refresh button's file is a ring with arrows on it, which read as two icons.
    MarkButton(marks, marks.raidMarkerReset, RESET_SPOT, "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo")
    if marks.raidMarkerReset then
        Tip(marks.raidMarkerReset, function()
            return Ground(marks) and L["RAIDMGR_CLEAR_GROUND"] or L["RAIDMGR_CLEAR_TARGETS"]
        end)
    end
    for _, tab in ipairs({ marks.raidMarkerGroundTab, marks.raidMarkerUnitTab }) do
        TextButton(tab)
        -- Its Unit or Ground word, cleared: a fade did not hold through the game's re-font on every switch.
        tab:SetText("")
        local ping = FileTex(tab, "eraPing", "ARTWORK", 1, RAID_ART .. "Raid-WorldPing")
        ping:SetSize(14, 14)
        ping:SetPoint("CENTER", tab, "CENTER", 0, -1)
    end
    local lit = FileTex(marks.raidMarkerUnitTab, "eraLit", "OVERLAY", 0, YELLOW)
    lit:SetTexCoord(0, 0.625, 0, 0.6875)
    lit:SetBlendMode("ADD")
    lit:SetAllPoints(marks.raidMarkerUnitTab)
    Tip(marks.raidMarkerGroundTab, L["RAIDMGR_MARK_GROUND"])
    Tip(marks.raidMarkerUnitTab, L["RAIDMGR_MARK_TARGET"])
end

-- Era's checkbox with its label at the right, the label clickable too.
local function AssistCheck(check)
    if not check then return end
    FadeStates(check)
    check:SetSize(24, 24)
    check:SetCheckedTexture(CHECK .. "Check")
    check:SetDisabledCheckedTexture(CHECK .. "Check-Disabled")
    local box = FileTex(check, "eraBox", "BACKGROUND", 1, CHECK .. "Up")
    box:SetAllPoints(check)
    local glow = FileTex(check, "eraGlow", "HIGHLIGHT", 0, CHECK .. "Highlight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(check)
    local label = ns.OwnFontString(check, "eraText", "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", -2, 1)
    label:SetText(_G.ALL_ASSIST_LABEL_LONG or _G.CRF_ALL_ASSIST or "")
    check:SetHitRectInsets(0, -140, 0, 0)
    era.assistLabel = label
end

local function ToggleTab(button, left)
    if not button then return end
    FadeStates(button)
    local tex = FileTex(button, "eraToggle", "OVERLAY", 1, RAID_ART .. "RaidPanel-Toggle")
    tex:SetAllPoints(button)
    tex:SetTexCoord(left, left + 0.5, 0, 1)
end

-- Shut with the edge off: the look before the Era panel, the game's back tab turned over (flat side on the screen
-- edge, arrow right) at the open one's spot. Forever maps the atlas to a bronze copy; the mainline sheet keeps the grey
-- rim and gold arrow.
local SMALL_TAB = { "gm-btnback-normal", "gm-btnback-hover" }
local MAINLINE_TAB_SHEET = 5524935
local MAINLINE_TAB = {
    ["gm-btnback-normal"] = { 449, 465, 986, 1021 },
    ["gm-btnback-hover"] = { 449, 465, 949, 984 },
}
-- The game's tab: 16x35, 7 in from the panel's right, on its middle as Era's open toggle (no jump on a switch); the
-- panel's right edge 22 in, as the game's 222-wide panel shut at -200.
local SMALL_W, SMALL_H, SMALL_X, SMALL_Y, SMALL_SHUT_X = 16, 35, -7, 0, 22 - PANEL_W

local function MainlineTab(tex, atlas)
    local px = MAINLINE_TAB[atlas]
    if not px or tex:SetTexture(MAINLINE_TAB_SHEET) == false then return false end
    tex:SetTexCoord(px[2] / 1024, px[1] / 1024, px[3] / 1024, px[4] / 1024)
    return true
end

-- Theme on: Forever's bronze tab (drained to the theme unless it shows client art); off: the mainline one, or the
-- bronze drained when that sheet is missing.
local function MirroredAtlas(tex, atlas)
    local look = ns.ThemeLook(true, "themePartUnits")
    ns.UndrainBronze(tex)
    if look == "classic" and MainlineTab(tex, atlas) then return true end
    local info = look ~= "classic" and C_Texture.GetAtlasInfo(atlas .. "-c60") or C_Texture.GetAtlasInfo(atlas)
    if not info or not info.file then return false end
    tex:SetTexture(info.file)
    tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
    if look ~= "client" then ns.DrainBronze(tex) end
    return true
end

-- Painted on each switch to it, so a theme change since shows.
local function SmallTab(button, small)
    local face = ns.OwnTexture(button, "smallTab", "BACKGROUND", 0)
    local glow = ns.OwnTexture(button, "smallTabGlow", "HIGHLIGHT", 0)
    local eraTab = button.fcui and button.fcui.eraToggle
    if small and era.small[button] ~= true then
        face:SetAllPoints(button)
        glow:SetAllPoints(button)
        if not MirroredAtlas(glow, SMALL_TAB[2]) then glow:SetColorTexture(1, 1, 1, 0.12) end
        small = MirroredAtlas(face, SMALL_TAB[1])
    end
    if era.small[button] == small then return end
    era.small[button] = small
    face:SetShown(small)
    glow:SetShown(small)
    if eraTab then eraTab:SetShown(not small) end
end

local LEAVE_BUTTONS = { "CompactRaidFrameManagerLeavePartyButton", "CompactRaidFrameManagerLeaveInstanceGroupButton" }

local function Dress(manager)
    local d = manager.displayFrame
    PanelArt(manager)
    HeaderArt(manager)
    if d.label then d.label:SetAlpha(0) end
    if d.settings then
        -- The info button opens the same raid frame settings, as Era's.
        d.settings:SetAlpha(0)
        d.settings:EnableMouse(false)
    end
    TextButton(d.readyCheckButton, _G.READY_CHECK or _G.CRF_READY_CHECK)
    TextButton(d.countdownButton, _G.CRF_COUNTDOWN)
    TextButton(d.rolePollButton, _G.ROLE_POLL or _G.CRF_ROLE_POLL)
    -- The old panel's Unlock: the game's button opens edit mode, where the raid frames move.
    TextButton(d.editMode, _G.UNLOCK or _G.EDIT)
    TextButton(d.hiddenModeToggle)
    TextButton(d.ModeControlDropdown)
    TextButton(d.difficulty, _G.DIFFICULTY or _G.CRF_DIFFICULTY)
    AssistCheck(d.everyoneIsAssistButton)
    if d.filterOptions then Filters(d.filterOptions) end
    if d.raidMarkers then Markers(d.raidMarkers) end
    if d.RestrictPingsLabel then d.RestrictPingsLabel:SetFontObject("GameFontNormalSmall") end
    if d.RestrictPingsDropdown then ns.EraDropdownArt(d.RestrictPingsDropdown, -1, -1, -24) end
    for _, name in ipairs(LEAVE_BUTTONS) do
        local button = _G[name]
        if button then
            ns.SkinRedButton(button)
            button:SetSize(169, 22)
        end
    end
    ToggleTab(manager.toggleButtonForward, 0)
    ToggleTab(manager.toggleButtonBack, 0.5)
end

-- In a fight a locked piece keeps the game's spot until the fight ends.
local function Locked(frame)
    return era.fight and frame.IsProtected ~= nil and (frame:IsProtected()) == true
end

local function At(frame, x, y, w, h)
    if not frame or Locked(frame) then return end
    SetPointIf(frame, "TOPLEFT", CompactRaidFrameManager, "TOPLEFT", x, y)
    if w then SetSizeIf(frame, w, h) end
end

local function Shown(frame) return frame ~= nil and frame:IsShown() end

local function Leaving()
    return Shown(_G[LEAVE_BUTTONS[1]]) or Shown(_G[LEAVE_BUTTONS[2]])
end

-- The old panel's rows top down, each where the last ended; the game's extras under them in the same column.
local function LayRows(manager, d)
    local x, y = ROW_X, FIRST_Y
    local marks = d.raidMarkers
    if Shown(d.filterOptions) then
        At(d.filterOptions, x, y - 4, 200, 85)
        y = y - 89
    end
    local world = Shown(marks)
    if world then
        At(marks, x, y, 200, 50)
        y = y - 50
    end
    if Shown(d.rolePollButton) then
        At(d.rolePollButton, x + 20, y - 5, 169, 20)
        y = y - 25
    end
    if Shown(d.readyCheckButton) or world then
        if Shown(d.readyCheckButton) then At(d.readyCheckButton, x + 20, y, 129, 20) end
        if world then
            At(marks.raidMarkerGroundTab, x + 149, y, 40, 20)
            At(marks.raidMarkerUnitTab, x + 149, y, 40, 20)
        end
        y = y - 20
    end
    if Shown(d.ModeControlDropdown) then
        At(d.ModeControlDropdown, x + 20, y, 169, 20)
        y = y - 20
    end
    if Shown(d.editMode) or Shown(d.hiddenModeToggle) then
        At(d.editMode, x + 20, y, 85, 20)
        At(d.hiddenModeToggle, x + 105, y, 85, 20)
        y = y - 20
    end
    if Shown(d.everyoneIsAssistButton) then
        At(d.everyoneIsAssistButton, x + 20, y, 24, 24)
        y = y - 24
    end
    for _, button in ipairs({ d.countdownButton, d.difficulty }) do
        if Shown(button) then
            At(button, x + 20, y, 169, 20)
            y = y - 20
        end
    end
    if Shown(d.RestrictPingsDropdown) then
        At(d.RestrictPingsLabel, x + 20, y - 6, 169, 12)
        At(d.RestrictPingsDropdown, x + 28, y - 22, 150, 24)
        y = y - 48
    end
    if Leaving() then
        At(manager.BottomButtons, x + 20, y - 6, 169, 49)
        y = y - 55
    end
    return y
end

local function Font(label, on, normal, off)
    local font = on and normal or off
    if era.fonts[label] ~= font then
        era.fonts[label] = font
        label:SetFontObject(font)
    end
end

local function WorldPlaced(id)
    local order = _G.WORLD_RAID_MARKER_ORDER
    local marker = order and order[9 - id]
    if not marker or not IsRaidMarkerActive then return false end
    local active = IsRaidMarkerActive(marker)
    return not IsSecret(active) and active == true
end

-- What the game changes as it goes: labels, picked filters, icon states, which marker button shows.
local function Mirror(d)
    era.label:SetText(IsInRaid() and (_G.RAID_MEMBERS or _G.RAID) or (_G.PARTY_MEMBERS or _G.PARTY))
    local hide = era.labels[d.hiddenModeToggle]
    if hide then hide:SetText(d.hiddenModeToggle.shownMode and _G.SHOW or _G.HIDE) end
    local mode = era.labels[d.ModeControlDropdown]
    if mode then mode:SetText(IsInRaid() and (_G.CONVERT_TO_PARTY or _G.PARTY) or (_G.CONVERT_TO_RAID or _G.RAID)) end
    for button, label in pairs(era.labels) do
        Font(label, button:IsEnabled(), "GameFontHighlightSmall", "GameFontDisableSmall")
    end
    if era.assistLabel then
        Font(era.assistLabel, d.everyoneIsAssistButton:IsEnabled(), "GameFontNormalSmall", "GameFontDisableSmall")
    end
    for button, lit in pairs(era.lit) do
        SetShownIf(lit, button.checked == true)
        SetAlphaIf(button, button:IsEnabled() and 1 or 0.5)
    end
    local marks = d.raidMarkers
    if not marks then return end
    local ground = Ground(marks)
    SetShownIf(marks.raidMarkerGroundTab, not ground)
    SetShownIf(marks.raidMarkerUnitTab, ground)
    local picked = GetRaidTargetIndex("target")
    if IsSecret(picked) then picked = nil end
    for button, icon in pairs(era.icons) do
        local placed = era.placed[button]
        local dim = not button:IsEnabled() or (not ground and placed ~= nil and button:GetID() == picked)
        icon:SetDesaturated(dim)
        SetAlphaIf(icon, dim and 0.7 or 1)
        if placed then SetShownIf(placed, ground and WorldPlaced(button:GetID())) end
    end
end

local function FadeDividers(manager, alpha)
    for _, key in ipairs(DIVIDER_POOLS) do
        local pool = manager[key]
        if pool and pool.EnumerateActive then
            for tex in pool:EnumerateActive() do ns.SetAlphaIf(tex, alpha) end
        end
    end
end

-- After each of the game's passes (its events, its toggle, a resize, the open panel's beat): our spots and states.
local function Relay()
    local manager = CompactRaidFrameManager
    if not (era.on and manager and manager:IsShown()) then return end
    local d = manager.displayFrame
    local shut = manager.collapsed and true or false
    if manager.Background then SetAlphaIf(manager.Background, 0) end
    FadeDividers(manager, 0)
    local edge = not shut or ns.db.raidManagerEdge == true
    local small = shut and not edge
    local spot = small and SMALL_SHUT_X or shut and SHUT_X or OPEN_X
    -- In a fight the panel is locked: the game's toggle and its row layout still run, so its size and spot wait for
    -- the fight's end while every piece that is not locked goes to its spot now, the tabs by where the panel sits.
    era.fight = InCombatLockdown()
    local held = Locked(manager)
    local off = 0
    if held then
        local left = manager:GetLeft()
        if left and not IsSecret(left) then off = spot - left end
        ns.WhenCalm("raidManager.relay", Relay)
    else
        SetSizeIf(manager, PANEL_W, manager:GetHeight())
        SetPointIf(manager, "TOPLEFT", UIParent, "TOPLEFT", spot, PANEL_Y)
    end
    for _, region in ipairs(era.header) do SetShownIf(region, not shut) end
    for _, region in ipairs(era.edge) do SetShownIf(region, edge) end
    for _, button in ipairs({ manager.toggleButtonForward, manager.toggleButtonBack }) do
        if not Locked(button) then
            SetPointIf(button, "RIGHT", manager, "RIGHT", (small and SMALL_X or -9) + off, small and SMALL_Y or 0)
            SetSizeIf(button, small and SMALL_W or 16, small and SMALL_H or 64)
        end
    end
    SmallTab(manager.toggleButtonForward, small)
    SetPointIf(d.memberCountLabel, "TOPRIGHT", manager, "TOPRIGHT", -28, -8)
    local info = _G.CompactRaidFrameManagerDisplayFrameOptionsButton
    if info then SetPointIf(info, "TOPRIGHT", manager, "TOPRIGHT", -9, -7) end
    -- Shut too: the panel keeps its height, and the leave buttons (outside the part shutting hides) go with it.
    local height = -LayRows(manager, d) + FOOT
    if not held then SetSizeIf(manager, PANEL_W, height) end
    if shut then
        if not Locked(manager.BottomButtons) then SetShownIf(manager.BottomButtons, false) end
        return
    end
    Mirror(d)
end

local relayFrame
local function EraOn(manager)
    era.on = true
    UF.taken.raidManager = true
    if ns.Once(manager, "eraPanel") then
        era.fonts = setmetatable({}, { __mode = "k" })
        Dress(manager)
        relayFrame = ns.EventFrame(EVENTS, Relay)
        -- The game's own passes we hear no event for: its resize, a marker tab's width, its toggle.
        ns.Sched.OnMove(manager, Relay)
        local marks = manager.displayFrame.raidMarkers
        if marks then
            ns.Sched.OnMove(marks.raidMarkerGroundTab, Relay)
            ns.Sched.OnMove(marks.raidMarkerUnitTab, Relay)
        end
        ns.Sched.AfterShow(manager.toggleButtonForward, "raidManager.shut", Relay)
        ns.Sched.AfterShow(manager.toggleButtonBack, "raidManager.open", Relay)
        ns.Sched.Attach(manager.displayFrame, { name = "raidManager.era", every = 0.2, fn = Relay })
    elseif relayFrame then
        ns.RegisterEvents(relayFrame, EVENTS)
    end
    Relay()
end

-- Our art stays until a reload; the game's own passes lay it out again from now.
local function EraOff()
    if not era.on then return end
    era.on = false
    UF.taken.raidManager = nil
    if relayFrame then relayFrame:UnregisterAllEvents() end
    ns.needsReload = true
end

-- Party and raid group borders wear Forever's bronze frame: drained silver without the theme.
local GROUP_FRAMES = { "CompactPartyFrame" }
for i = 1, 8 do GROUP_FRAMES[#GROUP_FRAMES + 1] = "CompactRaidGroup" .. i end
-- The flat raid container's border is its own grey file: silver off, tinted bronze on.
local CONTAINER_BORDER = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right" }
local CONTAINER_PREFIX = "CompactRaidFrameContainerBorderFrameBorder"

local bordersSeen = {}
local bordersLeft = #GROUP_FRAMES + 1
local drainedBorders = setmetatable({}, { __mode = "k" })
local tintedBorders = setmetatable({}, { __mode = "k" })

-- Texture calls only, so groups made mid-fight are dressed on the next beat. Groups not made yet cost one lookup.
local function WatchGroupBorders()
    if bordersLeft == 0 then return end
    for i = 1, #GROUP_FRAMES do
        local name = GROUP_FRAMES[i]
        local group = not bordersSeen[name] and _G[name]
        local bg = group and ns.Path(group, "borderFrame", "Background")
        if bg then
            bordersSeen[name] = true
            bordersLeft = bordersLeft - 1
            drainedBorders[bg] = true
            ns.DrainBronze(bg)
        end
    end
    if not bordersSeen.container and _G[CONTAINER_PREFIX .. CONTAINER_BORDER[1]] then
        bordersSeen.container = true
        bordersLeft = bordersLeft - 1
        for i = 1, #CONTAINER_BORDER do
            local tex = _G[CONTAINER_PREFIX .. CONTAINER_BORDER[i]]
            if tex then
                tintedBorders[tex] = true
                ns.BronzeTint(tex, nil, true)
            end
        end
    end
end

local function PlainGroupBorders()
    for bg in pairs(drainedBorders) do ns.UndrainBronze(bg) end
    for tex in pairs(tintedBorders) do ns.UntintBronze(tex) end
    wipe(drainedBorders)
    wipe(tintedBorders)
    wipe(bordersSeen)
    bordersLeft = #GROUP_FRAMES + 1
end

-- Era's panel with our unit frames on, unless the theme shows the game's art or the gamepad drives the panel.
local function LayoutRaidManager()
    if not UF.active then PlainGroupBorders() end
    local manager = CompactRaidFrameManager
    if not manager then return end
    if UF.active and ns.ThemeLook(true, "themePartUnits") ~= "client" and not ns.GamepadUI() then
        EraOn(manager)
    else
        EraOff()
    end
end

-- Watched, not hooked: the game's passes over the manager also set up the raid frames.
local function WatchRaidManager()
    WatchGroupBorders()
    if era.on then Relay() elseif UF.active and CompactRaidFrameManager then LayoutRaidManager() end
end

UF.LayoutRaidManager, UF.WatchRaidManager, UF.SkinRaidManager = LayoutRaidManager, WatchRaidManager, LayoutRaidManager

-- The options pass waits out a fight: the closed panel's edge answers at once.
ns.OnToggle(function(key)
    if key == "raidManagerEdge" then Relay() end
end)
