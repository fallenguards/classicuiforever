local _, ns = ...
if ns.OnForever() then return end

-- Retail's professions book is a window of its own (ProfessionsBookFrame): the old book's rows, art and foot tabs on it,
-- the small 1.x book or the full one (Skills/ProfessionsBook.lua, shared with Forever). Its cards cast, so all of it is
-- placed out of combat; a book first met in a fight stays the game's until the fight ends.

local T = ns.prof
local GAME_ART = { "ProfessionsBookPage1", "ProfessionsBookPage2" }
local EVENTS = { "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SKILL_LINES_CHANGED", "SPELLS_CHANGED" }

local state = { active = false, placed = false, dirty = true }

local function Fit(frame)
    local width, height = T.BookW(), T.BookH()
    if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
        frame:SetSize(width, height)
    end
end

-- The game's own pages and inset go under ours.
local function FadeGameArt(frame)
    for _, name in ipairs(GAME_ART) do
        if _G[name] then ns.SetAlphaIf(_G[name], 0) end
    end
    if frame.Inset then ns.SetAlphaIf(frame.Inset, 0) end
end

local function Pass()
    local frame = _G.ProfessionsBookFrame
    if not frame or not state.active then return end
    if not InCombatLockdown() then
        if not T.built then T.Build() end
        if not T.built then return end
        Fit(frame)
        FadeGameArt(frame)
        T.SmallFrame(not T.Big())
        if state.dirty or not state.placed then
            state.placed = T.PlaceCards() or state.placed
            state.dirty = false
        end
        -- The tabs' pads are secure: made and placed out of combat.
        state.sizeButton(true)
        T.BookTabs()
    end
    if not T.built then return end
    T.FillRows()
    T.ShowOurs(state.placed)
end

local watch
local function Changed()
    state.dirty = true
    local frame = _G.ProfessionsBookFrame
    if not frame then return end
    -- While it shows: the book's size and tabs follow the options.
    ns.Sched.Attach(frame, { name = "professions.retailBook", every = 0.1, fn = Pass })
    Pass()
end

-- From the module (Skills/ProfessionsWindow.lua): on or off, and its size button.
function T.RetailBook(on, sizeButton)
    state.active, state.sizeButton = on, sizeButton
    if not on then
        if T.built then T.ShowOurs(false) end
        return
    end
    watch = watch or ns.EventFrame(EVENTS, Changed)
    Changed()
end

ns.OnToggle(function(key)
    if key == "profBookBig" or key == "profBookBands" then Changed() end
end)
