-- Offline test under Lua 5.4 for the Damage row's tooltip numbers (FillHand in Character/CharacterStats.lua), as Era's
-- PaperDollFrame_SetDamage works them out: the range before bonuses, the bonuses after it, and damage per second.
-- Run from the addon root: lua tools/tests/damage_tip_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Character/CharacterStats.lua", "r"))
local source = handle:read("a"):gsub("\r\n", "\n")
handle:close()
local from = source:find("local function FillHand(", 1, true)
local to = from and source:find("\nend\n", from, true)
Check(from and to, "FillHand is in the file")
local env = setmetatable({ GREEN = "<g>", RED = "<r>" }, { __index = _G })
local FillHand = assert(load("local GREEN, RED = GREEN, RED\n" .. source:sub(from or 1, (to or 0) + 4)
    .. "\nreturn FillHand", "hand", "t", env))()

local hand = {}
FillHand(hand, 10, 20, 2, 0, 0, 1)
Check(hand.damage == "10 - 20" and hand.speed == 2 and hand.dps == 7.5, "no bonus: the range as is, 7.5 a second")

FillHand(hand, 15, 25, 2, 5, 0, 1)
Check(hand.damage == "10 - 20<g> +5|r", "a bonus: the range before it, the bonus after in green")
Check(hand.dps == 10, "a bonus: counted in damage per second")

FillHand(hand, 12, 24, 2, 0, 0, 1.2)
Check(hand.damage == "10 - 20<g> x120%|r", "a damage multiplier: shown as a percent")

FillHand(hand, 10, 20, 0, 0, 0, 1)
Check(hand.dps == 0, "no attack speed: no damage per second, no division by zero")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("damage_tip_test: ok")
