local _, ns = ...
local B = ns.bags

-- The one bag in sections (#185): by bag type or by bag (option), then the equipped bags' row (option), each from a
-- new row with a rule over it. The slot list comes foot to top (Windows/Bags.lua), the key ring's slots in it.

local REAGENT = Enum.BagIndex.ReagentBag
local KEYRING = Enum.BagIndex.Keyring
-- Slot tints in the combined bag over the socket: the reagent slots a soft green (option), the key ring's the brass
-- of its own bag's sheet (bagComponentsKeyring), always.
local REAGENT_TINT = { 0.25, 0.8, 0.35, 0.3 }
local KEYRING_TINT = { 0.85, 0.62, 0.22, 0.3 }
function B.SlotTint(button, tint)
    local bag = button:GetBagID()
    if bag == KEYRING then return KEYRING_TINT end
    return tint and bag == REAGENT and REAGENT_TINT or nil
end
local GetFreeSlots = C_Container.GetContainerNumFreeSlots
local SLOT = 37
local RULE_H, RULE_OVER = 2, 2   -- the rule in the gap over a section's first row, reaching past the grid each side
local RULE_COLOR = { 0.72, 0.58, 0.33, 0.8 }
local groups, order = {}, {}
local rules = setmetatable({}, { __mode = "k" })   -- bag frame -> its rule textures

function B.Sectioned()
    local db = ns.db
    return db ~= nil and (db.oneBagSplitType == true or db.oneBagSplitBag == true or db.oneBagBagSlots == true)
end

-- A slot's section: its bag, its bag's type (family; the reagent bag its own), or one for all.
local function Key(button)
    local bag = button:GetBagID()
    if ns.db.oneBagSplitBag == true then return bag end
    if ns.db.oneBagSplitType ~= true then return "items" end
    if bag == REAGENT then return "reagent" end
    local _, family = GetFreeSlots(bag)
    return "family" .. tostring(family or 0)
end

local function Add(key, button)
    local group = groups[key]
    if not group then
        group = {}
        groups[key] = group
    end
    if #group == 0 then order[#order + 1] = key end
    group[#group + 1] = button
end

-- Sections in reading order (the list read back), the key ring and the bag row last; returns the rows they take.
local function Group(list, count, columns)
    for _, key in ipairs(order) do wipe(groups[key]) end
    wipe(order)
    for i = count, 1, -1 do Add(Key(list[i]), list[i]) end
    for _, button in ipairs(B.BagSlotButtons()) do Add("bagSlots", button) end
    local rows = 0
    for _, key in ipairs(order) do rows = rows + math.ceil(#groups[key] / columns) end
    return rows
end

function B.SectionRows(list, count, columns)
    return math.max(1, Group(list, count, columns))
end

-- Place's grid index for a spot read from the top left (it counts from the bottom right).
local function Index(rowTop, colLeft, rows, columns)
    return (rows - 1 - rowTop) * columns + (columns - 1 - colLeft)
end

local function Rule(frame, i)
    local list = rules[frame]
    if not list then
        list = {}
        rules[frame] = list
    end
    if not list[i] then
        local holder = list.holder
        if not holder then
            holder = ns.NewFrame("Frame", nil, frame)
            holder:SetAllPoints()
            B.ownChildren[holder] = true
            list.holder = holder
        end
        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:SetColorTexture(RULE_COLOR[1], RULE_COLOR[2], RULE_COLOR[3], RULE_COLOR[4])
        list[i] = tex
    end
    return list[i]
end

-- Each section from a new row, a patch over its short last row's empty sockets; returns the patches used.
function B.LaySections(frame, list, count, columns, backpackExtra, tint)
    local rows = B.SectionRows(list, count, columns)
    for i = 1, count do list[i] = nil end
    local top, blanks = 0, 0
    for s, key in ipairs(order) do
        local group = groups[key]
        local n = #group
        for j = 1, n do
            local button = group[j]
            B.SlotArt(button)
            local index = Index(top + math.floor((j - 1) / columns), (j - 1) % columns, rows, columns)
            B.Place(button, index, 0, 0, frame, columns, rows, 0, false, backpackExtra)
            B.Tint(button, B.SlotTint(button, tint))
        end
        local used = math.ceil(n / columns)
        local missing = used * columns - n
        local last = Index(top + used - 1, columns - 1, rows, columns)
        if missing > 0 then
            blanks = blanks + 1
            local tex = B.Blank(frame, blanks)
            tex:SetSize(missing * B.COL - 3, B.BLANK_H)
            B.Place(tex, last, 1, -1, frame, columns, rows, 0, false, backpackExtra)
            tex:Show()
        end
        if s > 1 then
            local rule = Rule(frame, s - 1)
            rule:SetSize(columns * B.COL - 5 + 2 * RULE_OVER, RULE_H)
            B.Place(rule, Index(top, columns - 1, rows, columns), RULE_OVER, SLOT + 1, frame, columns, rows, 0, false,
                backpackExtra)
            rule:Show()
        end
        top = top + used
    end
    local made = rules[frame]
    if made then for i = #order, #made do made[i]:Hide() end end
    return blanks
end

-- Sections off: rules and the bag row go.
function B.ClearSections(frame)
    local made = rules[frame]
    if made then for _, rule in ipairs(made) do rule:Hide() end end
    B.BagSlotButtons()
end
