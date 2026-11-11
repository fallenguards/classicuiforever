local _, ns = ...
local L = ns.L

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

---------------------------------------------------------------- the controller on the classic layout

-- With the gamepad interface off, the pad's buttons are plain keys (padclassic v1, 2026-11-11). Override bindings of
-- ours, never saved, play the classic bars as the gamepad bars do: RT and LT (the engine's Ctrl and Shift) pick the
-- group, the d-pad and face buttons fire it. A pad key the player bound himself stays his.

-- Bar 2 by LT (Shift) and Bar 3 by RT (Ctrl); Swap RT and LT trades them.
local GROUP_MODS, SWAPPED_MODS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }, { "", "CTRL-", "SHIFT-", "CTRL-SHIFT-" }
local function GroupMods() return ns.db.padTrigSwap == true and SWAPPED_MODS or GROUP_MODS end
-- Bar 1 to 5's binding commands and buttons (the game's numbering: MULTIACTIONBAR1 is its Action Bar 2).
local GROUP_COMMANDS = { "ACTIONBUTTON", "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON", "MULTIACTIONBAR3BUTTON",
    "MULTIACTIONBAR4BUTTON" }
local GROUP_BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton" }
local PAD_SLOTS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
-- The bare face buttons keep the gamepad bars' fixed four: interact, inspect (the target's menu), back, jump.
local INSPECT = "inspect"
local BASE_FACE = { PAD3 = "INTERACTTARGET", PAD4 = INSPECT, PAD2 = "TOGGLEGAMEMENU", PAD1 = "JUMP" }
-- The shoulders target, as the gamepad interface's do, with or without a trigger held: RB the next enemy, LB the
-- next friend.
local SHOULDERS = { PADRSHOULDER = "TARGETNEARESTENEMY", PADLSHOULDER = "TARGETNEARESTFRIEND" }
-- The engine's settings each Gamepad tab pick writes (padtarget v1: all there on Forever, 2026-11-11); its first
-- choice each time is the engine's default, as the gamepad interface plays. All handed back when the layer goes.
-- The gamepad interface's own picks for interacting, as its Init sets them (Blizzard_Gamepad/Core.lua).
local PAD_CVARS = { GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateShift = "PADLTRIGGER", SoftTargetInteractRange = 20,
    SoftTargetInteractArc = 1, SoftTargetIconInteract = 1, SoftTargetIconGameObject = 1 }
local PAD_PICKS = {
    { "padTarget", {
        -- The gamepad interface's: casting at the lit enemy makes it your target (TargetAutoEnemy), so its frame shows.
        Gamepad = { SoftTargetEnemy = 1, SoftTargetForce = 0, SoftTargetMatchLocked = 1, SoftTargetWithLocked = 1,
            SoftTargetEnemyArc = 1, TargetAutoEnemy = 1, TargetAutoFriend = 1, TargetEnemyAttacker = 1, TargetAutoLock = 1 },
        Tab = { SoftTargetEnemy = 0, SoftTargetForce = 0, SoftTargetMatchLocked = 1, SoftTargetWithLocked = 1,
            SoftTargetEnemyArc = 1, TargetAutoEnemy = 1, TargetAutoFriend = 1, TargetEnemyAttacker = 0, TargetAutoLock = 0 },
        Lock = { SoftTargetEnemy = 1, SoftTargetForce = 1, SoftTargetMatchLocked = 1, SoftTargetWithLocked = 0,
            SoftTargetEnemyArc = 1, TargetAutoEnemy = 1, TargetAutoFriend = 1, TargetEnemyAttacker = 1, TargetAutoLock = 1 },
        Cone = { SoftTargetEnemy = 1, SoftTargetForce = 0, SoftTargetMatchLocked = 1, SoftTargetWithLocked = 1,
            SoftTargetEnemyArc = 0, TargetAutoEnemy = 1, TargetAutoFriend = 1, TargetEnemyAttacker = 1, TargetAutoLock = 1 },
    } },
    { "padRange", {
        Normal = { SoftTargetEnemyRange = 45, SoftTargetFriendRange = 45 },
        Near = { SoftTargetEnemyRange = 25, SoftTargetFriendRange = 25 },
        Far = { SoftTargetEnemyRange = 60, SoftTargetFriendRange = 60 },
    } },
    { "padMark", {
        Plate = { SoftTargetNameplateEnemy = 1, SoftTargetIconEnemy = 0 },
        Icon = { SoftTargetNameplateEnemy = 0, SoftTargetIconEnemy = 1 },
        Both = { SoftTargetNameplateEnemy = 1, SoftTargetIconEnemy = 1 },
        None = { SoftTargetNameplateEnemy = 0, SoftTargetIconEnemy = 0 },
    } },
    { "padCursor", {
        Sticks = { GamePadCursorLeftClick = "PADRSTICK", GamePadCursorRightClick = "PADLSTICK" },
        Menu = { GamePadCursorLeftClick = "PADFORWARD", GamePadCursorRightClick = "PADBACK" },
    } },
}

