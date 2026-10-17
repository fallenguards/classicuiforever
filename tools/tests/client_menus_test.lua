-- Offline test for the client menus' look (UI/ClientMenus.lua) under Lua 5.4: a menu opened from a drop down button
-- gets Classic Era's iron list, a right-click menu the thin rim. The game keeps what it writes on an open menu in a
-- side table behind the frame's metatable, so a raw read of the owner finds nothing and every menu got the rim.
-- A submenu is dressed as the game's show signal names it: a session's first one kept the game's art until hovered (#199).
-- Run from the addon root: lua tools/tests/client_menus_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

MenuProxyMixin = { InitScrollLayout = function() end, GetOwnerRegion = function(self) return self.ownerRegion end }
DropdownButtonMixin = { GenerateMenu = function() end }

local shown = {}             -- menu frame -> open
local copied = {}            -- the frame's own keys read through the metatable (each one a copy made in our name)
local insets, spot, moves = {}, {}, {}   -- menu frame -> clamp insets, anchor offsets, times moved
local DRIFT = 0.000244

local function Art(kind)
    local art = { kind = kind, shown = true }
    function art:IsShown() return self.shown end
    function art:Show() self.shown = true end
    function art:Hide() self.shown = false end
    function art:GetLeft() end
    function art:GetRight() end
    function art:GetTop() end
    function art:GetBottom() end
    return art
end

