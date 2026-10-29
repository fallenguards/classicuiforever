local _, ns = ...

-- A druid's mana in any form not on mana, as Wrath shows it (PlayerFrameAlternateManaBar): a small bar under the power
-- bar in the group tab's frame, hanging below the player frame. Retail's moonkin too, the game's own bar faded (#212).

local UF = ns.UF
local IsSecret = ns.IsSecret
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local MANA = Enum.PowerType.Mana

-- Wrath's tab (97 x 16, upside down: its open side up) centred under the power bar, one under its foot (Wrath's 3 px
-- over it showed through our frame art). The fill runs between the walls' bright lines (art texels 11 to 82: 81 wide,
-- 1 right of the middle), over the tab, so the right wall's wider inner shadow reads as no gap.
local BAR_W, BAR_H, BAR_SHIFT, BAR_Y = 81, 12, 1, -1
local TAB_W, TAB_H = 97, 16
local TAB_COORDS = { 0.0234375, 0.6875, 1.0, 0.0 }
-- Texts as the other bars' (Status Text setting, both numbers on hover): one centred, or percent left and value right.
local TEXT_SIDE = 2
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local EVENTS = { "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "CVAR_UPDATE" }
local bar, driver, live, hovered
local Update

local function GamePowerText()
    return ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain", "ManaBarArea", "ManaBar", "TextString")
end

local function Text(host, point, x)
    local fs = host:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    fs:SetPoint(point, bar, point, x, 0)
    return fs
end

local function Build(power)
    bar = ns.NewFrame("StatusBar", nil, PlayerFrame)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetFrameLevel(math.max(0, power:GetFrameLevel() - 1))
    bar:SetPoint("TOP", power, "BOTTOM", BAR_SHIFT, BAR_Y)
    ns.FillUnitBar(bar)
    bar:SetStatusBarColor(0, 0, 1)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(bar)
    back:SetColorTexture(0, 0, 0, 0.5)
    bar.tab = bar:CreateTexture(nil, "BORDER")
    ns.SetTex(bar.tab, "groupIndicator")
    bar.tab:SetTexCoord(unpack(TAB_COORDS))
    bar.tab:SetSize(TAB_W, TAB_H)
    bar.tab:SetPoint("TOP", power, "BOTTOM", 0, BAR_Y)
    -- The tab's opening (its closed edge bevelled at the corners), cut from its art: fill and backing stay inside it.
    local mask = bar:CreateMaskTexture()
    mask:SetTexture((ns.TexPath("druidManaMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(bar.tab)
    bar:GetStatusBarTexture():AddMaskTexture(mask)
    back:AddMaskTexture(mask)
    -- Over the frame art, as the other bars' texts.
    local host = ns.NewFrame("Frame", nil, bar)
    host:SetAllPoints(bar)
    host:SetFrameLevel(PlayerFrame:GetFrameLevel() + 6)
    bar.center, bar.left, bar.right = Text(host, "CENTER", 0), Text(host, "LEFT", TEXT_SIDE), Text(host, "RIGHT", -TEXT_SIDE)
    ns.Sched.OnHover(bar, function(over)
        hovered = over
        Update()
    end)
    bar:Hide()
end

local function Short(value)
    return BreakUpLargeNumbers(value)
end

local function Percent()
    return _G.UnitPowerPercent("player", MANA, false, _G.CurveConstants and _G.CurveConstants.ScaleTo100)
end

-- The Status Text setting: numeric, percent, both (percent left, value right) or none (numbers on hover only); with
-- both numbers on hover (the option), numeric and percent show both while the mouse is over the bar.
local function Numbers(now, most)
    local mode = ns.GetCVar("statusTextDisplay")
    -- The game's own rule (TextStatusBar): with its Status Text switch off, a bar's numbers show on hover only.
    if ns.GetCVar("statusText") ~= "1" and not hovered then mode = "NONE" end
    if mode == "NONE" and hovered then mode = "NUMERIC" end
    if hovered and ns.db.hoverBothNumbers ~= false and (mode == "NUMERIC" or mode == "PERCENT") then mode = "BOTH" end
    local font = GamePowerText()
    font = font and font:GetFontObject()
    for _, fs in ipairs({ bar.center, bar.left, bar.right }) do
        if font then fs:SetFontObject(font) end
        fs:Hide()
    end
    if mode == "NUMERIC" then
        bar.center:SetFormattedText("%s / %s", Short(now), Short(most))
        bar.center:Show()
    elseif mode == "PERCENT" then
        bar.center:SetFormattedText("%d%%", Percent())
        bar.center:Show()
    elseif mode == "BOTH" then
        bar.left:SetFormattedText("%d%%", Percent())
        bar.right:SetText(Short(now))
        bar.left:Show()
        bar.right:Show()
    end
end

function Update()
    local most = live and UnitPowerMax("player", MANA)
    local kind = live and UnitPowerType("player")
    local show = live and not IsSecret(most) and not IsSecret(kind) and kind ~= MANA and (most or 0) > 0
    if show then
        local now = UnitPower("player", MANA)
        bar:SetMinMaxValues(0, most)
        bar:SetValue(now)
        Numbers(now, most)
    end
    -- The frame's glow is routed by the tab (Units/PlayerFrame.lua): a form change re-lays it.
    if ns.SetShownIf(bar, show and true or false) then UF.PlayerGlowRoute() end
end

function ns.DruidManaShown()
    return bar ~= nil and bar:IsShown()
end

-- Druids only, with the classic player frame and the option on; called by the unit frame module and the switch.
function ns.DruidManaSync()
    local player = UF.frames.player
    local druid = select(2, UnitClass("player")) == "DRUID"
    local on = UF.active and player ~= nil and druid and ns.db.druidMana ~= false
    if on and not bar then Build(player.power) end
    if on and not driver then driver = ns.EventFrame(EVENTS, Update) end
    if driver then
        driver:UnregisterAllEvents()
        if on then
            ns.RegisterEvents(driver, EVENTS)
            ns.RegisterEvents(driver, UNIT_EVENTS, "player")
        end
    end
    live = on
    -- Retail's own moonkin mana bar, under ours while ours shows it (#212).
    if druid and _G.AlternatePowerBar then ns.SetAlphaIf(_G.AlternatePowerBar, on and 0 or 1) end
    if bar then Update() end
end

-- The options pass waits out a fight: the switch and the glow's pick answer at once.
local GLOW_KEYS = { druidManaGlowAround = true, druidManaGlowBehind = true, druidManaGlowOver = true }
ns.OnToggle(function(key)
    if key == "druidMana" then ns.DruidManaSync() end
    if GLOW_KEYS[key] then UF.PlayerGlowRoute() end
end)
