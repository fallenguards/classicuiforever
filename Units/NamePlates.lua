local _, ns = ...

-- 1.x plate: 128x16 border with the level in its right slot, 103.75x10 health bar, name above, cast bar below.
-- We re-lay the client plate's pieces and fade its retail art; forbidden plates (instances) are left alone.

local Dress, DressNew, FadeKeys, IsSecret = ns.Dress, ns.DressNew, ns.FadeKeys, ns.IsSecret

local BORDER_W, BORDER_H = 128, 16
-- Era's classic plate: the bar 3.5 and 20.75 in from the border's ends, 0.5 above its 3-each centring.
local INSET_L, INSET_R, INSET_T, INSET_B = 3.5, 20.75, 2.5, 3.5
local BAR_W, BAR_H = BORDER_W - INSET_L - INSET_R, BORDER_H - INSET_T - INSET_B
local BORDER_GAP = 2       -- health border to cast border
local NAME_GAP = 2         -- name bottom above the border top
local AURA_GAP = 4         -- debuff row above the name
-- Level slot spans 109-124 of the sheet's 128: centre 11.5 from the right.
local LEVEL_X = -11.5
local ICON_SIZE = 14
-- Cast border has no level slot: the left half twice, the second mirrored; the bar runs into the slot's width.
local CAST_EXTRA = INSET_R - INSET_L
-- Era's classic cast bar (Blizzard_NamePlateCastingBar, classic style): its own border under the health border, the
-- icon's slot at its left (the icon 11.5 in), the bar 20.75 in from the left and 3.5 from the right, a half-black
-- backing, the old spark; 4 between the health and cast boxes. Cast bar: icon beside it gives ours before back.
local ERA_CAST_GAP, ERA_ICON_X = 4, 11.5
-- The game's "cast at you" highlight, hugging Era's bar: 1.5 out at the sides, 1 above, 2.25 below (the modern look's 4).
local AIM_X, AIM_TOP, AIM_BOTTOM, CLIENT_AIM = 1.5, 1, 2.25, 4
local CAST_SPARK, CAST_SPARK_SIZE = "Interface\\CastingBar\\UI-CastingBar-Spark", 32
-- Era's shield on a cast that cannot be interrupted: the old small shield around the bar, the icon kept.
local SHIELD_L, SHIELD_T, SHIELD_R, SHIELD_B = 20, 11, 13, 13
-- Era brightens the fill of the target's plate and the moused-over one: the fill's own file added at a quarter.
local GLOW = { own = "glow", layer = "OVERLAY", sublevel = 0, blend = "ADD", alpha = 0.25, fill = true }
-- Under the icon and text (OVERLAY 1) as Era's (OVERLAY -1): its icon slot is filled art.
local CAST_BORDER = { own = "castBorder", layer = "OVERLAY", sublevel = -1, coords = { 0, 1, 0.5, 1 }, point = "TOPLEFT",
    x = -INSET_R, y = INSET_T, point2 = "BOTTOMRIGHT", x2 = INSET_L, y2 = -INSET_B, show = true }

local FULL = { 0, 1, 0, 1 }
local BORDER = { own = "border", layer = "OVERLAY", sublevel = 2, coords = { 0, 1, 0.5, 1 }, point = "TOPLEFT", x = -INSET_L, y = INSET_T,
    point2 = "BOTTOMRIGHT", x2 = INSET_R, y2 = -INSET_B, show = true }
local BORDER_L = { own = "borderL", layer = "OVERLAY", sublevel = 2, w = BORDER_W / 2, h = BORDER_H, coords = { 0, 0.5, 0.5, 1 },
    point = "TOPLEFT", x = -INSET_L, y = INSET_T, show = true }
local BORDER_R = { own = "borderR", layer = "OVERLAY", sublevel = 2, w = BORDER_W / 2, h = BORDER_H, coords = { 0.5, 0, 0.5, 1 },
    point = "TOPRIGHT", x = INSET_L, y = INSET_T, show = true }
local BAR_FILL = { coords = FULL }
local HEALTH_ART = { "bgTexture", "selectedBorder", "deselectedOverlay" }
-- The game's health numbers, shown by its Nameplate Information setting: over our border.
local HEALTH_TEXTS = { "Text", "LeftText", "RightText" }
-- The client's classic-style glow too: ours shows in every style, theirs would add to it.
local BADGES = { "LevelFrame", "PlayerLevelDiffFrame", "ClassificationFrame", "selectionHighlight" }
local CAST_ART = { "Background", "Border" }
local PLATE_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_LEVEL", "PLAYER_TARGET_CHANGED", "UNIT_FACTION", "UNIT_FLAGS",
    "PLAYER_FOCUS_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "CVAR_UPDATE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UPDATE_MOUSEOVER_UNIT" }
local CAST_EVENTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true }

