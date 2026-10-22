local _, ns = ...
local L = ns.L

-- The Profiles page: the character's profile picked from a list, plus new, copy, rename and delete (Core/Profiles.lua),
-- and the classic edit mode layout.

local O = ns.options
local ROW = 24
local DEFAULT = ns.PROFILE_DEFAULT

local function Say(why)
    if why and UIErrorsFrame then UIErrorsFrame:AddMessage(why, 1, 0.1, 0.1) end
end

-- data: { mode = "new" | "copy" | "rename", old = name }. A refused name keeps the box open.
local ASK = {
    new = L["OPTWIN_NAME_THE_NEW_PROFILE_IT"],
    copy = L["OPTWIN_NAME_THE_NEW_PROFILE_IT_2"],
    rename = "A new name for the profile %s.",
}

local function Accept(dialog, data)
    local box = ns.PopupEditBox(dialog)
    local text = box and box:GetText()
    local name, why
    if data.mode == "rename" then
        name, why = ns.RenameProfile(data.old, text)
    else
        name, why = ns.NewProfile(text, data.mode == "copy")
    end
    if name then return false end
    Say(why)
    return true
end

ns.Popup("FCUI_PROFILE_NAME", {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 32,
    OnShow = function(self, data)
        local box = ns.PopupEditBox(self)
        if not box then return end
        box:SetText(data and data.old or "")
        box:HighlightText()
        box:SetFocus()
    end,
    OnAccept = Accept,
    EditBoxOnEnterPressed = function(self, data)
        local dialog = self:GetParent()
        if not Accept(dialog, data) then dialog:Hide() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
})

ns.Popup("FCUI_PROFILE_DELETE", {
    text = L["OPTWIN_DELETE_THE_PROFILE_X_CHARACTERS"],
    button1 = _G.DELETE or "Delete",
    button2 = CANCEL,
    OnAccept = function(_, data) ns.DeleteProfile(data) end,
})

local function AskName(mode, old)
    local text = mode == "rename" and ASK.rename:format(old) or ASK[mode]
    StaticPopup_Show("FCUI_PROFILE_NAME", text, nil, { mode = mode, old = old })
end

local function RowClick(self)
    self:SetChecked(self.name == ns.ProfileName())
    ns.UseProfile(self.name)
end

local BUTTONS = {
    { "New", "A new profile from the default settings, used by this character.", function() AskName("new") end },
    { "Copy", "A new profile from the settings in use now, used by this character.", function() AskName("copy") end },
    { L["OPTWIN_RENAME"], L["OPTWIN_RENAMES_THE_PROFILE_IN_USE"],
        function() AskName("rename", ns.ProfileName()) end, true },
    { L["OPTWIN_DELETE"], L["OPTWIN_DELETES_THE_PROFILE_IN_USE"],
        function() StaticPopup_Show("FCUI_PROFILE_DELETE", ns.ProfileName(), nil, ns.ProfileName()) end, true },
}

-- A second row: the profile in use as text, and a profile from such text (Options/ProfileText.lua).
local TEXT_BUTTONS = {
    { L["OPTWIN_EXPORT"], L["OPTWIN_EXPORT_TIP"], function() O.ShowProfileText("export") end },
    { L["OPTWIN_IMPORT"], L["OPTWIN_IMPORT_TIP"], function() O.ShowProfileText("import") end },
}

local function PageButton(pane, top, spec, x, y)
    local button = ns.PanelButton(pane, spec[1], 80)
    button:SetPoint("TOPLEFT", top, "TOPLEFT", x, y)
    button:SetScript("OnClick", spec[3])
    button.label, button.tooltip = spec[1], spec[2]
    ns.AttachTip(button, O.OPTION_TIP)
    return button
end

local function ClassicLayout()
    if ns.ClassicLayoutActive() then
        StaticPopup_Show("FCUI_LAYOUT_RESET")
    else
        ns.CreateClassicLayout()
    end
end

-- At the page's top (top): caption over the buttons; rows on their own scroll child that the page swaps into the list.
-- setRange(height) sizes the list's scroll bar.
function O.ProfilesPane(frame, top, list, setRange)
    local pane = ns.NewFrame("Frame", nil, frame)
    pane:SetAllPoints(frame)
    pane:Hide()
    pane.headH = 78
    local caption = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("TOPLEFT", top, "TOPLEFT", 2, 0)
    local child = ns.NewFrame("Frame", nil, list)
    child:SetSize(list:GetWidth(), 1)
    child:Hide()
    pane.child = child
    local rows, named = {}, {}
    local x = 0
    for _, spec in ipairs(BUTTONS) do
        local button = PageButton(pane, top, spec, x, -20)
        if spec[4] then named[#named + 1] = button end
        x = x + 84
    end
    for i, spec in ipairs(TEXT_BUTTONS) do PageButton(pane, top, spec, (i - 1) * 84, -46) end
    -- Not a profile's: the edit mode layout the bars stand in, at the row's end.
    local layout = ns.PanelButton(pane, L["OPTWIN_CLASSIC_LAYOUT"], 130)
    layout:SetPoint("TOPLEFT", top, "TOPLEFT", x + 16, -20)
    layout:SetScript("OnClick", ClassicLayout)
    layout.label, layout.tooltip = L["OPTWIN_CLASSIC_LAYOUT"], L["OPTWIN_ADDS_AN_EDIT_MODE_LAYOUT"]
    ns.AttachTip(layout, O.OPTION_TIP)

    local function Row(i)
        local row = rows[i]
        if row then return row end
        row = ns.NewFrame("CheckButton", nil, child)
        row:SetSize(24, 24)
        ns.DressStates(row, O.RADIO, nil, nil, O.RADIO, O.OPTION_RADIO)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row, "RIGHT", 2, 1)
        row:SetScript("OnClick", RowClick)
        ns.SetPointOnce(row, "TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW)
        rows[i] = row
        return row
    end

    function pane.Refresh()
        local names, current = ns.ProfileNames(), ns.ProfileName()
        for i, name in ipairs(names) do
            local row = Row(i)
            row.name = name
            row.text:SetText(name)
            row:SetChecked(name == current)
            row:Show()
        end
        for i = #names + 1, #rows do rows[i]:Hide() end
        child:SetHeight(math.max(1, #names * ROW))
        setRange(#names * ROW)
        local who = ns.Safe(UnitName("player"), nil) or L["OPTWIN_THIS_CHARACTER"]
        caption:SetText(("%s uses the profile |cffffd100%s|r."):format(who, current))
        for _, button in ipairs(named) do button:SetEnabled(current ~= DEFAULT) end
    end
    return pane
end
