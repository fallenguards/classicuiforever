local _, ns = ...
local L = ns.L

-- WoW Forever's gamepad interface. Its window focus and d-pad navigation run in the name of whoever opens, closes or
-- builds into a window, and then refuse their protected call (SetPreferredGamepadInteractTarget) for the whole session.

local GAMEPAD = Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad

function ns.GamepadUI()
    local style = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
    if GAMEPAD == nil or type(style) ~= "function" then return false end
    local ok, current = pcall(style)
    return ok and current == GAMEPAD
end

-- Read only: the lookups pass dontCreate, so nothing of the navigator's is written in our name.
local function NavInfo(frame, withParents)
    local nav = SmartNavigation
    if not frame or not nav or not ns.GamepadUI() then return nil end
    local ok, info
    if withParents then
        if type(nav.GetParentPanelInfo) ~= "function" then return nil end
        ok, info = pcall(nav.GetParentPanelInfo, nav, frame)
    else
        if type(nav.GetPanelInfo) ~= "function" then return nil end
        ok, info = pcall(nav.GetPanelInfo, nav, frame, true)
    end
    return ok and info or nil
end

-- Whether the gamepad interface holds this window open: only its own close may shut it.
function ns.GamepadHolds(frame)
    if not frame or not ns.GamepadUI() then return false end
    if NavInfo(frame, false) then return true end
    local mgr = GamepadMode and GamepadMode.FrameControlsManager
    local shown = mgr and mgr.shownFrames
    if type(shown) ~= "table" then return false end
    for i = 1, #shown do
        if shown[i] == frame then return true end
    end
    return false
end

-- CreateFrame for a frame whose parent may be inside an open window. The navigator's CreateFrame hook re-reads that
-- window's controls in our name; made on UIParent and then moved, it never runs, and the window's next read finds it.
function ns.NewFrame(frameType, name, parent, template)
    if parent == nil or parent == UIParent or not NavInfo(parent, true) then
        return CreateFrame(frameType, name, parent, template)
    end
    -- A secure frame cannot change parent in a fight.
    if InCombatLockdown() and type(template) == "string" and template:find("Secure", 1, true) then
        return CreateFrame(frameType, name, parent, template)
    end
    if type(name) == "string" and name:find("$[Pp]arent") then
        name = name:gsub("%$[Pp]arent", parent:GetName() or "")
    end
    local frame = CreateFrame(frameType, name, UIParent, template)
    frame:SetParent(parent)
    ns.SetLevelIf(frame, parent:GetFrameLevel() + 1)
    return frame
end

-- The label style of the controller in use, else of a connected one, as the suffix of the game's key strings.
local STYLE_KEYS = { Letters = "_LTR", Shapes = "_SHP", Reverse = "_REV" }
local function PadStyle()
    local pad = _G.C_GamePad
    if not (pad and pad.GetDeviceMappedState) then return nil end
    local active = pad.GetActiveDeviceID and pad.GetActiveDeviceID()
    local state = active and pad.GetDeviceMappedState(active)
    if not state and pad.GetAllDeviceIDs then
        for _, id in ipairs(pad.GetAllDeviceIDs()) do
            state = state or pad.GetDeviceMappedState(id)
        end
    end
    return state and STYLE_KEYS[state.labelStyle]
end

-- A pad key's icon in that controller's style; the game's own text can come in its generic set (View and Menu as pills).
function ns.PadGlyph(key)
    local style = PadStyle()
    return style and _G["KEY_ABBR_" .. key .. style] or _G.GetBindingText(key, 1)
end

-- Switching between the gamepad and mouse interfaces re-runs the pass: the classic bar stands down for the gamepad's.
-- Our windows swap only on a reload: said in chat, as a popup would join the gamepad's focus in our name.
local swapSaid = false
ns.EventFrame("INPUT_DEVICE_INTERFACE_TRANSITION", function()
    ns.QueueApply()
    if swapSaid or not (ns.PadSwapOwed and ns.PadSwapOwed()) then return end
    swapSaid = true
    ns.Print(ns.GamepadUI() and L["CORE_GAMEPAD_ON_RELOAD"] or L["CORE_GAMEPAD_OFF_RELOAD"])
end)
