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

-- A window mover took this game window: it makes a <window>Move frame for each one it takes.
function ns.MoverTakes(frame)
    local name = frame and frame.GetName and frame:GetName()
    return type(name) == "string" and type(_G[name .. "Move"]) == "table"
end

-- The game's windows: its panel list, and the ones our window list holds as the game's (made once).
local gameNames
local function GameWindow(name)
    if _G.UIPanelWindows and _G.UIPanelWindows[name] then return true end
    if not gameNames then
        gameNames = {}
        for _, entry in ipairs(ns.WINDOW_LIST or {}) do
            if entry.client or entry.quests then gameNames[entry.name] = true end
        end
    end
    return gameNames[name] == true
end

-- A game window placed by someone else: a mover took it, or the player left the game's windows to other addons. Ours
-- stand aside, with no place, size, lock, row pass or learned shift of ours on it.
function ns.MoverHolds(frame)
    if ns.MoverTakes(frame) then return true end
    local name = ns.db and ns.db.leaveGameWindows and frame and frame.GetName and frame:GetName()
    return type(name) == "string" and GameWindow(name)
end

-- A window's scale against UIParent's (its units to UIParent units), nil while secret.
function ns.WindowRatio(frame)
    local scale, screen = Plain(frame:GetEffectiveScale()), UIParent:GetEffectiveScale()
    if not scale or not screen or screen <= 0 then return nil end
    return scale / screen
end

-- A size that keeps a window inside the screen: one kept from another look or UI scale ran past it (134% on the Classic
-- map's 768 tall sheet). w, h: its drawn size in its own units.
function ns.ScreenFitScale(frame, scale, w, h)
    local k, own = ns.WindowRatio(frame), Plain(frame:GetScale())
    if not (scale and w and h and k and own and own > 0) then return scale end
    local per = k / own
    local screenW, screenH = UIParent:GetSize()
    return math.min(scale, screenW / (w * per), screenH / (h * per))
end

-- A window's spot from a row start (left, top): its panel offsets (none with no frame), then raised to fit when h (its
-- drawn height) is given, as the game's ClampUIPanelY. Left, and down from the top.
local function Spot(frame, h, left, top)
    local down = -top - (Offset(frame, "yoffset") or 0)
    if h then
        local bottom = UIParent:GetHeight() - down - h
        local floor = Offset(frame, "bottomClampOverride") or GAME_BOTTOM
        if bottom < floor then down = down - (floor - bottom) end
        down = math.max(down, -(Offset(frame, "minYOffset") or GAME_MIN_Y))
    end
    return left + (Offset(frame, "xoffset") or 0), down
end

-- A panel setting (attribute, else its registration) and the game's width for a window (its GetUIPanelWidthUnscaled).
ns.GamePanelValue = Offset
function ns.GamePanelWidth(frame) return (Offset(frame, "width") or Plain(frame:GetWidth()) or 0) + (Offset(frame, "extraWidth") or 0) end

-- A window's x offset and how far down the game stands it (its y offset and its fit for a tall one), UIParent units.
function ns.GameXOffset(frame) return Offset(frame, "xoffset") or 0 end
function ns.GameDown(frame)
    local h, k = Plain(frame:GetHeight()), ns.WindowRatio(frame)
    local _, down = Spot(frame, h and k and h * k, 0, LayoutValue("TOP_OFFSET", GAME_TOP))
    return down
end

-- The classic sheet stands 12 above the game's line (Era's spot, UI/Windows.lua); within LINE_SLACK is on the line.
local ERA_RAISE, LINE_SLACK = 12, 1.5

-- A window's top in UIParent units, or nil while unreadable.
local function Top(panel)
    local top, k = Plain(panel:GetTop()), ns.WindowRatio(panel)
    return top and k and top * k
end

