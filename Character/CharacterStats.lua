local _, ns = ...

-- 1.x stat boxes under the model (attributes left, melee/ranged right), resistances up the right.

local T = ns.sheet
local Safe = ns.Safe

local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
-- Top to bottom: arcane, fire, nature, frost, shadow.
local RESISTANCES = {
    { id = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
    { id = 2, coords = { 0, 1, 0, 0.11328125 } },
    { id = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
    { id = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
    { id = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}
local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"
local ARMOR_NAME = ARMOR or "Armor"

-- Old three-piece box: caps and a stretched middle.
local BOX_TOP = { layer = "BACKGROUND", sublevel = 1, w = 115, h = 16, coords = { 0, 0.8984375, 0, 0.125 }, point = "TOPLEFT" }
local BOX_MID = { layer = "BACKGROUND", sublevel = 1, w = 115, coords = { 0, 0.8984375, 0.125, 0.1953125 }, point = "TOPLEFT", relPoint = "BOTTOMLEFT" }
local BOX_BOT = { layer = "BACKGROUND", sublevel = 1, w = 115, h = 16, coords = { 0, 0.8984375, 0.484375, 0.609375 }, point = "TOPLEFT", relPoint = "BOTTOMLEFT" }
local RESIST_ICON = { layer = "BACKGROUND", fill = true }

-- The box's bottom cap, and all three pieces (to show or hide the box).
local function StatBox(parent, x, y, middleHeight)
    local top = ns.DressNew(parent, "charStatBox", BOX_TOP, parent, x, y)
    local middle = ns.DressNew(parent, "charStatBox", BOX_MID, top, nil, nil, nil, middleHeight)
    local bottom = ns.DressNew(parent, "charStatBox", BOX_BOT, middle)
    return bottom, { top, middle, bottom }
end

local function BoxShown(pieces, shown)
    for _, piece in ipairs(pieces) do ns.SetShownIf(piece, shown) end
end

local function TipTitle(row) return row.tip end
local function TipDetail(row) return row.tip2 end
local STAT_TIP = { text = TipTitle, r = 1, g = 1, b = 1, lines = { { TipDetail, nil, nil, nil, true } } }

-- Era's Damage tooltip (CharacterDamageFrame_OnEnter): each hand's attack speed, damage and damage per second.
local hands = { main = {}, off = {} }
local LABEL_R, LABEL_G, LABEL_B = 1, 0.82, 0

-- Era's numbers for one hand (PaperDollFrame_SetDamage): the range before bonuses, the bonuses after it, and DPS.
local function FillHand(hand, low, high, speed, pos, neg, percent)
    if percent == 0 then
        low, high = 0, 0
    else
        low, high = low / percent - pos - neg, high / percent - pos - neg
    end
    local full = ((low + high) * 0.5 + pos + neg) * percent
    local text = string.format("%d - %d", math.max(math.floor(low), 1), math.max(math.ceil(high), 1))
    if pos > 0 then text = text .. GREEN .. " +" .. pos .. "|r" end
    if neg < 0 then text = text .. RED .. " " .. neg .. "|r" end
    if percent ~= 1 then
        text = text .. (percent > 1 and GREEN or RED) .. " x" .. math.floor(percent * 100 + 0.5) .. "%|r"
    end
    hand.speed, hand.damage, hand.dps = speed, text, speed == 0 and 0 or math.max(full, 1) / speed
end

local function HandLines(hand)
    GameTooltip:AddDoubleLine(ATTACK_SPEED_COLON or "Attack Speed (seconds):", string.format("%.2f", hand.speed),
        LABEL_R, LABEL_G, LABEL_B, 1, 1, 1)
    GameTooltip:AddDoubleLine(DAMAGE_COLON or "Damage:", hand.damage, LABEL_R, LABEL_G, LABEL_B, 1, 1, 1)
    GameTooltip:AddDoubleLine(DAMAGE_PER_SECOND or "Damage per Second", string.format("%.1f", hand.dps),
        LABEL_R, LABEL_G, LABEL_B, 1, 1, 1)
end

local function DamageTip(row)
    if not hands.main.speed then return ns.ShowTip(row) end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(INVTYPE_WEAPONMAINHAND or "Main Hand", 1, 1, 1)
    HandLines(hands.main)
    if hands.off.speed then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(INVTYPE_WEAPONOFFHAND or "Off Hand", 1, 1, 1)
        HandLines(hands.off)
    end
    GameTooltip:Show()
end

local function StatRow(parent, label, anchor, relPoint, x, y)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(104, 13)
    row:SetPoint("TOPLEFT", anchor, relPoint, x, y)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetText(label)
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetJustifyH("RIGHT")
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row:EnableMouse(true)
    ns.AttachTip(row, STAT_TIP)
    return row
end

local function ResistTip(row)
    local name = _G["DAMAGE_SCHOOL" .. (row.id + 1)] or _G["RESISTANCE" .. row.id .. "_NAME"] or ("Resistance " .. row.id)
    return name .. " " .. (RESISTANCE or "Resistance")
end
local RESIST_TIP = { text = ResistTip, r = 1, g = 1, b = 1 }

local function Number(value) return Safe(value, 0) end

-- Base in white, buffed total green or red, as 1.x showed it.
local function Buffed(base, pos, neg)
    base, pos, neg = Number(base), Number(pos), Number(neg)
    local total = base + pos + neg
    if pos == 0 and neg == 0 then return WHITE .. total .. "|r", nil end
    local color = (pos > 0 and neg == 0) and GREEN or ((neg < 0 and pos == 0) and RED or WHITE)
    local detail = string.format("%d (%d base", total, base)
    if pos > 0 then detail = detail .. string.format(" %s+%d|r", GREEN, pos) end
    if neg < 0 then detail = detail .. string.format(" %s%d|r", RED, neg) end
    return color .. total .. "|r", detail .. ")"
end

-- The 2.x stat panes take this area when their toggle is on.
function ns.SetClassicStatsShown(shown)
    if not T.attrs then return end
    T.attrs:SetShown(shown and true or false)
end

local statLabels = {}
local forever
local filledFor

-- A withheld switch to or from the pet: dashes, never the other unit's numbers.
local function Dashes()
    for i, row in ipairs(T.attributes) do
        row.value:SetText("--")
        row.tip, row.tip2 = statLabels[i], nil
    end
    for _, row in ipairs({ T.armor, T.attack, T.attackPower, T.damage, T.rangedAttack, T.rangedPower, T.rangedDamage, T.defense }) do
        row.value:SetText("--")
    end
    hands.main.speed, hands.off.speed = nil, nil
    T.armor.tip, T.armor.tip2 = ARMOR_NAME, nil
    for _, res in ipairs(T.resistances) do res.value:SetText("--") end
end

-- IsShown, not IsVisible: the doll stays shown while shut, so a combat open has pre-combat numbers.
-- Returns true when the stat panes were updated.
local function UpdateStats(opening)
    if not T.built or not T.active or not PaperDollFrame or not PaperDollFrame:IsShown() then return false end
    if ns.UpdateStatPanes then ns.UpdateStatPanes() end
    if ns.UpdateStatList then ns.UpdateStatList(opening) end
    -- The client's pet view shows the pet's numbers.
    local unit = T.PetView and T.PetView() and "pet" or "player"
    -- Secret in combat: keep the last numbers rather than zeros.
    local _, probe = UnitStat(unit, 1)
    if ns.IsSecret(probe) then
        if filledFor ~= unit then Dashes() end
        filledFor = unit
        return true
    end
    filledFor = unit
    for i, row in ipairs(T.attributes) do
        local _, effective, pos, neg = UnitStat(unit, i)
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        row.value:SetText(text)
        row.tip = statLabels[i] .. " " .. Number(effective)
        row.tip2 = detail
    end
    do
        local _, effective, _, pos, neg = UnitArmor(unit)
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        T.armor.value:SetText(text)
        T.armor.tip = ARMOR_NAME .. " " .. Number(effective)
        T.armor.tip2 = detail
    end
    -- Melee: weapon skill where the client has it, then power and damage.
    if UnitAttackBothHands then
        local base, mod = UnitAttackBothHands(unit)
        T.attack.value:SetText(Buffed(base, mod, 0))
    else
        T.attack.value:SetText("--")
    end
    do
        local base, pos, neg = UnitAttackPower(unit)
        T.attackPower.value:SetText(Buffed(base, pos, neg))
    end
    do
        local low, high, offLow, offHigh, pos, neg, percent = UnitDamage(unit)
        T.damage.value:SetText(string.format("%d - %d", math.max(math.floor(Number(low)), 1), math.max(math.ceil(Number(high)), 1)))
        local speed, offSpeed = _G.UnitAttackSpeed(unit)
        if type(speed) ~= "number" or type(low) ~= "number"
            or ns.AnySecret(speed, offSpeed, low, high, offLow, offHigh, pos, neg, percent) then
            hands.main.speed, hands.off.speed = nil, nil
        else
            pos, neg, percent = pos or 0, neg or 0, percent or 1
            FillHand(hands.main, low, high, speed, pos, neg, percent)
            hands.off.speed = nil
            if offSpeed then FillHand(hands.off, offLow or 0, offHigh or 0, offSpeed, pos, neg, percent) end
        end
    end
    -- Defense: the pet's sheet only (Forever's call is UnitDefenseSkill, Era's UnitDefense).
    local defense = unit == "pet" and (UnitDefenseSkill or UnitDefense)
    if defense then
        local base, mod = defense(unit)
        mod = Number(mod)
        T.defense.value:SetText(Buffed(base, math.max(mod, 0), math.min(mod, 0)))
    end
    -- Ranged: only with a ranged weapon or wand in hand; the pet has none.
    local hasRanged = unit == "player" and CharacterRangedSlot and CharacterRangedSlot:IsShown()
        and GetInventoryItemID("player", CharacterRangedSlot:GetID()) ~= nil
    if not hasRanged then
        T.rangedAttack.value:SetText("--")
        T.rangedPower.value:SetText("--")
        T.rangedDamage.value:SetText("--")
    else
        if UnitRangedAttack then
            local base, mod = UnitRangedAttack("player")
            T.rangedAttack.value:SetText(Buffed(base, mod, 0))
        else
            T.rangedAttack.value:SetText("--")
        end
        local base, pos, neg = UnitRangedAttackPower("player")
        T.rangedPower.value:SetText(Buffed(base, pos, neg))
        local _, minDamage, maxDamage = UnitRangedDamage("player")
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        if maxDamage > 0 then
            T.rangedDamage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
        else
            T.rangedDamage.value:SetText("--")
        end
    end
    -- Resistances are Forever only (retail dropped the API); 0 if the call is missing.
    if forever then
        -- Over the model scene, which takes the mouse across that side to turn the model.
        local scene, column = CharacterModelScene, T.resistances[1] and T.resistances[1]:GetParent()
        if scene and column then ns.SetLevelIf(column, scene:GetFrameLevel() + 2) end
        for _, res in ipairs(T.resistances) do
            if UnitResistance then
                local _, total = UnitResistance(unit, res.id)
                res.value:SetText(Number(total))
            else
                res.value:SetText("0")
            end
        end
    end
    return true
end
T.UpdateStats = UpdateStats

-- Boxes at (67, -291) and the resistance column, 32x29 a row.
function T.BuildStats(doll)
    forever = ns.OnForever()
    local attrs = ns.NewFrame("Frame", nil, doll)
    attrs:SetSize(230, 78)
    attrs:SetPoint("TOPLEFT", doll, "TOPLEFT", 67, -291)
    StatBox(attrs, 0, 0, 53)
    local meleeBottom, meleeBox = StatBox(attrs, 115, 0, 12)
    local _, rangedBox = StatBox(attrs, 115, -46, 11)
    -- 1.x's pet sheet: one right box as tall as the left, no melee and ranged heads.
    local _, petBox = StatBox(attrs, 115, 0, 53)
    T.charBoxes, T.petBox = { meleeBox, rangedBox }, petBox
    BoxShown(petBox, false)
    T.attrs = attrs
    T.attributes = {}
    local prev
    for i = 1, 5 do
        local label = _G["SPELL_STAT" .. i .. "_NAME"] or STAT_NAMES[i]
        statLabels[i] = label
        local row = StatRow(attrs, label, prev or attrs, prev and "BOTTOMLEFT" or "TOPLEFT", prev and 0 or 6, prev and 0 or -3)
        T.attributes[i] = row
        prev = row
    end
    T.armor = StatRow(attrs, ARMOR_NAME, prev, "BOTTOMLEFT", 0, 0)
    T.attack = StatRow(attrs, MELEE_ATTACK or "Melee Attack", attrs, "TOPLEFT", 122, -2)
    T.attackPower = StatRow(attrs, ATTACK_POWER or "Power", T.attack, "BOTTOMLEFT", 0, 1)
    T.damage = StatRow(attrs, DAMAGE or "Damage", T.attackPower, "BOTTOMLEFT", 0, 1)
    T.rangedAttack = StatRow(attrs, RANGED_ATTACK or "Ranged Attack", T.damage, "BOTTOMLEFT", 0, -6)
    T.rangedPower = StatRow(attrs, ATTACK_POWER or "Power", T.rangedAttack, "BOTTOMLEFT", 0, 1)
    T.rangedDamage = StatRow(attrs, DAMAGE or "Damage", T.rangedPower, "BOTTOMLEFT", 0, 1)
    T.defense = StatRow(attrs, DEFENSE or "Defense", T.damage, "BOTTOMLEFT", 0, -1)
    T.defense.tip = DEFENSE or "Defense"
    T.defense:Hide()
    T.attack.tip = MELEE_ATTACK or "Melee Attack"
    T.attackPower.tip = MELEE_ATTACK_POWER or "Attack Power"
    T.damage.tip = DAMAGE or "Damage"
    T.damage:SetScript("OnEnter", DamageTip)
    T.rangedAttack.tip = RANGED_ATTACK or "Ranged Attack"
    T.rangedPower.tip = RANGED_ATTACK_POWER or "Ranged Attack Power"
    T.rangedDamage.tip = DAMAGE or "Damage"
    meleeBottom:SetPoint("TOPLEFT", attrs, "TOPLEFT", 115, -28)

    local resFrame = ns.NewFrame("Frame", nil, doll)
    resFrame:SetSize(32, 160)
    resFrame:SetPoint("TOPRIGHT", doll, "TOPLEFT", 297, -77)
    resFrame:SetShown(forever)
    T.resistances = {}
    prev = nil
    for i, res in ipairs(RESISTANCES) do
        local row = ns.NewFrame("Frame", nil, resFrame)
        row:SetSize(32, 29)
        row:SetPoint("TOP", prev or resFrame, prev and "BOTTOM" or "TOP", 0, 0)
        ns.DressNew(row, "charResistIcons", RESIST_ICON, row, nil, nil, nil, nil, res.coords)
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.value:SetPoint("BOTTOM", row, "BOTTOM", 0, 3)
        row.id = res.id
        row:EnableMouse(true)
        ns.AttachTip(row, RESIST_TIP)
        T.resistances[i] = row
        prev = row
    end
end

-- Player and pet unit events, one pass a frame; the side panel lines need the extras.
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
    "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_ATTACK", "UNIT_RESISTANCES", "UNIT_INVENTORY_CHANGED",
    "UNIT_LEVEL", "UNIT_AURA", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_SPELL_HASTE" }
local EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PET_STATS_UPDATE" }
-- A change while the window is shut, laid as it opens or a fight begins: refreshing a shut sheet on every aura cost
-- each stealth and every buff in a fight a millisecond.
local stale = false
local function QueueStats(_, event, unit)
    -- UpdateStats' own test, asked first: the doll stays shown while the window is shut.
    if not (PaperDollFrame and PaperDollFrame:IsShown()) then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Pre-combat numbers for a window opened in the fight.
        if stale then
            stale = false
            UpdateStats()
        end
        return
    end
    -- The pet's changes count only while its view is up.
    if (unit == "pet" or event == "PET_STATS_UPDATE") and not (T.PetView and T.PetView()) then return end
    if not PaperDollFrame:IsVisible() then
        stale = true
        return
    end
    ns.Sched.Soon("character.stats", UpdateStats)
end
local function DollShown() if T.active then UpdateStats(true) end end
-- The doll stays shown while the window is shut: its window opening is the edge to refresh on, after the show pass.
local function DollSeen()
    if stale and T.active then
        stale = false
        UpdateStats()
    end
end

function T.WatchStats(doll)
    local watcher = ns.EventFrame(UNIT_EVENTS, QueueStats, "player", "pet")
    ns.RegisterEvents(watcher, EVENTS)
    doll:HookScript("OnShow", DollShown)
    ns.Sched.AfterShow(doll, "character.statsSeen", DollSeen)
end

-- Era's pet sheet: Attack, Attack Power, Damage, Defense and Armor in the right box from 122 in and 5 down, one under
-- the next; the attributes start level with them. The character's first attribute row stands 3 down.
local PET_ROWS_X, PET_ROWS_Y, PET_ROW_GAP = 122, -5, -1
local CHAR_ROWS_Y = -3

-- Rows for the view up: the pet's one right box, no heads; the character's melee and ranged boxes, armor under the
-- attributes.
function T.PetStatRows(pet)
    if not T.attrs then return end
    local attrs = T.attrs
    for _, pieces in ipairs(T.charBoxes) do BoxShown(pieces, not pet) end
    BoxShown(T.petBox, pet)
    for _, row in ipairs({ T.rangedAttack, T.rangedPower, T.rangedDamage }) do ns.SetShownIf(row, not pet) end
    local defense = pet and (UnitDefenseSkill or UnitDefense) ~= nil
    ns.SetShownIf(T.defense, defense)
    local attack = pet and (ATTACK or "Attack") or (MELEE_ATTACK or "Melee Attack")
    T.attack.label:SetText(attack)
    T.attack.tip = attack
    ns.SetPointOnce(T.attributes[1], "TOPLEFT", attrs, "TOPLEFT", 6, pet and PET_ROWS_Y or CHAR_ROWS_Y)
    if pet then
        ns.SetPointOnce(T.attack, "TOPLEFT", attrs, "TOPLEFT", PET_ROWS_X, PET_ROWS_Y)
        ns.SetPointOnce(T.attackPower, "TOPLEFT", T.attack, "BOTTOMLEFT", 0, PET_ROW_GAP)
        ns.SetPointOnce(T.damage, "TOPLEFT", T.attackPower, "BOTTOMLEFT", 0, PET_ROW_GAP)
        ns.SetPointOnce(T.armor, "TOPLEFT", defense and T.defense or T.damage, "BOTTOMLEFT", 0, PET_ROW_GAP)
    else
        ns.SetPointOnce(T.attack, "TOPLEFT", attrs, "TOPLEFT", 122, -2)
        ns.SetPointOnce(T.attackPower, "TOPLEFT", T.attack, "BOTTOMLEFT", 0, 1)
        ns.SetPointOnce(T.damage, "TOPLEFT", T.attackPower, "BOTTOMLEFT", 0, 1)
        ns.SetPointOnce(T.armor, "TOPLEFT", T.attributes[#T.attributes], "BOTTOMLEFT", 0, 0)
    end
end
