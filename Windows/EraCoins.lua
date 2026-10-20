local _, ns = ...

-- Classic coins: Era's gold, silver and copper (its file, which Forever ships) over the game's modern coins, ours a
-- texture of its own and the game's faded, never changed: it redraws them when it likes (a purchase did). Laid as a
-- tooltip's or window's money shows and a beat later (rows filled after); off, ours hidden.

local FILE = "Interface\\MoneyFrame\\UI-MoneyIcons"
-- Each coin's quarter of the file, by atlas name read case-blind: the game reports "Coin-Gold" (coins probe).
local LEFT = { ["coin-gold"] = 0, ["coin-silver"] = 0.25, ["coin-copper"] = 0.5 }
local BUTTONS = { "GoldButton", "SilverButton", "CopperButton" }
local DISPLAYS = { "GoldDisplay", "SilverDisplay", "CopperDisplay" }
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
-- Money frames the game shows on their own inside a window already open (a quest's reward, its required money).
local MONEY = { "QuestInfoMoneyFrame", "QuestInfoRequiredMoneyDisplay" }
local WINDOWS = { "MerchantFrame", "MailFrame", "OpenMailFrame", "TradeFrame", "QuestFrame", "ClassTrainerFrame",
    "BankFrame", "GuildBankFrame", "PetStableFrame", "WorldMapFrame", "ContainerFrameCombinedBags" }
for i = 1, 13 do WINDOWS[#WINDOWS + 1] = "ContainerFrame" .. i end
local DEPTH, LATER = 8, 0.3

local over = setmetatable({}, { __mode = "k" })    -- the game's coin texture -> ours over it
local looks = setmetatable({}, { __mode = "k" })   -- watched frame -> its look

local function On() return ns.db ~= nil and ns.db.eraCoins ~= false end

local function Lay(tex)
    if not tex then return end
    local atlas = tex:GetAtlas()
    local left = atlas and not ns.IsSecret(atlas) and LEFT[atlas:lower()]
    if not left then return end
    local era = over[tex]
    if not era then
        local layer, sub = tex:GetDrawLayer()
        if ns.AnySecret(layer, sub) then return end
        era = tex:GetParent():CreateTexture(nil, layer, nil, math.min(7, (sub or 0) + 1))
        era:SetAllPoints(tex)
        era:SetTexture(FILE)
        over[tex] = era
    end
    era:SetTexCoord(left, left + 0.25, 0, 1)
    era:Show()
    ns.SetAlphaIf(tex, 0)
end

-- A money frame's three coins: a button's face, or a display's icon.
local function Coins(frame)
    for _, key in ipairs(BUTTONS) do
        local button = frame[key]
        if button then Lay(button:GetNormalTexture()) end
    end
    for _, key in ipairs(DISPLAYS) do
        local display = frame[key]
        if display then Lay(display.Icon) end
    end
end

local function Walk(frame, depth)
    if depth > DEPTH or ns.IsForbidden(frame) then return end
    if frame.GoldButton or frame.GoldDisplay then
        Coins(frame)
        return
    end
    ns.EachChildProtected(frame, Walk, depth + 1)
end
local function WalkWindow(frame) Walk(frame, 0) end

-- A tooltip's money lines, made as it needs them: <tooltip>MoneyFrame1, 2, ...
local function TipCoins(tip)
    local name = tip:GetName()
    for i = 1, tip.numMoneyFrames or 0 do
        local money = _G[name .. "MoneyFrame" .. i]
        if money then Coins(money) end
    end
end

local function Watch(name, fn)
    local frame = _G[name]
    if not frame or looks[frame] then return end
    local key = "eraCoins." .. name
    local function Look()
        if On() and frame:IsShown() then fn(frame) end
    end
    looks[frame] = Look
    ns.Sched.OnVisible(frame, "eraCoins", function(shown)
        if not shown then return end
        ns.Sched.NextFrame(key, Look)
        ns.Sched.AfterPerFrame(key, LATER, Look)
    end)
end

-- At login and as the game's windows load.
local function WatchAll()
    for _, name in ipairs(TIPS) do Watch(name, TipCoins) end
    for _, name in ipairs(WINDOWS) do Watch(name, WalkWindow) end
    for _, name in ipairs(MONEY) do Watch(name, Coins) end
end
ns.EventFrame({ "PLAYER_LOGIN", "ADDON_LOADED" }, WatchAll)

-- A tooltip's text money (a sell price): the game writes its coins into the line as atlas markup; ours the same size
-- from Era's file, rewritten as the game finishes each tooltip (its post-call, run apart from the tooltip's own pass).
local CELL = { gold = 0, silver = 16, copper = 32 }   -- each coin's left in the 64 x 16 file
local MARKUP = "|A:[Cc][Oo][Ii][Nn]%-(%a+):(%d+):(%d+):(%-?%d+):(%-?%d+)|a"
local function EraMarkup(kind, h, w, x, y)
    local left = CELL[kind:lower()]
    if not left then return nil end
    return ("|T%s:%s:%s:%s:%s:64:16:%d:%d:0:16|t"):format(FILE, h, w, x, y, left, left + 16)
end
local function TextCoins(tip)
    local name = On() and tip and tip.GetName and tip:GetName()
    if type(name) ~= "string" then return end
    for i = 1, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text and not ns.IsSecret(text) and text:find("|A:[Cc][Oo][Ii][Nn]%-") then
            line:SetText((text:gsub(MARKUP, EraMarkup)))
        end
    end
end
if TooltipDataProcessor then TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, TextCoins) end

-- Money as text with its coins (our quest log, the trainer's costs). Classic coins on: the game's GetMoneyString, whose
-- coin files (UI-GoldIcon and the others) Forever ships as Era's; off: the game's coin text, modern coins.
function ns.CoinText(copper)
    copper = tonumber(copper) or 0
    if On() and GetMoneyString then return GetMoneyString(copper) end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(copper) end
    return GetMoneyString and GetMoneyString(copper) or tostring(copper)
end

-- Read by the dev addon's coins probe: frames watched, coins laid over.
function ns.EraCoinsState()
    local watched, coins = 0, 0
    for _ in pairs(looks) do watched = watched + 1 end
    for _ in pairs(over) do coins = coins + 1 end
    return watched, coins
end

ns.OnToggle(function(key)
    if key ~= "eraCoins" then return end
    if On() then
        for _, look in pairs(looks) do look() end
        return
    end
    for tex, era in pairs(over) do
        era:Hide()
        ns.SetAlphaIf(tex, 1)
    end
end)