local SetOverrideBinding, GetBindingText, IsUsingGamepad = _G.SetOverrideBinding, _G.GetBindingText, _G.IsUsingGamepad
local RANGE_DOT = _G.RANGE_INDICATOR

-- keys/commands: button frame name -> its pad key and binding command; groupOf: name -> its trigger group.
local pad = { owner = CreateFrame("Frame"), keys = {}, commands = {}, groupOf = {}, shown = false }
local LightPadGroup, FaceRow

local function ClassicPad()
    return ns.db ~= nil and ns.db.padClassic == true and not ns.GamepadUI()
end

-- Every name any pick may write, for the hand-back.
local PAD_NAMES = { SoftTargetInteract = true }
for name in pairs(PAD_CVARS) do PAD_NAMES[name] = true end
for _, pick in ipairs(PAD_PICKS) do
    for _, values in pairs(pick[2]) do
        for name in pairs(values) do PAD_NAMES[name] = true end
    end
end

-- The values the Gamepad tab's picks stand for now.
local function PadValues()
    local values = { SoftTargetInteract = ns.db.padInteract == false and 0 or 1 }
    for name, value in pairs(PAD_CVARS) do values[name] = value end
    for _, pick in ipairs(PAD_PICKS) do
        local chosen
        for choice, set in pairs(pick[2]) do
            if ns.db[pick[1] .. choice] == true then chosen = set end
        end
        for name, value in pairs(chosen or {}) do values[name] = value end
    end
    return values
end

local function PadCVars(on)
    if on then
        for name, value in pairs(PadValues()) do ns.SetCVar(name, tostring(value)) end
        return
    end
    for name in pairs(PAD_NAMES) do
        local was = ns.db.cvarWas and ns.db.cvarWas[name]
        if was ~= nil then
            ns.WriteCVar(name, was)
            ns.db.cvarWas[name] = nil
        end
    end
end

-- The keyboard key the game shows: its first bound key that is not the pad's, else the range dot hidden.
local function KeyboardText(command)
    for _, key in ipairs({ GetBindingKey(command) }) do
        if not key:find("PAD", 1, true) then return GetBindingText(key, 1), true end
    end
    return RANGE_DOT, false
end

local function KeyboardTexts()
    for name in pairs(pad.keys) do
        local hotkey = _G[name] and _G[name].HotKey
        if hotkey then
            local text, bound = KeyboardText(pad.commands[name])
            hotkey:SetText(text)
            hotkey:SetShown(bound)
        end
    end
    pad.shown = false
    LightPadGroup()
end

-- The target's menu as the game's own secure action, so its entries stay the game's (a call of ours tainted them).
local inspectButton
local function InspectButton()
    if not inspectButton then
        inspectButton = CreateFrame("Button", "ClassicUIForeverPadInspect", UIParent, "SecureActionButtonTemplate")
        inspectButton:SetSize(1, 1)
        inspectButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
        inspectButton:EnableMouse(false)
        inspectButton:RegisterForClicks("AnyUp")
        inspectButton:SetAttribute("useOnKeyDown", false)
        inspectButton:SetAttribute("type", "togglemenu")
        inspectButton:SetAttribute("unit", "target")
    end
    return inspectButton:GetName()
end

local function Free(key) return (GetBindingAction(key) or "") == "" end

-- The Gamepad tab's button picks and the game's binding each stands for.
local PAD_COMMANDS = { { "padAutorunKey", "TOGGLEAUTORUN" }, { "padChatKey", "OPENCHAT" } }
-- Menu opens chat by default (padChatKey). With chat moved to another button Menu opens the game menu, as in the
-- game's own controller mode, unless the cursor clicks with it.
local MENU_KEY = "PADFORWARD"

