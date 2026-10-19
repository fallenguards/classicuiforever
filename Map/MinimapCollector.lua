local _, ns = ...
local L = ns.L

-- Addon button collector (minimapCollector): other addons' minimap buttons (LibDBIcon's, and named map buttons with
-- "minimap" in the name) moved into a pop-out grid behind one ring button, and handed back where they were as it turns off.

-- PAD clears the dialog border.
local COLS, CELL, PAD = 5, 34, 16
local BAG_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
-- Named map buttons that are no addon's. Ours stay on the ring (the micro icons, this button); only the options button
-- joins, by name below.
local NOT_ADDONS = { ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true }
local OUR_PREFIX = "^ForeverClassicUI"
local OURS = ns.MM.OUR_BUTTON
-- Over the pop-out's backing, which is a frame at the pop-out's own level.
local ABOVE_BACKING = 5
-- Every button drawn this wide, whatever size its addon gave it.
local ICON = 31

local collected = {}   -- button -> { parent, points, lib name } it had
local order = {}       -- collected buttons in grid order
local popout
local active = false

local function DBIcon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

local function FitScale(button)
    local width = button:GetWidth()
    return (width and width > 0) and ICON / width or 1
end

-- Into the pop-out, one size, above the backing, full alpha; again whenever its addon or a refresh undid any of it.
local function Pocket(button)
    -- Their drag pulls a button back round the map.
    button:RegisterForDrag()
    if button:GetParent() ~= popout then button:SetParent(popout) end
    -- LibDBIcon pins its buttons at MEDIUM 8: under the backing they drew dim (#168).
    if button:HasFixedFrameStrata() then button:SetFixedFrameStrata(false) end
    if button:HasFixedFrameLevel() then button:SetFixedFrameLevel(false) end
    ns.SetStrataIf(button, popout:GetFrameStrata())
    ns.SetLevelIf(button, popout:GetFrameLevel() + ABOVE_BACKING)
    ns.SetScaleIf(button, FitScale(button))
    -- LibDBIcon fades show-on-hover buttons as the mouse leaves the map, which the pop-out is not: off while collected.
    button.showOnMouseover = false
    if button.fadeOut and button.fadeOut:IsPlaying() then button.fadeOut:Stop() end
    ns.SetAlphaIf(button, 1)
    ns.ThemeAddonRing(button)
end

local function Take(button, libName)
    if not button then return end
    if collected[button] then
        if button:GetParent() ~= popout then Pocket(button) end
        return
    end
    local record = { parent = button:GetParent(), lib = libName, points = {}, strata = button:GetFrameStrata(),
        level = button:GetFrameLevel(), scale = button:GetScale(), mouseover = button.showOnMouseover,
        fixedStrata = button:HasFixedFrameStrata(), fixedLevel = button:HasFixedFrameLevel() }
    for i = 1, button:GetNumPoints() do record.points[i] = { button:GetPoint(i) } end
    collected[button] = record
    order[#order + 1] = button
    Pocket(button)
end

-- The minimap's own pass leaves these alone (it refreshes LibDBIcon's onto its ring).
function ns.MinimapCollected(button)
    return active and button ~= nil and collected[button] ~= nil
end

-- Minimap children no addon's button by name or type, never looked at again (the sweep runs every frame).
local notAddon = setmetatable({}, { __mode = "k" })

local function NamedAddonButton(child)
    if notAddon[child] then return false end
    local name = child.GetName and child:GetName()
    if not name or NOT_ADDONS[name] or name:find(OUR_PREFIX) or name:find("^[Mm]ini[Mm]ap")
        or not name:lower():find("minimap", 1, true) or not child:IsObjectType("Button") then
        notAddon[child] = true
        return false
    end
    return true
end

local function TakeNamed(child)
    if NamedAddonButton(child) and child:IsShown() then Take(child) end
end

-- Other addons' ring buttons (LibDBIcon's and named map buttons), ours and the collected ones left out.
local function VisitNamed(child, fn)
    if NamedAddonButton(child) and not ns.MinimapCollected(child) then fn(child) end
end
function ns.EachAddonRingButton(fn)
    local lib = DBIcon()
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        for _, name in ipairs(lib:GetButtonList()) do
            local button = lib:GetMinimapButton(name)
            if button and not ns.MinimapCollected(button) then fn(button) end
        end
    end
    if Minimap then ns.EachChild(Minimap, VisitNamed, fn) end
end

-- Their Shown / On hover / Hidden on our ring, each its own or Addon buttons' (#194): one never touched is left as its
-- addon shows it (it may fade it itself), one we hid or faded is given back.
local ringPicked = setmetatable({}, { __mode = "k" })
local known = setmetatable({}, { __mode = "k" })    -- every addon button seen on the ring -> its key in the picks
local ringListener
local function Know(button)
    known[button] = known[button] or ns.MM.AddonButtonKey(button)
