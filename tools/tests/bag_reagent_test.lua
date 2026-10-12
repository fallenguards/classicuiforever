-- Offline test under Lua 5.4 for the reagent slots of ours in the one bag (Windows/BagReagent.lua): none without the
-- option or a reagent bag; made out of combat only (a slot made in a fight has its right-click refused), the rest once
-- it ends; the bag number on the parent, never a field on the slot (the game's click would read it as ours).
-- Run from the addon root: lua tools/tests/bag_reagent_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local function Frame(kind, name, parent, template)
    local f = { kind = kind, name = name, parent = parent, template = template, shown = true, id = 0 }
    function f:SetID(id) self.id = id end
    function f:GetID() return self.id end
    function f:SetAllPoints() end
    function f:SetScript() end
    function f:IsVisible() return false end
    function f:UnregisterAllEvents() end
    -- The template's mixin method the slot must drop, and its bag hover light.
    if template then
        f.GetItemContextMatchResult = function() end
        f.BagIndicator = { shown = false, SetShown = function(t, on) t.shown = on and true or false end }
    end
    return f
end

local slots, combat, calm = 24, false, {}
Enum = { BagIndex = { ReagentBag = 5 } }
C_Container = { GetContainerNumSlots = function() return slots end }
ContainerFrameCombinedBags = Frame("Frame", "ContainerFrameCombinedBags")
InCombatLockdown = function() return combat end
local expanded, hooks = true, {}
CharacterReagentBag0Slot = { GetIsBarExpanded = function() return expanded end }

local ns = {
    db = { reagentBagCombined = false },
    NewFrame = Frame,
    EventFrame = function() return Frame("Frame") end,
    RegisterEvents = function() end,
    SetShownIf = function(f, on) f.shown = on end,
    Sched = { NextFrame = function() end },
    WhenCalm = function(key, fn) calm[key] = fn end,
    ReskinOneBag = function() end,
    HookScriptOnce = function(frame, script, fn, tag)
        if frame == CharacterReagentBag0Slot and tag then hooks[script] = fn end
    end,
}
assert(loadfile(ROOT .. "/Windows/BagReagent.lua"))("ClassicUIForever", ns)

local list, n = ns.OwnReagentSlots()
Check(n == 0, "option off: no slots, got " .. n)
Check(list[1] == nil, "option off: none in the grid")

-- Made ahead with the option off: turned on in a fight, the slots show at once.
ns.db.reagentBagCombined, combat = true, true
list, n = ns.OwnReagentSlots()
combat = false
Check(n == 24 and #list == 24, "option on: 24 slots, got " .. n)
local first = list[1]
Check(first.template == "ContainerFrameItemButtonTemplate", "slots from the game's item button template")
Check(first.name == "ForeverClassicUIReagentSlot1", "slots named ours, got " .. tostring(first.name))
Check(first.parent.id == 5 and ns.IsReagentHolder(first.parent), "the bag number on the slots' parent")
Check(rawget(first, "bagID") == nil, "no bagID field on a slot")
Check(first.GetItemContextMatchResult == nil and first.noProfessionQualityOverlay == true,
    "slots off the game's callback lists")
Check(list[24]:GetID() == 24, "slot ids follow the bag's slots")

local function Lit()
    local count = 0
    for _, button in ipairs(list) do if button.BagIndicator.shown then count = count + 1 end end
    return count
end
Check(hooks.OnEnter and hooks.OnLeave, "hover on the reagent bag button heard, beside the bag row's own hook")
hooks.OnEnter(CharacterReagentBag0Slot)
Check(Lit() == 24, "hover on the reagent bag: its slots light, got " .. Lit())
hooks.OnLeave(CharacterReagentBag0Slot)
Check(Lit() == 0, "mouse off: the light goes, got " .. Lit())
expanded = false
hooks.OnEnter(CharacterReagentBag0Slot)
Check(Lit() == 0, "bag row folded: no light, as the game's bags")
expanded = true

combat, slots = true, 30
_, n = ns.OwnReagentSlots()
Check(n == 24, "in a fight: no slot made, got " .. n)
Check(calm["bags.reagentSlots"] ~= nil, "in a fight: the rest made once it ends")

combat = false
_, n = ns.OwnReagentSlots()
Check(n == 30, "after the fight: all 30, got " .. n)

slots = 0
_, n = ns.OwnReagentSlots()
Check(n == 0 and first.parent.shown == false and first.shown == false, "bag taken off: slots and holder hidden")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bag_reagent_test: all checks passed")
