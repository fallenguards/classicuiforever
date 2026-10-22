-- Offline test under Lua 5.4 for the map side tab's list at a picked font size (Quest/QuestMapPane.lua Grow, Restack):
-- the game measures a row it just made in its own font, before ours goes on, so a new row kept the old height and the
-- rows under it overlapped its text until the list was built again (collapse and expand a section).
-- Run from the addon root: lua tools/tests/quest_restack_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Quest/QuestMapPane.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("-- A row the game just made", 1, true)
local last = first and source:find("-- 1.x row highlight and check box", first, true)
assert(first and last, "the list's restack is in Quest/QuestMapPane.lua")

-- A row anchored from the list's top as the game's vertical layout leaves it.
local contents = { h = 200 }
function contents:GetHeight() return self.h end
function contents:SetHeight(h) self.h = h end
local function Row(y, h, questID)
    local row = { point = { "TOPLEFT", contents, "TOPLEFT", 0, y }, h = h, questID = questID, shown = true }
    function row:GetPoint() return table.unpack(self.point) end
    function row:SetPoint(...) self.point = { ... } end
    function row:GetHeight() return self.h end
    function row:SetHeight(h) self.h = h end
    function row:IsShown() return self.shown end
    return row
end
local function Y(row) return row.point[5] end

local header = Row(0, 20)
local titleA = Row(-20, 40, 101)
local titleB = Row(-60, 30, 102)
local hidden = Row(-90, 20)
hidden.shown = false
local header2 = Row(-90, 20)
local poi = Row(-24, 16)
poi.point = { "TOPLEFT", titleA, "TOPLEFT", 6, -4 }
local children = { titleB, header2, poi, header, hidden, titleA }

local wipe = function(t) for k in pairs(t) do t[k] = nil end end
local env = setmetatable({
    wipe = wipe,
    QuestScrollFrame = {
        Contents = contents,
        titleFramePool = { EnumerateActive = function() local i = 0 return function() i = i + 1 return ({ titleA, titleB })[i] end end },
    },
    ns = { EachChild = function(frame, fn, a1) for _, child in ipairs(children) do fn(child, a1) end end },
}, { __index = _G })
local Grow, Restack = assert(load(source:sub(first, last - 1) .. "\nreturn Grow, Restack", "restack", "t", env))()

-- Nothing grew (rows reused, already in our font): nothing moves.
Restack()
Check(Y(titleB) == -60 and Y(header2) == -90 and contents.h == 200, "with no new row nothing moves")

-- A new title wrapped to a second line (12 more) and a new objective line under it grew 3: that row takes 15, every
-- row under it moves down 15, the list grows 15; rows above, a hidden row and a pin hung on the row stay put.
Grow(101, 12)
Grow(101, 3)
Grow(nil, 50)
Grow(102, 0)
Restack()
Check(titleA.h == 55, "the grown title takes what its font and lines added (" .. titleA.h .. ")")
Check(Y(header) == 0 and Y(titleA) == -20, "rows above and the grown row itself stay")
Check(Y(titleB) == -75 and Y(header2) == -105, "rows under it move down by what it grew")
Check(Y(hidden) == -90, "a hidden row is left alone")
Check(poi.point[2] == titleA and poi.point[5] == -4, "a pin hung on a row rides it, unmoved")
Check(titleB.h == 30, "a row that did not grow keeps its height")
Check(contents.h == 215, "the list grows by the total (" .. contents.h .. ")")

-- Two rows grow: each shift adds up down the list.
Grow(101, 5)
Grow(102, 10)
Restack()
Check(Y(titleB) == -80 and Y(header2) == -120 and contents.h == 230, "two grown rows add up below them")

-- Handled once: a later pass with nothing new moves nothing.
Restack()
Check(Y(header2) == -120 and contents.h == 230, "a pass after it moves nothing again")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("quest_restack_test: all checks passed")
