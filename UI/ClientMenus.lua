local _, ns = ...

-- Every client menu (drop downs, right-click menus) in the 1.x dialog rim (tinted with a theme); the bronze theme gives
-- back Forever's own. The game's menu show signal names each menu frame as it shows; frames are pooled and discard
-- their keys on close, so all state lives here in weak tables.

local ART = ns.ART
local pairs, rawget, select = pairs, rawget, select

local ATLAS = "common-dropdown-bg"
local BG_ALPHA = 0.925       -- MenuStyle1Mixin:Generate
local GRACE = 3              -- ticks the watch stays up with no menu listed open (a root shows before it is)

local weak = { __mode = "k" }
local known = setmetatable({}, weak)   -- menu frame -> true
local backs = setmetatable({}, weak)   -- menu frame -> its background texture last seen
local rims = setmetatable({}, weak)    -- menu frame -> our rim
local irons = setmetatable({}, weak)   -- menu frame -> Era's drop down art
local reclamped = setmetatable({}, weak)   -- menu frame -> clamped again this open (secret-placed)
local placed = setmetatable({}, weak)  -- menu frame -> { anchor frame, x, y } as we last put it
local scrolls = setmetatable({}, weak) -- menu scroll bar -> in the classic look
-- The classic arrows' width; the menu lays its list beside the bar's width, with 10 to spare (MenuProxyMixin).
local SCROLL_W = 16

local active = false
local theme = {}             -- ThemeTurned state
local clientArt              -- last painted: true Forever's own, false our rim, nil never
local grace = 0
local host, job
local signal = {}             -- our handle on the game's menu show signal

local function Manager()
    return Menu and Menu.GetManager and Menu.GetManager()
end

-- rawget only: an open menu's metatable copies any key of the frame's own that is read through it.
local function IsMenuFrame(f)
    local mixin = _G.MenuProxyMixin
    return mixin and type(f) == "table" and f.IsForbidden and not f:IsForbidden()
        and rawget(f, "InitScrollLayout") == mixin.InitScrollLayout
end

local function IsBack(region)
    local atlas = region.GetAtlas and region:GetAtlas()
    return atlas == ATLAS
end

