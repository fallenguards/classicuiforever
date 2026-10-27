-- Offline test under Lua 5.4 for the theme's colour swatch (Options/ThemeRows.lua). The game's colour picker cancels
-- on any click outside it: that click undid the colour just picked, so a part unchecked next showed the old colour.
-- Run from the addon root: lua tools/tests/theme_rows_test.lua (CI runs every tools/tests/*_test.lua).
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

local noop = function() end
local function Stub()
    local scripts = {}
    return setmetatable({ scripts = scripts }, { __index = function(self, k)
        if k == "SetScript" then return function(_, name, fn) scripts[name] = fn end end
        if k == "CreateTexture" or k == "CreateFontString" then return function() return Stub() end end
        return noop
    end })
end

local mouseDown, overPicker, info = false, false, nil
function IsMouseButtonDown() return mouseDown end
ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, setup) info = setup end,
    GetColorRGB = function() return 0, 0, 1 end,
    IsMouseOver = function() return overPicker end,
}

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    options = {},
    db = { themeColor = "ff0000" },
    band = {},
    Sched = { NextFrame = function(_, fn) fn() end },
    NewFrame = function() return Stub() end,
    PanelButton = function() return Stub() end,
    AttachTip = noop,
}
function ns.HexColor(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then return nil end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
function ns.SetThemeColor(r, g, b)
    ns.db.themeColor = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end
ns.options.Describe = function(row) row.keyLow = "" end
assert(loadfile(ROOT .. "/Options/ThemeRows.lua"))("ClassicUIForever", ns)

local row = ns.options.ColorRow(Stub(), "themeColor", "Colour", "tip")
row.scripts.OnClick()
info.swatchFunc()
Check(ns.db.themeColor == "0000ff", "a pick in the picker paints at once")
-- A click outside the picker (a part's box): the game cancels, the pick stays.
mouseDown, overPicker = true, false
info.cancelFunc()
Check(ns.db.themeColor == "0000ff", "a click outside the picker keeps the colour picked")
-- Cancel (released over the picker) and Escape put the colour back.
ns.db.themeColor = "ff0000"
row.scripts.OnClick()
info.swatchFunc()
mouseDown, overPicker = false, true
info.cancelFunc()
Check(ns.db.themeColor == "ff0000", "Cancel puts back the colour from before the picker opened")
row.scripts.OnClick()
info.swatchFunc()
mouseDown, overPicker = false, false
info.cancelFunc()
Check(ns.db.themeColor == "ff0000", "Escape puts back the colour from before the picker opened")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("theme_rows_test: ok")
