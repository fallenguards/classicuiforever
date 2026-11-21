local _, ns = ...
local L = ns.L

-- The game's loot history window (/loot): the old frame as every dressed window, and sized both ways from its corner
-- (the game's handle sizes its height alone). The list runs to the right edge; the encounter pick and the roll timer
-- stay centred at the game's widths, as it fills the timer to a fixed width.

local P = ns.panels
local A = P.after

-- The game's own: 261 wide, 300 at the least, the list from 6 in and 90 down to 23 short of the right and 4 off the foot.
local GAME_W, MIN_H, GAME_H = 261, 300, 590
local LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_FOOT = 6, -90, 23, 4
local MAX_W, MAX_H = 1000, 1200
local GRIP_X, GRIP_Y = -5, 5
-- Over the rows (500) and the game's handle (600).
local GRIP_LEVEL = 610
-- An item name from its icon (the game's 6 right, 2 down) to 8 short of its row's right end.
local NAME_X, NAME_Y, NAME_RIGHT = 6, -2, 8

local ROWS_OWNER = {}
local TIP = { text = L["UI_RESIZE"], r = 1, g = 1, b = 1, lines = { { L["UI_RESIZE_TIP"], nil, nil, nil, true } } }

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- 0 is the game's own size.
local function SavedSize()
    local w, h = tonumber(ns.db.lootHistoryW) or 0, tonumber(ns.db.lootHistoryH) or 0
    if w > 0 and h > 0 then return Clamp(w, GAME_W, MAX_W), Clamp(h, MIN_H, MAX_H) end
end

local function KeepSize(frame)
    local w, h = frame:GetSize()
    ns.db.lootHistoryW, ns.db.lootHistoryH = w, h
end

local function GameSize(frame)
    ns.db.lootHistoryW, ns.db.lootHistoryH = 0, 0
    frame:SetSize(GAME_W, tonumber(frame.panelMaxHeight) or GAME_H)
end

-- A drop's name runs to its row's right end, the row as wide as the list (passed headers have none).
local function WideName(row)
    local name, item = row and row.ItemName, row and row.Item
    if not (name and item) then return end
    ns.SetTwoPointsIf(name, "TOPLEFT", item, "TOPRIGHT", NAME_X, NAME_Y, "TOPRIGHT", row, "TOPRIGHT", -NAME_RIGHT, NAME_Y)
end

local function Grip(frame)
    local grip = ns.GripButton(frame)
    grip:SetFrameLevel(GRIP_LEVEL)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", GRIP_X, GRIP_Y)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT", true) end
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        frame:StopMovingOrSizing()
        KeepSize(frame)
    end)
    grip:SetScript("OnClick", function() GameSize(frame) end)
    ns.AttachTip(grip, TIP)
end

local function Sizing(frame)
    frame:SetResizeBounds(GAME_W, MIN_H, MAX_W, MAX_H)
    local box = frame.ScrollBox
    if box then
        ns.SetTwoPointsIf(box, "TOPLEFT", frame, "TOPLEFT", LIST_LEFT, LIST_TOP, "BOTTOMRIGHT", frame, "BOTTOMRIGHT",
            -LIST_RIGHT, LIST_FOOT)
        box:ForEachFrame(WideName)
        -- Our own owner: the list's callbacks are kept one per owner, a game owner's would be replaced.
        box:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, row) WideName(row) end, ROWS_OWNER)
    end
    -- Ours sizes both ways from the corner; the game's own bottom handle stays, unseen and unclickable.
    local handle = frame.ResizeButton
    if handle then
        handle:SetAlpha(0)
        handle:EnableMouse(false)
    end
    Grip(frame)
    local w, h = SavedSize()
    if w then frame:SetSize(w, h) end
end

-- The flat panel's backing is a frame of its own, over our stone.
function A.GroupLootHistoryFrame(frame)
    if frame.Bg then frame.Bg:SetAlpha(0) end
    ns.SkinCloseButton(frame.ClosePanelButton)
    ns.SkinDropdown(frame.EncounterDropdown)
    if ns.Once(frame, "lootHistorySizing") then Sizing(frame) end
end
