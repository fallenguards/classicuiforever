-- Offline test under Lua 5.4 for the character window's stat boxes while the game hides stat numbers from addons
-- (Character/StatPanes.lua and StatHidden.lua, #330). In a fight (and maybe a whole battleground) the numbers come back secret: the boxes
-- kept their last text, and boxes never filled since a load stood empty with unnamed dropdowns. Now a line read off one
-- number shows it live in its own text (never the Value our code reads back), a worked-out line keeps its last text,
-- and a line this character has none of stays out.
-- Run from the addon root: lua tools/tests/stat_hidden_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local hidden = false
function issecretvalue(v) return v == SECRET end
local function Hid(...)
    local values = { ... }
    return function()
        if hidden then return SECRET, SECRET end
        return table.unpack(values)
    end
end

-- Anything not modelled answers as a no-op; data fields stay nil.
local function Loose(t)
    return setmetatable(t or {}, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
local function FontString()
    local fs = Loose({ text = nil, shown = true })
    function fs.SetText(self, v)
        if v == SECRET then self.secretEver = true end
        self.text = v
    end
    function fs.SetFormattedText(self, format, ...)
        for i = 1, select("#", ...) do
            if select(i, ...) == SECRET then
                self.secretEver, self.text = true, SECRET
                return
            end
        end
        self.text = string.format(format, ...)
    end
    function fs.GetText(self) return self.text end
    function fs.Show(self) self.shown = true end
    function fs.Hide(self) self.shown = false end
    function fs.IsShown(self) return self.shown end
    return fs
end
local function Frame(parent)
    local f = Loose({ shown = true, parent = parent, scripts = {} })
    function f.Show(self) self.shown = true end
    function f.Hide(self) self.shown = false end
    function f.IsShown(self) return self.shown end
    function f.IsVisible(self) return self.shown end
    function f.GetParent(self) return self.parent end
    function f.CreateFontString() return FontString() end
    function f.CreateTexture() return Loose({}) end
    function f.GetFrameLevel() return 1 end
    function f.GetWidth() return 200 end
    function f.GetHeight() return 300 end
    function f.GetVerticalScroll() return 0 end
    function f.SetScript(self, k, fn) self.scripts[k] = fn end
    function f.GetScript(self, k) return self.scripts[k] end
    function f.RegisterCallback(self, event, fn, owner) self.callbacks = self.callbacks or {} self.callbacks[event] = fn end
    -- A scroll frame: the game hands its range back hidden once a line shows a hidden number.
    function f.GetVerticalScrollRange() return hidden and SECRET or 50 end
    function f.SetVerticalScroll(self, v) self.scrolledTo = v end
    return f
end

STAT_FORMAT = "%s:"
SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT3_NAME = "Strength", "Agility", "Stamina"
SPELL_STAT4_NAME, SPELL_STAT5_NAME = "Intellect", "Spirit"
HEALTH, MANA, STAT_ARMOR, STAT_DODGE, STAT_PARRY, STAT_BLOCK = "Health", "Mana", "Armor", "Dodge", "Parry", "Block"
WEAPON_SPEED, STAT_EXPERTISE = "Speed", "Expertise"
PaperDollFrame = Frame()
function BreakUpLargeNumbers(value, natural)
    if natural == SECRET then error("the game refuses a hidden flag") end
    if value == SECRET then return SECRET end
    return tostring(value)
end
local stats = { 50, 40, 60, 30, 20 }
function UnitStat(_, index)
    if hidden then return SECRET, SECRET, SECRET, SECRET end
    return stats[index], stats[index], 0, 0
end
UnitHealthMax, UnitPowerMax = Hid(900), Hid(700)
function UnitPowerType() return 0, "MANA" end
function UnitArmor() if hidden then return SECRET, SECRET end return 300, 320 end
function UnitAttackSpeed() if hidden then return SECRET, nil end return 2.6, nil end
function UnitDamage() if hidden then error("secret") end return 10, 20 end
function UnitRangedDamage() if hidden then return SECRET, SECRET, SECRET end return 2.9, 8, 12 end
function UnitResistance() if hidden then return SECRET, SECRET end return 0, 5 end
function IsRangedWeapon() return true end
GetCritChance, GetRangedCritChance, GetSpellCritChance = Hid(5.5), Hid(4), Hid(3)
GetMeleeHaste, UnitSpellHaste, GetRangedHaste = Hid(0), Hid(0), Hid(0, 0)
GetCombatRatingBonus, GetHitModifier, GetRangedHitModifier, GetSpellHitModifier = Hid(0), Hid(1), Hid(0), Hid(0)
GetOffhandHitModifier = Hid(0)
GetExpertise, GetSpellBonusHealing, GetSpellPenetration = Hid(0, 0), Hid(12), Hid(0)
GetDodgeChance, GetParryChance, GetBlockChance = Hid(6), Hid(5), Hid(0)
function GetAverageItemLevel() return 20 end

-- The client's lines: each sets its label and value, and stops on a hidden number (it compares them).
local function Client(label, value, tip)
    return { updateFunc = function(row)
        if hidden then error("attempt to compare a secret number") end
        row.Label:SetText(label .. ":")
        row.Value:SetText(value)
        row.tooltip = tip
    end }
end
PAPERDOLL_STATINFO = {
    HEALTH = Client("Health", "900"), POWER = Client("Mana", "700"), MOVESPEED = Client("Movement Speed", "100%"),
    ITEMLEVEL = { updateFunc = function(row)
        if hidden then error("secret") end
        row.Label:SetText("Item Level:")
        row.Value:SetText("20")
        row.numericValue = 20
    end },
    STRENGTH = Client("Strength", "|cff20ff2050|r", "Strength 50"), AGILITY = Client("Agility", "40"),
    STAMINA = Client("Stamina", "60"), INTELLECT = Client("Intellect", "30"), SPIRIT = Client("Spirit", "20"),
    MAINHAND_DAMAGE = Client("Main Hand", "10 - 20", "Main Hand 10 - 20"),
    OFFHAND_DAMAGE = { updateFunc = function(row) if hidden then error("secret") end row:Hide() end },
    ATTACK_AP = Client("Attack Power", "120"), ATTACK_ATTACKSPEED = Client("Speed", "2.60"),
    RANGED_DAMAGE = Client("Ranged", "8 - 12"), RANGED_ATTACK_AP = Client("Attack Power", "40"),
    SPELLPOWER = Client("Spell Power", "0"), SPELLHEALING = Client("Bonus Healing", "12"),
    SPELLPENETRATION = Client("Spell Penetration", "0"), MANAREGEN = Client("Mana Regen", "10"),
    ARMOR = Client("Armor", "320"), DEFENSE = Client("Defense", "100"), DODGE = Client("Dodge", "6.0%"),
    -- This character cannot parry: the client's line hides its row.
    PARRY = { updateFunc = function(row) if hidden then error("secret") end row:Hide() end },
    BLOCK = Client("Block", "0%"),
}

local module, scrollBar
local ns = Loose({
    BACKDROP = { TIP12 = {} }, ART = {}, db = {},
    IsSecret = issecretvalue,
    AnySecret = function(...)
        for i = 1, select("#", ...) do if select(i, ...) == SECRET then return true end end
        return false
    end,
    OnForever = function() return true end,
    NewFrame = function(_, _, parent, template)
        local f = Frame(parent)
        if template == "MinimalScrollBar" then scrollBar = f end
        return f
    end,
    DressDropdown = function(head) return Frame(head) end,
    Sched = Loose({ OnFrame = function() return Loose({}) end }),
    RegisterModule = function(_, def) module = def end,
})
assert(loadfile(ROOT .. "/Character/StatHidden.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Character/StatPanes.lua"))("ClassicUIForever", ns)
Check(module and type(module.apply) == "function", "the stat panes register as a module")

-- The game's wiring, as Blizzard_SharedXML's ScrollUtil: it compares the range it reads back.
BaseScrollBoxEvents, ScrollBoxConstants = { OnScroll = "OnScroll" }, { NoScrollInterpolation = true }
ScrollUtil = { InitScrollFrameWithScrollBar = function(scroll, bar)
    local function OnVertical(self, offset)
        local range = self:GetVerticalScrollRange()
        if range > 0 then bar:SetScrollPercentage(offset / range) end
    end
    scroll:SetScript("OnVerticalScroll", OnVertical)
    function scroll.GetPanExtent(self) return self.panExtent end
    function scroll.SetPanExtent(self, v) self.panExtent = v end
    scroll:SetScript("OnScrollRangeChanged", function(self) OnVertical(self, 0) end)
    bar:RegisterCallback("OnScroll", function(_, percent) scroll:SetVerticalScroll(percent * scroll:GetVerticalScrollRange()) end, scroll)
end }
ns.StatList(Frame())

local function Rows(pane)
    local out = {}
    for k = 1, pane.lineCount or 0 do out[#out + 1] = pane.lines[k] end
    return out
end
local function Labels(rows)
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = tostring(row.Label:GetText()) end
    return table.concat(out, ", ")
end

-- A load while the game hides the numbers: never filled, the boxes show what can be shown.
hidden = true
module.apply()
ns.UpdateStatList(true)

-- The module keeps its panes and list as upvalues of its updates.
local function Upvalue(fn, name)
    for i = 1, 60 do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return v end
    end
end
local paneSet = Upvalue(ns.UpdateStatPanes, "panes")
local list = Upvalue(ns.UpdateStatList, "list")
Check(paneSet and paneSet.left and paneSet.right, "the panes are made at a load")
Check(list and #list.boxes == 6, "the side list has its six sections")
local left, right = paneSet.left, paneSet.right

Check(left.head.text:GetText() == "Attributes", "a load in a fight: the left dropdown is named (it stood blank)")
Check((left.lineCount or 0) == 5, "and its five attributes show (" .. tostring(left.lineCount) .. ")")
local strength = left.lines[1]
Check(strength.Label:GetText() == "Strength:" and strength.Live.text == SECRET and strength.Live.shown,
    "Strength shows the hidden number, labelled")
Check(not strength.Value.shown, "in its own text, the Value hidden")
Check(right.head.text:GetText() == "Melee", "the right dropdown is named")
Check(Labels(Rows(right)) == "Speed:, Crit Chance:, Expertise:",
    "melee: the lines read off one number show; damage, power and hit (worked out) stay out until the fight ends ("
    .. Labels(Rows(right)) .. ")")
local general = list.boxes[1]
local function BoxLabels(box)
    local out = {}
    for _, row in ipairs(box.rows) do if row.fcuiHas then out[#out + 1] = tostring(row.Label:GetText()) end end
    return table.concat(out, ", ")
end
Check(BoxLabels(general) == "Health:, Mana:", "the side list's General shows health and mana (" .. BoxLabels(general) .. ")")
Check(BoxLabels(list.boxes[2]) == "Strength:, Agility:, Stamina:, Intellect:, Spirit:", "and its attributes")

-- The fight ends: the client's lines fill as ever, in the Value.
hidden = false
ns.UpdateStatPanes()
ns.UpdateStatList(true)
Check(strength.Value.shown and not strength.Live.shown and strength.Value:GetText() == "|cff20ff2050|r",
    "out of a fight the client's line, buff color and all")
local melee = list.boxes[3]
Check(BoxLabels(melee):find("Damage:", 1, true) ~= nil, "main hand damage back, under its Damage label")
local defense = list.boxes[6]
Check(BoxLabels(defense):find("Parry:", 1, true) == nil, "no parry line for a character that cannot parry")

-- A fight: one-number lines live, worked-out lines keep their last text, a line the character lacks stays out.
hidden = true
ns.UpdateStatPanes()
ns.UpdateStatList()
local listStrength = list.boxes[2].rows[1]
Check(listStrength.Live.shown and listStrength.Live.text == SECRET and listStrength.Label:GetText() == "Strength:",
    "in the fight Strength is live")
local mainHand = melee.rows[1]
Check(mainHand.fcuiHas and mainHand.Value.shown and mainHand.Value:GetText() == "10 - 20",
    "main hand damage keeps its last text")
Check(mainHand.tooltip == "Main Hand 10 - 20", "and its tooltip")
Check(BoxLabels(defense):find("Parry:", 1, true) == nil, "parry stays out though the game has a number for it")
Check(BoxLabels(defense):find("Dodge:", 1, true) ~= nil, "dodge live")

-- The side list's scroll wiring in the fight: no compare on the hidden range, the bar scrolls by our own lay.
local scroll = list.scroll
local ok, err = pcall(scroll.scripts.OnScrollRangeChanged, scroll, 0, SECRET)
Check(ok, "the list's range change runs in a fight (" .. tostring(err) .. ")")
ok, err = pcall(scroll.scripts.OnVerticalScroll, scroll, 0)
Check(ok, "and its scroll (" .. tostring(err) .. ")")
ok, err = pcall(scrollBar.callbacks.OnScroll, nil, 0.5)
Check(ok and type(scroll.scrolledTo) == "number", "dragging its bar scrolls by our own lay (" .. tostring(err) .. ")")

-- The fight ends again: back in the Value.
hidden = false
ns.UpdateStatList()
Check(listStrength.Value.shown and not listStrength.Live.shown, "after the fight the Value again")

-- No hidden number ever reached a Value: our code reads those back (empty or not) and would stop on one.
local reached = 0
for _, pane in pairs(paneSet) do
    for _, row in ipairs(pane.lines) do if row.Value.secretEver then reached = reached + 1 end end
end
for _, box in ipairs(list.boxes) do
    for _, row in ipairs(box.rows) do if row.Value.secretEver then reached = reached + 1 end end
end
Check(reached == 0, "no hidden number in a Value (" .. reached .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("stat_hidden_test: ok")
