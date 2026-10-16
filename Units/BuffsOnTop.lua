local _, ns = ...
local L = ns.L
local UF = ns.UF

-- Buffs On Top under the game's edit mode dialog where it has none (#179): the pet frame, and the small focus frame
-- (the game offers its own only with Use Larger Frame).

local LABEL = _G.HUD_EDIT_MODE_SETTING_UNIT_FRAME_BUFFS_ON_TOP
-- The pet's aura row: the game's spot under the bars, or 2 over the pet's name, 5 left of it (the name stands over the
-- art's bar box, and the row on the box ran into it).
local PET_AURA_X, PET_AURA_Y, NAME_X, NAME_GAP = 48, -42, -5, 2
-- The row holds the pet's debuffs only, so in edit mode an empty one shows where it goes: four marks, as its icons.
local PREVIEW_ICONS, PREVIEW_SIZE, PREVIEW_GAP = 4, 15, 2
local PREVIEW_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local petTaken = false
local preview

local function Preview()
    local row = PetFrame and PetFrame.AuraFrameContainer
    if not row then return end
    local pool = PetFrame.AuraFramePool
    local empty = not (pool and pool:GetNumActive() > 0)
    if not (ns.EditMode.state == true and empty and PetFrame:IsShown()) then
        if preview then preview:Hide() end
        return
    end
    if not preview then
        -- On the pet frame, never in the row: the row lays out its children.
        preview = ns.NewFrame("Frame", nil, PetFrame)
        preview:SetSize(PREVIEW_ICONS * (PREVIEW_SIZE + PREVIEW_GAP) - PREVIEW_GAP, PREVIEW_SIZE)
        for i = 1, PREVIEW_ICONS do
            local icon = preview:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(PREVIEW_ICON)
            icon:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
            icon:SetPoint("LEFT", preview, "LEFT", (i - 1) * (PREVIEW_SIZE + PREVIEW_GAP), 0)
        end
    end
    ns.SetLevelIf(preview, row:GetFrameLevel())
    if ns.db.petBuffsOnTop == true then
        ns.SetPointOnce(preview, "BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    else
        ns.SetPointOnce(preview, "TOPLEFT", row, "TOPLEFT", 0, 0)
    end
    preview:Show()
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
        panel.onTop = ns.DialogExtraCheck(panel, LABEL, function() return ns.db.focusBuffsOnTop end, SetFocusOnTop)
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
ns.OnEditMode(Preview)