-- Button frame name -> its pad key, for the glyphs; the keyboard's text back first on the old list.
-- Group 2 to 4's button i: a bar each, or with Bars 2 and 3 as one run, eight at a time along their 24 buttons.
-- Custom: each trigger's own bar and first button (padBar<T>, padStart<T>), saved by trigger, so a swap moves nothing.
local TRIGGER_OF = { [""] = "None", ["SHIFT-"] = "LT", ["CTRL-"] = "RT", ["CTRL-SHIFT-"] = "Both" }
local function GroupStart(group)
    if ns.db.padGroupsCustom == true then
        local trigger = TRIGGER_OF[GroupMods()[group]]
        return tonumber(ns.db["padBar" .. trigger]) or 1, tonumber(ns.db["padStart" .. trigger]) or 1
    end
    if group == 1 then return 1, 1 end
    if ns.db.padGroupsRun == true then
        -- Bars 2 and 3's 24 buttons, eight to a group.
        return 2, (group - 2) * #PAD_SLOTS + 1
    end
    return group, 1
end

-- A group's button i, running on into the next bar past a bar's 12th; nil past bar 5.
local function GroupSlot(group, i)
    local bar, start = GroupStart(group)
    local n = start + i - 1
    bar, n = bar + math.floor((n - 1) / 12), (n - 1) % 12 + 1
    if not GROUP_COMMANDS[bar] then return nil end
    return GROUP_COMMANDS[bar] .. n, GROUP_BUTTONS[bar] .. n
end

local function Bind()
    if pad.shown then KeyboardTexts() end
    ClearOverrideBindings(pad.owner)
    wipe(pad.keys)
    wipe(pad.commands)
    wipe(pad.groupOf)
    if not ClassicPad() then return end
    for group, mod in ipairs(GroupMods()) do
        for i, slot in ipairs(PAD_SLOTS) do
            local key = mod .. slot
            local face = group == 1 and BASE_FACE[slot]
            local command, name = GroupSlot(group, i)
            -- Past bar 5's last button command is nil: the pad key stays free.
            command = face or command
            if command and Free(key) and face == INSPECT then
                SetOverrideBindingClick(pad.owner, false, key, ns.KeyProxy(InspectButton()), "LeftButton")
            elseif command and Free(key) then
                SetOverrideBinding(pad.owner, false, key, command)
                if not face then
                    pad.keys[name], pad.commands[name], pad.groupOf[name] = key, command, group
                end
            end
        end
        for shoulder, command in pairs(SHOULDERS) do
            if Free(mod .. shoulder) then SetOverrideBinding(pad.owner, false, mod .. shoulder, command) end
        end
    end
    -- Autorun and chat on their picked buttons, unless the cursor clicks with it or an earlier pick took it. The pick
    -- wins over the game's binding on that button (Menu is its game menu by default); a pad key the player bound to
    -- either keeps working beside it.
    local taken = { [ns.GetCVar("GamePadCursorLeftClick") or ""] = true, [ns.GetCVar("GamePadCursorRightClick") or ""] = true }
    for _, pick in ipairs(PAD_COMMANDS) do
        local key = ns.db[pick[1]]
        if key and key ~= "" and not taken[key] then
            taken[key] = true
            SetOverrideBinding(pad.owner, false, key, pick[2])
        end
    end
    if not taken[MENU_KEY] and Free(MENU_KEY) then SetOverrideBinding(pad.owner, false, MENU_KEY, "TOGGLEGAMEMENU") end
end

-- The button's glyph alone: a trigger's beside it ran past the hotkey's width and the game cut the markup to "|A...".
-- The lit group says which trigger.
local function Glyph(key)
    return GetBindingText(key:match("(PAD%w+)$"), 1)
end

