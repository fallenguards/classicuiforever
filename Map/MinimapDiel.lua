local _, ns = ...

-- Era's day/night picture (sun or moon in its ringed 50 x 50 of UI-TOD-Indicator) over the game's, which fades under it
-- and stays on top for its tooltip and click. Day and night are the game's own cycle, as its picture follows, not the
-- realm clock.

local MM = ns.MM

local TOD_FILE = "Interface\\Minimap\\UI-TOD-Indicator"
local TOD_SIZE = 50
local DIEL_EVENTS = { "DIEL_CYCLE_CHANGED", "PLAYER_ENTERING_WORLD" }

local function TimeOfDay()
    local api = C_DateAndTime
    local day = not (api and api.IsDayTime) or api.IsDayTime()
    local x = day and 0 or 0.5
    MM.tod:SetTexCoord(x, x + TOD_SIZE / 128, 0, TOD_SIZE / 64)
end

-- home: the day/night's home of ours (Map/Minimap.lua), its picture on it.
function MM.EraDiel(diel, home)
    local tod = MM.tod
    if not tod then
        tod = home:CreateTexture(nil, "ARTWORK")
        tod:SetTexture(TOD_FILE)
        tod:SetSize(TOD_SIZE, TOD_SIZE)
        tod:SetPoint("CENTER", home, "CENTER", 0, 0)
        MM.tod = tod
        MM.todWatch = ns.EventFrame(DIEL_EVENTS, TimeOfDay)
    elseif not MM.todWatching then
        ns.RegisterEvents(MM.todWatch, DIEL_EVENTS)
    end
    MM.todWatching = true
    tod:Show()
    TimeOfDay()
    ns.FadeTextures(diel)
end

-- Our minimap off: the game's own picture back.
function MM.EraDielOff(diel)
    if not MM.tod then return end
    MM.tod:Hide()
    MM.todWatch:UnregisterAllEvents()
    MM.todWatching = false
    ns.FadeTextures(diel, 1)
end
