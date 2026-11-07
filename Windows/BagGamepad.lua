local _, ns = ...
local B = ns.bags

-- The gamepad's bag buttons in the one bag: the game lays them among the items, and its pad navigation reads a grid off
-- that layout, so ours lays them too, at the top of our grid in bag order. Their art stays the game's.

B.PadBags = setmetatable({}, { __mode = "k" })   -- the buttons laid by us
local list = {}

function B.PadBagButtons()
    wipe(list)
    local bar = _G.GamepadBagBar
    if not (bar and bar.GetBagButton and ns.GamepadUI()) then return list end
    for bag = 0, NUM_TOTAL_BAG_FRAMES or 4 do list[#list + 1] = bar:GetBagButton(bag) end
    list[#list + 1] = bar:GetBagButton(KEYRING_CONTAINER or -2)
    for _, button in ipairs(list) do B.PadBags[button] = true end
    return list
end

-- Into a slot list after its count; the new count.
function B.AddPadBags(slots, count)
    for _, button in ipairs(B.PadBagButtons()) do
        count = count + 1
        slots[count] = button
    end
    return count
end
