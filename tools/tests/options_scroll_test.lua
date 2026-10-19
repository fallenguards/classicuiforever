-- Offline test under Lua 5.4 for the options window's scroll (Options/OptionsWindow.lua Show): a refresh after a toggle
-- stays where the player is; a new page or search starts at the top. Every toggle refreshed the window through the page
-- draw, which set the scroll back to the top: a box low on a long page jumped the page up (#197).
-- Run from the addon root: lua tools/tests/options_scroll_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Options/OptionsWindow.lua", "r"))
local source = handle:read("a"):gsub("\r\n", "\n")
handle:close()
local first = source:find("local function Show(frame", 1, true)
local last = first and source:find("\nend\n", first, true)
assert(first and last, "Show(frame) is in Options/OptionsWindow.lua")

-- The page's rows: 600 tall in a 300 list, so the bar runs 0 to 300.
local RANGE = 300
local function Stub() return setmetatable({}, { __index = function() return function() end end }) end
local list = { scroll = 0, child = nil }
function list:GetScrollChild() return self.child end
function list:SetScrollChild(child) self.child, self.scroll = child, 0 end
function list:SetVerticalScroll(v) self.scroll = v end
local bar = { value = 0, max = RANGE }
function bar:GetValue() return self.value end
function bar:SetValue(v)
    self.value = math.max(0, math.min(v, self.max))
    list:SetVerticalScroll(self.value)
end
function bar:SetRange(max)
    self.max = math.max(0, max)
    self:SetValue(math.min(self.value, self.max))
end
local search = Stub()
search.GetText = function() return "" end
search.hint, search.clear = Stub(), Stub()
local frame = { search = search, page = "Action bars", panes = {}, pageTitle = Stub(), pageButtons = {}, homeButtons = {},
    homeHint = Stub(), nav = {}, list = list, listChild = Stub(), listBar = bar, pageNote = Stub() }

local env = setmetatable({
    HOME = "Home", TITLE = "ClassicUI Forever", HOME_HEAD = 0, L = setmetatable({}, { __index = function(_, k) return k end }),
    O = { PAGE_NOTES = {} }, NOTE_GAP = 8,
    FitList = function() end,
    PlaceRows = function(f) f.listBar:SetRange(RANGE) end,
}, { __index = _G })
local Show = assert(load(source:sub(first, last + 4) .. "\nreturn Show", "Show", "t", env))()

Show(frame)
bar:SetValue(240)
Show(frame, true)
Check(bar:GetValue() == 240 and list.scroll == 240,
    "a refresh after a toggle stays where the player is (bar " .. bar:GetValue() .. ", list " .. list.scroll .. ")")
Show(frame)
Check(bar:GetValue() == 0 and list.scroll == 0, "a new page or a search starts at the top")

-- The toggle refreshes ask to keep the spot.
local refresh = source:match("function ns%.RefreshOptionsWindow%(%)(.-)\nend")
Check(refresh and refresh:find("Refresh%(true%)"), "ns.RefreshOptionsWindow keeps the scroll")
local finish = source:match("local function Finish%(%)(.-)\nend")
Check(finish and finish:find("Refresh%(true%)"), "the bulk toggle writes keep the scroll")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("options_scroll_test: ok")
