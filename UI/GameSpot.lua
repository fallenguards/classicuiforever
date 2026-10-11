local _, ns = ...

-- The game's left spot for a window (its panel manager's, Blizzard_UIParentPanelManager), for windows the game lays:
-- where Reset sends one, where edit mode's box shows one with no place, and the raise a tall one gets.

local Plain = ns.Safe

-- Era's spot for a new-style window (social, professions): the game's own, with no old frame margin to take off.
local GAME_LEFT, GAME_TOP = 16, 116

-- The game's fit for a tall window (ClampUIPanelY): raised till its bottom is 140 up, its top at least 10 down.
local GAME_BOTTOM, GAME_MIN_Y = 140, -10

-- The game's left spot for a window in UIParent units: its panel offsets (the professions book's -4, -2; none with no
-- frame), then raised to fit when h (its drawn height) is given. Left, and down from the top.
function ns.GameHome(frame, h)
    local function Offset(name)
        if not frame then return nil end
        local value = Plain(frame:GetAttribute("UIPanelLayout-" .. name))
        if value == nil and UIPanelWindows and frame.GetName then
            local registered = UIPanelWindows[frame:GetName() or ""]
            value = registered and registered[name]
        end
        return type(value) == "number" and value or nil
    end
    local down = GAME_TOP - (Offset("yoffset") or 0)
    if h then
        local bottom = UIParent:GetHeight() - down - h
        local floor = Offset("bottomClampOverride") or GAME_BOTTOM
        if bottom < floor then down = down - (floor - bottom) end
        down = math.max(down, -(Offset("minYOffset") or GAME_MIN_Y))
    end
    return GAME_LEFT + (Offset("xoffset") or 0), down
end

-- A window's scale against UIParent's (its units to UIParent units), nil while secret.
function ns.WindowRatio(frame)
    local scale, screen = Plain(frame:GetEffectiveScale()), UIParent:GetEffectiveScale()
    if not scale or not screen or screen <= 0 then return nil end
    return scale / screen
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
