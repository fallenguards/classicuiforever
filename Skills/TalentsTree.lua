local _, ns = ...

-- The talent window's data: this client's single tree (three groups; nodes with position, ranks, edges)
-- read into three lists of talents on a grid (ns.ReadTraitTree, UI/TraitTree.lua).

local TL = ns.talents
local SpecInfo = C_SpecializationInfo or {}

-- unit: nil for the player, or the inspected unit (its own read-only config). group: one of the player's specs, else
-- the active one; /fcuidev dualspec's second spec is the one there is.
local function ConfigID(unit, group)
    if unit then
        return Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
    end
    if TL.fakeSpecs then group = nil end
    local spec = group or SpecInfo.GetActiveSpecGroup and SpecInfo.GetActiveSpecGroup()
    local id = spec and SpecInfo.GetCombatConfigIDForSpecGroup and SpecInfo.GetCombatConfigIDForSpecGroup(spec)
    if not id and not group and C_ClassTalents and C_ClassTalents.GetActiveConfigID then id = C_ClassTalents.GetActiveConfigID() end
    return id
end

local function TreeID(configID)
    local config = configID and C_Traits and C_Traits.GetConfigInfo(configID)
    return config and config.treeIDs and config.treeIDs[1]
end

-- The tree read into three lists of talents on a grid. group: the player's spec not in use, read-only.
function TL.ReadTree(unit, group)
    local configID = ConfigID(unit, group)
    local opts = unit and { inspect = true } or group and { locked = true } or nil
    return ns.ReadTraitTree(configID, TreeID(configID), opts)
end

-- A spec's three trees (name, icon, points spent) without their talents; group nil for the active one.
function TL.ReadSpecTrees(group)
    local configID = ConfigID(nil, group)
    return ns.ReadTraitGroups(configID, TreeID(configID))
end
