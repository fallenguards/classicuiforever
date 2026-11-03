local _, ns = ...

-- A talent tree read into lists of talents on a grid, so added or moved talents land where the client puts them.
-- The talents window splits its one tree by group into three lists; a Legacy tree is one list of its own.

local function ByOrderIndex(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end

-- The class tree's cells are 600 apart. "auto": the smallest gap between nodes, for trees laid out on another scale.
local CELL = 600
local MIN_GAP = 50

local function AutoCell(nodes)
    local cell
    for _, axis in ipairs({ "x", "y" }) do
        local seen = {}
        for _, talent in ipairs(nodes) do seen[#seen + 1] = talent[axis] end
        table.sort(seen)
        for i = 2, #seen do
            local gap = seen[i] - seen[i - 1]
            if gap >= MIN_GAP and (not cell or gap < cell) then cell = gap end
        end
    end
    return cell or CELL
end

-- Columns from the tab's leftmost node, tiers from the tree's top. Stops at a gap of more than two empty rows: the
-- client can put a node far below its group, which stretched the page; such nodes are not drawn.
local function Grid(tab, topY, cell, nodesByID)
    local leftX
    for _, talent in ipairs(tab.nodes) do
        if not leftX or talent.x < leftX then leftX = talent.x end
    end
    local used = {}
    for _, talent in ipairs(tab.nodes) do
        talent.column = math.floor((talent.x - leftX) / cell + 0.5)
        talent.tier = math.floor((talent.y - (topY or talent.y)) / cell + 0.5)
        used[talent.tier] = true
    end
    local last = -1
    local tiers = {}
    for tier in pairs(used) do tiers[#tiers + 1] = tier end
    table.sort(tiers)
    for _, tier in ipairs(tiers) do
        if last >= 0 and tier - last > 3 then break end
        last = tier
    end
    tab.tiers = last + 1
    for i = #tab.nodes, 1, -1 do
        local talent = tab.nodes[i]
        if talent.tier > last then
            nodesByID[talent.nodeID] = nil
            table.remove(tab.nodes, i)
        end
    end
end

-- One talent from its node; nil for a hidden or unplaced one.
local function ReadTalent(configID, nodeID, points)
    local node = C_Traits.GetNodeInfo(configID, nodeID)
    if not (node and node.isVisible ~= false and node.posX) then return nil, nil end
    local entryID = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    local spellID = def and (def.overriddenSpellID or def.spellID)
    return {
        nodeID = nodeID, entryID = entryID, spellID = spellID, x = node.posX, y = node.posY,
        rank = node.ranksPurchased or 0, maxRank = node.maxRanks or 1,
        -- canPurchaseRank ignores points left; without the check unspent talents lit green.
        canBuy = node.canPurchaseRank and points > 0 and true or false,
        canRefund = node.canRefundRank and true or false,
        available = node.isAvailable and true or false, edges = node.visibleEdges or {},
        icon = def and def.overrideIcon or (spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)),
        conditions = node.conditionIDs or {},
    }, node
end

-- The groups as tabs, in their order, with points spent in each; nil when the client gives none.
local function GroupTabs(tree)
    local okGroups, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, tree.treeID)
    if not okGroups or type(groups) ~= "table" then return nil end
    table.sort(groups, ByOrderIndex)
    local byGroup, groupIDs = {}, {}
    for i, info in ipairs(groups) do
        local tab = { index = i, groupID = info.groupID, name = info.displayName or "", icon = info.icon, nodes = {}, spent = 0 }
        tree.tabs[i] = tab
        byGroup[info.groupID] = tab
        groupIDs[#groupIDs + 1] = info.groupID
    end
    local okSpent, spentInfos = pcall(C_Traits.GetGroupCurrencyInfo, tree.configID, groupIDs)
    for _, info in ipairs(okSpent and spentInfos or {}) do
        local tab = byGroup[info.traitNodeGroupID]
        local currency = info.currencyInfos and info.currencyInfos[1]
        if tab and currency then tab.spent = currency.spent or 0 end
    end
    return byGroup
end

-- ReadTraitGroups(configID, treeID) -> the groups as tabs (name, icon, spent) without their talents, or nil.
function ns.ReadTraitGroups(configID, treeID)
    if not (configID and treeID and C_Traits) then return nil end
    local tree = { configID = configID, treeID = treeID, tabs = {} }
    return GroupTabs(tree) and tree.tabs or nil
end

-- ReadTraitTree(configID, treeID, opts) -> tree { configID, treeID, points, cap, tabs, nodesByID, staged, inspect,
-- locked } or nil. opts.name: one tab of every node, so named (else one tab per group); opts.cell: "auto" or nil (600);
-- opts.inspect; opts.locked: the player's spec not in use, shown as it is with nothing to buy.
function ns.ReadTraitTree(configID, treeID, opts)
    if not (configID and treeID and C_Traits) then return nil end
    opts = opts or ns.EMPTY
    local tree = { configID = configID, treeID = treeID, tabs = {}, points = 0 }
    local okPoints, currencies = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    local currency = okPoints and currencies and currencies[1]
    if currency then
        tree.points = currency.quantity or 0
        tree.cap = currency.maxQuantity
    end
    local byGroup
    if opts.name then
        tree.tabs[1] = { index = 1, name = opts.name, nodes = {}, spent = currency and (currency.spentInTree or currency.spent) or 0 }
    else
        byGroup = GroupTabs(tree)
        if not byGroup then return nil end
    end
    local nodesByID = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local talent, node = ReadTalent(configID, nodeID, opts.locked and 0 or tree.points)
        if talent and opts.locked then talent.canRefund = false end
        local tab = talent and not byGroup and tree.tabs[1]
        for _, groupID in ipairs(talent and byGroup and node.groupIDs or {}) do
            if byGroup[groupID] then tab = byGroup[groupID] break end
        end
        if tab then
            tab.nodes[#tab.nodes + 1] = talent
            nodesByID[nodeID] = talent
        end
    end
    local topY, all = nil, {}
    for _, tab in ipairs(tree.tabs) do
        for _, talent in ipairs(tab.nodes) do
            all[#all + 1] = talent
            if not topY or talent.y < topY then topY = talent.y end
        end
    end
    local cell = opts.cell == "auto" and AutoCell(all) or CELL
    for _, tab in ipairs(tree.tabs) do Grid(tab, topY, cell, nodesByID) end
    tree.nodesByID = nodesByID
    tree.inspect = opts.inspect and true or false
    tree.locked = opts.locked and true or false
    tree.staged = not tree.inspect and not tree.locked and C_Traits.ConfigHasStagedChanges
        and C_Traits.ConfigHasStagedChanges(configID) and true or false
    return tree
end
