local _, ns = ...

-- Game windows opened and closed from our code: through the game's panel call out of a fight, raw in one (its Escape
-- then needs our stand-in). Ours (UI/Windows.lua) keep clear of a raw one in the row.

local rawShown = ns.windowRawShown

-- A window shown raw in a fight is off the client's panel list, so its Escape skips it. A child of ours signed up with
-- our Escape stands in, counted open while the window shows off that list (read each frame, not on show edges).
-- Never under a client layout frame (its layout pass would be ours).
local PANEL_SLOTS = { "left", "center", "right", "doublewide", "fullscreen" }
local escProxies = {}

local function OnPanelList(frame)
    local panelIn = _G.GetUIPanel
    if not panelIn then return true end
    for i = 1, #PANEL_SLOTS do
        if panelIn(PANEL_SLOTS[i]) == frame then return true end
    end
    return false
end

local function EscProxy(frame)
    if escProxies[frame] or frame.Layout then return end
    local proxy = ns.NewFrame("Frame", nil, frame)
    escProxies[frame] = proxy
    ns.CloseOnEscape(proxy, function() ns.HidePanel(frame) end, function() return not OnPanelList(frame) end, frame)
    if ns.debugSink then ns.Persist("esc: stand-in made for " .. tostring(frame:GetName())) end
end

-- In combat the client refuses addon opens: an unprotected window is shown raw (outside the
-- panel list; our Escape closes it), a protected one is left alone. With the gamepad on too: its focus would be ours.
function ns.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not InCombatLockdown() and not ns.GamepadUI() then
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    -- No anchor until its panel call has opened it once: give it the start of the game's row.
    if frame.GetNumPoints and frame:GetNumPoints() == 0 then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.GameRow())
    end
    frame:Show()
    -- Off the game's list, it still stands in the row ours keep clear of.
    rawShown[frame] = true
    EscProxy(frame)
    return true
end

-- A window the gamepad holds is left for its own close: shut from our code, every later close is refused.
function ns.HidePanel(frame)
    if not frame or not frame:IsShown() then return true end
    if ns.GamepadUI() then
        if ns.GamepadHolds(frame) or (frame.IsProtected and frame:IsProtected()) then return false end
        frame:Hide()
        return true
    end
    if not InCombatLockdown() then
        if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Hide()
    return true
end
