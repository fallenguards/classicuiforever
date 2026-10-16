local _, ns = ...
local L = ns.L

-- Another addon holding the action bars: it parks the game's main bar under a hidden frame of its own, where the game
-- never moves it. The classic bar's pieces then stand down (barPiece modules, Core's Runs), their option rows gray,
-- a popup says so once, and a chat line at each login until its own toggle is turned off (its link opens that row).

-- Option rows of the pieces standing down; rows under them follow.
local PIECE_ROWS = { classicBar = true, buttons = true, castAnim = true, hideMicroButtons = true,
    hideBagsAlways = true, hideBagsOpen = true, hideBagsHover = true, bagsBackpackOnly = true }

function ns.BarsTaken()
    local bar = MainActionBar
    local parent = bar and bar:GetParent()
    return parent ~= nil and parent ~= UIParent and not parent:IsShown()
end

local parentOf
function ns.BarRowHeld(key)
    if not ns.BarsTaken() then return false end
    if not parentOf then
        parentOf = {}
        for _, entry in ipairs(ns.TOGGLES or {}) do parentOf[entry[1]] = entry.parent end
    end
    for _ = 1, 8 do
        if not key then return false end
        if PIECE_ROWS[key] then return true end
        key = parentOf[key]
    end
    return false
end

ns.Popup("FCUI_BARS_TAKEN", { text = L["BARS_TAKEN"], button1 = OKAY or "Okay", button2 = false })

local function Tell()
    local db = ns.db
    if not (db and ns.BarsTaken()) or db.classicBar == false or db.addonMessages == false then return end
    if db.barsTakenNote ~= false then
        ns.Print(L["BARS_TAKEN"] .. " " .. string.format(L["BARS_TAKEN_OFF"], ns.ChatLink("barsnote", L["WELCOME_HERE"])))
    end
    if db.barsTakenSaid then return end
    db.barsTakenSaid = true
    StaticPopup_Show("FCUI_BARS_TAKEN")
end

ns.EventFrame("PLAYER_ENTERING_WORLD", function(_, _, login, reload)
    if login or reload then ns.Sched.AfterPerFrame("bars.taken", 3, Tell) end
end)
