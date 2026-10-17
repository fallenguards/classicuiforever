local _, ns = ...
local L = ns.L
local UF = ns.UF

-- Buffs On Top under the game's edit mode dialog where it has none (#179): the pet frame, and the small focus frame
-- (the game offers its own only with Use Larger Frame).

local LABEL = _G.HUD_EDIT_MODE_SETTING_UNIT_FRAME_BUFFS_ON_TOP
-- The pet's aura row: the game's spot under the bars, or 2 over the pet's name, 5 left of it (the name stands over the
-- art's bar box, and the row on the box ran into it).
local PET_AURA_X, PET_AURA_Y, NAME_X, NAME_GAP = 48, -42, -5, 2
-- The pet's row and the small focus frame's hold debuffs only, so in edit mode an empty one shows where it goes: four
-- marks as its icons, on the frame, never in the row (the pet's lays out its children).
local PREVIEW_ICONS, PREVIEW_GAP, PET_ICON, FOCUS_ICON = 4, 2, 15, 17
local PREVIEW_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local petTaken = false
local previews = {}   -- host frame -> its marks

-- want: shown; the rest its spot (point, relative frame, its point, x, y) and its frame level.
local function ShowPreview(host, size, want, level, point, rel, relPoint, x, y)
    local preview = previews[host]
    if not want then
        if preview then preview:Hide() end
        return
    end
    if not preview then
        preview = ns.NewFrame("Frame", nil, host)
        preview:SetSize(PREVIEW_ICONS * (size + PREVIEW_GAP) - PREVIEW_GAP, size)
        for i = 1, PREVIEW_ICONS do
            local icon = preview:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(PREVIEW_ICON)
            icon:SetSize(size, size)
            icon:SetPoint("LEFT", preview, "LEFT", (i - 1) * (size + PREVIEW_GAP), 0)
        end
        previews[host] = preview
    end
    ns.SetLevelIf(preview, level)
    ns.SetPointIf(preview, point, rel, relPoint, x, y)
    preview:Show()
end

local function Preview()
    local row = PetFrame and PetFrame.AuraFrameContainer
    if not row then return end
    local pool = PetFrame.AuraFramePool
    local empty = not (pool and pool:GetNumActive() > 0)
    local want = ns.EditMode.state == true and empty and PetFrame:IsShown()
    local point = ns.db.petBuffsOnTop == true and "BOTTOMLEFT" or "TOPLEFT"
    ShowPreview(PetFrame, PET_ICON, want, row:GetFrameLevel(), point, row, point, 0, 0)
end

-- The small focus frame's, on the row's own spot (UF.AuraSpot), with no focus at all (its auras are never read: the
-- game refuses that while they are secret); kept by the aura upkeep.
function UF.FocusPreview()
    local frame = FocusFrame
    if not frame then return end
    local open = ns.EditMode.state == true and frame.smallSize == true and UF.active and UF.frames[frame] ~= nil
    local focus = open and UnitExists("focus")
    local none = open and not ns.IsSecret(focus) and not focus
    local point, art, relPoint, x, y = UF.AuraSpot(frame)
    ShowPreview(frame, FOCUS_ICON, none and point ~= nil, frame:GetAuraContainer():GetFrameLevel(), point, art, relPoint, x, y)
end

local function PlacePetAuras()
    local row = PetFrame and PetFrame.AuraFrameContainer
    if not row then return end
    if ns.db.petBuffsOnTop == true and PetName then
        ns.SetPointOnce(row, "BOTTOMLEFT", PetName, "TOPLEFT", NAME_X, NAME_GAP)
        petTaken = true
    elseif petTaken then
        ns.SetPointOnce(row, "TOPLEFT", PetFrame, "TOPLEFT", PET_AURA_X, PET_AURA_Y)
        petTaken = false
    end
    Preview()
end

local function SetFocusOnTop(on)
    ns.db.focusBuffsOnTop = on
    if not FocusFrame then return end
    UF.KeepAuraRow(FocusFrame, true)
    if ns.PlaceUnitSpellBar and FocusFrame.spellbar then ns.PlaceUnitSpellBar(FocusFrame.spellbar) end
end

ns.DialogExtra({
    title = L["MAP_CLASSICUI_FOREVER"],
    match = function(system)
        return system == FocusFrame and FocusFrame.smallSize and UF.active and UF.frames[FocusFrame] ~= nil
    end,
    build = function(panel)
        -- The game's small focus frame shows debuffs only (its SetSmallSize): the row is theirs.
        panel.onTop = ns.DialogExtraCheck(panel, L["UNIT_DEBUFFS_ON_TOP"], function() return ns.db.focusBuffsOnTop end,
            SetFocusOnTop)
        ns.DialogExtraNote(panel, L["UNIT_SMALL_FOCUS_NOTE"]:format(_G.HUD_EDIT_MODE_SETTING_UNIT_FRAME_USE_LARGER_FRAME or ""))
    end,
    fill = function(panel) panel.onTop() end,
})

ns.DialogExtra({
    title = L["MAP_CLASSICUI_FOREVER"],
    match = function(system) return system == PetFrame end,
    build = function(panel)
        panel.onTop = ns.DialogExtraCheck(panel, LABEL, function() return ns.db.petBuffsOnTop end, function(on)
            ns.db.petBuffsOnTop = on
            PlacePetAuras()
        end)
    end,
    fill = function(panel) panel.onTop() end,
})

ns.EventFrame("PLAYER_LOGIN", PlacePetAuras)
ns.OnEditMode(function()
    Preview()
    UF.FocusPreview()
end)
