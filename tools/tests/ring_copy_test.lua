-- Offline test under Lua 5.4: the spellbook ring copy (media/UI-SpellbookPanel-Ring.tga) is drawn over the same ring
-- in the art under it (Skills/ProfessionsBookFrame.lua): a soft pixel drawn twice came out darker, and the professions
-- book's portrait differed from the spellbook's. Soft pixels stay only on the inner rim, over the game's portrait.
-- Run from the addon root: lua tools/tests/ring_copy_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local PATH = ROOT .. "/media/UI-SpellbookPanel-Ring.tga"
local CX, CY, INNER_SOFT = 40, 36, 30.5   -- dev/tools/spellbook_ring.py
local file = assert(io.open(PATH, "rb"))
local data = file:read("a")
file:close()

-- Uncompressed 32 bit TGA: an 18 byte head, its id field, then BGRA pixels, bottom row first unless bit 5 is set.
local kind, depth, desc = data:byte(3), data:byte(17), data:byte(18)
local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
assert(kind == 2 and depth == 32, "ring copy: expected an uncompressed 32 bit TGA, got type " .. kind .. ", " .. depth .. " bit")
local topFirst = desc & 0x20 ~= 0
local start = 18 + data:byte(1)
local outer = 0
for i = 0, w * h - 1 do
    local alpha = data:byte(start + i * 4 + 4)
    if alpha ~= 0 and alpha ~= 255 then
        local x, row = i % w, i // w
        local y = topFirst and row or (h - 1 - row)
        if math.sqrt((x + 0.5 - CX) ^ 2 + (y + 0.5 - CY) ^ 2) >= INNER_SOFT then outer = outer + 1 end
    end
end
if outer > 0 then
    print(string.format("FAIL ring copy: %d soft pixels past the inner rim; cut it with dev/tools/spellbook_ring.py", outer))
    os.exit(1)
end
print("ring_copy_test: ok")
