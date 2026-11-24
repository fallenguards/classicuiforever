local _, ns = ...

-- Secure frames over one of our windows (not its children: they would lock it in a fight) ride toplevel on its strata,
-- raised right after it: raise order, not level, stacks frames, and only a toplevel one raises. freeze: in a fight
-- neither raises itself, for a rider that stays up then (a locked rider could not follow).

local riders = {}   -- window -> its riders, in the order they came

-- The pressed frame is the window, a rider, or a child of either.
local function PressedIn(window)
    local foci = GetMouseFoci and GetMouseFoci()
    local frame = foci and foci[1]
    for _ = 1, 12 do
        if not frame or ns.IsForbidden(frame) then return false end
        if frame == window then return true end
        for _, rider in ipairs(riders[window]) do
            if frame == rider then return true end
        end
        frame = frame:GetParent()
    end
    return false
end

local function RaiseRiders(window)
    if InCombatLockdown() then return end
    for _, rider in ipairs(riders[window]) do
        if rider:IsShown() then rider:Raise() end
    end
end

local function Watch(window, freeze)
    -- The client raises the window on a press itself; a raise by code (a mover's drag) comes through Raise.
    ns.HookMethod(window, "Raise", RaiseRiders)
    local function Forward()
        if InCombatLockdown() or not window:IsVisible() then return end
        window:Raise()
    end
    ns.EventFrame("GLOBAL_MOUSE_DOWN", function()
        if InCombatLockdown() or not window:IsVisible() or not PressedIn(window) then return end
        ns.Sched.NextFrame(window, Forward)
    end)
    -- Opening raises the window over a rider still up from before.
    window:HookScript("OnShow", function() ns.Sched.NextFrame(window, Forward) end)
    if not freeze then return end
    local function SelfRaise(on)
        window:SetToplevel(on)
        for _, rider in ipairs(riders[window]) do
            if not (InCombatLockdown() and rider:IsProtected()) then rider:SetToplevel(on) end
        end
    end
    ns.EventFrame("PLAYER_REGEN_DISABLED", function() SelfRaise(false) end)
    ns.EventFrame("PLAYER_REGEN_ENABLED", function() SelfRaise(true) end)
end

function ns.StackOver(window, frame, freeze)
    frame:SetFrameStrata(window:GetFrameStrata())
    frame:SetToplevel(not (freeze and InCombatLockdown()))
    if riders[window] then
        table.insert(riders[window], frame)
        return
    end
    riders[window] = { frame }
    Watch(window, freeze)
    if freeze and InCombatLockdown() then window:SetToplevel(false) end
end
