local _, ns = ...

-- The Collections window's Heirlooms page (retail): the heirlooms the game's journal lists through its own filters (in
-- the Filter menu, its class pick too), laid as the spellbook's pages; a click on one you own creates it.

local HL = _G.C_Heirloom
if ns.OnForever() or not (HL and HL.GetNumDisplayedHeirlooms) then return end
local CW = ns.collections
local IsSecret = ns.IsSecret

local HEIRLOOMS_ICON = "Interface\\Icons\\inv_misc_enggizmos_19"
local searched = false

local function List()
    -- The game's own search would narrow its list past ours: cleared once.
    if not searched and HL.SetSearch then
        searched = true
        HL.SetSearch("")
    end
    local out = {}
    for i = 1, HL.GetNumDisplayedHeirlooms() or 0 do
        local itemID = HL.GetHeirloomItemIDFromDisplayedIndex(i)
        local name, _, pvp, icon, _, _, _, _, _, maxLevel = HL.GetHeirloomInfo(itemID)
        if type(name) == "string" and not IsSecret(name) then
            out[#out + 1] = { id = itemID, name = name, icon = icon, pvp = pvp == true, maxLevel = maxLevel,
                collected = HL.PlayerHasHeirloom(itemID) == true }
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

-- Under the name, as the spellbook's rank: the level an owned one scales to, PvP for the PvP ones.
local function Sub(entry)
    if entry.pvp then return CW.GameName("HEIRLOOMS_PVP") or "" end
    if entry.collected and entry.maxLevel then return string.format("%s %d", CW.Text("LEVEL", "COLL_LEVEL"), entry.maxLevel) end
    return ""
end

-- A copy into your bags, as the game's journal makes one on a click.
local function Act(entry)
    if entry.collected then HL.CreateHeirloom(entry.id) end
end

local function Tip(entry)
    if GameTooltip.SetHeirloomByItemID then GameTooltip:SetHeirloomByItemID(entry.id) else GameTooltip:SetText(entry.name) end
end

local function SourceName(i)
    local info = _G.C_HeirloomInfo
    return info and info.IsHeirloomSourceValid(i) and CW.GameName("BATTLE_PET_SOURCE_" .. i) or nil
end

-- Every class, as the journal's class menu (all of its specs); the game starts it on your own.
local function ClassEntries(after)
    local out = {}
    for classID = 1, GetNumClasses() do
        local name = GetClassInfo(classID)
        if name then
            out[#out + 1] = { name, radio = function() return HL.GetClassAndSpecFilters() == classID end,
                pick = function()
                    HL.SetClassAndSpecFilters(classID, 0)
                    after()
                end }
        end
    end
    return out
end

local function FilterEntries(after)
    local info = _G.C_HeirloomInfo
    return CW.Rows(
        CW.FilterCheck(CW.Text("COLLECTED", "COLL_COLLECTED"), HL.GetCollectedHeirloomFilter, HL.SetCollectedHeirloomFilter,
            after),
        CW.FilterCheck(CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), HL.GetUncollectedHeirloomFilter,
            HL.SetUncollectedHeirloomFilter, after),
        { divider = true },
        info and CW.FilterSub(CW.Text("SOURCES", "COLL_SOURCES"), info.SetAllSourceFilters, C_PetJournal.GetNumPetSources(),
            SourceName, HL.GetHeirloomSourceFilter, HL.SetHeirloomSourceFilter, after),
        { CW.Text("CLASS", "COLL_CLASS"), sub = function() return ClassEntries(after) end })
end

CW.AddPage({
    key = "heirlooms", tab = 4, icon = HEIRLOOMS_ICON, tip = { "HEIRLOOMS", "COLL_HEIRLOOMS" }, book = true,
    events = { "HEIRLOOMS_UPDATED", "GET_ITEM_INFO_RECEIVED" },
    List = List, Sub = Sub, Act = Act, Tip = Tip, Shown = CW.AllShown, FilterEntries = FilterEntries,
})