-- The game's nameplate Size (Small..Huge) one classic-style step up: Forever's default (Small) draws Era's (Medium).
local SIZE_CVAR = "nameplateSize"
local SIZE_SCALES = { 1.0, 1.25, 1.4, 1.6, 1.8 }
-- Read at most once a second (every plate asks on every re-lay); CVAR_UPDATE clears it.
local plateScale, plateScaleAt = nil, 0
local function PlateScale()
    local now = GetTime()
    if plateScale and now - plateScaleAt < 1 then return plateScale end
    local value = tonumber(ns.GetCVar(SIZE_CVAR))
    plateScale, plateScaleAt = SIZE_SCALES[value or 1] or 1, now
    return plateScale
end

-- Shared with NamePlateOptions.lua; active is written only by SetActive.
local NP = { active = false }
ns.NP = NP

local skinned = setmetatable({}, { __mode = "k" })

local Forbidden = ns.IsForbidden

-- The settings sample plate's "preview" token makes the lookup error: that is no plate.
local function PlateFor(unitToken)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    return ok and plate and plate.UnitFrame or nil
end

-- Border sheet around a bar, above its fill.
local function Border(bar)
    return (DressNew(bar, "nameplateBorder", BORDER))
end

local function CastBorder(bar)
    local own = bar.fcui
    if own and own.border then own.border:Hide() end
    if own and own.castBorder then own.castBorder:Hide() end
    local left = DressNew(bar, "nameplateBorder", BORDER_L)
    DressNew(bar, "nameplateBorder", BORDER_R)
    return left
end

local function EraCastBorder(bar)
    local own = bar.fcui
    for _, key in ipairs({ "border", "borderL", "borderR" }) do
        if own and own[key] then own[key]:Hide() end
    end
    return DressNew(bar, "nameplateCastBorder", CAST_BORDER)
end

local function OldCast() return ns.db.plateCastBeside == true end

-- The client's spark (its pip) to the old spark and back; what it had kept to give back.
local sparkWas = setmetatable({}, { __mode = "k" })
local function OldSpark(cast, on)
    local spark = cast.Spark
    if not spark then return end
    if on then
        if not sparkWas[spark] then sparkWas[spark] = { spark:GetAtlas(), spark:GetWidth(), spark:GetHeight() } end
        spark:SetTexture(CAST_SPARK)
        spark:SetSize(CAST_SPARK_SIZE, CAST_SPARK_SIZE)
    elseif sparkWas[spark] then
        local was = sparkWas[spark]
        sparkWas[spark] = nil
        if was[1] and not IsSecret(was[1]) then spark:SetAtlas(was[1]) end
        spark:SetSize(was[2], was[3])
    end
end

-- The client's shield (a badge in the icon's place) to Era's around the bar and back. A plate's shield cannot be
-- measured (restricted region): set blind, given back as the client's own setup lays it.
local CLIENT_SHIELD, CLIENT_SHIELD_W, CLIENT_SHIELD_H = "nameplates-InterruptShield", 10, 12
local shieldTaken = setmetatable({}, { __mode = "k" })
local function EraShield(cast, on)
    local shield = cast.BorderShield
    if not shield then return end
    if on then
        shieldTaken[shield] = true
        Dress(shield, "castSmallShield", BAR_FILL)
        shield:SetSize(0, 0)
        shield:ClearAllPoints()
        shield:SetPoint("TOPLEFT", cast, "TOPLEFT", -SHIELD_L, SHIELD_T)
        shield:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", SHIELD_R, -SHIELD_B)
    elseif shieldTaken[shield] then
        shieldTaken[shield] = nil
        ns.UntintBronze(shield)
        ns.UnswapBronze(shield)
        shield:SetAtlas(CLIENT_SHIELD)
        local setup = _G.NamePlateSetupOptions
        shield:SetSize(setup and setup.castBarShieldWidth or CLIENT_SHIELD_W,
            setup and setup.castBarShieldHeight or CLIENT_SHIELD_H)
        shield:ClearAllPoints()
        if cast.Icon then shield:SetPoint("RIGHT", cast.Icon, "RIGHT", 0, 0) end
    end
