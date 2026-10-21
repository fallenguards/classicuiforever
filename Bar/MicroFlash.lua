local _, ns = ...

-- A micro button's alert pulse (unspent talents and the like): the game flashes a copy of its modern icon over the
-- button and its gold border round it, alpha by alpha (UIFrameFlash), so a fade never holds. On the 1.x art the copy
-- draws nothing and the border pulses the 1.x glow, as Era's buttons flashed.

local BORDER_ATLAS = "UI-HUD-MicroMenu-Highlightalert"
local copyAtlas = setmetatable({}, { __mode = "k" })   -- button -> its copy's atlas, for the hand-back

function ns.ClassicMicroFlash(button)
    local copy, border = button.FlashContent, button.FlashBorder
    if copy then
        if copyAtlas[button] == nil then copyAtlas[button] = copy:GetAtlas() or false end
        if copy:GetTexture() then copy:SetTexture(nil) end
    end
    local glow = button:GetHighlightTexture()
    if not (border and glow) then return end
    border:SetTexture(glow:GetTexture())
    border:SetTexCoord(glow:GetTexCoord())
    border:SetBlendMode("ADD")
    border:ClearAllPoints()
    border:SetAllPoints(glow)
end

function ns.ClientMicroFlash(button)
    local atlas = copyAtlas[button]
    if atlas and button.FlashContent then button.FlashContent:SetAtlas(atlas, true) end
    local border = button.FlashBorder
    if not border then return end
    border:SetAtlas(BORDER_ATLAS)
    border:SetBlendMode("BLEND")
    border:ClearAllPoints()
    border:SetAllPoints(button)
end
