local _, ns = ...
local B = ns.band
local L = ns.L

-- Each action bar's Faded Opacity, under its own edit mode dialog: below 100% its buttons stand at that till the mouse
-- is on one of them, or on any bar linked with it, or something is in hand to drop on a bar. Our holders carry the alpha
-- (Bar/BandBars.lua); the band's art stays. Alpha is free in a fight, so a bar fades and lights there too.

local FADE_TIME = 0.2   -- seconds from faded to full
local GRACE = 0.15      -- between two buttons the mouse leaves one first: no fade for that
local FLYOUT_LOOK = 0.25
-- Each bar by name, its fade setting and its link; bar 1 is whichever the client has.
local BARS = { { nil, "fadeBar1", "fadeLinkBar1" }, { "MultiBarBottomLeft", "fadeBar2", "fadeLinkBar2" },
    { "MultiBarBottomRight", "fadeBar3", "fadeLinkBar3" }, { "MultiBarRight", "fadeBar4", "fadeLinkBar4" },
    { "MultiBarLeft", "fadeBar5", "fadeLinkBar5" }, { "MultiBar5", "fadeBar6", "fadeLinkBar6" },
    { "MultiBar6", "fadeBar7", "fadeLinkBar7" }, { "MultiBar7", "fadeBar8", "fadeLinkBar8" },
    { "StanceBar", "fadeStance", "fadeLinkStance" }, { "PetActionBar", "fadePet", "fadeLinkPet" } }

local F = { now = {}, hovered = {}, keyOf = {}, linkOf = {}, holding = false, hooked = {}, before = {}, panels = {} }

local function BarOf(row) return row[1] and _G[row[1]] or ns.GetMainBar() end

local function Faded(bar)
    local key = F.keyOf[bar]
    return math.max(0, math.min(100, tonumber(key and ns.db[key]) or 100)) / 100
end

local function Linked(bar)
    local key = F.linkOf[bar]
    return key ~= nil and ns.db[key] == true
end

-- A flyout opened from one of the bar's buttons, still up.
local function FlyoutFrom(bar)
    local flyout = _G.SpellFlyout
    if not (flyout and flyout:IsShown()) then return false end
    local from = flyout:GetParent()
    for _, button in ipairs(bar.actionButtons or ns.EMPTY) do
        if button == from then return true end
    end
    return false
end

-- The mouse on a linked bar, or a flyout open from one, lights every linked bar.
local function LinkedLit()
    for bar in pairs(F.linkOf) do
        if Linked(bar) and (F.hovered[bar] or FlyoutFrom(bar)) then return true end
    end
    return false
end

local function Want(bar)
    local faded = Faded(bar)
    if faded >= 1 or F.holding or F.hovered[bar] or ns.EditMode.Live() or FlyoutFrom(bar) then return 1 end
    if Linked(bar) and LinkedLit() then return 1 end
    return faded
end

-- The holder's alpha: the bar's own times the fade.
local function Apply(bar)
    local holder = B.HolderOf(bar)
    if not holder then return end
    local own = bar:GetAlpha()
    if ns.IsSecret(own) then own = 1 end
    holder:SetAlpha(own * (F.now[bar] or 1))
end

function B.FadeNow(bar)
    if F.now[bar] == nil and F.keyOf[bar] then F.now[bar] = Want(bar) end
    return F.now[bar] or 1
end

local function Step(_, since)
    local moving = false
    for bar in pairs(F.keyOf) do
        local now, want = F.now[bar] or 1, Want(bar)
        if now ~= want then
            local by = since / FADE_TIME
            now = want > now and math.min(want, now + by) or math.max(want, now - by)
            F.now[bar] = now
            Apply(bar)
            if now ~= want then moving = true end
        end
    end
    if not moving then F.job:Sleep() end
end

local function Update()
    if F.job then F.job:Wake() end
end

local function AnyOver(bar)
    for _, button in ipairs(bar.actionButtons or ns.EMPTY) do
        if button:IsVisible() and button:IsMouseOver() then return true end
    end
    return false
end

-- A flyout's pick keeps its bar lit: looked at again till it shuts.
local function Recheck(bar)
    F.hovered[bar] = AnyOver(bar)
    if FlyoutFrom(bar) then ns.Sched.AfterPerFrame("barFade.flyout", FLYOUT_LOOK, function() Recheck(bar) end) end
    Update()
end

local function HookButtons(bar)
    for _, button in ipairs(bar.actionButtons or ns.EMPTY) do
        if not F.hooked[button] then
            F.hooked[button] = true
            ns.HookScriptOnce(button, "OnEnter", function()
                if Faded(bar) >= 1 and not Linked(bar) then return end
                F.hovered[bar] = true
                Update()
            end, "barFade")
            ns.HookScriptOnce(button, "OnLeave", function()
                if Faded(bar) >= 1 and not Linked(bar) then return end
                ns.Sched.AfterPerFrame("barFade.leave", GRACE, function() Recheck(bar) end)
            end, "barFade")
        end
    end
