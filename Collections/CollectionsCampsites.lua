local _, ns = ...

-- The Collections window's Campsites page (retail's warband scenes): every campsite, its picture the icon and large in
-- the box, Favorite or Unfavorite on one you own (character select shows your favorites).

local WS = _G.C_WarbandScene
if not WS then return end
local CW = ns.collections
local IsSecret = ns.IsSecret

local CAMPSITES_ICON = "Interface\\Icons\\UI_CampCollection"
local SEARCH = { ownedOnly = false }

local function List()
    local out = {}
    for _, id in ipairs(WS.SearchWarbandSceneEntries(SEARCH) or ns.EMPTY) do
        local info = WS.GetWarbandSceneEntry(id)
        local name = info and info.name
        if type(name) == "string" and not IsSecret(name) then
            out[#out + 1] = { id = id, name = name, atlas = info.textureKit, source = info.source,
                collected = WS.HasWarbandScene(id) == true }
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

local function Show(entry, box)
    if type(entry.source) == "string" and not IsSecret(entry.source) then box.source:SetText(entry.source) end
    CW.ShowPicture(box, entry.atlas)
end

-- The random pick stands for every campsite: never a favorite of its own.
local function Random(entry) return WS.GetRandomEntryID and entry.id == WS.GetRandomEntryID() end

local function Action(entry)
    if WS.IsFavorite(entry.id) then return CW.Text("BATTLE_PET_UNFAVORITE", "COLL_UNFAVORITE"), true end
    return CW.Text("BATTLE_PET_FAVORITE", "COLL_FAVORITE"), entry.collected and not Random(entry)
end

local function Act(entry)
    WS.SetFavorite(entry.id, not WS.IsFavorite(entry.id))
end

local function Tip(entry)
    local util, info = _G.SharedCollectionUtil, WS.GetWarbandSceneEntry(entry.id)
    if util and util.ShowWarbandSceneEntryTooltip and info then
        util.ShowWarbandSceneEntryTooltip(GameTooltip, info, entry.collected)
    else
        GameTooltip:SetText(entry.name)
    end
end

CW.AddPage({
    key = "campsites", tab = 6, icon = CAMPSITES_ICON, tip = { "WARBAND_SCENES", "COLL_CAMPSITES" },
    events = { "WARBAND_SCENE_FAVORITES_UPDATED", "NEW_WARBAND_SCENE_ADDED" },
    List = List, Show = Show, Action = Action, Act = Act, Tip = Tip,
})
