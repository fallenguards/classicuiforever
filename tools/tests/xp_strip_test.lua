-- Offline test under Lua 5.4: the XP bar on the band sits where Era's does (Bar/BandStatus.lua, Bar/BandArt.lua,
-- Bar/Band.lua). Era's band is 53 tall with its 43-row body at the foot; the XP rail fills the 10 above the body, so the
-- body's top edge line shows under it. One lower, the fill hid that line and the bar read short beside Era's (#303).
-- Run from the addon root: lua tools/tests/xp_strip_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Read(path)
    local file = assert(io.open(ROOT .. "/" .. path, "rb"))
    local text = file:read("a")
    file:close()
    return text
end

local status, art, band = Read("Bar/BandStatus.lua"), Read("Bar/BandArt.lua"), Read("Bar/Band.lua")
local stripH = tonumber(status:match("\nlocal STRIP_H = (%-?%d+)"))
local lowerY = tonumber(status:match("\nlocal LOWER_Y = (%-?%d+)"))
local upperY = tonumber(status:match("\nlocal UPPER_Y = (%-?%d+)"))
local artH = tonumber(art:match("\nlocal ART_H = (%d+)"))
local bodyH = tonumber(band:match("B%.ART_W, B%.BAND_H, B%.CAP_SIZE = %d+, (%d+),"))
Check(stripH and lowerY and upperY and artH and bodyH, "constants found")
if stripH and lowerY and upperY and artH and bodyH then
    Check(artH == 53 and bodyH == 43, "Era's band: 53 tall, body 43")
    Check(artH + lowerY == artH, "XP rail top at the band's top (got " .. (artH + lowerY) .. ")")
    Check(artH + lowerY - stripH == bodyH, "XP rail foot on the body's top (got " .. (artH + lowerY - stripH) .. ")")
    Check(upperY == lowerY, "the second bar's foot on the XP rail's top")
end

if failed > 0 then
    print(failed .. " XP strip check(s) failed")
    os.exit(1)
end
print("XP strip: all checks passed")