-- A menu frame as the game hands it out: its mixin's keys on the frame, then the metatable that redirects writes.
local function OpenMenu(owner, submenu)
    local frame = { InitScrollLayout = MenuProxyMixin.InitScrollLayout, GetOwnerRegion = MenuProxyMixin.GetOwnerRegion }
    local back = { GetAtlas = function() return "common-dropdown-bg" end, GetParent = function() return frame end,
        GetAlpha = function() return 0 end }
    local methods = {
        IsForbidden = function() return false end,
        IsShown = function() return shown[frame] end,
        GetRegions = function() return back end,
        -- The game hands numbers back a hair off, so nothing read back equals what was set.
        GetClampRectInsets = function()
            local at = insets[frame]
            return at[1] + DRIFT, at[2] + DRIFT, at[3] + DRIFT, at[4] + DRIFT
        end,
        SetClampRectInsets = function(_, l, r, t, b) insets[frame] = { l, r, t, b } end,
        SetClampedToScreen = function() end,
        GetPoint = function() return "TOPLEFT", owner, "BOTTOMLEFT", spot[frame][1] + DRIFT, spot[frame][2] + DRIFT end,
        SetPoint = function(_, _, _, _, x, y)
            spot[frame] = { x, y }
            moves[frame] = moves[frame] + 1
        end,
    }
    local values = {}
    setmetatable(frame, {
        __index = function(_, key)
            local value = values[key]
            if value ~= nil then return value end
            local original = rawget(frame, key)
            if original ~= nil then
                rawset(values, key, original)
                copied[#copied + 1] = key
                return original
            end
            return methods[key]
        end,
        __newindex = values,
    })
    frame.ownerRegion = owner
    insets[frame], spot[frame], moves[frame] = { 0, 0, 0, 0 }, { 0, 0 }, 0
    if not submenu then
        for other in pairs(shown) do shown[other] = false end
    end
    shown[frame] = true
    return frame
end

local openMenu
Menu = { GetManager = function()
    return { IsAnyMenuOpen = function() return openMenu ~= nil end, GetOpenMenu = function() return openMenu end }
end }
-- The watcher never walks the game's frames (70 ms a frame on retail with a menu open, read live 2026-10-04).
EnumerateFrames = function() error("the menu watcher walked the game's frames") end
CreateFrame = function() return { SetScript = function() end, UnregisterAllEvents = function() end } end
local showSignal             -- the game's menu show signal as the module listens to it
EventRegistry = {
    RegisterCallback = function(_, event, fn, owner)
        if event == "MenuProxy.OnShow" then showSignal = { fn = fn, owner = owner } end
    end,
    UnregisterCallback = function(_, event, owner)
        if event == "MenuProxy.OnShow" and showSignal and showSignal.owner == owner then showSignal = nil end
    end,
}
UIParent = {}

------------------------------------------------------------------ the stub addon

local made = {}              -- menu frame -> { iron = art, rim = art }
local function Made(frame, kind)
    made[frame] = made[frame] or {}
    made[frame][kind] = Art(kind)
    return made[frame][kind]
end

local tick, module
local ns = setmetatable({ ART = {}, db = { panels = false } }, { __index = function() return function() end end })
ns.Sched = { OnFrame = function(_, spec)
    tick = spec.fn
    return { Wake = function() end, Sleep = function() end }
end }
ns.RegisterModule = function(_, mod) module = mod end
ns.ThemeTurned = function() return true end
ns.ThemeLook = function() return "classic" end
ns.IsForbidden = function() return false end
ns.AnySecret = function() return false end
ns.Near = function(a, b, tol) return math.abs(a - b) <= tol end
ns.TipRim = function(frame) return Made(frame, "rim") end

-- The real reach and shift numbers; the art itself is the stub's.
assert(loadfile(ROOT .. "/UI/Menus.lua"))("ClassicUIForever", ns)
ns.IronMenuArt = function(frame) return Made(frame, "iron") end
assert(loadfile(ROOT .. "/UI/ClientMenus.lua"))("ClassicUIForever", ns)
module.apply()

------------------------------------------------------------------ the checks

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Look(owner)
    openMenu = OpenMenu(owner)
    for _ = 1, 30 do tick() end
    local art = made[openMenu] or {}
    return art.iron and art.iron.shown or false, art.rim and art.rim.shown or false
end

local iron, rim = Look({ GenerateMenu = DropdownButtonMixin.GenerateMenu })
Check(iron and not rim, "a drop down button's menu wears the iron list")

-- Era's art stands 19, 13, 19, 14 off its rows (insets 16, 10, 16, 10 plus its reach); Forever pads the rows 8, 8, 8, 15.
-- On the right it stands off the row's whole width, not its text's (20 less): a row's icon, arrow and highlight
-- stood outside the border (the tracking menu, seen live 2026-10-04).
local reach = ns.IRON_REACH
Check(8 - reach[1] == 19 and 8 + reach[2] == 13 and 8 + reach[3] == 19 and 15 - reach[4] == 14,
    "the iron stands off the rows as in Classic Era, holding their whole width (" .. table.concat(reach, ", ") .. ")")
Check(moves[openMenu] == 1 and math.abs(spot[openMenu][1] - 8) < 0.01 and math.abs(spot[openMenu][2] + 2) < 0.01,
    "the drop down's menu moves once, 8 right and 2 down (" .. moves[openMenu] .. " moves to "
    .. table.concat(spot[openMenu], ", ") .. ")")

iron, rim = Look({})
Check(rim and not iron, "a right-click menu wears the rim")
Check(moves[openMenu] == 0, "a right-click menu stays where the game put it")

iron, rim = Look(nil)
Check(rim and not iron, "a menu with no owner wears the rim")

Check(#copied == 0, "no key of the menu frame's own is read through its metatable (" .. table.concat(copied, ", ") .. ")")

-- The show signal, with no tick and no hover: the root shows before the game lists it as the open menu.
local function Shows(owner)
    local root = OpenMenu(owner)
    openMenu = nil
    showSignal.fn(nil, root)
    openMenu = root
    local sub = OpenMenu(nil, true)
    showSignal.fn(nil, sub)
    return made[root] or {}, made[sub] or {}
end
Check(showSignal ~= nil, "the module listens to the game's menu show signal")
local rootArt, subArt = Shows({})
Check(rootArt.rim and rootArt.rim.shown, "a right-click menu wears the rim as it shows")
Check(subArt.rim and subArt.rim.shown and not subArt.iron, "its submenu wears the rim as it shows, before any hover")
rootArt, subArt = Shows({ GenerateMenu = DropdownButtonMixin.GenerateMenu })
Check(rootArt.iron and rootArt.iron.shown, "a drop down button's menu wears the iron as it shows")
Check(subArt.iron and subArt.iron.shown and not subArt.rim, "its submenu wears the iron as it shows, before any hover")
module.restore()
Check(showSignal == nil, "turned off, the module stops listening")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("client_menus_test: ok")
