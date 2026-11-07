local _, ns = ...

-- The gamepad over our own windows, which the game's navigator never takes (driven from our code it taints its bindings):
-- the window on top takes the pad by override bindings, d-pad to a pointer over its buttons, A presses, B closes, a
-- legend under it. A protected button has A bound to it (a native click) out of combat; a game window focused, we yield.

local KEY_A, KEY_B = GAMEPAD_FACE_BOTTOM or "PAD1", GAMEPAD_FACE_RIGHT or "PAD2"
local MOVES = { up = { "PADDUP", 0, 1 }, down = { "PADDDOWN", 0, -1 }, left = { "PADDLEFT", -1, 0 }, right = { "PADDRIGHT", 1, 0 } }
local PRESS, CLOSE = "ClassicUIForeverPadPress", "ClassicUIForeverPadClose"
local POINTER_ATLAS, POINTER_GAP = "gamepad-largecursor-white", 2
local PROMPT_ICON, PROMPT_TEXT_GAP, PROMPT_GAP, LEGEND_PAD, LEGEND_DROP = 22, 4, 14, 6, 6
local DEPTH = 6

local P = { specs = {}, shown = {}, current = {} }   -- current: window -> its selected button
local owner = CreateFrame("Frame")
local pointer, legend
local prompts = {}        -- the legend's rows, made as needed
local bound               -- the name A is bound to
local held = {}           -- pad key -> the button it clicks (through its key proxy) while ours
local promptCount = 0
local list = {}

local function Top()
    for i = #P.shown, 1, -1 do
        local frame = P.shown[i]
        if frame:IsShown() then return frame end
        table.remove(P.shown, i)
    end
end

-- The game's navigator up (a game window has the pad), or its console bar editor, which takes every button itself.
local yieldTo = {}        -- frames of ours that take the pad keys themselves while shown
local function Yielding()
    if SmartNavigation and SmartNavigation:IsShown() then return true end
    if GamepadActionBarEditFrame and GamepadActionBarEditFrame:IsShown() then return true end
    for _, frame in ipairs(yieldTo) do
        if frame:IsShown() then return true end
    end
    return false
end

------------------------------------------------------------------ the buttons

local function Usable(button)
    if not button:IsObjectType("Button") or not button:IsVisible() or not button:IsMouseEnabled() then return false end
    if button.IsEnabled and not button:IsEnabled() then return false end
    if rawget(button, "padSkip") then return false end
    local x, y = button:GetCenter()
    return x ~= nil and not ns.IsSecret(x) and not ns.IsSecret(y)
end

