local _, ns = ...

-- Forever stands a class's three skill lines in its own order (a mage's Arcane not first); Era stood them in talent tree
-- order. Each class's three by their icons, in Era's order (wago SkillLine and TalentTab, both clients).
local ERA_ORDER = {
    WARRIOR = { 132292, 132347, 132341 },   -- Arms, Fury, Protection
    PALADIN = { 135920, 135893, 135873 },   -- Holy, Protection, Retribution
    HUNTER = { 132164, 132222, 132215 },    -- Beast Mastery, Marksmanship, Survival
    ROGUE = { 132292, 132090, 132320 },     -- Assassination, Combat, Subtlety
    PRIEST = { 135987, 135920, 136207 },    -- Discipline, Holy, Shadow Magic
    SHAMAN = { 136048, 136051, 136052 },    -- Elemental Combat, Enhancement, Restoration
    MAGE = { 135932, 135810, 135846 },      -- Arcane, Fire, Frost
    WARLOCK = { 136145, 136172, 136186 },   -- Affliction, Demonology, Destruction
    DRUID = { 136096, 132276, 136041 },     -- Balance, Feral Combat, Restoration
}

local placeOf   -- icon -> Era place, for the player's class
local iconOf, spots, moved = {}, {}, {}

local function Places()
    if not placeOf then
        placeOf = {}
        local order = ns.OnForever() and ERA_ORDER[select(2, UnitClass("player"))]
        for place, icon in ipairs(order or {}) do placeOf[icon] = place end
    end
    return placeOf
end

local function ByEraPlace(a, b) return placeOf[iconOf[a]] < placeOf[iconOf[b]] end

-- The book's skill lines (not hidden, not another spec's) into out, at most max; the class's three take each other's
-- places in Era's order, every other line keeps its own.
function ns.BookLines(out, max)
    wipe(out)
    wipe(spots)
    wipe(moved)
    local places = Places()
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide and (info.offSpecID or 0) == 0 then
            out[#out + 1] = line
            iconOf[line] = info.iconID
            if places[info.iconID] then
                spots[#spots + 1] = #out
                moved[#moved + 1] = line
            end
        end
    end
    table.sort(moved, ByEraPlace)
    for i, spot in ipairs(spots) do out[spot] = moved[i] end
    for i = #out, (max or #out) + 1, -1 do out[i] = nil end
    return out
end