-- Its top and the manager's line for it, or nil while unreadable; the layout's top alone (the row's left asks Learn).
local function TopAndLine(panel)
    local top, h, k = Top(panel), Plain(panel:GetHeight()), ns.WindowRatio(panel)
    if not (top and h and k) then return nil end
    local _, down = Spot(panel, h * k, 0, LayoutValue("TOP_OFFSET", GAME_TOP))
    return top, UIParent:GetHeight() - down
end

-- Not where the manager puts it at its height now (nor Era's spot above that): exact, for learning a shift only.
function ns.GameWindowOffLine(panel)
    local top, line = TopAndLine(panel)
    if not top then return false end
    return math.abs(top - line) > LINE_SLACK and math.abs(top - (line + ERA_RAISE)) > LINE_SLACK
end

-- On Era's spot (the sheet, UI/Windows.lua): raised 12 above the line and stood 16 left of the manager's x.
function ns.GameWindowAtEra(panel)
    local top, line = TopAndLine(panel)
    return top ~= nil and math.abs(top - (line + ERA_RAISE)) <= LINE_SLACK
end

-- A game window off the band its manager places in: below its line, or above the highest the fit raises it to (Era's
-- spot counted). The player or a window mover put it there, so it leaves the row as our own placed ones do. A band, not
-- the line: the game's spell window is laid at its two-page size on its first open, then shrinks to its talents.
function ns.GameWindowOffRow(panel)
    local top = Top(panel)
    if not top then return false end
    local line = UIParent:GetHeight() + LayoutValue("TOP_OFFSET", GAME_TOP) + (Offset(panel, "yoffset") or 0)
    local highest = UIParent:GetHeight() + (Offset(panel, "minYOffset") or GAME_MIN_Y) + ERA_RAISE
    return top < line - LINE_SLACK or top > highest + LINE_SLACK
end

-- How far the game's left window stands from where its manager put it: an addon that moves the game's windows (a
-- centering one, by its own anchor or by the offset on UIParent's) moves ours by as much. Read from where it is drawn,
-- on its line, less Era's step left where the sheet stands at Era's spot; kept while no game window is up.
local ERA_LEFT = 16
local shift, shiftFrom = 0, nil
local function Learn(left)
    local panel = _G.GetUIPanel and _G.GetUIPanel("left")
    if not (panel and panel:IsVisible()) or (ns.FramePlaced and ns.FramePlaced(panel)) or ns.MoverHolds(panel) then return end
    -- The loot window is the game's left panel too, at its own edit mode spot (on the line, far right): never the row's.
    local name = panel.GetName and panel:GetName()
    if ns.WINDOW_FLOATS and ns.WINDOW_FLOATS[name or ""] then return end
    if (ns.WindowMoving and ns.WindowMoving(panel)) or ns.GameWindowOffLine(panel) then return end
    -- The book's page stands on the book's spot by our own hand (UI/Windows.lua): no shift of the game's to read there.
    if ns.BookPageWindow and ns.BookPageWindow(panel) then return end
    local x, k = Plain(panel:GetLeft()), ns.WindowRatio(panel)
    if not (x and k) then return end
    local era = ns.GameWindowAtEra(panel) and ERA_LEFT or 0
    -- Retail's crafting window stands with its panel offset taken off (Skills/TradeSkillRetail.lua).
    local offset = (ns.CraftingOffsetTaken and ns.CraftingOffsetTaken(panel)) and 0 or (Offset(panel, "xoffset") or 0)
    shift = math.floor(x * k + era - left - offset + 0.5)
    shiftFrom = name
end

-- Reset windows: the row starts where the game's layout says until a game window teaches it again.
function ns.ForgetRowShift() shift, shiftFrom = 0, nil end

-- For the dev probe (windowrow): the shift and the window it was last learned from.
function ns.GameRowShift() return shift, shiftFrom end

-- Where the game's row of windows starts, in UIParent units: left, and top (down from the screen's top, negative).
-- Its layout's own values, which a layout addon may change, and the shift its left window was last seen at.
function ns.GameRow()
    local left = LayoutValue("LEFT_OFFSET", GAME_LEFT)
    Learn(left)
    return left + shift, LayoutValue("TOP_OFFSET", GAME_TOP)
end

-- The game's left spot for a window in UIParent units, from the row's start. Left, and down from the top.
function ns.GameHome(frame, h)
    local left, top = ns.GameRow()
    return Spot(frame, h, left, top)
end

-- The manager's start for the slot it holds a window in (its UpdateUIPanelPositions; read, never driven), with the
-- shift last learned; nil for a window in none.
local SLOT_START = { left = "LEFT_OFFSET", doublewide = "LEFT_OFFSET", center = "CENTER_OFFSET", right = "RIGHT_OFFSET" }
local function SlotStart(frame)
    local getPanel = _G.GetUIPanel
    if not getPanel then return nil end
    for slot, key in pairs(SLOT_START) do
        if getPanel(slot) == frame then return LayoutValue(key, GAME_LEFT) + shift end
    end
end

-- A game window back where its manager puts it for its slot (the sheet's Era pass takes it on); ours standing there
-- give way on their next pass. Never learned from this one, still where it was dragged. One in no slot goes to the
-- left spot when that is clear, else waits for its next opening, when the game lays it.
function ns.GameSpot(frame)
    if not frame:IsShown() or (InCombatLockdown() and ns.WindowLocked(frame)) or ns.MoverHolds(frame) then return end
    local w, h = Plain(frame:GetWidth()), Plain(frame:GetHeight())
    local k = ns.WindowRatio(frame)
    if not (w and h and k) then return end
    local start = SlotStart(frame)
    local left, down = Spot(frame, h * k, start or (LayoutValue("LEFT_OFFSET", GAME_LEFT) + shift),
        LayoutValue("TOP_OFFSET", GAME_TOP))
    if not start and ns.WindowCovers(frame, left, UIParent:GetHeight() - down, w * k, h * k) then return end
    -- Offsets in the window's own units, its anchors cleared first as the game's manager does: a drag's end leaves it
    -- on the screen's centre, and a second anchor beside that one is refused (anchor family connection).
    ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPLEFT", left / k, -down / k)
end

-- A game window our layout grew after the game laid it: raised as the game raises a tall one, left kept; placed, it stays.
function ns.FitGameWindow(key)
    local W = ns.windowEdit
    local entry = W.ByKey[key]
    local frame = entry and ns.WindowFrame(entry)
    if not frame or W.PlaceOf(entry) or W.Full(entry, frame) or not frame:IsShown() or ns.MoverHolds(frame) then return end
    if InCombatLockdown() and ns.WindowLocked(frame) then return end
    local left, top, h, k = Plain(frame:GetLeft()), Plain(frame:GetTop()), Plain(frame:GetHeight()), ns.WindowRatio(frame)
    if not (left and top and h and k) then return end
    local _, down = ns.GameHome(frame, h * k)
    local want = UIParent:GetHeight() - down
    if top * k >= want - 0.5 then return end
    -- Anchors cleared first: one a drag's end left is refused a second beside it.
    ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPLEFT", left, -down / k)
end
