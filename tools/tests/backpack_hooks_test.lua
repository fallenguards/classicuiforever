-- Offline test under Lua 5.4 for the backpack's skin hooks (Bar/BarSkins.lua ns.SkinBagButton): the classic bar stays
-- down until world entry, so its hand-back (ns.GameBackpackFreeSlots) makes the backpack's record before the skin does.
-- The skin hooked only a record it made itself, so the game's texture passes (any bag change: looting, buying) left
-- Forever's backpack until the next re-lay (2026-11-15).
-- Run from the addon root: lua tools/tests/backpack_hooks_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local handle = assert(io.open(ROOT .. "/Bar/BarSkins.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("-- Our bar off: the game's own backpack", 1, true)
local last = first and source:find("function ns.UnskinBagButton", first, true)
assert(first and last, "the bag skin's record and hooks are in Bar/BarSkins.lua")

-- The game's backpack: its texture pass puts Forever's icon on; a hook wraps the method in place.
local backpack = { Count = {}, icon = "era" }
function backpack.UpdateTextures(self) self.icon = "forever" end
function backpack.SetItemButtonQuality(self) self:UpdateTextures() end
function backpack.SetItemButtonTexture(self) self:UpdateTextures() end

local installs = {}
local function Hook(t, method, fn)
    installs[method] = (installs[method] or 0) + 1
    local orig = t[method]
    t[method] = function(...) orig(...) fn(...) end
end

local bags = {}
local env = setmetatable({
    ns = {},
    bags = bags,
    MainMenuBarBackpackButton = backpack,
    hooksecurefunc = Hook,
    rawget = rawget,
    -- The skin's paint: Era's icon while the skin is on.
    ApplyBagArt = function(button)
        local state = bags[button]
        if state and state.active then button.icon = "era" end
    end,
    SkinFreeSlots = function() end,
    PlaceFreeCount = function() end,
}, { __index = _G })
local ns = env.ns
assert(load(source:sub(first, last - 1), "bagskin", "t", env))()

-- Login: the bar's hand-back first, then the skin at world entry.
ns.GameBackpackFreeSlots()
ns.SkinBagButton(backpack, 37, true)
Check(backpack.icon == "era", "skinned: Era's backpack")
backpack:SetItemButtonTexture(132382)
Check(backpack.icon == "era", "a bag change (the ammo slot's refresh) keeps Era's backpack (" .. backpack.icon .. ")")
backpack:SetItemButtonQuality()
Check(backpack.icon == "era", "the quality pass keeps it too")

-- Skinned again (every re-lay): hooked once, not once per pass.
ns.SkinBagButton(backpack, 37, true)
ns.SkinBagButton(backpack, 37, true)
for _, method in ipairs({ "UpdateTextures", "SetItemButtonQuality", "SetItemButtonTexture" }) do
    Check(installs[method] == 1, method .. " hooked once (" .. tostring(installs[method]) .. ")")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("backpack_hooks_test: ok")
