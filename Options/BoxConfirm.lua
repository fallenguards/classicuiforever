local _, ns = ...

-- A confirm of ours with one tick box between its text and its buttons (the game's popup lays its own rows): the
-- interface size under Toggle none and Default toggles (#181).

local O = ns.options
local W, PAD, CHECK = 320, 16, 26

-- tip(): the box's tooltip text. Returns show(withBox, onOk); onOk(checked) runs on OK.
function O.BoxConfirm(name, text, boxLabel, tip)
    local dialog, row, check, line, onOk
    local function Build()
        dialog = O.DialogWindow(name, 120, nil, { toplevel = true })
        -- A whole box from the start: the text's width comes from its edges, else it measures as one cut line.
        dialog:SetSize(W, 120)
        line = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        line:SetPoint("TOPLEFT", dialog, "TOPLEFT", PAD, -PAD)
        line:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -PAD, -PAD)
        line:SetText(text)
        -- The box and its label centered under the text, as wide as the label asks up to the text's width.
        row = ns.NewFrame("Frame", nil, dialog)
        row:SetHeight(CHECK)
        row:SetPoint("TOP", line, "BOTTOM", 0, -6)
        check = ns.NewFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(CHECK, CHECK)
        check:SetPoint("LEFT", row, "LEFT", 0, 0)
        ns.SkinCheckbox(check)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetText(boxLabel)
        local wide = math.min(CHECK + 2 + math.ceil(label:GetUnboundedStringWidth()), W - 2 * PAD)
        row:SetWidth(wide)
        -- The label clicks and explains too.
        check:SetHitRectInsets(0, -(wide - CHECK), 0, 0)
        ns.AttachTip(check, { text = boxLabel, lines = { { tip, 1, 1, 1, true } } })
        local ok, cancel = ns.PanelButton(dialog, OKAY, 110), ns.PanelButton(dialog, CANCEL, 110)
        ok:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, PAD)
        cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, PAD)
        ok:SetScript("OnClick", function()
            local checked = row:IsShown() and check:GetChecked() and true or false
            dialog:Hide()
            onOk(checked)
        end)
        cancel:SetScript("OnClick", function() dialog:Hide() end)
        ns.CloseOnEscape(dialog)
    end
    return function(withBox, fn)
        if not dialog then Build() end
        onOk = fn
        row:SetShown(withBox)
        check:SetChecked(true)
        dialog:Show()
        dialog:Raise()
        -- Shown first: the text wraps to its anchored width.
        dialog:SetHeight(PAD + math.ceil(line:GetStringHeight()) + (withBox and CHECK + 8 or 0) + 16 + 22 + PAD)
    end
end
