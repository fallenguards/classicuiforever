-- Offline test for the theme masks (Art/ThemeArt.lua, media/theme-mask/): every themed sheet's file is shipped, and
-- each mask it wears (metal, parchment, picture) or its lifted metal file is too, at the sheet's own pixel size, since
-- a layer draws the sheet under its mask with the piece's crop. A mask is stored top row first: the game's mask reader
-- ignores the TGA origin flag, and bottom-up masks drew upside down (bands across the micro and red buttons).
-- Run from the addon root: lua tools/tests/theme_masks_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end
local MEDIA = ROOT .. "/media/"

local failures, checked = 0, 0
local function Fail(line)
    failures = failures + 1
    print("FAIL " .. line)
end

-- Width and height from a TGA or BLP2 header, and for a TGA whether its top row comes first; nil when missing or unread.
local function Size(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local head = file:read(20) or ""
    file:close()
    if #head < 20 then return nil end
    if head:sub(1, 4) == "BLP2" then return string.unpack("<I4I4", head, 13) end
    local w, h = string.unpack("<I2I2", head, 13)
    return w, h, head:byte(18) & 0x20 ~= 0
end

local ns = {}
assert(loadfile(ROOT .. "/Art/ThemeArt.lua"))("ClassicUIForever", ns)
local function Names(list)
    local out = {}
    for line in (list or ""):gmatch("[^\n]+") do out[line:lower()] = line end
    return out
end
local lifted, parch, pictures = Names(ns.METAL_FILE), Names(ns.PARCH_ART), Names(ns.PICTURE_ART)

local function Mask(name, suffix, w, h, what)
    local mw, mh, topFirst = Size(MEDIA .. "theme-mask/" .. name .. suffix .. ".tga")
    checked = checked + 1
    if not mw then
        Fail(string.format("%s has no %s (theme-mask/%s%s.tga)", name, what, name, suffix))
    elseif mw ~= w or mh ~= h then
        Fail(string.format("%s %s is %dx%d, its sheet %dx%d", name, what, mw, mh, w, h))
    elseif suffix ~= "_metal" and not topFirst then
        Fail(string.format("%s %s is stored bottom row first: the game draws it upside down", name, what))
    end
end

local sheets = 0
for file in (ns.THEME_ART or ""):gmatch("[^\n]+") do
    sheets = sheets + 1
    local path = MEDIA .. file:gsub("\\", "/")
    local name = file:match("([^\\]+)%.%w+$")
    local w, h = Size(path)
    if not w then
        Fail("themed sheet not shipped: media/" .. file)
    else
        local key = name:lower()
        if lifted[key] then Mask(name, "_metal", w, h, "lifted metal file") else Mask(name, "", w, h, "metal mask") end
        if parch[key] then Mask(name, "_parch", w, h, "parchment mask") end
        if pictures[key] then Mask(name, "_picture", w, h, "picture mask") end
        parch[key], pictures[key], lifted[key] = nil, nil, nil
    end
end
for _, leftover in ipairs({ lifted, parch, pictures }) do
    for _, name in pairs(leftover) do Fail(name .. " is listed with a mask but is no themed sheet") end
end
if sheets == 0 then Fail("Art/ThemeArt.lua lists no themed sheet") end

if failures > 0 then
    print(string.format("theme masks: %d failed (%d sheets, %d masks)", failures, sheets, checked))
    os.exit(1)
end
print(string.format("theme masks: ok (%d sheets, %d masks and metal files)", sheets, checked))
