-- Offline test under Lua 5.4 for the talents window's spec tabs (Skills/TalentSpecs.lua): Era's main tree pick for a
-- tab's icon, the tabs only with two specs, Activate only on the spec not in use, the switch call, the dev fake.
-- Run from the addon root: lua tools/tests/talent_specs_test.lua (CI runs every tools/tests/*_test.lua).
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

local NOOP = function() end
local function Stub(fields)
    return setmetatable(fields or {}, { __index = function() return NOOP end })
end

local function Shown(fields)
    local s = Stub(fields)
    s.shown = false
    function s:SetShown(on) self.shown = on and true or false end
    function s:Show() self.shown = true end
    function s:Hide() self.shown = false end
    function s:IsShown() return self.shown end
    return s
end

local groups, active, switched = 1, 1, nil
GetNumSpecGroups = function() return groups end
C_SpecializationInfo = {
    GetActiveSpecGroup = function() return active end,
    SetActiveSpecGroup = function(group) switched = group end,
}
GameTooltip = Stub({ IsOwned = function() return false end })
PlaySound, SOUNDKIT = NOOP, {}
GREEN_FONT_COLOR = Stub({ GetRGB = function() return 0.1, 1, 0.1 end })
HIGHLIGHT_FONT_COLOR = Stub({ GetRGB = function() return 1, 1, 1 end })
TALENT_ACTIVATION_SPELLS = { 63645, 63644 }
C_Spell = { IsCurrentSpell = function() return false end }

local tabs, button, points = {}, nil, {}
local TL = {}
local ns = {
    talents = TL, EMPTY = {}, SIDE_TAB_SLOT = 392,
    IsSecret = function() return false end,
    RegisterEvents = NOOP,
    SkillLineTab = function()
        local tab = Shown()
        function tab:SetID(id) self.id = id end
        function tab:GetID() return self.id end
        function tab:SetScript(name, fn) self[name] = fn end
        function tab:SetChecked(on) self.checked = on end
        function tab:SetNormalTexture(icon) self.icon = icon end
        tabs[#tabs + 1] = tab
        return tab
    end,
    PanelButton = function()
        button = Shown({ GetFontString = function() return Stub({ GetStringWidth = function() return 50 end }) end })
        function button:SetScript(name, fn) self[name] = fn end
        function button:SetEnabled(on) self.enabled = on end
        return button
    end,
    SetPointOnce = function(region, point, relative) points[region] = relative end,
}
-- Each spec's trees: the first deep in Fire, the second spread.
local SPEC_TREES = {
    { { name = "Arcane", icon = "arcane", spent = 0 }, { name = "Fire", icon = "fire", spent = 31 },
        { name = "Frost", icon = "frost", spent = 20 } },
    { { name = "Arcane", icon = "arcane", spent = 21 }, { name = "Fire", icon = "fire", spent = 20 },
        { name = "Frost", icon = "frost", spent = 10 } },
}
function TL.ReadSpecTrees(group) return SPEC_TREES[group or active] end

assert(loadfile(ROOT .. "/Skills/TalentSpecs.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ Era's main tree

Check(TL.MainTree(SPEC_TREES[1]) == 2, "31/20/0: Fire is the main tree")
Check(TL.MainTree(SPEC_TREES[2]) == nil, "21/20/10: a hybrid, no main tree")
Check(TL.MainTree({ { spent = 0 }, { spent = 0 }, { spent = 0 } }) == nil, "nothing spent: no main tree")
Check(TL.MainTree({ { spent = 0 }, { spent = 41 }, { spent = 10 } }) == 2, "0/41/10: the deep tree")

------------------------------------------------------------------ the window

local refreshed = 0
local frame = { spentBar = Shown(), learn = Shown(), foot = {}, trees = { on = false, Reslot = function() end } }
local reslots = 0
frame.trees.Reslot = function() reslots = reslots + 1 end
frame.spentBar:Show()
frame.learn:Show()
TL.BuildSpecs(frame, function() refreshed = refreshed + 1 end)
Check(#tabs == 2 and tabs[1].id == 1 and tabs[2].id == 2, "two spec tabs, ids 1 and 2")

TL.ShowActiveSpec()
TL.DrawSpecs(frame, true)
Check(not tabs[1].shown and not tabs[2].shown, "one spec: no tabs, as Era")
Check(TL.SpecTitle(true) == nil and TL.OtherSpec(true) == nil, "one spec: the plain title, the spec in use drawn")
Check(not button.shown and frame.spentBar.shown, "one spec: the points bar, no Activate")
Check(TL.specSlot == nil, "one spec: the row's own width")

groups = 2
TL.DrawSpecs(frame, true)
Check(tabs[1].shown and tabs[2].shown, "two specs: both tabs")
Check(tabs[1].checked == true and tabs[2].checked == false, "the spec in use picked")
Check(tabs[1].icon == "fire", "a deep spec's tab: its main tree's icon")
Check(tabs[2].icon == "Interface\\Icons\\Ability_DualWieldSpecialization", "a spread spec's tab: Era's hybrid icon")
Check(TL.specSlot == 392 and reslots == 1, "two specs: the row leaves the tabs room")
Check(not button.shown and frame.spentBar.shown, "on the spec in use: the points bar, no Activate")

tabs[2].OnClick(tabs[2])
Check(refreshed == 1 and TL.OtherSpec(true) == 2, "the second tab picked: that spec drawn")
TL.DrawSpecs(frame, true)
Check(button.shown and not frame.spentBar.shown, "the spec not in use: Activate in the points bar's place")
Check(points[button] == frame and frame.learn.shown, "one tree: Activate at the top, Apply kept")
button.OnClick()
Check(switched == 2, "Activate asks the game for the picked spec")

frame.trees.on = true
TL.DrawSpecs(frame, true)
Check(points[button] == frame.foot and not frame.learn.shown and not frame.spentBar.shown,
    "three trees: Activate in Apply's place at the foot")
frame.trees.on = false

active = 2
TL.ShowActiveSpec()
TL.DrawSpecs(frame, true)
Check(tabs[2].checked == true and not button.shown, "the switch done: the new spec picked, no Activate")

TL.DrawSpecs(frame, false)
Check(not tabs[1].shown and not tabs[2].shown and TL.OtherSpec(false) == nil, "someone else's talents: no tabs")
Check(TL.specSlot == nil and reslots == 2, "no tabs: the row's own width again")

------------------------------------------------------------------ /fcuidev dualspec

groups, active, switched = 1, 1, nil
TL.fakeSpecs = { active = 1 }
TL.ShowActiveSpec()
TL.DrawSpecs(frame, true)
Check(tabs[1].shown and tabs[2].shown, "faked: two tabs on one spec")
tabs[2].OnClick(tabs[2])
TL.DrawSpecs(frame, true)
button.OnClick()
Check(switched == nil and TL.fakeSpecs.active == 2, "faked: Activate swaps which is in use, the game untouched")
TL.fakeSpecs = nil

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("talent_specs_test: all checks passed")
