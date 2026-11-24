local _, ns = ...

-- Our book and its secure casting layer stack as one game window. Here raise order, not frame level, decides what is
-- on top, and only a toplevel frame can be raised: the layer is toplevel on the book's strata and raised right after
-- the book, so a window raised later covers both. A fight locks the layer: neither raises itself until it ends.

-- The pressed frame is the book, the layer, or a child of either.
local function PressedIn(book, layer)
    local foci = GetMouseFoci and GetMouseFoci()
    local frame = foci and foci[1]
    for _ = 1, 12 do
        if not frame or ns.IsForbidden(frame) then return false end
        if frame == book or frame == layer then return true end
        frame = frame:GetParent()
    end
    return false
end

function ns.StackBookLayer(book, layer)
    layer:SetFrameStrata(book:GetFrameStrata())
    local function SelfRaise(on)
        book:SetToplevel(on)
        if not (InCombatLockdown() and layer:IsProtected()) then layer:SetToplevel(on) end
    end
    local function LayerOver()
        if InCombatLockdown() or not layer:IsShown() then return end
        layer:Raise()
    end
    -- The client raises the book on a press itself; a raise by code (a mover's drag) comes through Raise.
    ns.HookMethod(book, "Raise", LayerOver)
    local function BookForward()
        if InCombatLockdown() or not book:IsVisible() then return end
        book:Raise()
    end
    ns.EventFrame("GLOBAL_MOUSE_DOWN", function()
        if InCombatLockdown() or not book:IsVisible() or not PressedIn(book, layer) then return end
        ns.Sched.NextFrame("bookstack", BookForward)
    end)
    ns.EventFrame("PLAYER_REGEN_DISABLED", function() SelfRaise(false) end)
    ns.EventFrame("PLAYER_REGEN_ENABLED", function() SelfRaise(true) end)
    SelfRaise(not InCombatLockdown())
end