local function FindBack(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if IsBack(region) then return region end
    end
end

-- The client's background while it is still this menu's (a fresh one comes on every open).
local function Back(frame)
    local bg = backs[frame]
    if bg and bg:GetParent() == frame and IsBack(bg) then return bg end
    bg = FindBack(frame:GetRegions())
    backs[frame] = bg
    return bg
end

local function MakeRim(frame)
    -- At the menu's level so its rows draw over the rim; the fill under the rows' highlight (BACKGROUND).
    local rim = ns.TipRim(frame, -7, 6, 7, 1)
    rims[frame] = rim
    return rim
end

local function Place(frame, point, rel, relPoint, x, y)
    frame:SetPoint(point, rel, relPoint, x, y)
    local at = placed[frame] or {}
    at[1], at[2], at[3] = rel, x, y
    placed[frame] = at
end

-- The client clamped the menu as it opened, before our rim; new insets don't re-clamp, so shift it by what sticks out.
local function OnScreen(frame, rim)
    local left, right, top, bottom = rim:GetLeft(), rim:GetRight(), rim:GetTop(), rim:GetBottom()
    -- A menu on a secret-placed frame has secret edges: the client clamps it again, now counting the rim.
    if not (left and right and top and bottom) or ns.AnySecret(left, right, top, bottom) then
        if not reclamped[frame] then
            reclamped[frame] = true
            pcall(frame.SetClampedToScreen, frame, false)
            pcall(frame.SetClampedToScreen, frame, true)
        end
        return
    end
    reclamped[frame] = nil
    local k = rim:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local dx, dy = 0, 0
    if top * k > height then dy = height - top * k elseif bottom * k < 0 then dy = -bottom * k end
    if right * k > width then dx = width - right * k elseif left * k < 0 then dx = -left * k end
    if dx == 0 and dy == 0 then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point or ns.AnySecret(x, y) then return end
    local f = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    Place(frame, point, rel, relPoint, (x or 0) + dx * f, (y or 0) + dy * f)
end

-- Opened from a drop down button: Era draws those in its iron style, right-click menus in the rim (#69).
local function FromDropdown(root)
    -- Written after the menu opened, so it is in the metatable's side table: rawget misses it, a plain read copies nothing.
    local owner = root.ownerRegion
    local mixin = _G.DropdownButtonMixin
    return type(owner) == "table" and mixin ~= nil and not ns.IsForbidden(owner)
        and rawget(owner, "GenerateMenu") == mixin.GenerateMenu
end

-- A drop down's menu moved for the iron to sit against its button as Era's did. Every pass: one still where we put it
-- stays, so it moves once per place the game gives it.
local function Settle(frame)
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point or ns.AnySecret(point, rel, x, y) then return end
    x, y = x or 0, y or 0
    local at = placed[frame]
    if at and at[1] == rel and ns.Near(x, at[2], 0.01) and ns.Near(y, at[3], 0.01) then return end
    local shift = ns.IRON_SHIFT
    local dx = point:find("LEFT") and shift.LEFT or point:find("RIGHT") and shift.RIGHT or 0
    local dy = point:find("TOP") and shift.TOP or point:find("BOTTOM") and shift.BOTTOM or 0
    Place(frame, point, rel, relPoint, x + dx, y + dy)
end

local function Dress(frame, iron, isRoot)
    local bg = Back(frame)
    local rim, art = rims[frame], irons[frame]
    -- Other menu styles (the barber shop's) stay as drawn.
    if not bg then
        if rim and rim:IsShown() then rim:Hide() end
        if art and art:IsShown() then art:Hide() end
        return
    end
    -- Exact: Undress restores only an alpha of exactly 0.
    ns.SetAlphaIf(bg, 0, 0)
    local shown, hidden
    if iron then
        art = art or ns.IronMenuArt(frame)
        irons[frame] = art
        shown, hidden = art, rim
    else
        rim = rim or MakeRim(frame)
        shown, hidden = rim, art
    end
    if hidden and hidden:IsShown() then hidden:Hide() end
    if not shown:IsShown() then shown:Show() end
    -- The client clamps the menu frame and resets its insets per open; our art hangs out, so the clamp counts it.
    local reach = ns.IRON_REACH
    local wl, wr, wt, wb = -7, 7, 6, -1
    if iron then wl, wr, wt, wb = reach[1], reach[3], reach[2], reach[4] end
    local ok, l, r, t, b = pcall(frame.GetClampRectInsets, frame)
    if not ok or ns.AnySecret(l, r, t, b) or l ~= wl or r ~= wr or t ~= wt or b ~= wb then
        pcall(frame.SetClampRectInsets, frame, wl, wr, wt, wb)
        reclamped[frame] = nil   -- a new open
    end
    if iron and isRoot then Settle(frame) end
    OnScreen(frame, shown)
    -- A long list's scroll bar (every menu frame has one) in the classic look; rawget, the frame's own key.
    local bar = rawget(frame, "ScrollBar")
    if bar and not scrolls[bar] then
        scrolls[bar] = true
        bar:SetWidth(SCROLL_W)
        ns.SkinMinimalScrollBar(bar)
    end
end

local function Undress(frame)
    local bg = Back(frame)
    if bg and bg:GetAlpha() == 0 then bg:SetAlpha(BG_ALPHA) end
    local rim, art = rims[frame], irons[frame]
    if (rim and rim:IsShown()) or (art and art:IsShown()) then
        if rim then rim:Hide() end
        if art then art:Hide() end
        pcall(frame.SetClampRectInsets, frame, 0, 0, 0, 0)
    end
end

local function UndressAll()
    for frame in pairs(known) do ns.SafeCall(Undress, frame) end
end

local function Tick()
    local m = Manager()
    if clientArt ~= false or not m or not m:IsAnyMenuOpen() then
        grace = grace - 1
        if grace <= 0 then job:Sleep() end
        return
    end
    grace = GRACE
    local root = m:GetOpenMenu()
    local iron = false
    if IsMenuFrame(root) then
        known[root] = true
        iron = FromDropdown(root)
    end
    -- One menu tree opens at a time: its submenus wear the root's style.
    for frame in pairs(known) do
        if frame:IsShown() then Dress(frame, iron, frame == root) end
    end
end

local function Wake()
    if not active or clientArt ~= false then return end
    grace = GRACE
    job:Wake()
end

-- Placed, not yet drawn: dressed now, so even a session's first submenu never shows the game's art (#199). The one
-- client registry we listen to besides Menu.ModifyMenu; it runs its listeners in protected calls.
local function OnMenuShow(_, frame)
    if not active or clientArt ~= false or not IsMenuFrame(frame) then return end
    known[frame] = true
    local m = Manager()
    -- The root shows before the game lists it as the open menu.
    local root = m and m:IsAnyMenuOpen() and m:GetOpenMenu()
    if not IsMenuFrame(root) then root = frame end
    Dress(frame, FromDropdown(root), frame == root)
    Wake()
end

-------------------------------------------------- social window buttons

local CLIENT_SQUARE = "Interface\\Buttons\\UI-SquareButton-"
-- The contacts button: the game's square and down arrow in every look, 2 right of the Battle.net bar as the game sets
-- it, 3 further left while ours dresses the window.
local CONTACTS_X, CLIENT_CONTACTS_X = -1, 2
-- IconButtonTemplate.xml's art, filling the button.
local CLIENT_STATES = { set = "file", highlightSet = "raw", coords = { 0, 1, 0, 1 }, fill = true, add = true }
local DD_PIECES = { "ddLeft", "ddMiddle", "ddRight", "ddArrow", "ddArrowGlow" }
local buttonsPainted         -- ThemeLook(true) last painted, or nil (never touched)

local function StatusDropdown()
    return _G.FriendsFrameStatusDropdown
end

local function ContactsButton()
    local bnet = _G.FriendsFrameBattlenetFrame
    return bnet and bnet.ContactsMenuButton
end

local function PaintStatus(dd, classic)
    if classic then ns.DressDropdown(dd) end
    local own = dd.fcui
    if own then
        for i = 1, #DD_PIECES do
            local piece = own[DD_PIECES[i]]
            if piece then piece:SetShown(classic) end
        end
    end
    if dd.Background then dd.Background:SetAlpha(classic and 0 or 1) end
    if dd.Arrow then dd.Arrow:SetAlpha(classic and 0 or 1) end
end

local function PaintContacts(btn, classic)
    ns.DressStates(btn, CLIENT_SQUARE .. "Up", CLIENT_SQUARE .. "Down", CLIENT_SQUARE .. "Disabled", ART.HILIGHT,
        CLIENT_STATES)
    if btn.Icon then btn.Icon:SetAlpha(1) end
    ns.SetPointIf(btn, "LEFT", btn:GetParent(), "RIGHT", classic and CONTACTS_X or CLIENT_CONTACTS_X, 0)
end

-- Classic only while the social window wears the old chrome; client art otherwise.
local function PaintButtons()
    local want
    if active and ns.panels and ns.panels.Dressing and ns.panels.Dressing("panelSocial") then
        want = ns.ThemeLook(true, "themePartWindows")
    elseif buttonsPainted then
        want = "client"
    end
    if not want or want == buttonsPainted then return end
    local dd, btn = StatusDropdown(), ContactsButton()
    if not dd and not btn then return end
    buttonsPainted = want
    local classic = want ~= "client"
    if dd then ns.SafeCall(PaintStatus, dd, classic) end
    if btn then ns.SafeCall(PaintContacts, btn, classic) end
end

------------------------------------------------------------------ module

-- Every pass calls these: work only on a change.
local function Apply()
    if not job then
        host = CreateFrame("Frame")
        job = ns.Sched.OnFrame(host, { name = "clientMenus.watch", every = 0, fn = Tick, awake = false })
    end
    if not active then
        active = true
        EventRegistry:RegisterCallback("MenuProxy.OnShow", OnMenuShow, signal)
    end
    if ns.ThemeTurned(theme, "themePartTooltips") and (ns.ThemeLook(true, "themePartTooltips") == "client") ~= clientArt then
        clientArt = ns.ThemeLook(true, "themePartTooltips") == "client"
        if clientArt then UndressAll() else Wake() end
    end
    PaintButtons()
end

local function Restore()
    if not active then return end
    active, theme.on, clientArt = false, nil, nil
    EventRegistry:UnregisterCallback("MenuProxy.OnShow", signal)
    job:Sleep()
    UndressAll()
    PaintButtons()
end

ns.RegisterModule("clientMenus", { apply = Apply, restore = Restore })
