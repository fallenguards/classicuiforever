local _, ns = ...

-- The stat panes' lines while the game hides stat numbers from addons (in a fight, maybe a whole battleground, #330):
-- a line read off one number shows it in its own text, white (a buff's color needs a compare); a worked-out line keeps
-- its last text (Character/StatPanes.lua's hidden pass).

local NA = _G.NOT_APPLICABLE or "N/A"
local CRIT_LABEL, HASTE_LABEL = _G.CRIT_CHANCE or "Crit Chance", _G.STAT_HASTE or "Haste"
local SPEED_LABEL = _G.WEAPON_SPEED or "Speed"

-- One value each: BreakUpLargeNumbers' second argument is a flag the game refuses hidden.
local function Shown(format, read)
    return function(live)
        local value = read()
        live:SetFormattedText(format, value)
    end
end
local function Big(read)
    return function(live)
        local value = read()
        live:SetText(BreakUpLargeNumbers(value))
    end
end
local function Attribute(index)
    return Big(function() return select(2, UnitStat("player", index)) end)
end
local function PowerLabel()
    local _, token = UnitPowerType("player")
    return not ns.IsSecret(token) and token and _G[token] or _G.MANA
end
-- The off hand's speed when one is worn: nil is never hidden, so the test is safe.
local function OffHand()
    local _, off = _G.UnitAttackSpeed("player")
    return ns.IsSecret(off) or off ~= nil
end

-- { label (or its function) for a line never filled before, filler }; the label a line had last wins.
local LIVE = {
    HEALTH = { _G.HEALTH, Big(function() return UnitHealthMax("player") end) },
    POWER = { PowerLabel, Big(function() return UnitPowerMax("player") end) },
    STRENGTH = { _G.SPELL_STAT1_NAME, Attribute(1) },
    AGILITY = { _G.SPELL_STAT2_NAME, Attribute(2) },
    STAMINA = { _G.SPELL_STAT3_NAME, Attribute(3) },
    INTELLECT = { _G.SPELL_STAT4_NAME, Attribute(4) },
    SPIRIT = { _G.SPELL_STAT5_NAME, Attribute(5) },
    ATTACK_ATTACKSPEED = { _G.WEAPON_SPEED, function(live)
        if OffHand() then live:SetFormattedText("%.2f / %.2f", _G.UnitAttackSpeed("player"))
        else live:SetFormattedText("%.2f", (_G.UnitAttackSpeed("player"))) end
    end },
    MELEE_HASTE = { HASTE_LABEL, Shown("+%.2f%%", function() return _G.GetMeleeHaste() end) },
    MELEE_CRIT = { CRIT_LABEL, Shown("%.2f%%", function() return _G.GetCritChance() end) },
    EXPERTISE = { _G.STAT_EXPERTISE, function(live)
        if OffHand() then live:SetFormattedText("%.2f%% / %.2f%%", _G.GetExpertise())
        else live:SetFormattedText("%.2f%%", (_G.GetExpertise())) end
    end },
    RANGED_SPEED = { SPEED_LABEL, function(live)
        if _G.IsRangedWeapon and _G.IsRangedWeapon() == false then live:SetText(NA)
        else live:SetFormattedText("%.2f", (UnitRangedDamage("player"))) end
    end },
    RANGED_CRIT = { CRIT_LABEL, Shown("%.2f%%", function() return _G.GetRangedCritChance() end) },
    SPELLHEALING = { _G.STAT_SPELLHEALING, Big(function() return _G.GetSpellBonusHealing() end) },
    SPELL_CRIT = { CRIT_LABEL, Shown("%.2f%%", function() return _G.GetSpellCritChance() end) },
    SPELL_HASTE = { HASTE_LABEL, Shown("+%.2f%%", function() return _G.UnitSpellHaste("player") end) },
    SPELLPENETRATION = { _G.STAT_SPELL_PENETRATION, Shown("%d", function() return _G.GetSpellPenetration() end) },
    ARMOR = { _G.STAT_ARMOR, Big(function() return select(2, UnitArmor("player")) end) },
    DODGE = { _G.STAT_DODGE, Shown("%.1f%%", function() return _G.GetDodgeChance() end) },
    PARRY = { _G.STAT_PARRY, Shown("%.1f%%", function() return _G.GetParryChance() end) },
    BLOCK = { _G.STAT_BLOCK, Shown("%.0f%%", function() return _G.GetBlockChance() end) },
}
local resists = {}

-- The filler for a line read off one number, or nil for a line worked out from several.
function ns.StatLive(entry, resistances)
    if not resistances then return LIVE[entry.own or entry.stat] end
    resists[entry] = resists[entry]
        or { nil, Big(function() return select(2, UnitResistance("player", entry.school)) end) }
    return resists[entry]
end

-- Per line (the panes and the side list share them): had one at the last pass that read numbers, and its text.
local hadLine, kept = {}, {}
function ns.StatKeep(row, entry, had)
    hadLine[entry] = had
    if not had then return end
    local label, value = row.Label:GetText(), row.Value:GetText()
    if ns.AnySecret(label, value, row.tooltip, row.tooltip2, row.tooltip3) then
        kept[entry] = nil
        return
    end
    local last = kept[entry] or {}
    last[1], last[2], last[3], last[4], last[5] = label, value, row.tooltip, row.tooltip2, row.tooltip3
    kept[entry] = last
end
function ns.StatKept(entry) return hadLine[entry], kept[entry] end

-- The game's scroll wiring reads the range back, which it can hand back hidden once a line shows a hidden number: the
-- same wiring on a plain scroll frame, the range from extent(), our own lay's height (the side list).
function ns.StatOwnRange(scroll, bar, extent)
    local function Range(self) return math.max(0, extent() - self:GetHeight()) end
    local function Track(self, offset)
        local range = Range(self)
        bar:SetScrollPercentage(range > 0 and offset / range or 0, _G.ScrollBoxConstants.NoScrollInterpolation)
    end
    scroll:SetScript("OnVerticalScroll", Track)
    scroll:SetScript("OnScrollRangeChanged", function(self)
        local offset = self:GetVerticalScroll()
        if not ns.IsSecret(offset) then Track(self, offset) end
        local height, range = self:GetHeight(), Range(self)
        bar:SetVisibleExtentPercentage(height > 0 and height / (range + height) or 0)
        bar:SetPanExtentPercentage(range > 0 and math.min(1, self:GetPanExtent() / range) or 0)
    end)
    bar:RegisterCallback(_G.BaseScrollBoxEvents.OnScroll, function(_, percent)
        scroll:SetVerticalScroll(percent * Range(scroll))
    end, scroll)
end
