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

-- The tabard colour the client tints its guild sheet with, while it shows the emblem.
local function ClientTint(button)
    local emblem = button.Emblem
    if not (emblem and emblem:IsShown()) then return nil end
    local info = C_GuildInfo and C_GuildInfo.GetGuildTabardInfo and C_GuildInfo.GetGuildTabardInfo("player")
    return info and info.backgroundColor
end

-- The client's own micro art back as its LoadMicroButtonTextures draws it, tabard tint too, never through it: that writes
-- textureName, and written by us the client's next micro pass ran as ours (the character window's health text and the
-- game menu's Log Out and Exit refused).
local CLIENT_MICRO_ART = { { "SetNormalAtlas", "GetNormalTexture", "-Up" }, { "SetPushedAtlas", "GetPushedTexture", "-Down" },
    { "SetDisabledAtlas", "GetDisabledTexture", "-Disabled" }, { "SetHighlightAtlas", "GetHighlightTexture", "-Mouseover" } }
function ns.ClientMicroArt(button)
    local name = button.textureName
    if type(name) ~= "string" then return end
    local color = ClientTint(button)
    for _, art in ipairs(CLIENT_MICRO_ART) do
        button[art[1]](button, "UI-HUD-MicroMenu-" .. name .. art[3])
        local tex = color and button[art[2]](button)
        if tex then tex:SetVertexColor(color.r, color.g, color.b) end
    end
end

-- What the client gave a micro button before our first dress, put back as it was: Forever's character button has no
-- state textures of its own (ours drew the 1.x art over its portrait after the hand-back) and its portrait's size and
-- anchors (ours stayed, squashed).
function ns.KeepClientMicro(button, state)
    -- Forever's character button has the texture objects but nothing set on them.
    local normal = button:GetNormalTexture()
    state.bare = normal == nil or (normal:GetTexture() == nil and normal:GetAtlas() == nil)
    local portrait = button.Portrait
    if not portrait then return end
    state.portraitW, state.portraitH = portrait:GetSize()
    local points = {}
    for i = 1, portrait:GetNumPoints() or 0 do points[i] = { portrait:GetPoint(i) } end
    state.portraitPoints = points
end

local STATE_KINDS = { "Normal", "Pushed", "Disabled" }
function ns.ClientMicroBack(button, state)
    if state.bare then
        for _, kind in ipairs(STATE_KINDS) do
            local clear = button["Clear" .. kind .. "Texture"]
            local tex = not clear and button["Get" .. kind .. "Texture"](button)
            if clear then clear(button) elseif tex then tex:SetTexture(nil) end
        end
    end
    local portrait, points = button.Portrait, state.portraitPoints
    if not (portrait and points and state.portraitW) then return end
    portrait:SetSize(state.portraitW, state.portraitH)
    portrait:ClearAllPoints()
    for _, p in ipairs(points) do portrait:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
end