-- The group the held triggers pick (RT the engine's Ctrl, LT its Shift), lit over its buttons as the gamepad bars
-- light theirs: the game's checked glow, on a frame of ours over each button.
local LIT_ART = "Interface\\Buttons\\CheckButtonHilight"
local lit = { marks = {}, dims = {} }
local DIM_ALPHA = 0.55
local function HeldGroup()
    local ctrl, shift = IsControlKeyDown(), IsShiftKeyDown()
    if ctrl and shift then return 4 end
    local held = ctrl and "CTRL-" or shift and "SHIFT-"
    if not held then return 1 end
    return GroupMods()[2] == held and 2 or 3
end

local function Dim(group)
    local dim = group ~= nil and ns.db.padGlowDim == true
    for name in pairs(pad.keys) do
        local shade = lit.dims[name]
        local button = _G[name]
        if dim and button and button:IsVisible() and pad.groupOf[name] ~= group then
            if not shade then
                shade = lit.frame:CreateTexture(nil, "OVERLAY")
                shade:SetColorTexture(0, 0, 0, DIM_ALPHA)
                lit.dims[name] = shade
            end
            shade:ClearAllPoints()
            shade:SetAllPoints(button)
            shade:Show()
        elseif shade then
            shade:Hide()
        end
    end
end

function LightPadGroup()
    local group = pad.shown and HeldGroup() or nil
    if group == lit.group then return end
    lit.group = group
    if not lit.frame then
        lit.frame = CreateFrame("Frame", nil, UIParent)
        lit.frame:SetFrameStrata("HIGH")
        lit.frame:EnableMouse(false)
        for i = 1, #PAD_SLOTS do
            local mark = lit.frame:CreateTexture(nil, "OVERLAY")
            mark:SetTexture(LIT_ART)
            mark:SetBlendMode("ADD")
            lit.marks[i] = mark
        end
    end
    local glow = group ~= nil and ns.db.padGlowOff ~= true
    Dim(group)
    for i, mark in ipairs(lit.marks) do
        local _, name = GroupSlot(group or 1, i)
        local button = glow and name and pad.groupOf[name] == group and _G[name]
        if button and button:IsVisible() then
            mark:ClearAllPoints()
            mark:SetAllPoints(button)
            mark:Show()
        else
            mark:Hide()
        end
    end
end

-- On the pad, each button shows its pad keys; off it, the keyboard's again. Paint only: the game's own hotkey text.
local function Glyphs()
    local onPad = ClassicPad() and IsUsingGamepad ~= nil and IsUsingGamepad() == true
    if not onPad then
        if pad.shown then KeyboardTexts() end
        FaceRow()
        return
    end
    pad.shown = true
    FaceRow()
    LightPadGroup()
    for name, key in pairs(pad.keys) do
        local hotkey = _G[name] and _G[name].HotKey
        if hotkey then
            hotkey:SetText(Glyph(key))
            hotkey:Show()
        end
    end
end

-- The bare face buttons' fixed actions in a row by Bar 1 while the pad is in use: its glyph over each name.
local FACE_ROW = { { "PAD1", "PAD_FACE_JUMP" }, { "PAD2", "PAD_FACE_BACK" }, { "PAD3", "PAD_FACE_INTERACT" },
    { "PAD4", "PAD_FACE_MENU" } }
local FACE_W, FACE_H, FACE_GAP = 52, 34, 2
-- The game's gamepad bar icons for the same four (Blizzard_GamepadActionBars/MainActionBarFrame.lua).
local FACE_ART = { PAD1 = "gamepad-ability-icon-jump", PAD2 = "128-redbutton-exit", PAD3 = "Interface\\Cursor\\Interact",
    PAD4 = "crosshair_inspect_32" }
local face, tiles

-- On Bar 1: each action over the button its key would press with a trigger's bar (X Y B A, buttons 5 to 8),
-- its icon on black with the key's glyph in the corner. Only while all four buttons are empty: an action of
-- the player's is never covered, and the loose row shows then.
local function FaceOnBar(on)
    local free = on
    for i = 5, 8 do
        local button = _G["ActionButton" .. i]
        local slot = button and button.action
        free = free and button ~= nil and button:IsVisible() and not (slot and HasAction(slot))
    end
    if not free then
        if tiles then tiles:Hide() end
        return false
    end
    if not tiles then
        tiles = CreateFrame("Frame", nil, UIParent)
        tiles:SetFrameStrata("HIGH")
        tiles:EnableMouse(false)
        tiles.back, tiles.icon, tiles.key = {}, {}, {}
        for i = 5, 8 do
            local key = PAD_SLOTS[i]
            tiles.back[i] = tiles:CreateTexture(nil, "BACKGROUND")
            tiles.back[i]:SetColorTexture(0, 0, 0, 0.85)
            local icon = tiles:CreateTexture(nil, "ARTWORK")
            local art = FACE_ART[key]
            if art:find("\\", 1, true) then
                icon:SetTexture(art)
            elseif C_Texture.GetAtlasInfo(art) then
                icon:SetAtlas(art)
            end
            tiles.icon[i] = icon
            local glyph = tiles:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
            glyph:SetText(GetBindingText(key, 1))
            tiles.key[i] = glyph
        end
    end
    for i = 5, 8 do
        local button = _G["ActionButton" .. i]
        tiles.back[i]:ClearAllPoints()
        tiles.back[i]:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        tiles.back[i]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        tiles.icon[i]:ClearAllPoints()
        tiles.icon[i]:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
        tiles.icon[i]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 6)
        ns.SetPointOnce(tiles.key[i], "TOPRIGHT", button, "TOPRIGHT", -2, -3)
    end
    tiles:Show()
    return true
