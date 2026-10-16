local _, ns = ...
local L = ns.L

-- The totem bar laid as the stance bar is (#179), under the game's edit mode dialog, room kept for unlearned totems.
-- The game's own layout at the defaults. Secure buttons: laid out of combat only, and again after each client re-place
-- of the first slot and Totemic Recall (spell changes).

local MARGIN, BUTTON, PAGES, SLOTS = 3, 30, 3, 4
local NATIVE_W, NATIVE_H, NATIVE_GAP = 230, 38, 8
local DEFAULTS = { totemOrientation = "horizontal", totemRows = 1, totemSize = 100, totemPadding = 8, totemKeepRoom = false }
local EVENTS = { "PLAYER_ENTERING_WORLD", "UPDATE_MULTI_CAST_ACTIONBAR", "SPELLS_CHANGED" }
local taken = false
local cells = {}   -- this lay's cells: a slot index, or the summon or recall button
local watch

local function AtDefaults()
    for key, value in pairs(DEFAULTS) do
        if ns.db[key] ~= value then return false end
    end
    return true
end

local function Put(button, point, x, y, scale)
    ns.SetScaleIf(button, scale, 0.001)
    -- Offsets count in the button's own scale.
    ns.SetPointOnce(button, point, _G.MultiCastActionBarFrame, "TOPLEFT", x / scale, y / scale)
end

local function Cells(keepRoom)
    wipe(cells)
    local summon, recall = _G.MultiCastSummonSpellButton, _G.MultiCastRecallSpellButton
    if keepRoom or summon:IsShown() then cells[#cells + 1] = summon end
    for i = 1, SLOTS do
        if keepRoom or _G["MultiCastSlotButton" .. i]:IsShown() then cells[#cells + 1] = i end
    end
    if keepRoom or recall:IsShown() then cells[#cells + 1] = recall end
    return cells
end

-- The game's own anchors (MultiCastActionBarFrame.xml, and where its updates put the first slot and recall).
local function GiveBack()
    local bar = _G.MultiCastActionBarFrame
    local summon, recall = _G.MultiCastSummonSpellButton, _G.MultiCastRecallSpellButton
    summon:SetScale(1)
    recall:SetScale(1)
    ns.SetPointOnce(summon, "BOTTOMLEFT", bar, "BOTTOMLEFT", MARGIN, MARGIN)
    local first = summon:IsShown() and summon:GetWidth() + NATIVE_GAP + MARGIN or MARGIN
    for i = 1, SLOTS do
        local slot = _G["MultiCastSlotButton" .. i]
        slot:SetScale(1)
        if i == 1 then
            ns.SetPointOnce(slot, "BOTTOMLEFT", bar, "BOTTOMLEFT", first, MARGIN)
        else
            ns.SetPointOnce(slot, "LEFT", _G["MultiCastSlotButton" .. (i - 1)], "RIGHT", NATIVE_GAP, 0)
        end
        for page = 0, PAGES - 1 do
            local index = i + page * SLOTS
            local button = _G["MultiCastActionButton" .. index]
            button:SetScale(1)
            local previous = i == 1 and _G["MultiCastActionPage" .. (page + 1)] or _G["MultiCastActionButton" .. (index - 1)]
            ns.SetPointOnce(button, "LEFT", previous, i == 1 and "LEFT" or "RIGHT", i == 1 and 0 or NATIVE_GAP, 0)
        end
    end
    local active = tonumber(bar.numActiveSlots) or 0
    local last = active > 0 and _G["MultiCastSlotButton" .. active] or _G.MultiCastActionButton4
    ns.SetPointOnce(recall, "LEFT", last, "RIGHT", NATIVE_GAP, 0)
    bar:SetSize(NATIVE_W, NATIVE_H)
    taken = false
end

local function Lay()
    local bar = _G.MultiCastActionBarFrame
    if not (bar and ns.db) then return end
    if InCombatLockdown() then return ns.WhenCalm("totemBar", Lay) end
    if AtDefaults() then
        if taken then GiveBack() end
        return
    end
    local list = Cells(ns.db.totemKeepRoom == true)
    local count = #list
    if count == 0 then return end
    local scale = ns.db.totemSize / 100
    local cell, pad = BUTTON * scale, ns.db.totemPadding
    local lines = math.min(ns.db.totemRows, count)
    local perLine = math.ceil(count / lines)
    local vertical = ns.db.totemOrientation == "vertical"
    for k, entry in ipairs(list) do
        local along, across = (k - 1) % perLine, math.floor((k - 1) / perLine)
        local col, row = along, across
        if vertical then col, row = across, along end
        local x, top = MARGIN + col * (cell + pad), MARGIN + row * (cell + pad)
        -- Recall by its LEFT and the first slot by its BOTTOMLEFT: the points the client sets them by, so its own
        -- re-place swaps ours out instead of stretching the button.
        if entry == _G.MultiCastRecallSpellButton then
            Put(entry, "LEFT", x, -(top + cell / 2), scale)
        elseif type(entry) == "number" then
            Put(_G["MultiCastSlotButton" .. entry], "BOTTOMLEFT", x, -(top + cell), scale)
            for page = 0, PAGES - 1 do
                Put(_G["MultiCastActionButton" .. (entry + page * SLOTS)], "BOTTOMLEFT", x, -(top + cell), scale)
            end
        else
            Put(entry, "BOTTOMLEFT", x, -(top + cell), scale)
        end
    end
    local wide, tall = perLine, lines
    if vertical then wide, tall = lines, perLine end
    bar:SetSize(2 * MARGIN + wide * cell + (wide - 1) * pad, 2 * MARGIN + tall * cell + (tall - 1) * pad)
    taken = true
end

-- The client's updates first, then ours; events only while a setting is off its default.
local function LaySoon() ns.Sched.NextFrame("totemBar.lay", Lay) end
local function Watch()
    local on = not AtDefaults()
    if on and not watch then watch = ns.EventFrame(EVENTS, LaySoon) end
    if watch and (on ~= (watch.on == true)) then
        if on then ns.RegisterEvents(watch, EVENTS) else watch:UnregisterAllEvents() end
    end
    if watch then watch.on = on end
end

local function SetTotem(key, value)
    ns.db[key] = value
    Watch()
    Lay()
end

local ORIENTATIONS = {
    { value = "horizontal", text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_HORIZONTAL },
    { value = "vertical", text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_VERTICAL },
}
local function Percent(value) return string.format("%d%%", math.floor(value + 0.5)) end

ns.DialogExtra({
    title = L["MAP_CLASSICUI_FOREVER"],
    match = function(system) return system ~= nil and system == _G.MultiCastActionBarFrame end,
    build = function(panel)
        panel.orientation = ns.DialogExtraDrop(panel, _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION, ORIENTATIONS,
            function() return ns.db.totemOrientation end, function(value)
                SetTotem("totemOrientation", value)
                panel.rowsLabel:SetText(value == "vertical" and _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_COLUMNS
                    or _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS)
            end)
        panel.rowSlider, panel.rowsLabel = ns.DialogExtraSlider(panel, _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS,
            function() return ns.db.totemRows, 1, 4, 3 end, function(value) SetTotem("totemRows", math.floor(value + 0.5)) end)
        panel.size = ns.DialogExtraSlider(panel, _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_SIZE,
            function() return ns.db.totemSize, 50, 200, 15 end,
            function(value) SetTotem("totemSize", math.floor(value / 10 + 0.5) * 10) end, Percent)
        panel.padding = ns.DialogExtraSlider(panel, _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_PADDING,
            function() return ns.db.totemPadding, 2, 10, 8 end,
            function(value) SetTotem("totemPadding", math.floor(value + 0.5)) end)
        panel.keepRoom = ns.DialogExtraCheck(panel, L["TOTEM_KEEP_ROOM"], function() return ns.db.totemKeepRoom end,
            function(on) SetTotem("totemKeepRoom", on) end)
    end,
    fill = function(panel)
        panel.orientation()
        panel.rowsLabel:SetText(ns.db.totemOrientation == "vertical" and _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_COLUMNS
            or _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS)
        panel.rowSlider()
        panel.size()
        panel.padding()
        panel.keepRoom()
    end,
})

ns.EventFrame("PLAYER_LOGIN", function()
    if not _G.MultiCastActionBarFrame then return end
    Watch()
    LaySoon()
end)
