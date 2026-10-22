-- Offline test under Lua 5.4 for the rows our options window hands EasyFind's search (Options/OptionsWindow.lua
-- ns.OptionsIndexRowsOf): every setting row with its page and search words; headings, a windows list's copies and
-- rows hidden on this client left out.
-- Run from the addon root: lua tools/tests/options_index_test.lua (CI runs every tools/tests/*_test.lua).
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

local changed
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    options = { TITLE = "ClassicUI Forever", ROW = 18, INDENT = 12, BoxConfirm = function() return function() end end },
    EMPTY = {},
    Popup = function() end,
    db = { band = true, size = 3, a = true, b = false, color = "red" },
    ToggleChanged = function(key) changed = key end,
}
local env = setmetatable({}, { __index = _G })
assert(loadfile(ROOT .. "/Options/OptionsWindow.lua", "t", env))("ClassicUIForever", ns)

local rows = ns.OptionsIndexRowsOf({
    { key = "band", label = "Show the band", page = "Band", keyLow = "show the band gryphon band" },
    { key = "head", label = "Art", page = "Band", keyLow = "" },
    { key = "also:bags", label = "Bags", page = "All windows", keyLow = "" },
    { key = "retail", label = "Retail only", page = "Band", keyLow = "retail only band", hideIf = function() return true end },
    { key = "stray", label = "No page", keyLow = "no page" },
})

Check(#rows == 1, "one setting row: " .. #rows)
local row = rows[1]
Check(row and row.name == "Show the band", "its label is the name")
Check(row and row.path == "Band", "its page is the path")
Check(row and type(row.open) == "function", "an opener")
local found = false
for _, word in ipairs(row and row.keywords or {}) do if word == "gryphon" then found = true end end
Check(found, "its search words are keywords")

-- The inline controls: each kind works through the row's own setter.
local pressed
local kinds = ns.OptionsIndexRowsOf({
    { key = "band", label = "Show the band", page = "P", keyLow = "band", toggle = true },
    { key = "a", label = "Pick A", page = "P", keyLow = "a", toggle = true, radio = true },
    { key = "size", label = "Size", page = "P", keyLow = "size", step = { low = 1, high = 5, set = function(v) ns.db.size = v end } },
    { key = "look", label = "Look", page = "P", keyLow = "look", choices = { { key = "a", label = "A" }, { key = "b", label = "B" } } },
    { key = "color", label = "Color", page = "P", keyLow = "color", choices = { { key = "red", label = "Red" }, { key = "blue", label = "Blue" } },
        apply = function(key, value) ns.db[key] = value end },
    { key = "go", label = "Go", page = "P", keyLow = "go", button = { Click = function() pressed = true end } },
    { key = "many", label = "Many", page = "P", keyLow = "many", keys = { "x", "y" } },
})
local c = {}
for _, r in ipairs(kinds) do c[r.name] = r.control end
Check(c["Show the band"] and c["Show the band"].kind == "check" and c["Show the band"].get() == true, "a box is a check that reads its key")
c["Show the band"].set(false)
Check(ns.db.band == false and changed == "band", "the check flips the key through the toggle path")
Check(c["Pick A"] and c["Pick A"].kind == "radio", "a radio box is a radio")
Check(c["Size"] and c["Size"].kind == "slider" and c["Size"].min == 1 and c["Size"].max == 5 and c["Size"].get() == 3, "a stepper is a slider with its range")
c["Size"].set(9)
Check(ns.db.size == 5, "the slider clamps to the range")
Check(c["Look"] and c["Look"].kind == "choice" and c["Look"].get() == "a" and #c["Look"].choices == 2, "a drop group is a choice reading the key on")
c["Look"].set("b")
Check(ns.db.b == true and changed == "b", "the choice turns its key on")
Check(c["Color"] and c["Color"].get() == "red", "a value drop reads the value")
c["Color"].set("blue")
Check(ns.db.color == "blue", "and sets it through its apply")
Check(c["Go"] and c["Go"].kind == "button", "a button row is a button")
c["Go"].press()
Check(pressed == true, "whose press clicks the button")
Check(c["Many"] == nil, "a drop-down of several boxes stays a plain row")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("options_index_test: ok")
