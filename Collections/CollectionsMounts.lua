local _, ns = ...

-- The Collections window's Mounts page: the mounts the game's journal lists through its own filters (in the Filter
-- menu); the picked one's creature in the model box, Mount or Dismount at its foot.

local CW = ns.collections
local MJ = C_MountJournal
local IsSecret = ns.IsSecret

local MOUNT_ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"
-- The game's mount types, by its menu's names.
local TYPES = { { "Ground", "MOUNT_JOURNAL_FILTER_GROUND" }, { "Flying", "MOUNT_JOURNAL_FILTER_FLYING" },
    { "Aquatic", "MOUNT_JOURNAL_FILTER_AQUATIC" }, { "Dragonriding", "MOUNT_JOURNAL_FILTER_DRAGONRIDING" },
    { "RideAlong", "MOUNT_JOURNAL_FILTER_RIDEALONG" } }
local searched = false

local function List()
    -- The game's own search would narrow its list past ours: cleared once.
    if not searched and MJ.SetSearch then
        searched = true
        MJ.SetSearch("")
    end
    local out = {}
    for i = 1, MJ.GetNumDisplayedMounts() or 0 do
        local id = MJ.GetDisplayedMountID(i)
        local name, spellID, icon, isActive, isUsable, _, _, _, _, hidden, collected = MJ.GetMountInfoByID(id)
        if type(name) == "string" and not IsSecret(name) and not hidden then
            out[#out + 1] = { id = id, name = name, icon = icon, spellID = spellID, active = isActive == true,
                usable = isUsable == true, collected = collected == true }
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

local function Show(entry, box)
    local displayID, _, source = MJ.GetMountInfoExtraByID(entry.id)
    if type(source) == "string" and not IsSecret(source) then box.source:SetText(source) end
    CW.ShowCreature(box, displayID)
end

local function Action(entry)
    if entry.active then return CW.Text("BINDING_NAME_DISMOUNT", "COLL_DISMOUNT"), true end
    return CW.Text("MOUNT", "COLL_MOUNT"), entry.collected and entry.usable
end

-- The game refuses either in a fight with its own message.
local function Act(entry)
    if entry.active then MJ.Dismiss() else MJ.SummonByID(entry.id) end
end

-- The journal's own pickup needs the mount's place in its shown list; past its filters, the mount's spell.
local function Pickup(entry)
    for i = 1, MJ.GetNumDisplayedMounts() or 0 do
        if MJ.GetDisplayedMountID(i) == entry.id then
            MJ.Pickup(i)
            return
        end
    end
    if C_Spell and C_Spell.PickupSpell and entry.spellID then C_Spell.PickupSpell(entry.spellID) end
end

local function CollectedRow(label, filter, after)
    if not filter then return nil end
    return CW.FilterCheck(label, function() return MJ.GetCollectedFilterSetting(filter) end,
        function(on) MJ.SetCollectedFilterSetting(filter, on) end, after)
end

local function TypeName(i)
    for _, row in ipairs(TYPES) do
        local value = Enum.MountType and Enum.MountType[row[1]]
        if value and value + 1 == i and MJ.IsValidTypeFilter(i) then return CW.GameName(row[2]) end
    end
end

local function SourceName(i) return MJ.IsValidSourceFilter(i) and CW.GameName("BATTLE_PET_SOURCE_" .. i) or nil end

local function FilterEntries(after)
    return CW.Rows(
        CollectedRow(CW.Text("COLLECTED", "COLL_COLLECTED"), _G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, after),
        CollectedRow(CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), _G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, after),
        CollectedRow(CW.GameName("MOUNT_JOURNAL_FILTER_UNUSABLE"), _G.LE_MOUNT_JOURNAL_FILTER_UNUSABLE, after),
        { divider = true },
        CW.FilterSub(CW.GameName("MOUNT_JOURNAL_FILTER_TYPE"), MJ.SetAllTypeFilters,
            Enum.MountTypeMeta and Enum.MountTypeMeta.NumValues, TypeName, MJ.IsTypeChecked, MJ.SetTypeFilter, after),
        CW.FilterSub(CW.Text("SOURCES", "COLL_SOURCES"), MJ.SetAllSourceFilters, C_PetJournal.GetNumPetSources(), SourceName,
            MJ.IsSourceChecked, MJ.SetSourceFilter, after))
end

local function Tip(entry)
    if GameTooltip.SetMountBySpellID and entry.spellID then
        GameTooltip:SetMountBySpellID(entry.spellID)
    else
        GameTooltip:SetText(entry.name)
    end
end

CW.AddPage({
    key = "mounts", tab = 1, icon = MOUNT_ICON, tip = { "MOUNTS", "COLL_MOUNTS" },
    events = { "NEW_MOUNT_ADDED", "MOUNT_JOURNAL_USABILITY_CHANGED", "COMPANION_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED",
        "MOUNT_JOURNAL_SEARCH_UPDATED" },
    List = List, Show = Show, Action = Action, Act = Act, Pickup = Pickup, Tip = Tip, Shown = CW.AllShown,
    FilterEntries = FilterEntries,
})
