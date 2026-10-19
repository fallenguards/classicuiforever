-- Offline tests for Options/OptionsSearch.lua under Lua 5.4: a search shows each match and the boxes above it (parents,
-- and a box it needs), never the rest of its section (a search for "dark" listed the whole theme section), so a match
-- that is off can be switched on where it shows.
-- Run from the addon root: lua tools/tests/search_hits_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local ns = {}
assert(loadfile(ROOT .. "/Options/OptionsSearch.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ the rows of the screenshot

-- key, parent, name side, needs
local ROWS = {
    { "bronzeTheme", nil, "custom theme custom skin color dark mode look" },
    { "themeBronze", "bronzeTheme", "bronze look" },
    { "themeCustom", "bronzeTheme", "custom color rgb hex color look" },
    { "themeColor", "themeCustom", "color rgb hex color theme look" },
    { "themeDark", "bronzeTheme", "dark look" },
    { "themeDarkness", "themeDark", "dark black grey gray shade slider theme look" },
    { "themeTextured", "bronzeTheme", "textured color texture textured flat solid plain stone grain look" },
    { "texturedWindows", "themeTextured", "other windows look" },
    { "themeIgnoreElite", "bronzeTheme", "ignore theme for elite frames look" },
    { "classicBar", nil, "classic bar action bars" },
    { "shadedBars", "classicBar", "shaded xp and reputation bars darker action bars" },
    { "panels", nil, "panels look" },
    { "classicTracking", "classicBar", "classic tracking button" },
    { "trackingSameSize", "classicBar", "same size as tracking", "classicTracking" },
}

local boxes, kids, parentOf = {}, {}, {}
for _, r in ipairs(ROWS) do
    local box = { key = r[1], keyLow = r[3], tipLow = "", needs = r[4] }
    boxes[#boxes + 1] = box
    parentOf[r[1]] = r[2]
    if r[2] then
        kids[r[2]] = kids[r[2]] or {}
        table.insert(kids[r[2]], box)
    end
end

local function Search(text)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    local level, best, matched = {}, 0, {}
    for _, box in ipairs(boxes) do
        level[box] = ns.OptionMatchLevel(box, words)
        if level[box] > best then best = level[box] end
    end
    for _, box in ipairs(boxes) do matched[box] = best > 0 and level[box] == best end
    local hit = ns.OptionSearchHits(boxes, matched, parentOf, text ~= "")
    local shown = {}
    for _, box in ipairs(boxes) do
        if hit[box.key] then shown[#shown + 1] = box.key end
    end
    return table.concat(shown, " ")
end

------------------------------------------------------------------ checks

local failures = 0
local function Check(what, got, want)
    if got ~= want then
        failures = failures + 1
        print("FAIL: " .. what .. "\n  got:  " .. got .. "\n  want: " .. want)
    end
end

Check("the matches and the boxes above them, no other rows of their sections", Search("dark"),
    "bronzeTheme themeDark themeDarkness classicBar shadedBars")
Check("a nested match brings every box above it", Search("other windows"), "bronzeTheme themeTextured texturedWindows")
Check("a match brings the box it needs", Search("same size"), "classicBar classicTracking trackingSameSize")
Check("no search shows everything", Search(""), table.concat((function()
    local all = {}
    for _, r in ipairs(ROWS) do all[#all + 1] = r[1] end
    return all
end)(), " "))

if failures > 0 then
    print(string.format("search hits: %d failed", failures))
    os.exit(1)
end
print("search hits: ok")
