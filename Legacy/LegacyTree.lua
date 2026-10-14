local _, ns = ...
local L = ns.L

-- The Legacy window's tree page: Professions, Adventure and Resourcefulness as the talent window's foot tabs, each on
-- an Era talent background, or side by side (option, UI/TalentTrees.lua). Each tree is its own config, spending the
-- account's Legacy Points; a click stages, Apply commits. Read from the client's tree data, so new perks land in place.

local LG = ns.legacy
local Text = LG.Text

local LegacyConsts = Constants and Constants.LegacyConsts or ns.EMPTY
-- Tree ids, names and backgrounds in the game's tab order. Backgrounds are Era class trees picked for the theme.
local TREES = {
    { id = LegacyConsts.LEGACY_TREE_PROFESSIONS_ID or 1187, global = "LEGACY_TREE_PROFESSIONS", key = "LEGACY_PROFESSIONS",
        art = "DruidRestoration" },
    { id = LegacyConsts.LEGACY_TREE_ADVENTURE_ID or 1188, global = "LEGACY_TREE_ADVENTURE", key = "LEGACY_ADVENTURE",
        art = "HunterBeastMastery" },
    { id = LegacyConsts.LEGACY_TREE_PROGRESSION_ID or 1189, global = "LEGACY_TREE_PROGRESSION", key = "LEGACY_RESOURCEFULNESS",
        art = "WarriorProtection" },
}

local names = {}
local function TreeNames()
    for i, info in ipairs(TREES) do names[i] = Text(info.global, info.key) end
    return names
end

-- One tree, its tab marked with the tree's place for its background.
local function ReadTree(index)
    local info = TREES[index]
    local configID = C_Traits.GetConfigIDByTreeID(info.id)
    if not configID then return nil end
    local tree = ns.ReadTraitTree(configID, info.id, { name = Text(info.global, info.key), cell = "auto" })
    if tree then tree.tabs[1].index = index end
    return tree
end

-- Side by side: each tree in its pane, the foot's tree their parts (Apply and Undo reach each one staged).
local side, parts = {}, {}
local whole = { parts = parts }
local function ReadAll()
    wipe(parts)
    whole.staged = false
    for i = 1, #TREES do
        local tree = ReadTree(i)
        side[i] = tree
        if tree then
            parts[#parts + 1] = tree
            whole.staged = whole.staged or tree.staged
        end
    end
    if #parts == 0 then return nil end
    whole.points = parts[1].points
    return whole
end

local window, locked
local showing = false

-- The trees are 4 rows: at Era's height, no scroll bars, growing only should the game add rows.
local THREE = {
    wanted = function() return showing and ns.db and ns.db.legacyThreePane == true end,
    mode = function() return "tall" end,
    keys = { legacyThreePane = true },
    slot = ns.SIDE_TAB_SLOT,
}

local function Background(tab)
    return TREES[tab and tab.index or window.tabIndex].art
end

local function Build(frame)
    window = frame
    ns.TalentTrees(frame, THREE)
    locked = frame.child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    locked:SetWidth(240)
    locked:SetText(L["LEGACY_LOCKED"])
    locked:Hide()
end

-- The no-points line over the one tree, or the middle of three.
local function Locked(frame, three, shown)
    local view = three and frame.panes[2] or frame
    if locked:GetParent() ~= view.child then locked:SetParent(view.child) end
    ns.SetPointOnce(locked, "CENTER", view.scroll, "CENTER", 0, 0)
    locked:SetShown(shown)
end

local function Refresh(frame)
    local three = frame.trees.on
    local tree
    if three then tree = ReadAll() else tree = ReadTree(frame.tabIndex) end
    local points = tree and string.format(L["LEGACY_POINTS"], "|cffffffff" .. tree.points .. "|r") or ""
    ns.DrawTalentTab(frame, tree, { background = Background, title = Text("LEGACY_TREE_FRAME_TITLE", "LEGACY_TITLE"),
        points = points, tabNames = TreeNames(), trees = three and side or nil })
    -- No config yet: the account has earned no Legacy Point.
    Locked(frame, three, tree == nil)
end

-- Side by side only on this page: off before its pieces go (the one tree's come back), on once they show.
local function Shown(frame, on)
    showing = on
    if not on then frame.trees.Reshape() end
    ns.TalentTreeShown(frame, on)
    if on then frame.trees.Reshape() end
end

local function Learn(tree)
    if not C_Traits.CommitConfig then return end
    for _, part in ipairs(tree.parts or { tree }) do
        if part.staged or not tree.parts then pcall(C_Traits.CommitConfig, part.configID) end
    end
end

LG.AddPage({
    key = "tree", tab = 3, icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    tip = { "LEGACY_TREE_TAB_TOOLTIP", "LEGACY_TREE_TAB" }, title = { "LEGACY_TREE_FRAME_TITLE", "LEGACY_TITLE" },
    -- Points, perks and staged changes.
    events = { "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED" },
    build = Build, shown = Shown, refresh = Refresh, learn = Learn,
})