local function Collect(child, depth)
    if depth > DEPTH or ns.IsForbidden(child) then return end
    if Usable(child) then list[#list + 1] = child end
    ns.EachChild(child, Collect, depth + 1)
end

local function Buttons(frame)
    wipe(list)
    for _, root in ipairs(P.specs[frame].roots) do ns.EachChild(root, Collect, 1) end
    return list
end

-- The window's own first pick (spec.first), else the highest row's leftmost button, the window's close X only when it
-- is all there is.
local function First(buttons, frame)
    local spec = frame and P.specs[frame]
    local own = spec and spec.first and spec.first(buttons)
    if own and Usable(own) then return own end
    local x = frame and (frame.close or frame.Close)
    local best, bx, by
    for _, b in ipairs(buttons) do
        local left, top = b:GetLeft(), b:GetTop()
        if left and b ~= x and (not best or top > by + 1 or (math.abs(top - by) <= 1 and left < bx)) then
            best, bx, by = b, left, top
        end
    end
    return best or (x and Usable(x) and x) or nil
end

-- What A presses for a button: the secure pad standing over it when one does (its name binds), else the button.
local function PressTarget(button)
    local pad = rawget(button, "padPress") or (ns.PressTarget and ns.PressTarget(button))
    if pad and pad ~= button and pad:IsProtected() and pad:GetName() then return pad end
    return button
end

-- The nearest button in a direction: within a cone from the current one's centre, the closest along it.
local function Next(from, dx, dy, buttons)
    local cx, cy = from:GetCenter()
    local best, bestScore
    for _, b in ipairs(buttons) do
        if b ~= from then
            local x, y = b:GetCenter()
            local along = (x - cx) * dx + (y - cy) * dy
            if along > 1 then
                local across = math.abs((x - cx) * dy - (y - cy) * dx)
                if across <= along * 1.5 then
                    local score = along + across * 2
                    if not best or score < bestScore then best, bestScore = b, score end
                end
            end
        end
    end
    return best
end

------------------------------------------------------------------ the selection

local function Leave(button)
    if not button then return end
    button:UnlockHighlight()
    local leave = button:GetScript("OnLeave")
    if leave then ns.SafeCall(leave, button) end
end

local function Enter(button)
    button:LockHighlight()
    local enter = button:GetScript("OnEnter")
    if enter then ns.SafeCall(enter, button) end
end

-- A: the selected protected button itself by name (a native click), else the press proxy.
local function BindPress(button)
    if InCombatLockdown() then return end
    local press = button and PressTarget(button)
    local target = press and press:IsProtected() and press:GetName() or PRESS
    if bound == target then return end
    bound = target
    held[KEY_A] = target
    SetOverrideBindingClick(owner, true, KEY_A, ns.KeyProxy(target), "LeftButton")
end

local function PlacePointer(button)
    if not button then
        pointer:Hide()
        return
    end
    ns.SetPointOnce(pointer, "RIGHT", button, "LEFT", POINTER_GAP, 0)
    pointer:Show()
end

local function Select(button)
    local top = Top()
    if not top then return end
    local was = P.current[top]
    if was ~= button then
        Leave(was)
        P.current[top] = button
        if button then Enter(button) end
    end
    BindPress(button)
    PlacePointer(button)
end

-- The selection stands, or the first button once it is gone (a page turned, a tab picked).
-- The layer at work: the gamepad interface on and nothing of the game's holding the pad.
local function Working() return ns.GamepadUI() and not Yielding() end

local function Refresh()
    local top = Top()
    if not top or not Working() then return end
    local current = P.current[top]
    if not (current and Usable(current)) then current = First(Buttons(top), top) end
    Select(current)
end

------------------------------------------------------------------ the presses

local function Move(key)
    local top = Top()
    if not top then return end
    local current = P.current[top]
    -- A stays bound to a protected button through a fight: the pointer stays with it.
    if current and InCombatLockdown() and current:IsProtected() then return end
    local move = MOVES[key]
    -- A list at its shown end scrolls a row under the pointer instead of leaving it.
    local scroll = P.specs[top].scroll
    if scroll and current and move[3] ~= 0 and scroll(current, move[3]) then
        Leave(current)
        Enter(current)
        return
    end
    local buttons = Buttons(top)
    local to
    if current and Usable(current) then
        to = Next(current, move[2], move[3], buttons)
    else
        to = First(buttons, top)
    end
    if to then Select(to) end
end

local function Press()
    local top = Top()
    local button = top and P.current[top]
    if not button or PressTarget(button):IsProtected() or not Usable(button) then return end
    button:Click("LeftButton")
    ns.Sched.NextFrame("padNav.refresh", Refresh)
end

local function Close()
    local top = Top()
    if not top then return end
    local spec = P.specs[top]
    if spec.close then return spec.close(top) end
    local x = top.close or top.Close
    if x and x.Click then x:Click("LeftButton") else top:Hide() end
end

local function Proxy(name, fn)
    local button = CreateFrame("Button", name, UIParent)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnClick", fn)
    return button
end

for key in pairs(MOVES) do Proxy("ClassicUIForeverPad" .. key, function() Move(key) end) end
Proxy(PRESS, Press)
Proxy(CLOSE, Close)

------------------------------------------------------------------ the legend

-- The key icons are the gamepad interface's own template, Forever only; retail has no gamepad interface to show them in.
local ICON_TEMPLATE = ns.OnForever() and "InputIconTextureFrameTemplate" or nil

local function Prompt(i)
    local row = prompts[i]
    if row then return row end
    row = { icon = ns.NewFrame("Frame", nil, legend, ICON_TEMPLATE) }
    row.icon:SetSize(PROMPT_ICON, PROMPT_ICON)
    row.text = legend:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", PROMPT_TEXT_GAP, 0)
    prompts[i] = row
    return row
end

local function ShowPrompt(i, key, text, after)
    local row = Prompt(i)
    row.icon:ClearAllPoints()
    if after then
        row.icon:SetPoint("LEFT", after.text, "RIGHT", PROMPT_GAP, 0)
    else
        row.icon:SetPoint("LEFT", legend, "LEFT", LEGEND_PAD, 0)
    end
    row.icon:SetInputKey(key)
    row.text:SetText(text or "")
    row.icon:Show()
    row.text:Show()
    return row
end

local function LayLegend(top)
    local spec = P.specs[top]
    local rows = { { GAMEPAD_DPAD or "DIRPAD", FRAME_ACTION_NAVIGATE }, { KEY_A, spec.press or ACTION_LABEL_SELECT } }
    for _, extra in ipairs(spec.prompts or ns.EMPTY) do rows[#rows + 1] = { extra.key, extra.text } end
    rows[#rows + 1] = { KEY_B, spec.closeText or FRAME_ACTION_CLOSE }
    local width, last = LEGEND_PAD, nil
    for i, row in ipairs(rows) do
        last = ShowPrompt(i, row[1], row[2], last)
        width = width + PROMPT_ICON + PROMPT_TEXT_GAP + last.text:GetStringWidth() + (i < #rows and PROMPT_GAP or LEGEND_PAD)
    end
    for i = #rows + 1, #prompts do
        prompts[i].icon:Hide()
        prompts[i].text:Hide()
    end
    ns.SetPointOnce(legend, "TOPLEFT", top, "BOTTOMLEFT", spec.footX or 0, (spec.foot or 0) - LEGEND_DROP)
    legend:SetSize(width, PROMPT_ICON + 2 * LEGEND_PAD)
    legend:Show()
end

------------------------------------------------------------------ the bindings

local function Over(key, name)
    held[key] = name
    SetOverrideBindingClick(owner, true, key, ns.KeyProxy(name), "LeftButton")
end

local function Bind(top)
    if InCombatLockdown() then return end
    for key, move in pairs(MOVES) do Over(move[1], "ClassicUIForeverPad" .. key) end
    Over(KEY_B, CLOSE)
    for _, extra in ipairs(P.specs[top].prompts or ns.EMPTY) do Over(extra.key, extra.click or extra.proxy) end
    bound = nil
end

local function Unbind()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    wipe(held)
    bound = nil
end

-- The game's key sets put the pad keys back over ours whenever they change (the chat's typing, a menu): ours again on
-- top, set anew so they are the latest.
local function Reassert()
    if InCombatLockdown() or next(held) == nil then return end
    for key, name in pairs(held) do
        local action = GetBindingAction(key, true)
        if type(action) ~= "string" or not action:find(ns.KeyProxy(name), 1, true) then
            ClearOverrideBindings(owner)
            for k, n in pairs(held) do SetOverrideBindingClick(owner, true, k, ns.KeyProxy(n), "LeftButton") end
            return
        end
    end
end

local navHooked, editHooked = false, false
local function Sync()
    if SmartNavigation and not navHooked then
        navHooked = true
        ns.HookScriptOnce(SmartNavigation, "OnShow", Sync, "padNav")
        ns.HookScriptOnce(SmartNavigation, "OnHide", Sync, "padNav")
    end
    if GamepadActionBarEditFrame and not editHooked then
        editHooked = true
        ns.HookScriptOnce(GamepadActionBarEditFrame, "OnShow", Sync, "padNav")
        ns.HookScriptOnce(GamepadActionBarEditFrame, "OnHide", Sync, "padNav")
    end
    local top = Top()
    if not top or not Working() then
        Unbind()
        pointer:Hide()
        legend:Hide()
        -- The gamepad interface off: the pick lets its button go, no highlight or tooltip held for a mouse player.
        if top and not ns.GamepadUI() then
            Leave(P.current[top])
            P.current[top] = nil
        end
        return
    end
    Bind(top)
    Refresh()
    LayLegend(top)
end

-- A frame of ours that binds the pad keys itself while shown (the bind dialog): the layer lets go of them meanwhile.
function ns.PadNavYield(frame)
    yieldTo[#yieldTo + 1] = frame
    ns.HookScriptOnce(frame, "OnShow", Sync, "padNavYield")
    ns.HookScriptOnce(frame, "OnHide", Sync, "padNavYield")
end

local function Raise(frame)
    for i = #P.shown, 1, -1 do
        if P.shown[i] == frame then table.remove(P.shown, i) end
    end
    P.shown[#P.shown + 1] = frame
    Sync()
end

------------------------------------------------------------------ the windows

local function BuildPieces()
    if pointer then return end
    pointer = CreateFrame("Frame", nil, UIParent)
    pointer:SetFrameStrata("TOOLTIP")
    pointer:EnableMouse(false)
    local arrow = pointer:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas(POINTER_ATLAS, true)
    arrow:SetPoint("CENTER")
    local color = GAMEPAD_SMARTNAV_CURSOR_COLOR
    if color and color.GetRGB then arrow:SetVertexColor(color:GetRGB()) end
    pointer:SetSize(arrow:GetSize())
    pointer:Hide()
    legend = CreateFrame("Frame", nil, UIParent)
    legend:SetFrameStrata("HIGH")
    legend:EnableMouse(false)
    local backing = legend:CreateTexture(nil, "BACKGROUND")
    backing:SetAllPoints()
    backing:SetColorTexture(0, 0, 0, 0.6)
    legend:Hide()
    ns.EventFrame({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "INPUT_DEVICE_INTERFACE_TRANSITION" }, Sync)
    ns.EventFrame("UPDATE_BINDINGS", Reassert)
    -- While the legend shows: a key set swapped with no binding event still finds ours back on top.
    ns.Sched.Attach(legend, { name = "padNav.keys", every = 0.5, fn = Reassert })
end

-- A window of ours under the pad. spec: roots (frames whose buttons count), close(frame), first(buttons) (where the
-- pointer starts), scroll(button, dy) (true when it scrolled its list instead), press and closeText (the legend's words),
-- foot and footX (where the legend hangs), prompts { key, text, fn(frame, button) } or { key, text, click = a game button }.
function ns.PadNav(frame, spec)
    BuildPieces()
    spec = spec or {}
    spec.roots = spec.roots or { frame }
    for _, extra in ipairs(spec.prompts or ns.EMPTY) do
        -- A prompt with click names a game button its key presses natively; the others run fn through a proxy.
        if not extra.click then
            promptCount = promptCount + 1
            extra.proxy = "ClassicUIForeverPadPrompt" .. promptCount
            Proxy(extra.proxy, function()
                local top = Top()
                if top == frame then extra.fn(frame, P.current[frame]) end
            end)
        end
    end
    P.specs[frame] = spec
    ns.HookScriptOnce(frame, "OnShow", Raise, "padNav")
    ns.HookScriptOnce(frame, "OnHide", function(self)
        Leave(P.current[self])
        P.current[self] = nil
        Sync()
    end, "padNav")
    if frame:IsShown() then Raise(frame) end
end

-- The window laid again (a page turned by its own means): the pointer follows.
function ns.PadNavRefresh(frame)
    if pointer and Top() == frame and Working() then ns.Sched.NextFrame("padNav.refresh", Refresh) end
end
