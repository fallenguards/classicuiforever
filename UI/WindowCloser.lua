local _, ns = ...

-- Forever's spell window (spellbook and talents, up to 1618 wide) gives way to one of ours with no room past it, as the
-- game closes its own older window for a newer one. Closed by a click in the player's name, its close button pressed
-- through our keys' and buttons' secure clicks: closed from our code it leaves the action bars showing empty slots.

local CLOSER = "ForeverClassicUIGameSpellsClose"
local closer
local watchers = {}   -- each opener's fn(): its secure clicks set for the room now, out of a fight

-- The named button a macro clicks to press the game's close, aimed once its window has loaded; out of a fight.
local function Closer()
    local spells = _G.PlayerSpellsFrame
    local close = spells and spells.CloseButton
    if not close or InCombatLockdown() then return nil end
    closer = closer or ns.ClickProxy(CLOSER)
    ns.SetAttributeIf(closer, "clickbutton", close)
    return closer
end

-- Whether one of ours, opened now, finds no room past the game's windows with the game's spell window among them.
function ns.GameSpellsInTheWay(frame)
    local spells = _G.PlayerSpellsFrame
    if not (frame and spells and spells:IsVisible()) or frame:IsShown() then return false end
    local room, inRow = ns.RowRoomFor(frame)
    return inRow and room < 0
end

-- For an opener: the closer as a macro line, or as its secure click's target, while in the way; else none.
function ns.GameSpellsCloseLine(frame)
    if not ns.GameSpellsInTheWay(frame) or not Closer() then return "" end
    return "/click " .. CLOSER .. "\n"
end
function ns.GameSpellsCloser(frame)
    if not ns.GameSpellsInTheWay(frame) then return nil end
    return Closer()
end

function ns.OnGameSpellsRoom(fn) watchers[#watchers + 1] = fn end

local function Run()
    if InCombatLockdown() then return end
    for _, fn in ipairs(watchers) do ns.SafeCall(fn) end
end
-- A window of ours or the game's spell window shown or hidden: the openers set again next frame.
function ns.GameSpellsRoomChanged() ns.Sched.NextFrame("windows.gameSpellsRoom", Run) end

local watched = false
local function Watch()
    local spells = _G.PlayerSpellsFrame
    if watched or not spells then return end
    watched = true
    ns.Sched.OnVisible(spells, "windows.gameSpells", ns.GameSpellsRoomChanged)
    -- Its tab sets its width (one page, both pages, talents) while it shows.
    ns.Sched.Attach(spells, { name = "windows.gameSpells", every = 0.5, fn = Run })
end

ns.EventFrame({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }, function()
    Watch()
    ns.GameSpellsRoomChanged()
end)
