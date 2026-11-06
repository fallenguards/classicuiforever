local _, ns = ...

-- The game's toasts 1.x had none of: the loot ones ("You received" for a rare drop, a roll won, an upgrade) and the
-- skill ones ("New Recipe Learned" as a profession teaches something). The alert frame stops hearing their events
-- unless the row is ticked; ticked, it hears them again.

local TOASTS = {
    lootToast = { "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED",
        "SHOW_PVP_FACTION_LOOT_TOAST", "SHOW_RATED_PVP_REWARD_TOAST", "LOOT_ITEM_ROLL_WON" },
    skillToast = { "NEW_RECIPE_LEARNED", "SKILL_LINE_SPECS_UNLOCKED" },
}
local deaf = {}

local function Apply(key)
    local frame = _G.AlertFrame
    if not frame then return end
    local hide = ns.db[key] == false
    if hide == (deaf[key] == true) then return end
    deaf[key] = hide
    if not hide then
        ns.RegisterEvents(frame, TOASTS[key])
        return
    end
    for _, event in ipairs(TOASTS[key]) do frame:UnregisterEvent(event) end
end

for key in pairs(TOASTS) do
    local function Pass() Apply(key) end
    ns.RegisterModule(key, { apply = Pass, restore = Pass })
end
