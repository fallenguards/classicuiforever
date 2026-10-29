local _, ns = ...

-- The one color look, a theme's default: which part (its row under Textured color) a themed piece belongs to, by the
-- frames it sits in; anything else counts as the other windows' part.

local PartOf = ns.PartFinder({
    texturedBars = ns.BAR_ROOTS,
    texturedCharacter = { "CharacterFrame" },
    texturedSpellbook = { "PlayerSpellsFrame", "SpellBookFrame", "ForeverClassicUISpellBook" },
}, nil, "texturedWindows")
local PARTS = { "texturedBars", "texturedCharacter", "texturedSpellbook", "texturedWindows" }

-- Read by the dev addon's flatdump probe.
ns.FlatPartOf = PartOf

-- True while a theme is on and the piece's part is one color: every part, unless Textured color keeps it textured.
-- theme: the piece's own theme when the caller has it already.
function ns.FlatOn(piece, theme)
    local db = ns.db
    if not (db and (theme or ns.ThemeFor(piece))) then return false end
    if db.themeTextured ~= true then return true end
    return db[PartOf(piece)] == false
end

-- True while a theme darkens parchment past dark text: its color's lightness under DARK_PAGE.
local DARK_PAGE = 0.5
function ns.PageDark()
    local name = ns.ThemePartOn("themePartParchment") and ns.ThemeName()
    local t = name and ns.bronze.THEMES[name].tint
    if not t then return false end
    return 0.3 * t[1] + 0.59 * t[2] + 0.11 * t[3] < DARK_PAGE
end

-- Text on parchment: near white on a dark page, else r, g, b.
local PAGE_INK = { 0.9, 0.86, 0.76 }
ns.PAGE_INK = PAGE_INK
function ns.PageInk(r, g, b)
    if ns.PageDark() then return unpack(PAGE_INK) end
    return r, g, b
end

-- A setting that changes the theme: text on its pages repaints on it.
function ns.ThemeKey(key) return ns.bronze.THEME_KEYS[key] == true end

-- dbVersion 21: one color became a theme's default, Flat color's opposite Textured color. A theme worn without Flat
-- color stays textured; parts left out of Flat color stay textured. In the account and every profile.
function ns.KeepTexturedLook()
    local function Keep(t)
        if t.themeFlat == true then
            local kept = false
            for _, part in ipairs(PARTS) do kept = kept or t["flat" .. part:sub(9)] == false end
            if kept then
                t.themeTextured = true
                for _, part in ipairs(PARTS) do t[part] = t["flat" .. part:sub(9)] == false end
            end
        elseif t.bronzeTheme == true then
            t.themeTextured = true
        end
        t.themeFlat, t.flatHideBorders = nil, nil
        for _, part in ipairs(PARTS) do t["flat" .. part:sub(9)] = nil end
    end
    local db = ns.db
    local saved = { db }
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then saved[#saved + 1] = shot end
    end
    for _, t in ipairs(saved) do Keep(t) end
    db.dbVersion = 21
end