end

function FaceRow()
    local on = pad.shown and ns.db.padFace ~= false
    if FaceOnBar(on and ns.db.padFaceBar == true) then on = false end
    if not on then
        if face then face:Hide() end
        return
    end
    if not face then
        face = CreateFrame("Frame", nil, UIParent, ns.BACKDROP_TEMPLATE)
        face:SetSize(#FACE_ROW * (FACE_W + FACE_GAP) + 8, FACE_H + 8)
        face:EnableMouse(false)
        ns.Backdrop(face, ns.BACKDROP.TOOLTIP)
        for i, spec in ipairs(FACE_ROW) do
            local glyph = face:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            glyph:SetPoint("TOP", face, "TOPLEFT", 4 + (i - 0.5) * (FACE_W + FACE_GAP), -6)
            glyph:SetText(GetBindingText(spec[1], 1))
            local name = face:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            name:SetPoint("TOP", glyph, "BOTTOM", 0, -2)
            name:SetWidth(FACE_W)
            name:SetText(L[spec[2]])
        end
    end
    local first, last = _G.ActionButton1, _G.ActionButton12
    if not (first and last) then return face:Hide() end
    if ns.db.padFaceRight == true then
        ns.SetPointIf(face, "LEFT", last, "RIGHT", 8, 0)
    elseif ns.db.padFaceAbove == true then
        ns.SetPointIf(face, "BOTTOMLEFT", first, "TOPLEFT", 0, 8)
    else
        ns.SetPointIf(face, "RIGHT", first, "LEFT", -8, 0)
    end
    face:Show()
end

local function PadSync()
    ns.WhenCalm("padClassic.bind", function()
        Bind()
        Glyphs()
    end)
end

---------------------------------------------------------------- the choice

local choice
local function Choose(classic)
    if InCombatLockdown() then return ns.SayNotInCombat() end
    ns.db.padLayoutAsked = true
    ns.db.padClassic = classic
    PadCVars(classic)
    choice:Hide()
    -- The player's own pick of interface: written as his, never handed back as ours.
    if classic and ns.GamepadUI() then
        -- The game's gamepad Uninit puts Edit Mode on its Modern preset; the player's own layout is his to pick again.
        ns.WriteCVar("InputDeviceInterfaceStyle", "0")
        ns.Print(L["PAD_LAYOUT_RESET"])
    elseif not classic and not ns.GamepadUI() then
        ns.WriteCVar("InputDeviceInterfaceStyle", "1")
    end
    PadSync()
    -- The follow-up: the Gamepad tab at its targeting row, where every choice stays to change later.
    if classic and ns.OpenOptionsAt then ns.OpenOptionsAt("padTargetGamepad") end
end

local choiceButtons = {}
local function ChoiceButton(i, classic)
    local button = CreateFrame("Button", "ClassicUIForeverPadChoice" .. i, UIParent)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnClick", function() Choose(classic) end)
    choiceButtons[i] = button
end

local function BuildChoice()
    choice = CreateFrame("Frame", "ClassicUIForeverPadChoice", UIParent, ns.BACKDROP_TEMPLATE)
    choice:SetSize(DIALOG_W, 150)
    choice:SetPoint("CENTER", UIParent, "CENTER", 0, 75)
    choice:SetFrameStrata("DIALOG")
    choice:EnableMouse(true)
    ns.Backdrop(choice, ns.BACKDROP.DIALOG)
    ns.DialogHeader(choice, L["PAD_CHOICE_TITLE"])
    local text = choice:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", choice, "TOPLEFT", 20, TEXT_Y)
    text:SetPoint("TOPRIGHT", choice, "TOPRIGHT", -20, TEXT_Y)
    text:SetText(L["PAD_CHOICE_TEXT"])
    for i, spec in ipairs({ { L["PAD_CHOICE_CLASSIC"], true, "PAD1", -1 }, { L["PAD_CHOICE_GAMEPAD"], false, "PAD2", 1 } }) do
        local button = ns.PanelButton(choice, spec[1], 170)
        button:SetPoint("BOTTOM", choice, "BOTTOM", spec[4] * 92, 40)
        button:SetScript("OnClick", function() Choose(spec[2]) end)
        local icon = ns.NewFrame("Frame", nil, choice, ICON_TEMPLATE)
        icon:SetSize(PROMPT_ICON, PROMPT_ICON)
        icon:SetPoint("TOP", button, "BOTTOM", 0, -4)
        if icon.SetInputKey then icon:SetInputKey(spec[3]) end
        ChoiceButton(i, spec[2])
    end
    choice:SetScript("OnShow", function()
        -- A and B answer while it is up, under either interface.
        ClearOverrideBindings(owner)
        SetOverrideBindingClick(owner, true, "PAD1", ns.KeyProxy(choiceButtons[1]:GetName()), "LeftButton")
        SetOverrideBindingClick(owner, true, "PAD2", ns.KeyProxy(choiceButtons[2]:GetName()), "LeftButton")
    end)
    choice:SetScript("OnHide", function()
        if not InCombatLockdown() then ClearOverrideBindings(owner) end
    end)
    choice:Hide()
    ns.PadNavYield(choice)
end

local function Ask()
    if ns.db == nil or InCombatLockdown() then return end
    if not choice then BuildChoice() end
    choice:Show()
end

-- Asked the first time a controller is used on the normal interface, and whenever the gamepad interface is turned on
-- by a player who has not picked it.
-- The game's bar updates rewrite the hotkey text: the glyphs go back on after them.
local PAD_EVENTS = { "GAME_PAD_ACTIVE_CHANGED", "INPUT_DEVICE_INTERFACE_TRANSITION", "UPDATE_BINDINGS", "PLAYER_LOGIN",
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "MODIFIER_STATE_CHANGED" }
ns.EventFrame(PAD_EVENTS, function(_, event, active)
    if event == "PLAYER_LOGIN" then return PadSync() end
    if event == "MODIFIER_STATE_CHANGED" then return LightPadGroup() end
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        PadSync()
        if ns.GamepadUI() and not (ns.db.padLayoutAsked and ns.db.padClassic == false) then ns.WhenCalm("padClassic.ask", Ask) end
        return
    end
    if event == "GAME_PAD_ACTIVE_CHANGED" and active and not ns.db.padLayoutAsked and not ns.GamepadUI() then
        ns.WhenCalm("padClassic.ask", Ask)
    end
    Glyphs()
end)

-- The option answers at once, in a fight too once it ends: binds and the engine's trigger keys follow it.
-- A Gamepad tab drop-down's pick (Options/OptionsRows.lua).
function ns.PadPick(key, value)
    ns.db[key] = value
    ns.ToggleChanged(key)
end

-- A placement drop-down's pick: Trigger groups turns Custom, and the binds follow.
function ns.PadPlace(key, value)
    ns.db[key] = value
    ns.db.padGroupsBars, ns.db.padGroupsRun, ns.db.padGroupsCustom = false, false, true
    ns.ToggleChanged("padGroupsCustom")
end

local GLOW_KEYS = { padGlowLit = true, padGlowDim = true, padGlowOff = true }
ns.OnToggle(function(key)
    if GLOW_KEYS[key] then
        lit.group = false
        return LightPadGroup()
    end
    if key == "padFace" or key == "padFaceBar" or key == "padFaceLeft" or key == "padFaceRight" or key == "padFaceAbove" then
        return FaceRow()
    end
    if key == "padTrigSwap" or key == "padGroupsBars" or key == "padGroupsRun" or key == "padGroupsCustom"
        or key == "padAutorunKey" or key == "padChatKey" then
        lit.group = false
        return PadSync()
    end
    -- A pick on the Gamepad tab writes its engine settings while the layer is on.
    if key ~= "padClassic" and key:find("^pad") then
        if ns.db.padClassic == true then ns.WhenCalm("padClassic.cvars", function() PadCVars(true) end) end
        return
    end
    if key ~= "padClassic" then return end
    ns.db.padLayoutAsked = true
    ns.WhenCalm("padClassic.cvars", function() PadCVars(ns.db.padClassic == true) end)
    PadSync()
end)
