-- Offline test under Lua 5.4 for the options rows (Options/Toggles.lua, Options/OptionsRows.lua BuildRows) over stub
-- frames: All windows lists every window once in its sections; a window whose box is on a page of its own keeps that
-- row there and shows here as the same setting; no row key repeats.
-- Run from the addon root: lua tools/tests/options_rows_test.lua (CI runs every tools/tests/*_test.lua).
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

-- Any frame or region: every method answers another stub, sizes answer numbers.
local NUMBERS = { GetStringWidth = 60, GetStringHeight = 12, GetWidth = 100, GetHeight = 24 }
local Stub
local function Method(_, name)
    if NUMBERS[name] then return function() return NUMBERS[name] end end
    return function() return Stub() end
end
function Stub() return setmetatable({}, { __index = Method }) end

local L = setmetatable({}, { __index = function(_, key) return key end })
local ns = setmetatable({ L = L, ART = { CHECK = "check" }, EMPTY = {}, db = {}, ENGLISH_CLIENT = true },
    { __index = function() return function() return Stub() end end })
ns.OnForever = function() return true end
ns.NewFrame = function() return Stub() end
ns.PACKAGE = false
GameTooltip, MenuUtil, SOUNDKIT = Stub(), Stub(), {}
assert(loadfile(ROOT .. "/Options/Toggles.lua"))("ClassicUIForever", ns)
local O = ns.options
local function Row(key)
    local row = Stub()
    row.key, row.keyLow, row.tipLow, row.text = key, "", "", Stub()
    return row
end
O.CameraRow = function() return Row("cameraDistance"), Row("cameraSlider") end
O.ColorRow = function(_, key) return Row(key) end
O.DarknessRow = function() return Row("themeDarkness") end
assert(loadfile(ROOT .. "/Options/OptionsRows.lua"))("ClassicUIForever", ns)
local built = O.BuildRows(Stub(), 300)

local windows
for _, entry in ipairs(ns.TOGGLES) do
    if entry.windows then windows = entry.windows end
end
Check(windows ~= nil, "a toggle holds All windows' list")

local onPage, seen, pageOf = {}, {}, {}
local page
for _, entry in ipairs(ns.TOGGLES) do
    page = entry.group or page
    pageOf[entry[1]] = page
end
for _, row in ipairs(built.rows) do
    Check(not seen[row.key], "row key " .. tostring(row.key) .. " is used once")
    seen[row.key] = true
    -- Fields read raw: a stub answers any other with a function.
    if rawget(row, "page") == O.MASTER_PAGE and rawget(row, "toggle") then
        local key = rawget(row, "setting") or row.key
        onPage[key] = (onPage[key] or 0) + 1
    end
end
for _, key in ipairs(windows or {}) do
    if pageOf[key] then
        Check(onPage[key] == 1, key .. " shows once on All windows (" .. tostring(onPage[key]) .. ")")
        if pageOf[key] ~= O.MASTER_PAGE then
            Check(seen[key] and seen["also:" .. key], key .. " keeps its own page's row and shows on All windows")
        end
    end
end
for key in pairs(onPage) do
    local listed = false
    for _, other in ipairs(windows or {}) do listed = listed or other == key end
    Check(listed, key .. " on All windows is in its list")
end

if failed > 0 then
    print("options rows: " .. failed .. " failures")
    os.exit(1)
end
print("options rows: ok")