end

-- A spell, item or macro picked up shows the grid on every bar: all of them light for the drop.
local function OnGrid(_, event)
    F.holding = event == "ACTIONBAR_SHOWGRID"
    Update()
end

-- Events and hooks only while a bar is set to fade.
local function Watch()
    local any = false
    for bar in pairs(F.keyOf) do
        if Faded(bar) < 1 then any = true end
    end
    -- A bar shown in full but linked lights the faded ones it is linked with: its buttons are watched too.
    for bar in pairs(F.keyOf) do
        if Faded(bar) < 1 or (any and Linked(bar)) then HookButtons(bar) end
    end
    if any and not F.grid then F.grid = ns.EventFrame({}, OnGrid) end
    if F.grid and any ~= (F.grid.on == true) then
        if any then
            ns.RegisterEvents(F.grid, { "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID" })
        else
            F.grid:UnregisterAllEvents()
            F.holding = false
        end
        F.grid.on = any
    end
    Update()
end

-- A change in edit mode lights its Save and Revert All as the game's own settings do: Revert All puts every bar's fade
-- back as the session found it; Save, or leaving, keeps it (the micro menu's way, Bar/BandWatch.lua).
local function FootClick(revert)
    local snapshot = F.snapshot
    F.snapshot = nil
    if not (revert and snapshot) then return end
    for key, value in pairs(snapshot) do ns.db[key] = value end
    Watch()
    for _, panel in pairs(F.panels) do
        if panel:IsShown() then
            panel.hoverOnly()
            panel.fade()
            panel.link()
        end
    end
end

-- The game dims them again as it re-checks its own changes: lit while ours wait (the band watch's beat).
function B.FadeRelight(editing)
    if not F.snapshot then return end
    if editing then ns.LightEditFoot("barFade", FootClick) else F.snapshot = nil end
end

local function SetBarSetting(key, value)
    if ns.EditMode.Live() then
        if not F.snapshot then
            F.snapshot = {}
            for _, row in ipairs(BARS) do F.snapshot[row[2]], F.snapshot[row[3]] = ns.db[row[2]], ns.db[row[3]] end
        end
        ns.LightEditFoot("barFade", FootClick)
    end
    ns.db[key] = value
    Watch()
end

local function SetFade(key, value) SetBarSetting(key, math.floor(value / 5 + 0.5) * 5) end

local function Percent(value) return string.format("%d%%", math.floor(value + 0.5)) end

local function Start()
    for _, row in ipairs(BARS) do
        local bar = BarOf(row)
        if bar then F.keyOf[bar], F.linkOf[bar] = row[2], row[3] end
    end
    F.job = ns.Sched.OnFrame(ns.NewFrame("Frame", nil, UIParent), { name = "barFade.step", every = 0, awake = false, fn = Step })
    Watch()
end

-- Under each bar's own dialog while the band holds its buttons (with the classic bar off they are the game's).
for _, row in ipairs(BARS) do
    ns.DialogExtra({
        title = L["MAP_CLASSICUI_FOREVER"],
        match = function(system) return system ~= nil and system == BarOf(row) and B.HolderOf(system) ~= nil end,
        build = function(panel)
            local key = row[2]
            F.panels[key] = panel
            -- Show Only On Hover is the slider at 0; unchecked, the opacity before it comes back.
            panel.hoverOnly = ns.DialogExtraCheck(panel, L["BAR_HOVER_ONLY"],
                function() return (tonumber(ns.db[key]) or 100) == 0 end,
                function(on)
                    local now = tonumber(ns.db[key]) or 100
                    if on and now > 0 then F.before[key] = now end
                    SetFade(key, on and 0 or (F.before[key] or 100))
                    panel.fade()
                end)
            panel.fade = ns.DialogExtraSlider(panel, L["BAR_FADE"],
                function() return tonumber(ns.db[key]) or 100, 0, 100, 20 end,
                function(value)
                    SetFade(key, value)
                    panel.hoverOnly()
                end, Percent)
            local link = row[3]
            panel.link = ns.DialogExtraCheck(panel, L["BAR_FADE_LINK"], function() return ns.db[link] == true end,
                function(on) SetBarSetting(link, on and true or false) end)
            ns.DialogExtraNote(panel, L["BAR_FADE_NOTE"])
        end,
        fill = function(panel)
            panel.hoverOnly()
            panel.fade()
            panel.link()
        end,
    })
end

ns.EventFrame("PLAYER_LOGIN", Start)
ns.OnEditMode(Update)
-- A profile switch or reset sets them anew.
ns.OnToggle(function(key) if key:match("^fade") then Watch() end end)
