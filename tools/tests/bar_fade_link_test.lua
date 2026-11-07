-- Offline test under Lua 5.4 for Bar/BarFade.lua's linked fading: a faded bar linked with others lights while the mouse
-- is on any linked bar (a bar shown in full included), stays faded for an unlinked one, and fades back on leaving.
-- Run from the addon root: lua tools/tests/bar_fade_link_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

------------------------------------------------------------------ the stub client

local Button = {}
Button.__index = Button
local function NewButton()
    return setmetatable({ hooks = {}, over = false }, Button)
end
function Button:IsVisible() return true end
function Button:IsMouseOver() return self.over end
function Button:Hover(on)
    self.over = on
    for _, fn in ipairs(self.hooks[on and "OnEnter" or "OnLeave"] or {}) do fn(self) end
end

local function NewBar()
    local bar = { actionButtons = { NewButton(), NewButton() } }
    function bar:GetAlpha() return 1 end
    bar.holder = { alpha = 1 }
    function bar.holder:SetAlpha(a) self.alpha = a end
    return bar
end

local bars = {}
for _, name in ipairs({ "Main", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5",
    "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar" }) do
    bars[name] = NewBar()
    if name ~= "Main" then _G[name] = bars[name] end
end
_G.SpellFlyout = nil
UIParent = {}

------------------------------------------------------------------ the addon

local start, step
local ns = { EMPTY = {}, band = {}, L = setmetatable({}, { __index = function(_, k) return k end }) }
ns.db = {}
for i = 1, 8 do ns.db["fadeBar" .. i], ns.db["fadeLinkBar" .. i] = 100, false end
ns.db.fadeStance, ns.db.fadePet, ns.db.fadeLinkStance, ns.db.fadeLinkPet = 100, 100, false, false
ns.band.HolderOf = function(bar) return bar.holder end
ns.GetMainBar = function() return bars.Main end
ns.IsSecret = function() return false end
ns.EditMode = { Live = function() return false end }
ns.NewFrame = function() return {} end
ns.Sched = {
    OnFrame = function(_, spec)
        step = spec.fn
        return { Wake = function() end, Sleep = function() end }
    end,
    AfterPerFrame = function(_, _, fn) fn() end,
}
ns.EventFrame = function(events, fn)
    if events == "PLAYER_LOGIN" then start = fn end
    return { RegisterEvent = function() end, UnregisterAllEvents = function() end }
end
ns.RegisterEvents = function() end
ns.HookScriptOnce = function(button, script, fn)
    button.hooks[script] = button.hooks[script] or {}
    table.insert(button.hooks[script], fn)
end
ns.OnEditMode = function() end
ns.OnToggle = function() end
ns.DialogExtra = function() end
ns.LightEditFoot = function() end

assert(loadfile(ROOT .. "/Bar/BarFade.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ the checks

-- Bars 2 and 3 hidden till hovered, both linked; bar 4 hidden, unlinked; bar 1 in full and linked.
ns.db.fadeBar2, ns.db.fadeBar3, ns.db.fadeBar4 = 0, 0, 0
ns.db.fadeLinkBar2, ns.db.fadeLinkBar3, ns.db.fadeLinkBar1 = true, true, true
start()
local function Settle() step(nil, 10) end
Settle()
local b2, b3, b4 = bars.MultiBarBottomLeft, bars.MultiBarBottomRight, bars.MultiBarRight
Check(b2.holder.alpha == 0 and b3.holder.alpha == 0 and b4.holder.alpha == 0, "the faded bars start faded")

b2.actionButtons[1]:Hover(true)
Settle()
Check(b2.holder.alpha == 1 and b3.holder.alpha == 1, "the mouse on bar 2 lights bar 3, linked with it")
Check(b4.holder.alpha == 0, "bar 4, not linked, stays faded")

b2.actionButtons[1]:Hover(false)
Settle()
Check(b2.holder.alpha == 0 and b3.holder.alpha == 0, "the mouse gone, the linked bars fade back")

bars.Main.actionButtons[2]:Hover(true)
Settle()
Check(b2.holder.alpha == 1 and b3.holder.alpha == 1, "a linked bar shown in full lights the faded ones")
bars.Main.actionButtons[2]:Hover(false)
Settle()

ns.db.fadeLinkBar3 = false
b2.actionButtons[2]:Hover(true)
Settle()
Check(b2.holder.alpha == 1 and b3.holder.alpha == 0, "unlinked, bar 3 no longer lights with bar 2")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bar_fade_link_test: ok")
