-- Offline test under Lua 5.4 for the totem bar's buttons in the classic button skin's walk (Bar/Buttons.lua). The bar
-- keeps no button list of its own: its summon and recall spells and the twelve totem action buttons are walked by name,
-- and its slot buttons (the colored totem frames) are not. A client without the bar walks nothing of it.
-- Run from the addon root: lua tools/tests/totem_buttons_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Frame(name)
    return { name = name, GetName = function(self) return self.name end }
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local ns = { RegisterModule = function() end }
assert(loadfile(ROOT .. "/Bar/Buttons.lua"))("ClassicUIForever", ns)

local function Walk()
    local seen = {}
    ns.ForEachActionButton(function(button) seen[button.name] = true end)
    return seen
end

-- Forever: the totem bar with its buttons.
MultiCastActionBarFrame = Frame("MultiCastActionBarFrame")
MultiCastSummonSpellButton = Frame("MultiCastSummonSpellButton")
MultiCastRecallSpellButton = Frame("MultiCastRecallSpellButton")
for i = 1, 12 do _G["MultiCastActionButton" .. i] = Frame("MultiCastActionButton" .. i) end
for i = 1, 4 do _G["MultiCastSlotButton" .. i] = Frame("MultiCastSlotButton" .. i) end
local seen = Walk()
Check(seen.MultiCastSummonSpellButton and seen.MultiCastRecallSpellButton, "the summon and recall spells are walked")
local pages = 0
for i = 1, 12 do
    if seen["MultiCastActionButton" .. i] then pages = pages + 1 end
end
Check(pages == 12, "all twelve totem action buttons are walked (" .. pages .. ")")
Check(not seen.MultiCastSlotButton1, "the slot buttons keep their totem frames")

-- A client without the bar.
MultiCastActionBarFrame = nil
seen = Walk()
Check(next(seen) == nil, "nothing walked without the bar")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("totem_buttons_test: all checks passed")
