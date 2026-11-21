-- Offline test under Lua 5.4 for Classic in the game's nameplate Style list (Units/NamePlateOptions.lua). Our plate
-- draws over every game style, so a pick in Options, Nameplates, Style changed only the settings preview (2026-11-21).
-- Classic there turns our Nameplates on, the game's styles turn it off, and with ours on the game's rows show unpicked.
-- Run from the addon root: lua tools/tests/plate_style_list_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 121

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

-- The game's menu rows, as the proxies addons get: fields on the row, the radio's own picked test.
local function Row(label, isSelected, responder, radio)
    local row = { label = label, isSelected = isSelected, responder = responder, radio = radio }
    function row:IsRadio() return self.radio end
    function row:SetIsSelected(fn) self.isSelected = fn end
    function row:IsSelected() return self.isSelected ~= nil and self.isSelected(self.data) end
    function row:HookResponder(fn)
        local was = self.responder
        self.responder = function(...) was(...) fn(...) end
    end
    function row:Pick() self.responder(self.data) end
    return row
end

local styleValue = 1   -- the game's Thin
local function Root()
    local root = { rows = {} }
    for i, style in ipairs({ { "Thin", 1 }, { "Modern", 0 } }) do
        local row = Row(style[1], function(data) return styleValue == data.value end,
            function(data) styleValue = data.value end, true)
        row.data = { value = style[2] }
        root.rows[i] = row
    end
    function root:EnumerateElementDescriptions() return ipairs(self.rows) end
    function root:CreateHighlightRadio(label, isSelected, setSelected)
        local row = Row(label, isSelected, setSelected, true)
        self.rows[#self.rows + 1] = row
        return row
    end
    return root
end

local styleSetting = { GetVariable = function() return "nameplateStyle" end }
local initData = {}
local init = { GetSetting = function() return styleSetting end, GetData = function() return initData end }
local other = { GetSetting = function() return { GetVariable = function() return "nameplateSize" end } end }
local category = { GetSubcategories = function() return {} end }
local hooks, missing, toggled = {}, {}, {}
SettingsPanel = {
    GetAllCategories = function() return { category } end,
    GetLayout = function(_, c) return c == category and { GetInitializers = function() return { other, init } end } or nil end,
    HookScript = function(_, script, fn) hooks[script] = fn end,
}

local db = { namePlates = true }
local runs = true
local ns = {
    db = db, NP = {}, L = { PLATE_STYLE_CLASSIC = "Classic" }, EMPTY = {},
    Dress = function() end, IsSecret = function() return false end,
    RegisterModule = function() end, OnToggle = function() end,
    EventFrame = function() return { UnregisterAllEvents = function() end } end,
    Sched = { NextFrame = function() end },
    PackageRuns = function(key) return key ~= "namePlates" or runs end,
    MissingPiece = function(what) missing[#missing + 1] = what end,
    ToggleChanged = function(key) toggled[#toggled + 1] = key .. "=" .. tostring(db[key]) end,
}
assert(loadfile(ROOT .. "/Units/NamePlateOptions.lua"))("ClassicUIForever", ns)

local List = ns.NP.ListClassicStyle
Check(type(List) == "function", "the Style list hook is shared")
Check(hooks.OnShow == List, "the settings window's show lists Classic")
if type(List) ~= "function" then
    print(failed .. " check(s) failed")
    os.exit(1)
end

-- Outside the package that keeps our plates: no Classic row.
runs = false
List()
Check(init.customOptionHandler == nil, "a package without our nameplates leaves the list alone")
Check(initData.forceSteppersHidden == nil, "a package without our nameplates keeps the row's arrows")
runs = true

local priorRan = false
init.customOptionHandler = function() priorRan = true end
List()
Check(type(init.customOptionHandler) == "function", "the Style row gets our rows")
Check(initData.forceSteppersHidden == true, "the Style row's arrows are hidden (they would write the style as ours)")

local root = Root()
init.customOptionHandler(root)
Check(priorRan, "a handler the row had runs first")
local classic = root.rows[3]
Check(#root.rows == 3 and classic and classic.label == "Classic", "Classic is listed after the game's styles")
local thin, modern = root.rows[1], root.rows[2]

-- Ours on: Classic alone is picked.
Check(classic:IsSelected() == true, "ours on: Classic shows picked")
Check(not thin:IsSelected() and not modern:IsSelected(), "ours on: the game's styles show unpicked")

-- A game style: the game writes its CVar, ours goes off as its box would.
modern:Pick()
Check(styleValue == 0, "the game's row still sets the game's style")
Check(db.namePlates == false and toggled[#toggled] == "namePlates=false", "a game style turns our Nameplates off")
Check(modern:IsSelected() and not thin:IsSelected() and not classic:IsSelected(), "ours off: the game's pick shows")

-- The same game style again: nothing more to turn.
local count = #toggled
modern:Pick()
Check(#toggled == count, "a game style with ours already off changes nothing")

-- Classic: ours back on, the game's style kept for the plates we cannot dress.
classic:Pick()
Check(db.namePlates == true and toggled[#toggled] == "namePlates=true", "Classic turns our Nameplates on")
Check(styleValue == 0, "Classic leaves the game's style as it was")

-- Listed once: another show adds nothing more.
local handler = init.customOptionHandler
List()
Check(init.customOptionHandler == handler, "the list is hooked once")

-- A menu without the calls we use: the game's list still builds, the gap is reported.
local bare = { EnumerateElementDescriptions = function() return ipairs({}) end }
local ok = pcall(init.customOptionHandler, bare)
Check(ok and #missing == 1, "a changed menu leaves the game's list working and is reported")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("plate_style_list_test: ok")
