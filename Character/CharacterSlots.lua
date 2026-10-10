local _, ns = ...

-- The sheet's gear slots on the 1.x doll: the client's slots, chained down the sides and along the foot, its frames
-- faded under the old wells, and Era's ammo slot.

local T = ns.sheet
local Take, Own, Fade = T.Take, T.Own, T.Fade

local SLOT_GAP = 4
local LEFT_SLOTS = { "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot" }
local RIGHT_SLOTS = { "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot" }
local WEAPON_SLOTS = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }
-- Era's ammo slot: its socket and the arrow to the ranged slot (one sheet, the socket's 41 square and the 23 right of
-- it), 15 past the ranged slot.
local AMMO_GAP, AMMO_U = 15, 0.640625

-- Old bronze slot rim, owned so it hides with the sheet.
local function Rim(slot)
    ns.BronzeRim(slot, nil, 3)
    local rim = Own(slot.fcuiBronzeRim)
    if rim then rim:Show() end
end

local function DressSlot(slot, name)
    Fade(_G[name .. "Frame"])
    Fade(slot.BorderFrame)
    Rim(slot)
end

-- Each slot off the previous (nextPoint, dx, dy); the first at relPoint, x, y on the doll.
local function ChainSlots(names, doll, relPoint, x, y, nextPoint, dx, dy)
    local prev
    for _, name in ipairs(names) do
        local slot = _G[name]
        if slot then
            Take(slot, "points")
            slot:ClearAllPoints()
            if prev then
                slot:SetPoint("TOPLEFT", prev, nextPoint, dx, dy)
            else
                slot:SetPoint("TOPLEFT", doll, relPoint, x, y)
            end
            DressSlot(slot, name)
            prev = slot
        end
    end
end

local function FadeGearArt(frame) ns.FadeAtlas(frame, "gearslot", false, Fade) end

local function AmmoSlot(ammo)
    DressSlot(ammo, "CharacterAmmoSlot")
    FadeGearArt(ammo)
    ns.EachChild(ammo, FadeGearArt)
    local ranged = _G["CharacterRangedSlot"]
    if ranged then
        Take(ammo, "points")
        ns.SetPointOnce(ammo, "LEFT", ranged, "RIGHT", AMMO_GAP, 0)
    end
    local socket = Own(ns.OwnTexture(ammo, "ammoSocket", "BACKGROUND", 1))
    ns.SetTex(socket, "ammoSlot")
    socket:SetTexCoord(0, AMMO_U, 0, AMMO_U)
    socket:SetSize(41, 41)
    ns.SetPointOnce(socket, "CENTER", ammo, "CENTER", 0, 0)
    socket:Show()
    local arrow = Own(ns.OwnTexture(ammo, "ammoArrow", "OVERLAY"))
    ns.SetTex(arrow, "ammoSlot")
    arrow:SetTexCoord(AMMO_U, 1, 0, AMMO_U)
    arrow:SetSize(23, 41)
    ns.SetPointOnce(arrow, "CENTER", ammo, "CENTER", -22, 0)
    arrow:Show()
end

function T.LaySlots(doll)
    ChainSlots(LEFT_SLOTS, doll, "TOPLEFT", 21, -74, "BOTTOMLEFT", 0, -SLOT_GAP)
    ChainSlots(RIGHT_SLOTS, doll, "TOPLEFT", 306, -74, "BOTTOMLEFT", 0, -SLOT_GAP)
    ChainSlots(WEAPON_SLOTS, doll, "BOTTOMLEFT", T.WEAPON_SLOTS_X, 127, "TOPRIGHT", 5, 0)
    local ammo = _G["CharacterAmmoSlot"]
    if ammo then AmmoSlot(ammo) end
end