end
local function RingButtonShow(button)
    Know(button)
    local state = ns.MM.AddonButtonState(known[button])
    if state == nil and not ringPicked[button] then return end
    ringPicked[button] = state ~= nil or nil
    ns.MinimapShowAs(button, state, true)
end

-- A list's name for a button: its frame name's minimap words cut off.
local function Label(key)
    local short = key:gsub("_?[Mm]ini[Mm]ap_?[Bb]utton$", ""):gsub("_?[Mm]ini[Mm]ap$", "")
    return short ~= "" and short or key
end
local function ByLabel(a, b) return a.label:lower() < b.label:lower() end

-- The buttons Addon buttons' list offers: ours first while it is on, then each seen one its addon shows, by name.
function ns.AddonRingButtons()
    local list = {}
    for button, key in pairs(known) do
        if key and button:IsShown() and not ns.MinimapCollected(button) then
            list[#list + 1] = { key = key, label = Label(key) }
        end
    end
    table.sort(list, ByLabel)
    if ns.db.minimapButton then table.insert(list, 1, { key = ns.MM.OUR_BUTTON, label = L["MAP_CLASSICUI_FOREVER"] }) end
    return list
end

-- The minimap's pass (Map/Minimap.lua); a LibDBIcon button made later takes the pick as it comes.
function ns.ShowAddonRingButtons()
    ns.EachAddonRingButton(Know)
    -- Every one seen: a named button we hid sits under our stash, off the map's children.
    for button in pairs(known) do
        if not ns.MinimapCollected(button) then RingButtonShow(button) end
    end
    local lib = DBIcon()
    if ringListener or not (lib and lib.RegisterCallback) then return end
    ringListener = {}
    lib.RegisterCallback(ringListener, "LibDBIcon_IconCreated", function(_, button)
        if ns.MM.active and not ns.MinimapCollected(button) then RingButtonShow(button) end
    end)
end

-- Our minimap off: every button we hid or faded given back.
function ns.AddonRingButtonsBack()
    for button in pairs(ringPicked) do
        ns.MinimapShow(button, nil, true)
        ringPicked[button] = nil
    end
end

-- Named map buttons, which LibDBIcon says nothing of, and our options button.
local function ScanNamed()
    if Minimap then ns.EachChild(Minimap, TakeNamed) end
    local ours = _G[OURS]
    if ours and ours:IsShown() then Take(ours) end
end

local function Scan()
    local lib = DBIcon()
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        for _, name in ipairs(lib:GetButtonList()) do
            local button = lib:GetMinimapButton(name)
            if button and not (button.db and button.db.hide) then Take(button, name) end
        end
    end
    ScanNamed()
end

-- Shown buttons only: an addon may hide its own. Offsets are in the button's own scale.
local function Layout()
    local shown = 0
    for _, button in ipairs(order) do
        Pocket(button)
        if button:IsShown() then
            local col, row = shown % COLS, math.floor(shown / COLS)
            local scale = button:GetScale() or 1
            ns.SetPointOnce(button, "CENTER", popout, "TOPLEFT", (PAD + (col + 0.5) * CELL) / scale,
                -(PAD + (row + 0.5) * CELL) / scale)
            shown = shown + 1
        end
    end
    local cols, rows = math.max(1, math.min(COLS, shown)), math.max(1, math.ceil(shown / COLS))
    popout:SetSize(math.max(cols * CELL + PAD * 2, shown == 0 and 150 or 0), rows * CELL + PAD * 2)
    popout.empty:SetShown(shown == 0)
end

local function Popout()
    if popout then return popout end
    popout = CreateFrame("Frame", "ForeverClassicUIMinimapBag", UIParent)
    popout:SetFrameStrata("HIGH")
    popout:SetClampedToScreen(true)
    ns.DialogBacking(popout)
    popout.empty = popout:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    popout.empty:SetPoint("CENTER")
    popout.empty:SetText(L["MAP_NO_ADDON_BUTTONS"])
    popout:Hide()
    ns.CloseOnEscape(popout)
    -- A press anywhere else closes it; one on the ring button is left to its toggle.
    ns.RegisterEvents(popout, { "GLOBAL_MOUSE_DOWN" })
    popout:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        if self.owner and self.owner:IsMouseOver() then return end
        self:Hide()
    end)
    -- While open, whatever an addon does to its button (level, size, fade, anchor back on the map) is undone.
    ns.Sched.Attach(popout, { name = "minimapBag", every = 0.25, fn = function() Layout() end })
    return popout
