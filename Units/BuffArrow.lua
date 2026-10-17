local _, ns = ...

-- Buff collapse arrow (1.x had none): shown, on hover or hidden (one drop down, #190). Alpha 0, not hidden, no BuffFrame
-- calls (it handles secret values).

local arrowHidden = false
local arrowJob, watch
-- The arrow's hover sensor took (Sched.OnHover): no mouse polling.
local sensed = false
-- The alpha we last wrote: the client only shows and hides the arrow (BuffFrame.lua 693, 705, 858), never its alpha.
local shownAlpha

local function Arrow()
    return BuffFrame and BuffFrame.CollapseAndExpandButton
end

-- On hover it shows under the mouse. Hidden it never shows and takes no click, but while the buffs are folded (the
-- arrow unchecked) the mouse still finds it: they would have no way back. Unseen, it has no hover to test.
local function SetBuffArrow(hidden)
    local button = Arrow()
    if not button then return end
    local gone = hidden and ns.db.buffArrowHidden == true and button:GetChecked() == true
    local alpha = 1
    if gone or (hidden and not (button:IsVisible() and button:IsMouseOver(6, -6, -6, 6))) then alpha = 0 end
    if button:IsMouseEnabled() == gone then button:EnableMouse(not gone) end
    if alpha == shownAlpha then return end
    ns.SetAlphaIf(button, alpha, 0.01)
    shownAlpha = alpha
end

-- Runs only while the arrow shows and is hidden: the mouse and the fold are all that change.
local function ArrowPass()
    if arrowHidden then SetBuffArrow(true) end
end

-- Sole writer of the job's wake: awake exactly while the arrow shows and is hidden.
local function Refresh()
    local button = Arrow()
    if arrowHidden and button and button:IsVisible() and not sensed then
        if arrowJob then
            arrowJob:Wake()
        else
            arrowJob = ns.Sched.Job({ name = "buffArrow", every = 0.05, fn = ArrowPass })
        end
    elseif arrowJob then
        arrowJob:Sleep()
    end
end

local function Settle()
    Refresh()
    if arrowHidden then SetBuffArrow(true) end
end

-- It shows and hides inside the client's aura pass: our part waits for the next frame.
local function Edge()
    ns.Sched.NextFrame("buffArrow", Settle)
end

-- Sole writer of arrowHidden.
local function SetArrowHidden(on)
    arrowHidden = on
    -- Still clicks in both modes; the client never writes its mouse.
    local button = Arrow()
    if button then
        button:EnableMouse(true)
        -- A pure child: its OnShow/OnHide run only on the arrow's own visibility edges.
        if not watch then
            watch = CreateFrame("Frame", nil, button)
            watch:SetScript("OnShow", Edge)
            watch:SetScript("OnHide", Edge)
            sensed = ns.Sched.OnHover(button, ArrowPass, 6)
        end
    end
    Refresh()
end

local function HandBack()
    if not arrowHidden then return end
    SetArrowHidden(false)
    SetBuffArrow(false)
end

-- The pick: the game's own arrow, or ours on hover or hidden.
local function Sync()
    if ns.db.buffArrowShown == true then return HandBack() end
    SetArrowHidden(true)
    SetBuffArrow(true)
end

-- A pick turns at once, in a fight too (the options pass waits one out).
local PICKS = { buffArrowShown = true, buffArrowHover = true, buffArrowHidden = true }
ns.OnToggle(function(key)
    if PICKS[key] then Sync() end
end)

-- dbVersion 19: Hide buff arrow became this drop down; unticked, it picks shown (the account and every profile).
function ns.BuffArrowChoice()
    local db = ns.db
    local function Pick(t)
        if t.hideBuffArrow == false then t.buffArrowShown, t.buffArrowHover = true, false end
        t.hideBuffArrow = nil
    end
    Pick(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Pick(shot) end
    end
end

ns.RegisterModule("buffArrow", { apply = Sync, restore = HandBack })
