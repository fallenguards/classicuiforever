-- Offline test under Lua 5.4 for the old scroll column behind client scroll bars (UI/ScrollBars.lua ScrollTrackArt). A bar
-- too short for the column's head and foot hides them; the dark channel between them hid with them only from beta
-- 70291 on, when the group finder's activity list came up 36 shorter and its loose channel drew a 256 box over the page.
-- Run from the addon root: lua tools/tests/scroll_column_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

-- Regions and frames: shown state, height and scripts; every other method does nothing.
local Region = {}
Region.__index = function(_, key)
    if Region[key] then return Region[key] end
    -- Methods only: a bar's Back, Forward and Track read nil (none here).
    if type(key) == "string" and (key:match("^Set") or key:match("^Get") or key:match("^Clear") or key:match("^Hook")) then
        return function() end
    end
end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(on) self.shown = on and true or false end
function Region:IsShown() return self.shown end
function Region:GetHeight() return self.height or 0 end
function Region:SetScript(name, fn) self.scripts[name] = fn end
local function New() return setmetatable({ shown = true, scripts = {} }, Region) end

local owned = {}
local ns = setmetatable({}, { __index = function() return function() end end })
ns.KEYS = {}
-- The next-frame refit runs at once here.
ns.Sched = { NextFrame = function(_, fn) fn() end }
ns.OwnTexture = function(_, key) owned[key] = New() return owned[key] end
assert(loadfile(ROOT .. "/UI/ScrollBars.lua"))("ClassicUIForever", ns)

-- The bar's size watcher is our own child frame; its OnSizeChanged refits.
local child
ns.NewFrame = function() child = New() return child end

-- The group finder's activity bar since 70291: 107 tall, short of the column's head and foot.
local bar = New()
bar.height = 107
ns.ScrollTrackArt(bar)
Check(owned.trackTop and not owned.trackTop.shown, "a short bar: the column's head is hidden")
Check(owned.trackChannel and not owned.trackChannel.shown, "a short bar: its channel is hidden with it")

-- Grown tall enough (143, as before 70291): head and channel show together; short again, both hide.
bar.height = 143
child.scripts.OnSizeChanged()
Check(owned.trackTop.shown and owned.trackChannel.shown, "grown tall enough: head and channel show")
bar.height = 107
child.scripts.OnSizeChanged()
Check(not owned.trackTop.shown and not owned.trackChannel.shown, "short again: both hide")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("scroll_column_test: ok")