end

local function Toggle(ringButton)
    if popout:IsShown() then
        popout:Hide()
        return
    end
    Scan()
    Layout()
    popout.owner = ringButton
    ns.SetPointOnce(popout, "TOPRIGHT", ringButton, "BOTTOMLEFT", 6, 6)
    popout:Show()
end

local ShowRing, HideRing = ns.RingButton({
    name = "ForeverClassicUIMinimapCollector",
    key = "minimapAddonBag",
    angleKey = "minimapCollectorAngle",
    angle = 238,   -- left of the clock; the nearest clear spot when a button stands there
    free = true,
    show = "AddonBag",
    face = function(icon)
        icon:SetTexture(BAG_ICON)
        ns.Dress(icon, nil, ns.RING_ICON_FACE)
    end,
    onClick = function(self) Toggle(self) end,
    tip = { anchor = "ANCHOR_LEFT", text = L["MAP_ADDON_BUTTONS"], r = 1, g = 1, b = 1, lines = {
        { L["MAP_LEFT_CLICK_THE_OTHER_ADDONS"], 0.8, 0.8, 0.8 },
        { L["MAP_DRAG_TO_MOVE_AROUND_THE"], 0.8, 0.8, 0.8 },
    } },
})

-- Every button back on its parent and points; LibDBIcon puts its own back in place.
local function Release()
    local lib = DBIcon()
    for i = #order, 1, -1 do
        local button = order[i]
        local record = collected[button]
        button:SetParent(record.parent)
        button:SetFrameStrata(record.strata)
        button:SetFrameLevel(record.level)
        button:SetFixedFrameStrata(record.fixedStrata)
        button:SetFixedFrameLevel(record.fixedLevel)
        button:SetScale(record.scale or 1)
        button:ClearAllPoints()
        for _, point in ipairs(record.points) do button:SetPoint(unpack(point)) end
        button:RegisterForDrag("LeftButton")
        button.showOnMouseover = record.mouseover
        if record.lib and lib and lib.Refresh then pcall(lib.Refresh, lib, record.lib) end
        collected[button], order[i] = nil, nil
    end
end

-- A button made later joins at once (LibDBIcon says so); others on the next opening.
local listener
local function Listen()
    local lib = DBIcon()
    if listener or not (lib and lib.RegisterCallback) then return end
    listener = {}
    lib.RegisterCallback(listener, "LibDBIcon_IconCreated", function(_, button, name)
        if not active then return end
        Take(button, name)
        if popout:IsShown() then Layout() end
    end)
end

-- The minimap's pass: a button its addon moved back onto the map goes back in the bag.
function ns.OnMinimapLaid()
    if not active then return end
    for _, button in ipairs(order) do
        if button:GetParent() ~= popout then Pocket(button) end
    end
    -- Buttons made since the last sweep (addons that make theirs late, outside LibDBIcon).
    Scan()
end

-- Addons make their map buttons for a while after login, most outside LibDBIcon's word (one 0.6 s in): swept every frame
-- for the first 30 s the bag is on, so none stands on the map first (every 2 s showed them); then on the map's passes.
local SWEEP_FOR = 30
local sweepJob, sweepUntil
local function Sweep(job)
    if not active or GetTime() > sweepUntil then
        job:Sleep()
        return
    end
    local before = #order
    ScanNamed()
    if #order > before and popout:IsShown() then Layout() end
end

-- Every pass calls this: the sweep as it turns on, then for a while (and on each opening).
local function Apply()
    Popout()
    if not active then
        active = true
        -- Our ring's hidden or faded ones back on the map first: a hidden one is under our stash, out of the scan's sight.
        ns.AddonRingButtonsBack()
        Scan()
        Listen()
        sweepUntil = GetTime() + SWEEP_FOR
        if sweepJob then sweepJob:Wake() else sweepJob = ns.Sched.Job({ name = "minimapBag.sweep", every = 0, fn = Sweep }) end
    end
    ShowRing()
end

local function Restore()
    if not active then return end
    active = false
    popout:Hide()
    Release()
    HideRing()
end

ns.RegisterModule("minimapCollector", { apply = Apply, restore = Restore })

-- The saved default (132) stood on the group finder eye: one never dragged takes a clear spot, in the account and
-- every profile. Runs before the defaults fill.
function ns.FreeAddonBag()
    local db = ns.db
    if db.minimapCollectorAngle == 132 then db.minimapCollectorAngle = nil end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" and shot.minimapCollectorAngle == 132 then shot.minimapCollectorAngle = nil end
    end
    db.dbVersion = 13
end
