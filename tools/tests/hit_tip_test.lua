-- Offline test under Lua 5.4 for the classic stat panes' Hit Chance tooltip on Forever (Character/StatPanes.lua, #307):
-- the client's CharacterHitFrame_OnEnter takes the off hand's hit as a sixth number and starts with max() over all
-- four, so a call with five failed and no tooltip showed. Our lines pass the off hand as the client's own line does.
-- Run from the addon root: lua tools/tests/hit_tip_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Character/StatPanes.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("-- Melee, ranged and spell", 1, true)
local last = first and source:find("local function HasRanged", first, true)
assert(first and last, "the hit reader and tooltips are in Character/StatPanes.lua")

local seen
local function Load(globals)
    seen = nil
    local G = {
        STAT_HIT_CHANCE = "Hit Chance",
        CR_HIT_MELEE = 6, CR_HIT_RANGED = 7, CR_HIT_SPELL = 8,
        GetCombatRatingBonus = function() return 0 end,
        GetHitModifier = function() return 1 end,
        GetRangedHitModifier = function() return 0 end,
        GetSpellHitModifier = function() return 0 end,
        -- Forever's (Camelot PaperDollFrameStats.lua): max over all four throws on a nil one.
        CharacterHitFrame_OnEnter = function(self, melee, ranged, spell, label, offhand)
            local top = math.max(melee, ranged, spell, offhand)
            seen = { top = top, offhand = offhand, label = label }
        end,
    }
    for k, v in pairs(globals) do G[k] = v end
    local env = setmetatable({
        _G = G,
        CreateFrame = function() return {} end,
        ns = { OnForever = function() return true end },
        Put = function() end,
    }, { __index = _G })
    local chunk = source:sub(first, last - 1) .. "\nreturn Hits, HitTip, School"
    return assert(load(chunk, "hits", "t", env))()
end

-- Forever: the off hand read with the others and handed to the client's tooltip.
local Hits, HitTip, School = Load({ GetOffhandHitModifier = function() return 3 end })
local row = {}
School(Hits, 1, "Hit Chance", "+%.2f%%", HitTip)(row)
local ok, err = pcall(row.onEnterFunc, row)
Check(ok, "the tooltip draws (" .. tostring(err) .. ")")
Check(seen and seen.offhand == 3, "the off hand's hit goes in (" .. tostring(seen and seen.offhand) .. ")")
Check(seen and seen.top == 3, "the tooltip's top number is the highest of the four")

-- No off hand reader: the main hand's number stands in, so the client's max still has four numbers.
Hits, HitTip, School = Load({})
row = {}
School(Hits, 3, "Hit Chance", "+%.2f%%", HitTip)(row)
ok, err = pcall(row.onEnterFunc, row)
Check(ok, "with no off hand reader the tooltip still draws (" .. tostring(err) .. ")")
Check(seen and seen.offhand == 1, "the main hand stands in for the off hand")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("hit_tip_test: ok")
