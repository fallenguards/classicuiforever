local _, ns = ...

-- The game's loot toasts ("You received" for a rare drop, a roll won, an upgrade): 1.x had none, so the alert frame
-- stops hearing their events unless Loot toast is ticked; ticked, it hears them again.

local EVENTS = { "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED",
    "SHOW_PVP_FACTION_LOOT_TOAST", "SHOW_RATED_PVP_REWARD_TOAST", "LOOT_ITEM_ROLL_WON" }
local deaf = false

local function Apply()
    local frame = _G.AlertFrame
    if not frame then return end
    local hide = ns.db.lootToast == false
    if hide == deaf then return end
    deaf = hide
    if not hide then
        ns.RegisterEvents(frame, EVENTS)
        return
    end
    for _, event in ipairs(EVENTS) do frame:UnregisterEvent(event) end
end

ns.RegisterModule("lootToast", { apply = Apply, restore = Apply })
