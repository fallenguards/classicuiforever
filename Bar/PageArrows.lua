local _, ns = ...

-- Stone page arrows ride with the classic bar; restore puts the modern atlases back.
local saved

local STATES = ns.KEYS.STATES
local ARROW = { coords = { 0, 1, 0, 1 }, fill = true, add = true }
local STONE = {
    Up = { "arrowUpUp", "arrowUpDown", "arrowUpDisabled", "arrowUpHighlight" },
    Down = { "arrowDownUp", "arrowDownDown", "arrowDownDisabled", "arrowDownHighlight" },
}
local MODERN = {
    Up = { Normal = "ui-hud-actionbar-pageuparrow-up", Pushed = "ui-hud-actionbar-pageuparrow-down", Disabled = "ui-hud-actionbar-pageuparrow-disabled", Highlight = "ui-hud-actionbar-pageuparrow-mouseover" },
    Down = { Normal = "ui-hud-actionbar-pagedownarrow-up", Pushed = "ui-hud-actionbar-pagedownarrow-down", Disabled = "ui-hud-actionbar-pagedownarrow-disabled", Highlight = "ui-hud-actionbar-pagedownarrow-mouseover" },
}
local ATLAS_SETTER = { Normal = "SetNormalAtlas", Pushed = "SetPushedAtlas", Disabled = "SetDisabledAtlas", Highlight = "SetHighlightAtlas" }

local function Buttons()
    local bar = ns.GetMainBar()
    local pn = bar and bar.ActionBarPageNumber
    if not pn or not pn.UpButton or not pn.DownButton then return end
    return pn, pn.UpButton, pn.DownButton
end

-- Main bar alone: faded and out of the mouse's way, as the game's Hide Bar Scrolling (its setting is never written).
local faded = false
local function Fade(pn, up, down, fade)
    if fade == faded or InCombatLockdown() then return end
    faded = fade
    ns.SetAlphaIf(pn, fade and 0 or 1)
    up:EnableMouse(not fade)
    down:EnableMouse(not fade)
end

local function Refill(tex, state, button)
    tex:ClearAllPoints()
    tex:SetAllPoints(button)
    if state == "Highlight" then tex:SetBlendMode("BLEND") end
end

-- The game's own arrow art, as its file draws it.
local function ModernFaces(up, down)
    for _, button in ipairs({ up, down }) do
        local atlases = MODERN[(button == up) and "Up" or "Down"]
        for _, state in ipairs(STATES) do
            button[ATLAS_SETTER[state]](button, atlases[state])
        end
        ns.EachState(button, STATES, Refill, button)
    end
end

-- One bar fades them, unless its Modern page arrows option shows the game's own on the left gryphon (#207).
local function Apply()
    local pn, up, down = Buttons()
    if not pn then return end
    local modern = ns.band.ModernPages()
    Fade(pn, up, down, ns.band.OneBar() and not modern)
    if not saved then
        local _, _, _, _, upY = up:GetPoint(1)
        local _, _, _, _, downY = down:GetPoint(1)
        saved = { w = up:GetWidth(), h = up:GetHeight(), upY = upY or 10, downY = downY or -10 }
    end
    if modern then
        ModernFaces(up, down)
        return
    end
    for _, button in ipairs({ up, down }) do
        local keys = STONE[(button == up) and "Up" or "Down"]
        ns.DressStates(button, keys[1], keys[2], keys[3], keys[4], ARROW)
    end
end

local function Restore()
    if not saved then return end
    local pn, up, down = Buttons()
    if not pn then return end
    Fade(pn, up, down, false)
    ModernFaces(up, down)
    for _, button in ipairs({ up, down }) do button:SetSize(saved.w, saved.h) end
    ns.SetPointOnce(up, "CENTER", pn, "CENTER", 0, saved.upY)
    ns.SetPointOnce(down, "CENTER", pn, "CENTER", 0, saved.downY)
    saved = nil
end

-- Own id for module order; classicBar is the toggle key.
ns.RegisterModule("classicBar", { id = "pageArrows", apply = Apply, restore = Restore, padOff = true, barPiece = true })
