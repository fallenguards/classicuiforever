-- Offline test under Lua 5.4 for the spellbook's tab order (Spells/BookLines.lua): on Forever a class's three skill lines
-- stand in Era's order whatever order the client hands them in; General and any other line keep their places; hidden
-- and other specs' lines are left out; retail keeps the client's order.
-- Run from the addon root: lua tools/tests/book_lines_test.lua (CI runs every tools/tests/*_test.lua).
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

wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local class, forever = "MAGE", true
local lines = {}
UnitClass = function() return class, class end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return #lines end,
    GetSpellBookSkillLineInfo = function(i) return lines[i] end,
}

local function Load()
    local ns = { OnForever = function() return forever end }
    assert(loadfile(ROOT .. "/Spells/BookLines.lua"))("ClassicUIForever", ns)
    return ns
end

local function Names(ns, max)
    local out = {}
    for _, line in ipairs(ns.BookLines({}, max)) do out[#out + 1] = lines[line].name end
    return table.concat(out, ",")
end

local GENERAL = { name = "General", iconID = 136830 }

-- A mage's lines as Forever hands them back.
lines = { GENERAL, { name = "Frost", iconID = 135846 }, { name = "Fire", iconID = 135810 },
    { name = "Arcane", iconID = 135932 } }
local ns = Load()
Check(Names(ns) == "General,Arcane,Fire,Frost", "mage: Era's order, got " .. Names(ns))

-- Another line between them keeps its place; hidden and other specs' lines are left out.
lines = { GENERAL, { name = "Frost", iconID = 135846 }, { name = "Other", iconID = 1 },
    { name = "Hidden", iconID = 2, shouldHide = true }, { name = "Fire", iconID = 135810 },
    { name = "Spec", iconID = 3, offSpecID = 62 }, { name = "Arcane", iconID = 135932 } }
Check(Names(ns) == "General,Arcane,Other,Fire,Frost", "mage with others: got " .. Names(ns))
Check(Names(ns, 3) == "General,Arcane,Other", "at most max lines, ordered first: got " .. Names(ns, 3))

-- Every class: its three come out in Era's order from the reverse.
local ERA = {
    WARRIOR = { { "Arms", 132292 }, { "Fury", 132347 }, { "Protection", 132341 } },
    PALADIN = { { "Holy", 135920 }, { "Protection", 135893 }, { "Retribution", 135873 } },
    HUNTER = { { "Beast Mastery", 132164 }, { "Marksmanship", 132222 }, { "Survival", 132215 } },
    ROGUE = { { "Assassination", 132292 }, { "Combat", 132090 }, { "Subtlety", 132320 } },
    PRIEST = { { "Discipline", 135987 }, { "Holy", 135920 }, { "Shadow Magic", 136207 } },
    SHAMAN = { { "Elemental Combat", 136048 }, { "Enhancement", 136051 }, { "Restoration", 136052 } },
    WARLOCK = { { "Affliction", 136145 }, { "Demonology", 136172 }, { "Destruction", 136186 } },
    DRUID = { { "Balance", 136096 }, { "Feral Combat", 132276 }, { "Restoration", 136041 } },
}
for name, three in pairs(ERA) do
    class = name
    lines = { GENERAL }
    local want = { "General" }
    for i = 3, 1, -1 do lines[#lines + 1] = { name = three[i][1], iconID = three[i][2] } end
    for i = 1, 3 do want[#want + 1] = three[i][1] end
    local fresh = Load()
    Check(Names(fresh) == table.concat(want, ","), name .. ": Era's order, got " .. Names(fresh))
end

-- Retail: the client's order.
class, forever = "MAGE", false
lines = { GENERAL, { name = "Frost", iconID = 135846 }, { name = "Arcane", iconID = 135932 } }
local retail = Load()
Check(Names(retail) == "General,Frost,Arcane", "retail: the client's order, got " .. Names(retail))

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("book_lines_test: all checks passed")