end

-- Era's glow on the target's plate and the moused-over one, looked up afresh for each pass.
local glowTarget, glowOver
local function GlowPlate(unitFrame)
    local glow = ns.Path(unitFrame, "HealthBarsContainer", "healthBar", "fcui", "glow")
    if glow then glow:SetShown(unitFrame == glowTarget or unitFrame == glowOver) end
end

local function LookGlows()
    glowTarget, glowOver = PlateFor("target"), PlateFor("mouseover")
end

local function Glow(unitFrame, health)
    local fill = health.barTexture or health:GetStatusBarTexture()
    if not fill then return end
    DressNew(health, "barFill", GLOW, fill):SetIgnoreParentAlpha(true)
    LookGlows()
    GlowPlate(unitFrame)
end

local function ShadedFill(bar)
    local tex = bar.barTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
    if not tex then return end
    tex:SetAtlas(nil)
    Dress(tex, "barFill", BAR_FILL)
end

local function UpdateLevel(unitFrame)
    local own = unitFrame.fcui
    local level, skull = own and own.level, own and own.skull
    if not level or not unitFrame.unit then return end
    -- The effective level, as the client's target frame reads it: -1 (a skull) from ten levels up, where UnitLevel still
    -- tells the number.
    local lvl = (UnitEffectiveLevel or UnitLevel)(unitFrame.unit)
    if lvl == nil or IsSecret(lvl) then
        level:SetText("")
        skull:Hide()
        return
    end
    if ns.SkullLevel(lvl, unitFrame.unit) then
        level:SetText("")
        skull:Show()
        return
    end
    skull:Hide()
    level:SetText(lvl)
    -- Target frame colour by unit (by level this client says yellow where the frame shows green); gold if not attackable.
    local color
    local foe = UnitCanAttack("player", unitFrame.unit)
    if IsSecret(foe) then foe = false end
    if foe then
        local rate = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer
        if rate and GetDifficultyColor then
            local ok, difficulty = pcall(rate, unitFrame.unit)
            if ok and difficulty then color = GetDifficultyColor(difficulty) end
        end
        if not color and GetCreatureDifficultyColor then color = GetCreatureDifficultyColor(lvl) end
        color = ns.EraLevelColor(color)
    end
    if color then level:SetTextColor(color.r, color.g, color.b) else level:SetTextColor(1, 0.82, 0) end
end

-- Elite dragons (an option, as Mists of Pandaria drew them): gold round an elite's level, silver round a rare's, under
-- the border. The 64x32 art (drawn 37x27 from its top left) hugs the level box's right end; its top left from the level's centre.
local DRAGON_X = -12.5
local DRAGON_Y = 12
local DRAGON_WIDTH = 57.5
local DRAGON_HEIGHT = 29
local DRAGON = { own = "dragon", layer = "OVERLAY", sublevel = 1, w = DRAGON_WIDTH, h = DRAGON_HEIGHT, coords = FULL,
    point = "TOPLEFT", relPoint = "RIGHT", x = LEVEL_X + DRAGON_X, y = DRAGON_Y }
local DRAGON_KEY = { elite = "plateElite", worldboss = "plateElite", rare = "plateRare", rareelite = "plateRare" }

local function UpdateDragon(unitFrame, health)
    local own = health.fcui
    local border = own and own.border
    if not border then return end
    local kind = ns.db and ns.db.plateDragons == true and unitFrame.unit and UnitClassification(unitFrame.unit)
    if IsSecret(kind) then kind = nil end
    local key = kind and DRAGON_KEY[kind]
    if key then DressNew(health, key, DRAGON, border) end
    if own.dragon then ns.SetShownIf(own.dragon, key ~= nil) end
