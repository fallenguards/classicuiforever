local _, ns = ...

-- Bind to Action Bar from our spellbook under the gamepad, as the game's book does with X: a dialog asks for the button
-- combination and the game's placement utility puts the spell there. While it is up its own override bindings take the
-- eight action buttons; LT and RT stay the game's, so its console bars light the group they point at, as in play.

local KEY_B = GAMEPAD_FACE_RIGHT or "PAD2"
local BUTTONS = 8
local DIALOG_W, DIALOG_H, TEXT_Y, NAME_Y, ICON_SIZE, ICON_Y = 440, 170, -40, -70, 36, -96
local PROMPT_ICON, PROMPT_TEXT_GAP = 22, 4
-- The game's selected slot borders, which its edit view shows on the lit group (ActionBarButton.lua): square on the
-- d-pad side (Left), round on the face side (Right), four a side.
local SQUARE_RING, CIRCLE_RING, SIDE = "gamepad-actionbar-squareslot-border-selected", "gamepad-actionbar-circleslot-border-selected", 4
-- The key icons are the gamepad interface's own template, Forever only; retail has no gamepad interface to show them in.
local ICON_TEMPLATE = ns.OnForever() and "InputIconTextureFrameTemplate" or nil

local dialog, ringFrame, ringBar
local rings = {}
local owner = CreateFrame("Frame")
local pending   -- { slot, bank } while the dialog is up

local function Held(binding)
    for _, key in ipairs({ GetBindingKey(binding, 1) }) do
        if IsKeyDown(key) then return true end
    end
    return false
end

-- The group the game's console bars have lit for the held triggers.
local function ActiveBar()
    local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    return unit and unit.GetActiveBar and unit:GetActiveBar() or nil
end

-- The selected borders over the lit group's eight slots, re-laid as the triggers move the lit group.
local function LightGroup()
    local bar = ActiveBar()
    if bar == ringBar then return end
    ringBar = bar
    for i = 1, 2 * SIDE do
        local side = bar and (i <= SIDE and bar.Left or bar.Right)
        local button = side and side["ActionButton" .. ((i - 1) % SIDE + 1)]
        local ring = rings[i]
        if button and button:IsVisible() then
            ring:SetAllPoints(button)
            ring:Show()
        else
            ring:Hide()
        end
    end
end

local function BuildRings()
    ringFrame = CreateFrame("Frame", nil, UIParent)
    ringFrame:SetFrameStrata("HIGH")
    ringFrame:EnableMouse(false)
    for i = 1, 2 * SIDE do
        rings[i] = ringFrame:CreateTexture(nil, "OVERLAY")
        rings[i]:SetAtlas(i <= SIDE and SQUARE_RING or CIRCLE_RING)
    end
    ringFrame:Hide()
end

-- The lit group's button i's storage slot.
local function SlotAt(i)
    local bar = ActiveBar()
    local button = bar and bar.GetActionButtonByIndex and bar:GetActionButtonByIndex(i)
    local slot = button and button:GetID()
    if slot and slot ~= 0 then return slot end
end

-- Action button i pressed: B with no trigger held is the footer's back, every other press binds.
local function Press(i, key)
    if not pending then return end
    if key == KEY_B and not (Held("GAMEPADLEFTMOD") or Held("GAMEPADRIGHTMOD")) then
        dialog:Hide()
        return
    end
    if InCombatLockdown() then return ns.SayNotInCombat() end
    local slot = SlotAt(i)
    local util = GamepadActionBarBindingUtil
    if slot and util and util.AssignActionToGamepadStandardSlot and C_SpellBook and C_SpellBook.PickupSpellBookItem then
        util.AssignActionToGamepadStandardSlot(slot, C_SpellBook.PickupSpellBookItem, pending.slot, pending.bank)
    end
    dialog:Hide()
end

-- One plain button per action button, pressed through its key proxy; it knows which pad key it stands for.
local slotButtons = {}
local function SlotButton(i)
    local button = slotButtons[i]
    if button then return button end
    button = CreateFrame("Button", "ClassicUIForeverPadBindSlot" .. i, UIParent)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnClick", function(self) Press(i, self.padKey) end)
    slotButtons[i] = button
    return button
end

local function TakeKeys()
    ClearOverrideBindings(owner)
    for i = 1, BUTTONS do
        local button = SlotButton(i)
        for _, key in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. i, 1) }) do
            button.padKey = key
            SetOverrideBindingClick(owner, true, key, ns.KeyProxy(button:GetName()), "LeftButton")
        end
    end
end

local function Prompt(key, text)
    local icon = ns.NewFrame("Frame", nil, dialog, ICON_TEMPLATE)
    icon:SetSize(PROMPT_ICON, PROMPT_ICON)
    icon:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 12)
    if icon.SetInputKey then icon:SetInputKey(key) end
    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", PROMPT_TEXT_GAP, 0)
    label:SetText(text or "")
end

local function Build()
    dialog = CreateFrame("Frame", "ClassicUIForeverPadBind", UIParent, ns.BACKDROP_TEMPLATE)
    dialog:SetSize(DIALOG_W, DIALOG_H)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 75)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    ns.Backdrop(dialog, ns.BACKDROP.DIALOG)
    ns.DialogHeader(dialog, GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_TITLE)
    dialog.text = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dialog.text:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, TEXT_Y)
    dialog.text:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -20, TEXT_Y)
    dialog.text:SetText(GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_BIND_INSTRUCTION or "")
    dialog.name = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    dialog.name:SetPoint("TOP", dialog, "TOP", 0, NAME_Y)
    dialog.icon = dialog:CreateTexture(nil, "ARTWORK")
    dialog.icon:SetSize(ICON_SIZE, ICON_SIZE)
    dialog.icon:SetPoint("TOP", dialog, "TOP", 0, ICON_Y)
    Prompt(KEY_B, FRAME_ACTION_BACK or CANCEL)
    BuildRings()
    dialog:SetScript("OnShow", function()
        ringBar = false
        ringFrame:Show()
        LightGroup()
    end)
    dialog:SetScript("OnHide", function()
        pending = nil
        ringFrame:Hide()
        if not InCombatLockdown() then ClearOverrideBindings(owner) end
    end)
    dialog:Hide()
    -- The triggers move the lit group with no event of ours: read while the dialog shows.
    ns.Sched.Attach(dialog, { name = "padBind.rings", every = 0.05, fn = LightGroup })
    -- The book's pad layer lets go of its keys while this is up.
    ns.PadNavYield(dialog)
end

-- The spell under the pointer offered a button combination; passives and a fight are declined as the game declines them.
function ns.PadBindSpell(button)
    local slot, bank = button and button.slot, button and button.bank
    if type(slot) ~= "number" or not (C_SpellBook and C_SpellBook.GetSpellBookItemInfo) then return end
    if InCombatLockdown() then return ns.SayNotInCombat() end
    local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
    if not info or info.isPassive then return end
    if not dialog then Build() end
    pending = { slot = slot, bank = bank }
    dialog.name:SetText(info.name or "")
    dialog.icon:SetTexture(info.iconID)
    dialog:Show()
    TakeKeys()
end
