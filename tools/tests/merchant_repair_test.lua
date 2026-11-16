-- Offline test under Lua 5.4 for the merchant's repair buttons (Windows/PanelAfters.lua EraRepairIcons): Era's icons
-- from the client's UI-Merchant-RepairIcons sheet at Vanilla MerchantFrame.xml's cells, Forever's slot behind each
-- hidden. Forever's own art is SpellIcon atlases (2026-11-15).
-- Run from the addon root: lua tools/tests/merchant_repair_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

-- The dressing on fake buttons: every texture call recorded.
local function Tex(layer)
    local t = { layer = layer, shown = true }
    function t.IsObjectType(_, kind) return kind == "Texture" end
    function t:GetDrawLayer() return self.layer end
    function t:SetTexture(file) self.file = file end
    function t:SetTexCoord(...) self.coords = { ... } end
    function t:Hide() self.shown = false end
    return t
end
local buttons = {}
for _, name in ipairs({ "MerchantRepairItemButton", "MerchantRepairAllButton", "MerchantGuildBankRepairButton" }) do
    local icon, socket = Tex("BORDER"), Tex("BACKGROUND")
    local button = { Icon = icon, socket = socket }
    function button.GetRegions() return socket, icon end
    buttons[name] = button
    _G[name] = button
end

local ns, P = { L = setmetatable({}, { __index = function(_, k) return k end }) }, { after = {} }
ns.panels = P
local set = {}
function ns.SetTex(texture, key) set[texture] = key texture:SetTexture(key) end
function ns.EachRegion(frame, fn) for _, r in ipairs({ frame:GetRegions() }) do fn(r) end end
function ns.AnySecret() return false end
for _, stub in ipairs({ "FadeTextures", "EraTabRow", "ShowInsetBorder", "Dress", "SetPointOnce", "HookGlobal", "EachChild" }) do
    ns[stub] = function() end
end
function ns.DressNew() return { Show = function() end, Hide = function() end, SetShown = function() end } end
function ns.Once() return false end
ns.Sched = setmetatable({}, { __index = function() return function() end end })

assert(loadfile(ROOT .. "/Windows/PanelAfters.lua"))("ClassicUIForever", ns)
local after = P.after.MerchantFrame
Check(type(after) == "function", "the merchant dressing loads")
if type(after) == "function" then
    after({})
    local ERA = {
        MerchantRepairItemButton = { 0, 0.28125, 0, 0.5625 },
        MerchantRepairAllButton = { 0.28125, 0.5625, 0, 0.5625 },
        MerchantGuildBankRepairButton = { 0.5625, 0.84375, 0, 0.5625 },
    }
    for name, cell in pairs(ERA) do
        local b = buttons[name]
        Check(set[b.Icon] == "merchantRepair", name .. ": Era's sheet")
        local c = b.Icon.coords or {}
        Check(c[1] == cell[1] and c[2] == cell[2] and c[3] == cell[3] and c[4] == cell[4], name .. ": Era's cell")
        Check(b.socket.shown == false, name .. ": the client's slot behind it hidden")
        Check(b.Icon.shown == true, name .. ": the icon itself kept")
    end
end

-- The key reads the client's sheet: Forever's and retail's copies hold Era's two icons unchanged.
local data = assert(io.open(ROOT .. "/Art/TextureData.lua")):read("a")
Check(data:find('merchantRepair = "=MerchantFrame\\\\UI%-Merchant%-RepairIcons"') ~= nil, "merchantRepair is the client's sheet")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("merchant_repair_test: ok")
