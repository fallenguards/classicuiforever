-- Offline tests for Options/OptionsSearch.lua under Lua 5.4: Only show matches shows the matching rows alone, never
-- the rest of a matching row's section nor the rows above a match (a search for "dark" listed the whole theme section).
-- Run from the addon root: lua tools/tests/search_only_matches_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local ns = {}
assert(loadfile(ROOT .. "/Options/OptionsSearch.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ the rows of the screenshot

-- key, parent, name side, tooltip
local ROWS = {
    { "bronzeTheme", nil, "custom theme custom skin color dark mode look" },
    { "themeBronze", "bronzeTheme", "bronze look" },
    { "themeCustom", "bronzeTheme", "custom color rgb hex color look" },
    { "themeColor", "themeCustom", "color rgb hex color theme look" },
    { "themeDark", "bronzeTheme", "dark look" },
    { "themeDarkness", "themeDark", "dark black grey gray shade slider theme look" },
    { "themeFlat", "bronzeTheme", "flat color flat solid plain texture look" },
    { "flatHideBorders", "themeFlat", "hide inner borders look" },
    { "themeIgnoreElite", "bronzeTheme", "ignore theme for elite frames look" },
    { "classicBar", nil, "classic bar action bars" },
    { "shadedBars", "classicBar", "shaded xp and reputation bars darker action bars" },
    { "panels", nil, "panels look" },
}

local boxes, kids, parentOf = {}, {}, {}
for _, r in ipairs(ROWS) do
    local box = { key = r[1], keyLow = r[3], tipLow = "" }
    boxes[#boxes + 1] = box
    parentOf[r[1]] = r[2]
    if r[2] then
        kids[r[2]] = kids[r[2]] or {}
        table.insert(kids[r[2]], box)
    end
end

local function Search(text, only)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    local level, best, matched = {}, 0, {}
    for _, box in ipairs(boxes) do
        level[box] = ns.OptionMatchLevel(box, words)
        if level[box] > best then best = level[box] end
    end
    for _, box in ipairs(boxes) do matched[box] = best > 0 and level[box] == best end
    local hit = ns.OptionSearchHits(boxes, matched, kids, parentOf, text ~= "", only)
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

Check("only matches: the matching rows alone", Search("dark", true), "bronzeTheme themeDark themeDarkness shadedBars")
Check("whole sections without it", Search("dark", false),
    "bronzeTheme themeBronze themeCustom themeColor themeDark themeDarkness themeFlat flatHideBorders"
    .. " themeIgnoreElite classicBar shadedBars")
Check("a child match alone, no parent", Search("hide inner", true), "flatHideBorders")
Check("no search shows everything", Search("", true), table.concat((function()
    local all = {}
    for _, r in ipairs(ROWS) do all[#all + 1] = r[1] end
    return all
end)(), " "))

if failures > 0 then
    print(string.format("search only matches: %d failed", failures))
    os.exit(1)
end
print("search only matches: ok")
