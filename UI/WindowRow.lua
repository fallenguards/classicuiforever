local _, ns = ...

-- The row our windows stand in, from plain numbers (UI/Windows.lua gathers them; tools/tests run it alone): the game's
-- windows stay where the game put them, ours stand past the last in the order opened, a held one where it is.

local lefts, rights = {}, {}   -- blocks laid so far this pass: held ones first, then each placed
local closed = {}              -- index -> true while left out to make room

-- A game window across nearly the whole screen (the maximized map): nothing stands past it, so it is left out.
local SCREEN_WIDE = 0.9

-- Past the game's last window, but one it shares a place with or a screen-wide one. A window too big to share the
-- screen with (Forever's spell window) still counts: the one past it is pulled back to the edge, over it.
local function GameEnd(s, shares)
    local x = s.start
    for _, block in ipairs(s.game) do
        local right = block[2]
        if right > x and right - block[1] < s.screen * SCREEN_WIDE and not (shares and shares[block[3]]) then x = right end
    end
    return x
end

local function FirstFree(x, width, n)
    local moved = true
    while moved do
        moved = false
        for i = 1, n do
            if x < rights[i] and lefts[i] < x + width then
                x = rights[i]
                moved = true
            end
        end
    end
    return x
end

-- One pass with the closed ones left out; returns the first placed one that runs off the screen.
local function Lay(s, out)
    local n = 0
    for i, w in ipairs(s.ours) do
        if w.held and not closed[i] then
            n = n + 1
            lefts[n], rights[n] = w.held, w.held + w.width
        end
    end
    local cursor, over = s.start, nil
    for i, w in ipairs(s.ours) do
        local x
        if w.held and not closed[i] then
            x = w.held
        elseif not closed[i] then
            x = math.max(cursor, GameEnd(s, w.shares), w.keep or cursor)
            -- Whole units, rounded up: a game window's fractional edge (a centering addon's) is never overlapped.
            x = math.ceil(FirstFree(x, w.width, n) - 0.01)
            n = n + 1
            lefts[n], rights[n] = x, x + w.width
            cursor = x + w.width
            if not over and x + w.drawn > s.screen then over = i end
        end
        out.x[i] = x
    end
    return over
end

-- The oldest placed one standing before the one that ran off: closing it makes room. With a game window opened after all
-- of ours (gameLast) the one that ran off may close too: the newest window is the game's. None in a stay pass.
local function Oldest(s, over)
    if s.stay then return nil end
    for i = 1, s.gameLast and over or over - 1 do
        if not closed[i] and not s.ours[i].held then return i end
    end
end

-- s: start, screen, stay (nothing closes), gameLast, game = { { left, right, name } }, ours = { { width, drawn, held,
-- shares, keep } } oldest first. Fills out.x[i] (nil: closing) and out.close (indexes, oldest first).
function ns.SolveWindowRow(s, out)
    out.x, out.close = out.x or {}, out.close or {}
    for i in pairs(out.x) do out.x[i] = nil end
    for i in pairs(out.close) do out.close[i] = nil end
    for i in pairs(closed) do closed[i] = nil end
    while true do
        local over = Lay(s, out)
        if not over then break end
        local oldest = Oldest(s, over)
        if not oldest then
            -- No room to make: back on the screen, over its neighbor.
            for i, w in ipairs(s.ours) do
                local x = out.x[i]
                if x and not w.held and x + w.drawn > s.screen then out.x[i] = math.max(0, math.floor(s.screen - w.drawn)) end
            end
            break
        end
        closed[oldest] = true
        out.close[#out.close + 1] = oldest
    end
    return out
end

-- Past everything in a solved row (the loot window on its own spot).
function ns.WindowRowEnd(s, out)
    local finish = GameEnd(s, nil)
    for i, w in ipairs(s.ours) do
        local x = out.x[i]
        if x and x + w.width > finish then finish = x + w.width end
    end
    return finish
end
