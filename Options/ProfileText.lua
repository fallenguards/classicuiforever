local _, ns = ...
local L = ns.L

-- The Profiles page's Export and Import: one dialog with a text box, read-only with the profile's text to copy, or
-- open for a pasted one that Import turns into a profile (Core/ProfileText.lua).

local O = ns.options
local HEADER = { width = 300 }

local window

local function Say(why)
    if why and UIErrorsFrame then UIErrorsFrame:AddMessage(why, 1, 0.1, 0.1) end
end

local function Build()
    local frame = O.DialogWindow("ForeverClassicUIProfileText", 60)
    frame:SetSize(520, 300)
    local _, title = ns.DialogHeader(frame, "", HEADER)
    frame.title = title

    local how = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    how:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -32)
    how:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -32)
    how:SetJustifyH("LEFT")
    frame.how = how

    local edit = O.TextBox(frame, how, 460)
    frame.edit = edit

    local select = ns.PanelButton(frame, L["OPTWIN_SELECT_ALL"], 110)
    select:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    select:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    frame.select = select
    local import = ns.PanelButton(frame, L["OPTWIN_IMPORT"], 110)
    import:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    import:SetScript("OnClick", function()
        local name, why = ns.ImportProfile(edit:GetText())
        if name then frame:Hide() else Say(why) end
    end)
    frame.import = import
    local close = ns.PanelButton(frame, CLOSE or "Close", 100)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)
    ns.CloseOnEscape(frame)
    return frame
end

-- export: the profile in use as text, selected to copy; import: an empty box for a pasted one.
function O.ShowProfileText(mode)
    if not window then window = Build() end
    if window:IsShown() then window:Hide() end
    local exporting = mode == "export"
    window.text = exporting and ns.ExportProfile() or nil
    window.title:SetText(exporting and L["OPTWIN_EXPORT_TITLE"] or L["OPTWIN_IMPORT_TITLE"])
    window.how:SetText(exporting and L["OPTWIN_EXPORT_HOW"] or L["OPTWIN_IMPORT_HOW"])
    window.select:SetShown(exporting)
    window.import:SetShown(not exporting)
    window.edit:SetText(window.text or "")
    window.edit:SetCursorPosition(0)
    window:Show()
    window.edit:SetFocus()
    if exporting then window.edit:HighlightText() end
end
