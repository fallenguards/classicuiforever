-- Offline test under Lua 5.4 for Classic coins (Windows/EraCoins.lua): a window's money frame and a tooltip's money line
-- wear Era's coin over the game's (faded, never changed), the game's coin back with the option off, and the game drawing
-- its coin again (a purchase did) leaves ours whole: before, a crop of ours left on its texture cut it up.
-- Run from the addon root: lua tools/tests/era_coins_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(what, got, want)
    if got ~= want then
        failed = failed + 1
        print(string.format("FAIL %s: got %s, want %s", what, tostring(got), tostring(want)))
    end
end

local function Texture(parent)
    local tex = { parent = parent, alpha = 1, shown = true }
    function tex:GetAtlas() return self.atlas end
    function tex:SetAtlas(name) self.atlas = name end
    function tex:SetTexture(file) self.file = file end
    function tex:SetTexCoord(left) self.left = left end
    function tex:GetDrawLayer() return "ARTWORK", 0 end
    function tex:GetParent() return self.parent end
    function tex:SetAllPoints(other) self.over = other end
    function tex:Show() self.shown = true end
    function tex:Hide() self.shown = false end
    return tex
end
-- A coin button: its face the game's atlas, as the game reports it (capitalized).
local function Button(coin)
    local button = { made = {} }
    function button:CreateTexture() local t = Texture(self) table.insert(self.made, t) return t end
    button.face = Texture(button)
    button.face:SetAtlas("Coin-" .. coin)
    function button:GetNormalTexture() return self.face end
    return button
end
local function Money()
    local frame = { children = {} }
    for _, coin in ipairs({ "Gold", "Silver", "Copper" }) do frame[coin .. "Button"] = Button(coin) end
    return frame
end
local function Window(child)
    local frame = { shown = true, children = { child } }
    function frame:IsShown() return self.shown end
    return frame
end
local function Ours(button) return button.made[1] end

local bags = Money()
ContainerFrame1 = Window({ children = { bags } })
local line = Money()
GameTooltip = Window(nil)
function GameTooltip:GetName() return "GameTooltip" end
GameTooltip.numMoneyFrames = 1
GameTooltipMoneyFrame1 = line

local edges, onLogin, onToggle = {}, nil, nil
local ns = {
    db = {},
    IsSecret = function() return false end,
    AnySecret = function() return false end,
    IsForbidden = function() return false end,
    SetAlphaIf = function(region, alpha) region.alpha = alpha end,
    EachChildProtected = function(frame, fn, a1)
        for _, child in ipairs(frame.children or {}) do fn(child, a1) end
    end,
    EventFrame = function(_, fn) onLogin = fn end,
    OnToggle = function(fn) onToggle = fn end,
    Sched = {
        OnVisible = function(frame, _, fn) edges[frame] = fn end,
        NextFrame = function(_, fn) fn() end,
        AfterPerFrame = function() end,
    },
}
local postCall
TooltipDataProcessor = { AllTypes = "all", AddTooltipPostCall = function(_, fn) postCall = fn end }
assert(loadfile(ROOT .. "/Windows/EraCoins.lua"))("ClassicUIForever", ns)
onLogin()

edges[ContainerFrame1](true)
local gold = bags.GoldButton
Check("a bag's gold wears Era's coin over the game's", Ours(gold) and Ours(gold).file, "Interface\\MoneyFrame\\UI-MoneyIcons")
Check("laid on the game's coin", Ours(gold).over, gold.face)
Check("the game's coin faded", gold.face.alpha, 0)
Check("never changed", gold.face.atlas == "Coin-Gold" and gold.face.file == nil and gold.face.left == nil, true)
Check("copper the file's third quarter", Ours(bags.CopperButton).left, 0.5)
edges[GameTooltip](true)
Check("a tooltip's money line too", Ours(line.SilverButton).left, 0.25)

-- A finished tooltip's sell price, its coins written in the text: Era's from the same file, the size kept.
local function Text(text)
    local fs = { text = text }
    function fs:GetText() return self.text end
    function fs:SetText(t) self.text = t end
    return fs
end
GameTooltipTextLeft1 = Text("Rough Arrow")
GameTooltipTextLeft2 = Text("Sell Price: 1|A:coin-gold:14:14:0:0|a 20|A:Coin-Copper:14:14:0:0|a")
function GameTooltip:NumLines() return 2 end
postCall(GameTooltip)
Check("a sell price in Era's coins", GameTooltipTextLeft2.text,
    "Sell Price: 1|TInterface\\MoneyFrame\\UI-MoneyIcons:14:14:0:0:64:16:0:16:0:16|t 20"
    .. "|TInterface\\MoneyFrame\\UI-MoneyIcons:14:14:0:0:64:16:32:48:0:16|t")
Check("a line without coins left alone", GameTooltipTextLeft1.text, "Rough Arrow")

-- A purchase: the game draws its coins again; ours stays one, whole.
gold.face:SetAtlas("Coin-Gold")
edges[ContainerFrame1](true)
Check("drawn again, still one coin of ours", #gold.made, 1)
Check("the game's still faded", gold.face.alpha, 0)

ns.db.eraCoins = false
onToggle("eraCoins")
Check("off: ours hidden", Ours(gold).shown, false)
Check("the game's coin back as it was", gold.face.alpha == 1 and gold.face.atlas == "Coin-Gold", true)
ns.db.eraCoins = nil
onToggle("eraCoins")
Check("on again: ours", Ours(gold).shown and gold.face.alpha == 0, true)

-- Money as text: the game's GetMoneyString (Era's coin files) with the option on, its coin text off.
GetMoneyString = function(copper) return "classic " .. copper end
C_CurrencyInfo = { GetCoinTextureString = function(copper) return "modern " .. copper end }
Check("text money in Era's coins", ns.CoinText(120), "classic 120")
ns.db.eraCoins = false
Check("off: the game's coin text", ns.CoinText(120), "modern 120")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("era_coins_test: all checks passed")