end

-- Crowd control icons: the client puts them 5 past the bar, on our level slot. Past the level (and a dragon's tip) or
-- in the debuff row. Gaps in plate units: the border art ends 2 in from its edge.
local CC_FRAMES = { "CrowdControlListFrame", "LossOfControlFrame" }
local CC_GAP, CLIENT_CC_GAP = 2, 5
local DRAGON_TIP = LEVEL_X + DRAGON_X + DRAGON_WIDTH * 37 / 64

local function PlaceCrowdControl(unitFrame)
    local auras = unitFrame.AurasFrame
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    local own = health and health.fcui
    local border = own and own.border
    if not auras or not border then return end
    local scale = PlateScale()
    for _, key in ipairs(CC_FRAMES) do
        local icons = auras[key]
        if icons and ns.db.plateCCAbove == true and auras.DebuffListFrame then
            ns.SetPointIf(icons, "BOTTOMLEFT", auras.DebuffListFrame, "BOTTOMRIGHT", CC_GAP, 0)
        elseif icons then
            local tip = own.dragon and own.dragon:IsShown() and DRAGON_TIP or 0
            ns.SetPointIf(icons, "LEFT", border, "RIGHT", (tip + CC_GAP) * scale, 0)
        end
    end
end

-- The client's own spot back, as its next anchor pass lays it.
local function UnplaceCrowdControl(unitFrame)
    local auras, container = unitFrame.AurasFrame, unitFrame.HealthBarsContainer
    if not auras or not container then return end
    for _, key in ipairs(CC_FRAMES) do
        if auras[key] then ns.SetPointIf(auras[key], "LEFT", container, "RIGHT", CLIENT_CC_GAP, 0) end
    end
end

-- The client's bottom-up chain at 1.x sizes, bars scaled by Size; name and auras keep the client's sizing.
local function LayChain(unitFrame, castContainer, container, health)
    local scale = PlateScale()
    ns.SetScaleIf(castContainer, scale)
    ns.SetScaleIf(container, scale)
    ns.SetSizeIf(castContainer, BAR_W, BAR_H)
    ns.SetPointIf(castContainer, "BOTTOM", unitFrame, "BOTTOM", 0, INSET_B)
    ns.SetSizeIf(container, BAR_W, BAR_H)
    ns.SetPointIf(container, "BOTTOM", castContainer, "TOP", 0,
        OldCast() and INSET_T + BORDER_GAP + INSET_B or ERA_CAST_GAP)
    ns.SetTwoPointsIf(health, "TOPLEFT", container, "TOPLEFT", 0, 0, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
end

-- Plate -> its cast was interrupted, till the next one starts (from our event watch: plates are never hooked).
local castCut = setmetatable({}, { __mode = "k" })

-- Cast bar: same fill and border, icon to the left, text inside.
local function LayCast(castContainer, unitFrame)
    local cast = castContainer.castBar
    if not cast then return end
    local old = OldCast()
    ns.SetTwoPointsIf(cast, "TOPLEFT", castContainer, "TOPLEFT", old and 0 or CAST_EXTRA, 0, "BOTTOMRIGHT", castContainer,
        "BOTTOMRIGHT", CAST_EXTRA, 0)
    ShadedFill(cast)
    -- 1.x yellow cast, green channel, red and full once interrupted (on our own 0 to 1: its range is secret).
    if castCut[unitFrame] then
        ns.SetBarColorIf(cast, 1, 0, 0)
        cast:SetMinMaxValues(0, 1)
        cast:SetValue(1)
        if cast.Text and not ns.db.castBarInterrupter then cast.Text:SetText(INTERRUPTED) end
    elseif cast.channeling then
        ns.SetBarColorIf(cast, 0, 1, 0)
    else
        ns.SetBarColorIf(cast, 1, 0.7, 0)
    end
    local castBorder = old and CastBorder(cast) or EraCastBorder(cast)
    FadeKeys(cast, CAST_ART)
    local back = ns.OwnTexture(cast, "castBack", "BACKGROUND", -1)
    back:SetColorTexture(0, 0, 0, 0.5)
    back:SetAllPoints(cast)
    back:SetShown(not old)
    OldSpark(cast, not old)
    EraShield(cast, not old)
    local aim = cast.CastTargetIndicator
    if aim then
        local x, top, bottom = old and CLIENT_AIM or AIM_X, old and CLIENT_AIM or AIM_TOP, old and CLIENT_AIM or AIM_BOTTOM
        ns.SetTwoPointsIf(aim, "TOPLEFT", cast, "TOPLEFT", -x, top, "BOTTOMRIGHT", cast, "BOTTOMRIGHT", x, -bottom)
    end
    if cast.Icon then
        ns.SetSizeIf(cast.Icon, ICON_SIZE, ICON_SIZE)
        if old then
            ns.SetPointIf(cast.Icon, "RIGHT", castBorder, "LEFT", -1, 0)
        else
            ns.SetPointIf(cast.Icon, "CENTER", castBorder, "LEFT", ERA_ICON_X, 0)
            -- Era keeps the icon on a cast that cannot be interrupted; the client's own style hides it.
            if cast.showIcon ~= false and (cast.casting or cast.channeling) then cast.Icon:Show() end
        end
    end
    if cast.Text then
        ns.SetPointIf(cast.Text, "CENTER", cast, "CENTER", 0, 0)
        cast.Text:SetJustifyH("CENTER")
    end
    if cast.CastTargetNameText then ns.SetAlphaIf(cast.CastTargetNameText, 0) end
end

-- Plate pieces, nil for a plate we leave alone.
local function Pieces(unitFrame)
    if not NP.active or Forbidden(unitFrame) then return nil end
    local container = unitFrame.HealthBarsContainer
    local health = container and container.healthBar
    local castContainer = unitFrame.CastBarsContainer
    if not health or not castContainer then return nil end
    return container, health, castContainer
end

-- A cast starting or ending moves only the chain and the cast bar.
local function CastLayout(unitFrame)
    local container, health, castContainer = Pieces(unitFrame)
    if not container then return end
    LayChain(unitFrame, castContainer, container, health)
    LayCast(castContainer, unitFrame)
end

ns.PLATE_NAME_MIN, ns.PLATE_NAME_MAX = -6, 6

-- Era's plate name: Friz 10 at the plate's size, no outline, no shadow (Forever's is 17.5, outlined and shadowed).
-- Era draws it from SystemFont_NamePlate's own 9, stretched to that height: about 2% wider and softer than a true 10.
local ERA_NAME_SIZE, ERA_NAME_FONT = 10, 9

-- The size the client shows (Classic fonts: Era's at the plate's size) plus the player's offset in points. The client's
-- size is read off the name itself (it scales plate fonts on its own): any other than the one we last set is its new one.
local function NameSize(name, own)
    local file, size, flags = name:GetFont()
    if not size or ns.IsSecret(size) or ns.IsSecret(flags) then return end
    if not own.nameSet or math.abs(own.nameSet - size) > 0.05 then own.nameBase = size end
    local classic = ns.ClassicFonts()
    local base = classic and ERA_NAME_SIZE * PlateScale() or own.nameBase
    local want = math.max(6, base + (tonumber(ns.db.plateNameSize) or 0))
    local wantFlags = classic and (flags or ""):gsub("THICKOUTLINE", ""):gsub("OUTLINE", ""):gsub("^[,%s]+", "")
        :gsub("[,%s]+$", ""):gsub(",%s*,", ",") or flags
    -- The drawn base first, then the height: a later SetFont does not undo a stretch (the client reads back the height).
    local drawn = classic and ERA_NAME_FONT or want
    if math.abs(size - want) > 0.05 or flags ~= wantFlags or own.nameFont ~= drawn then
        -- The plate's own font for its other alphabets: a Cyrillic name keeps its letters (#188).
        local family = ns.FontFamily(_G.SystemFont_NamePlate or GameFontNormal, drawn, wantFlags, file)
        if family then ns.SetFontFamily(name, family) else name:SetFont(file, drawn, wantFlags) end
        name:SetTextHeight(want)
        own.nameFont = drawn
    end
    own.nameSet = want
end

-- Plate text shadows: none in Era's look, a 1 px drop shadow otherwise.
local function TextShadow(text)
    local off = ns.ClassicFonts() and 0 or 1
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(off, -off)
end

-- Runs after the client has anchored the unit frame.
local function Layout(unitFrame)
    local container, health, castContainer = Pieces(unitFrame)
    if not container then return end
    unitFrame.fcui = unitFrame.fcui or {}
    local own = unitFrame.fcui

    LayChain(unitFrame, castContainer, container, health)

    ShadedFill(health)
    Glow(unitFrame, health)
    NP.ClassColor(unitFrame)
    local border = Border(health)
    FadeKeys(health, HEALTH_ART)
    for _, key in ipairs(HEALTH_TEXTS) do
        local text = health[key]
        if text then text:SetDrawLayer("OVERLAY", 4) end
    end
    FadeKeys(unitFrame, BADGES)

    -- Level in the border slot, a skull when unknown.
    local level = own.level
    if not level then
        level = health:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlateLevel")
        level:SetDrawLayer("OVERLAY", 3)
        own.level = level
        local skull = health:CreateTexture(nil, "OVERLAY", nil, 3)
        skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        skull:SetSize(12, 12)
        skull:Hide()
        own.skull = skull
    end
    TextShadow(level)
    ns.SetPointIf(level, "CENTER", border, "RIGHT", LEVEL_X, 0)
    ns.SetPointIf(own.skull, "CENTER", border, "RIGHT", LEVEL_X, 0)
    UpdateLevel(unitFrame)
    UpdateDragon(unitFrame, health)

    -- Name centred above the border, sized to its text; debuffs above it.
    local name = unitFrame.name
    if name then
        ns.SetPointIf(name, "BOTTOM", border, "TOP", 0, NAME_GAP)
        name:SetWidth(0)
        name:SetJustifyH("CENTER")
        TextShadow(name)
        NameSize(name, own)
        local debuffs = ns.Path(unitFrame, "AurasFrame", "DebuffListFrame")
        if debuffs then
            ns.SetTwoPointsIf(debuffs, "LEFT", border, "LEFT", 0, 0, "BOTTOM", name, "TOP", 0, AURA_GAP)
        end
    end
    PlaceCrowdControl(unitFrame)

    LayCast(castContainer, unitFrame)
end

-- From our passes, never a client hook: a pass our code joins is refused unit health for the rest of it.
local function SkinPlate(unitFrame)
    if not NP.active or Forbidden(unitFrame) then return end
    skinned[unitFrame] = true
    Layout(unitFrame)
end

local function LivePlate(unit)
    local unitFrame = unit and PlateFor(unit)
    if unitFrame and not Forbidden(unitFrame) then return unitFrame end
end

-- Every plate on screen; forbidden ones only with withForbidden. Returns how many fn saw.
local function EachPlate(fn, withForbidden)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return 0 end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return 0 end
    local seen = 0
    for _, plate in ipairs(plates) do
        local unitFrame = plate and plate.UnitFrame
        if unitFrame and (withForbidden or not Forbidden(unitFrame)) then
            seen = seen + 1
            fn(unitFrame)
        end
    end
    return seen
end
NP.EachPlate = EachPlate

local function PlaceAllCrowdControl()
    EachPlate(function(unitFrame)
        if Pieces(unitFrame) then PlaceCrowdControl(unitFrame) end
    end)
end

local function PlateText(unitFrame)
    local own = unitFrame.fcui
    if not own then return end
    if unitFrame.name then
        TextShadow(unitFrame.name)
        NameSize(unitFrame.name, own)
    end
    if own.level then TextShadow(own.level) end
end

-- Name text size (options stepper); applies live.
function ns.SetPlateNameSize(offset)
    offset = math.max(ns.PLATE_NAME_MIN, math.min(ns.PLATE_NAME_MAX, math.floor(tonumber(offset) or 0)))
    ns.db.plateNameSize = offset
    if NP.active then EachPlate(PlateText) end
    return offset
end

-- Classic fonts answers on the plates at once, in a fight too.
ns.OnToggle(function(key)
    if key == "classicFonts" and NP.active then EachPlate(PlateText) end
end)

-- Plates re-lay after the client's handlers for what re-anchors them (added, faction, target, focus, casts, options, scale),
-- in this frame's pass and the next: a plate registers its events after ours. Only player plates change colour with no
-- event (a duel, a flag, a death): a 0.2 s sweep recolours while one shows.
local SWEEP = 0.2
local driver, sweepJob, overJob
-- Plates owed a re-lay in this frame's pass and in the next frame's; all = every plate.
local relaySoon = { plates = setmetatable({}, { __mode = "k" }) }
local relayNext = { plates = setmetatable({}, { __mode = "k" }) }

-- Sole writer of the sweep's awake state.
local function SetSweeping(on)
    if not sweepJob then return end
    if on then sweepJob:Wake() else sweepJob:Sleep() end
end

-- The client says when the mouse finds a unit, never when it leaves one: while a plate glows for it, look again.
local function OverGlow()
    LookGlows()
    EachPlate(GlowPlate)
    if not overJob then return end
    if glowOver then overJob:Wake() else overJob:Sleep() end
end
local function OverLeft()
    if PlateFor("mouseover") ~= glowOver then OverGlow() end
end

-- Sole writer of NP.active.
local function SetActive(on)
    NP.active = on
    SetSweeping(on)
    if overJob and not on then overJob:Sleep() end
end

local function Relay(owed)
    local plates = owed.plates
    if owed.all then
        owed.all = false
        wipe(plates)
        EachPlate(SkinPlate)
        return
    end
    for unitFrame, kind in pairs(plates) do
        plates[unitFrame] = nil
        -- A plate never fully laid gets the whole pass.
        if kind == "cast" and skinned[unitFrame] then CastLayout(unitFrame) else SkinPlate(unitFrame) end
    end
end

local function RelaySoon() Relay(relaySoon) end
local function RelayNext() Relay(relayNext) end

-- kind: true for the whole plate, "cast" for the chain and cast bar; a whole pass owed stays whole.
local function Owe(owed, unitFrame, kind)
    if not unitFrame then
        owed.all = true
    elseif owed.plates[unitFrame] ~= true then
        owed.plates[unitFrame] = kind
    end
end

local function QueueRelay(unitFrame, kind)
    kind = kind or true
    Owe(relaySoon, unitFrame, kind)
    Owe(relayNext, unitFrame, kind)
    ns.Sched.Soon("namePlates.relay", RelaySoon)
    ns.Sched.NextFrame("namePlates.relay", RelayNext)
end

-- A secret answer counts as a player: the sweep then finds out.
local function MaybePlayer(unit)
    local isPlayer = UnitIsPlayer(unit)
    return IsSecret(isPlayer) or isPlayer
end

local swept
local function SweepPlate(unitFrame)
    local unit = unitFrame.unit or unitFrame.displayedUnit
    local isPlayer = unit and UnitIsPlayer(unit)
    local maybe = IsSecret(isPlayer) or isPlayer
    if maybe then swept = swept + 1 end
    -- Not a player: only a fill of ours it still wears needs the pass.
    if not maybe and not NP.Painted(unitFrame) then return end
    NP.ClassColor(unitFrame, isPlayer)
end

local function Sweep()
    if not NP.active then return end
    swept = 0
    EachPlate(SweepPlate)
    -- No player plate in view: sleep until one is added.
    if swept == 0 then SetSweeping(false) end
end

local ALL_EVENTS = { PLAYER_TARGET_CHANGED = true, PLAYER_FOCUS_CHANGED = true, DISPLAY_SIZE_CHANGED = true,
    UI_SCALE_CHANGED = true, CVAR_UPDATE = true }

local function OnEvent(_, event, unit, _, _, interruptedBy)
    if not NP.active then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if MaybePlayer(unit) then SetSweeping(true) end
        local unitFrame = PlateFor(unit)
        if unitFrame then QueueRelay(unitFrame) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- The plate is recycled for another unit.
        local unitFrame = LivePlate(unit)
        if unitFrame then
            castCut[unitFrame] = nil
            NP.Unpaint(ns.Path(unitFrame, "HealthBarsContainer", "healthBar"))
        end
    elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        local unitFrame = LivePlate(unit)
        if unitFrame then
            NP.ClassColor(unitFrame)
            if event == "UNIT_FACTION" then QueueRelay(unitFrame) end
        end
    elseif event == "UNIT_LEVEL" then
        local unitFrame = LivePlate(unit)
        if unitFrame then UpdateLevel(unitFrame) end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        OverGlow()
    elseif CAST_EVENTS[event] then
        -- Cast start or stop re-lays only that plate's chain and cast bar; a channel's stop names who interrupted it.
        local unitFrame = unit and PlateFor(unit)
        if unitFrame then
            if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
                castCut[unitFrame] = nil
            elseif event == "UNIT_SPELLCAST_INTERRUPTED" or (event == "UNIT_SPELLCAST_CHANNEL_STOP"
                and (ns.IsSecret(interruptedBy) or interruptedBy ~= nil)) then
                castCut[unitFrame] = true
            end
            QueueRelay(unitFrame, "cast")
        end
    elseif ALL_EVENTS[event] then
        if event == "CVAR_UPDATE" then
            -- unit holds the CVar's name; the client's plates and ours answer only to "nameplate" ones.
            if not unit:lower():find("nameplate", 1, true) then return end
            plateScale = nil
        end
        QueueRelay()
    end
end

local function Apply()
    SetActive(true)
    NP.RestoreStyleChoice()
    if not NamePlateDriverFrame then ns.MissingPiece("NamePlateDriverFrame") return end
    if not driver then
        driver = CreateFrame("Frame")
        ns.RegisterEvents(driver, PLATE_EVENTS)
        driver:SetScript("OnEvent", OnEvent)
        sweepJob = ns.Sched.Job({ name = "namePlates.sweep", every = SWEEP, fn = Sweep })
        overJob = ns.Sched.Job({ name = "namePlates.over", every = 0.1, awake = false, fn = OverLeft })
    end
    EachPlate(SkinPlate)
end

local function Restore()
    SetActive(false)
    NP.RestoreStyleChoice()
    for unitFrame in pairs(skinned) do
        if unitFrame.fcui then
            -- Regions only: the table also keeps the name's sizes.
            for _, region in pairs(unitFrame.fcui) do
                if type(region) == "table" and region.Hide then region:Hide() end
            end
        end
        UnplaceCrowdControl(unitFrame)
        if unitFrame.HealthBarsContainer then unitFrame.HealthBarsContainer:SetScale(1) end
        if unitFrame.CastBarsContainer then unitFrame.CastBarsContainer:SetScale(1) end
        local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
        local cast = ns.Path(unitFrame, "CastBarsContainer", "castBar")
        if cast then
            OldSpark(cast, false)
            EraShield(cast, false)
        end
        for _, bar in pairs({ health, cast }) do
            if bar.fcui then
                for _, tex in pairs(bar.fcui) do tex:Hide() end
            end
        end
        -- The client's fill back on its own draw step; ours re-pins if turned on again.
        local fill = health and health.fcui and health.fcui.fill
        local tex = fill and fill.fcuiPinnedTo
        if tex and fill.fcuiLayer then tex:SetDrawLayer(fill.fcuiLayer, fill.fcuiSub) end
        if fill then fill.fcuiPinnedTo = nil end
    end
    ns.needsReload = true
end

ns.RegisterModule("namePlates", { apply = Apply, restore = Restore })

-- Elite dragons, the cast bar's look and the crowd control spot turn at once, in a fight too.
local CC_KEYS = { plateCCBeside = true, plateCCAbove = true }
ns.OnToggle(function(key)
    if not NP.active then return end
    if key == "plateDragons" then
        EachPlate(function(unitFrame)
            local _, health = Pieces(unitFrame)
            if health then UpdateDragon(unitFrame, health) end
        end)
        PlaceAllCrowdControl()
    elseif key == "plateCastBeside" then
        EachPlate(CastLayout)
    elseif CC_KEYS[key] then
        PlaceAllCrowdControl()
    end
end)
