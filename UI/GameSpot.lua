local _, ns = ...

-- The game's left spot for a window (its panel manager's, Blizzard_UIParentPanelManager), for windows the game lays:
-- where Reset sends one, where edit mode's box shows one with no place, and the raise a tall one gets.

local Plain = ns.Safe

-- The game's own row start when its layout values cannot be read (its LEFT_OFFSET and TOP_OFFSET).
local GAME_LEFT, GAME_TOP = 16, -116

-- The game's fit for a tall window (ClampUIPanelY): raised till its bottom is 140 up, its top at least 10 down.
local GAME_BOTTOM, GAME_MIN_Y = 140, -10

-- A window's panel offset (the professions book's -4, -2), from its attributes or the game's panel list.
local function Offset(frame, name)
    if not frame then return nil end
    local value = Plain(frame:GetAttribute("UIPanelLayout-" .. name))
    if value == nil and UIPanelWindows and frame.GetName then
        local registered = UIPanelWindows[frame:GetName() or ""]
        value = registered and registered[name]
    end
    return type(value) == "number" and value or nil
end

local function LayoutValue(name, default)
    local get = _G.GetUIPanelLayoutAttribute
    local value = get and Plain(get(name))
    return type(value) == "number" and value or default
end

-- A window's scale against UIParent's (its units to UIParent units), nil while secret.
function ns.WindowRatio(frame)
    local scale, screen = Plain(frame:GetEffectiveScale()), UIParent:GetEffectiveScale()
    if not scale or not screen or screen <= 0 then return nil end
    return scale / screen
end

-- How far the game's left window stands from where its manager put it: an addon that re-anchors the game's windows
-- (a centering one) moves ours by as much. Read while that window stands on an anchor not the manager's.
local shift = 0
local function Learn(left)
    local panel = _G.GetUIPanel and _G.GetUIPanel("left")
    if not (panel and panel:IsVisible()) or (ns.FramePlaced and ns.FramePlaced(panel)) then return end
    if ns.WindowMoving and ns.WindowMoving(panel) then return end
    if Plain(panel:GetNumPoints()) == 1 then
        local point, rel, relPoint = panel:GetPoint(1)
        if Plain(point) == "TOPLEFT" and Plain(relPoint) == "TOPLEFT" and (rel == nil or Plain(rel) == UIParent) then
            shift = 0
            return
        end
    end
    local x, k = Plain(panel:GetLeft()), ns.WindowRatio(panel)
    if x and k then shift = math.floor(x * k - left - (Offset(panel, "xoffset") or 0) + 0.5) end
end

-- Where the game's row of windows starts, in UIParent units: left, and top (down from the screen's top, negative).
-- Its layout's own values, which a layout addon may change, and the shift its left window was last seen at.
function ns.GameRow()
    local left = LayoutValue("LEFT_OFFSET", GAME_LEFT)
    Learn(left)
    return left + shift, LayoutValue("TOP_OFFSET", GAME_TOP)
end

-- The game's left spot for a window in UIParent units: the row's start and its panel offsets (none with no frame),
-- then raised to fit when h (its drawn height) is given. Left, and down from the top.
function ns.GameHome(frame, h)
    local left, top = ns.GameRow()
    local down = -top - (Offset(frame, "yoffset") or 0)
    if h then
        local bottom = UIParent:GetHeight() - down - h
        local floor = Offset(frame, "bottomClampOverride") or GAME_BOTTOM
        if bottom < floor then down = down - (floor - bottom) end
        down = math.max(down, -(Offset(frame, "minYOffset") or GAME_MIN_Y))
    end
    return left + (Offset(frame, "xoffset") or 0), down
end

-- A game window open alone goes to the game's own left spot now (the sheet's Era pass takes it on); beside another it
-- waits for its next opening, when the game lays it.
function ns.GameSpot(frame)
    if not frame:IsShown() or (InCombatLockdown() and ns.WindowLocked(frame)) then return end
    local w, h = Plain(frame:GetWidth()), Plain(frame:GetHeight())
    local k = ns.WindowRatio(frame)
    if not (w and h and k) then return end
    local left, down = ns.GameHome(frame, h * k)
    if ns.WindowCovers(frame, left, UIParent:GetHeight() - down, w * k, h * k) then return end
    -- Offsets in the window's own units, as the game sets them.
    pcall(frame.SetPoint, frame, "TOPLEFT", UIParent, "TOPLEFT", left / k, -down / k)
end
