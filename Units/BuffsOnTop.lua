local _, ns = ...
local L = ns.L
local UF = ns.UF

-- Buffs On Top under the game's edit mode dialog where it has none (#179): the pet frame, and the small focus frame
-- (the game offers its own only with Use Larger Frame).

local LABEL = _G.HUD_EDIT_MODE_SETTING_UNIT_FRAME_BUFFS_ON_TOP
-- The pet's aura row: the game's spot under the bars, or over the frame growing upward.
local PET_AURA_X, PET_AURA_Y, PET_AURA_TOP_Y = 48, -42, 0
local petTaken = false

local function PlacePetAuras()
    local row = PetFrame and PetFrame.AuraFrameContainer
    if not row then return end
    if ns.db.petBuffsOnTop == true then
        ns.SetPointOnce(row, "BOTTOMLEFT", PetFrame, "TOPLEFT", PET_AURA_X, PET_AURA_TOP_Y)
        petTaken = true
    elseif petTaken then
        ns.SetPointOnce(row, "TOPLEFT", PetFrame, "TOPLEFT", PET_AURA_X, PET_AURA_Y)
        petTaken = false
    end
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
