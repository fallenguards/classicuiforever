local _, ns = ...

-- Shown, on hover or hidden for the minimap's pieces (show<id>, hover<id>, hide<id>) and for the addon buttons on its
-- ring, each of which may hold a pick of its own over Addon buttons' (minimapButtonPicks, #194).

local MM = ns.MM

local ADDON_ID = "MinimapAddonButtons"
-- Our options button's key among the addon buttons' picks.
MM.OUR_BUTTON = "ForeverClassicUIMinimapButton"
local PICK_STATE = { show = false, hover = "hover", hide = "hide" }

-- "hide", "hover" or nil (shown).
function MM.ShowState(id)
    local db = ns.db
    if not id or not db then return nil end
    if db["hide" .. id] or (MM.closed and id ~= "MinimapZone") then return "hide" end
    if db["hover" .. id] then return "hover" end
end

-- A ring button's key in the picks: LibDBIcon's name for one of its own, else the frame's name.
function MM.AddonButtonKey(button)
    local name = button and button:GetName()
    return name and (name:gsub("^LibDBIcon10_", ""))
end

-- An addon button's state: its own pick, else Addon buttons'; all shown while the addon bag holds them.
function MM.AddonButtonState(key)
    local db = ns.db
    if not db or db.minimapCollector then return nil end
    local picks = db.minimapButtonPicks
    local own = PICK_STATE[type(picks) == "table" and key and picks[key] or ""]
    if own == nil or MM.closed then return MM.ShowState(ADDON_ID) end
    return own or nil
end

-- Frames shown only while the mouse is over the minimap or over them.
local hovering = {}
local hoverJob

local function HoverTick(job)
    if not next(hovering) then job:Sleep() return end
    local over = MinimapCluster and MinimapCluster:IsMouseOver()
    if not over then
        for frame in pairs(hovering) do
            if frame:IsVisible() and frame:IsMouseOver() then over = true break end
        end
    end
    -- Our ring button inside the addon bag stays lit there.
    for frame in pairs(hovering) do
        if not (ns.MinimapCollected and ns.MinimapCollected(frame)) then ns.FadeTo(frame, over and 1 or 0) end
    end
end

-- A client frame hidden under a hidden frame of ours: by alpha alone it still took the mouse and showed its tooltip, and
-- the client's own shows cannot reach it here. Its parent, strata and level back for any other choice.
local stash
local stashedFrom = setmetatable({}, { __mode = "k" })
local function Stash(frame, hide)
    local was = stashedFrom[frame]
    if hide and not was then
        if not stash then
            stash = CreateFrame("Frame")
            stash:Hide()
        end
        stashedFrom[frame] = { frame:GetParent(), frame:GetFrameStrata(), frame:GetFrameLevel() }
        frame:SetParent(stash)
    elseif not hide and was then
        stashedFrom[frame] = nil
        frame:SetParent(was[1])
        frame:SetFrameStrata(was[2])
        frame:SetFrameLevel(was[3])
    end
end

-- state: "hide", "hover" or nil (shown); client: a frame the client shows and hides itself (never shown from here).
function ns.MinimapShowAs(frame, state, client)
    if not frame then return end
    if client then
        Stash(frame, state == "hide")
    else
        ns.SetShownIf(frame, state ~= "hide")
    end
    hovering[frame] = state == "hover" or nil
    if state == nil then ns.FadeTo(frame, 1, nil, true) end
    if not next(hovering) or not MinimapCluster then return end
    hoverJob = hoverJob or ns.Sched.Job({ name = "minimap.hover", every = 0.1, awake = false, fn = HoverTick })
    hoverJob:Wake()
    HoverTick(hoverJob)
end

function ns.MinimapShow(frame, id, client)
    ns.MinimapShowAs(frame, MM.ShowState(id), client)
end
