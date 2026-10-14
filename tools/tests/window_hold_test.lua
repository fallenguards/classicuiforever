-- Offline test under Lua 5.4 for the row's hold (UI/Windows.lua stay, Release, NoteLeavers): a window that leaves the
-- row by drag or size holds the rest where they stand; an opening lays the row afresh. A member list kept across an
-- opening held a spellbook opened after the macro window had left unseen, on an anchor from an older size.
-- Run from the addon root: lua tools/tests/window_hold_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Cut(source, from, to)
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, "the code to test is in UI/Windows.lua")
    return source:sub(first, last - 1)
end

local handle = assert(io.open(ROOT .. "/UI/Windows.lua", "r"))
local source = handle:read("a")
handle:close()

local moved = {}
local env = setmetatable({
    ns = {},
    row = { game = {} },
    classicWindows = {},
    Moved = function(frame) return moved[frame] end,
    wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end,
}, { __index = _G })
local body = Cut(source, "local stay = setmetatable", "local WatchClientWindows")
    .. Cut(source, "local function NoteLeavers()", "local function Solve(")
    .. "\nreturn NoteLeavers, Release, stay"
local NoteLeavers, Release, stay = assert(load(body, "hold", "t", env))()

local function Window(name, slotX)
    local frame = { shown = false, fcuiSlotX = slotX }
    function frame:IsShown() return self.shown end
    function frame:GetName() return name end
    return frame
end
local macros, book, talents = Window("MacroFrame"), Window("book", 354), Window("talents", 392)
_G.MacroFrame = macros
env.classicWindows[book], env.classicWindows[talents] = true, true

-- The macro window in the row, then moved off it with none of ours open, so no pass saw it leave.
macros.shown = true
env.row.game = { { 16, 354, "MacroFrame" } }
NoteLeavers()
env.row.game = {}
book.shown = true
Release()
NoteLeavers()
Check(stay[book] == nil, "the spellbook opened after the macro window left is laid afresh, not held at "
    .. tostring(stay[book]))

-- Talents dragged out of the row: the spellbook stays where it stands.
talents.shown = true
Release()
NoteLeavers()
moved[talents] = true
NoteLeavers()
Check(stay[book] == 354, "a window dragged out of the row holds the rest (" .. tostring(stay[book]) .. ")")
Check(stay[talents] == nil, "the dragged window itself is not held")

_G.MacroFrame = nil
if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_hold_test: all checks passed")
