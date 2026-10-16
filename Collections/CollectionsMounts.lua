local _, ns = ...

-- The Collections window's Mounts page: every mount this character may see, by ID (the game's journal keeps its own
-- filters and search); the picked one's creature in the model box, Mount or Dismount at its foot.

local CW = ns.collections
local MJ = C_MountJournal
local IsSecret = ns.IsSecret

local MOUNT_ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"

local function List()
    local out = {}
    for _, id in ipairs(MJ.GetMountIDs() or ns.EMPTY) do
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

local function Tip(entry)
    if GameTooltip.SetMountBySpellID and entry.spellID then
        GameTooltip:SetMountBySpellID(entry.spellID)
    else
        GameTooltip:SetText(entry.name)
    end
end

CW.AddPage({
    key = "mounts", tab = 1, icon = MOUNT_ICON, tip = { "MOUNTS", "COLL_MOUNTS" },
    events = { "NEW_MOUNT_ADDED", "MOUNT_JOURNAL_USABILITY_CHANGED", "COMPANION_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED" },
    List = List, Show = Show, Action = Action, Act = Act, Pickup = Pickup, Tip = Tip,
})
