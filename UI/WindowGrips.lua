local _, ns = ...
local L = ns.L

local W = ns.windowEdit
local Plain = ns.Safe

-- Each unlocked window's corner grip, the chat frame's: a drag sizes it from its top left (edit mode's Size), a right
-- click puts its own size back. Shown while the mouse is on the window, or always with windowLocksAlways.
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"
local GRIP_SIZE = 16
local GRIP_X, GRIP_Y = -5, 5    -- its bottom right from the window's drawn corner
local GRIP_GAP = 2              -- to a piece beside it on the foot (the map's Map Options)
local LIFT = 25                 -- over the window's own art, as the lock
local MIN_SCALE, MAX_SCALE = 0.5, 1.5

local grips = {}   -- entry key -> its grip
local drag = {}    -- the drag under way: entry, frame, top left and size, grab offset

local TIP = { text = L["UI_RESIZE"], r = 1, g = 1, b = 1, lines = { { L["UI_RESIZE_TIP"], nil, nil, nil, true } } }

-- Unlocked, not maximized, and not a window a fight holds still.
local function Usable(entry, frame)
    if not W.IsFree(entry) or W.Full(entry, frame) or ns.MoverHolds(frame) then return false end
    return not (InCombatLockdown() and (entry.calm or ns.WindowLocked(frame)))
end

-- How far a piece on the window's foot stays from its right edge to leave the grip room: 0 while it has none.
function ns.WindowGripRoom(key)
    for _, entry in ipairs(W.WINDOWS) do
        if entry.key == key then
            if not W.IsFree(entry) or W.Full(entry, ns.WindowFrame(entry)) then return 0 end
            return GRIP_SIZE - GRIP_X + GRIP_GAP
        end
    end
    return 0
end

local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local job

local function Stop()
    local entry = drag.entry
    if not entry then return end
    wipe(drag)
    job:Sleep()
    grips[entry.key]:SetButtonState("NORMAL", false)
    W.PlaceAll()
    W.Refresh()
end

-- The drawn corner on the cursor (less where it was grabbed), the top left kept and the window on the screen.
local function Step()
    local entry, frame = drag.entry, drag.frame
    if not entry then return end
    if not IsMouseButtonDown("LeftButton") then
        Stop()
        return
    end
    local x, y = Cursor()
    x, y = x - drag.dx - drag.left, drag.top - y + drag.dy
    local w, h = drag.w, drag.h
    local k = (x * w + y * h) / (w * w + h * h)
    k = math.min(k, (UIParent:GetWidth() - drag.left) / w, drag.top / h)
    local scale = math.max(MIN_SCALE, math.min(MAX_SCALE, k / drag.base))
    scale = math.floor(scale * 100 + 0.5) / 100
    if scale == drag.scale then return end
    -- Its place from where it stands, before the first new size moves it.
    if not drag.placed then
        W.SaveFrom(entry, frame)
        drag.placed = true
    end
    drag.scale = scale
    W.Scales()[W.SizeKey(entry)] = math.abs(scale - 1) > 0.001 and scale or nil
    W.PlaceAll()
end

job = ns.Sched.Job({ name = "windows.gripDrag", every = 0, awake = false, fn = Step })

local function Start(entry)
    local frame = ns.WindowFrame(entry)
    if drag.entry or not (frame and Usable(entry, frame)) then return end
    local k, scale = W.Ratio(frame), Plain(frame:GetScale())
    local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
    local w, h = W.DrawnSize(entry, frame)
    if not (k and scale and scale > 0 and left and top and w) then return end
    local x, y = Cursor()
    left, top = left * k, top * k
    drag.entry, drag.frame, drag.left, drag.top, drag.w, drag.h = entry, frame, left, top, w, h
    drag.dx, drag.dy = x - (left + w * k), y - (top - h * k)
    drag.base, drag.scale, drag.placed = k / scale, scale, false
    grips[entry.key]:SetButtonState("PUSHED", true)
    GameTooltip:Hide()
    job:Wake()
end

local function DefaultSize(entry)
    local scales, key = W.Scales(), W.SizeKey(entry)
    if scales[key] == nil then return end
    scales[key] = nil
    W.PlaceAll()
    W.Refresh()
end

local function Sync(entry)
    local grip, frame = grips[entry.key], ns.WindowFrame(entry)
    if not frame then return end
    local on = drag.entry == entry or (Usable(entry, frame) and (ns.db.windowLocksAlways or frame:IsMouseOver()))
    ns.SetShownIf(grip, on and true or false)
    if not on then return end
    -- A toplevel window is raised as it opens or is clicked: the grip follows it up.
    ns.SetLevelIf(grip, frame:GetFrameLevel() + LIFT)
    local w, h = W.DrawnSize(entry, frame)
    if w then ns.SetPointIf(grip, "BOTTOMRIGHT", frame, "TOPLEFT", w + GRIP_X, GRIP_Y - h) end
end

local function MakeGrip(entry)
    local frame = ns.WindowFrame(entry)
    if entry.piece or grips[entry.key] or not frame then return end
    local grip = ns.NewFrame("Button", nil, entry.quests and frame.BorderFrame or frame)
    ns.MarkWindowPiece(grip)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetNormalTexture(GRIP .. "Up")
    grip:SetPushedTexture(GRIP .. "Down")
    grip:SetHighlightTexture(GRIP .. "Highlight")
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnClick", function() DefaultSize(entry) end)
    grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then Start(entry) end end)
    grip:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then Stop() end end)
    ns.AttachTip(grip, TIP)
    grip:Hide()
    grips[entry.key] = grip
    ns.Sched.Attach(frame, { name = "windowGrip", every = 0.1, fn = function() Sync(entry) end })
end

ns.MakeWindowGrip = MakeGrip
-- For the dev addon's window test.
function ns.WindowGripButton(key) return grips[key] end
