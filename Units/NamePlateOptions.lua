local _, ns = ...

-- Plate colours and options: class colours, full-size plates, the player's own plate style given back.

local NP = ns.NP
local Dress, IsSecret = ns.Dress, ns.IsSecret

local BAR_FILL = { coords = { 0, 1, 0, 1 } }
-- Game setting: class colours on enemy plates.
local ENEMY_CLASS_CVAR = "nameplateShowClassColor"
local STYLE_CVAR = "nameplateStyle"
local SIMPLIFIED_CVAR = "nameplateSimplifiedTypes"

-- Colour on our own fill pinned over the client's: its repaint can land after ours in the same frame. The client's
-- faded under it: a layer it set again tied with ours, and its own colour (retail's lilac friends) flashed through.
local pins = setmetatable({}, { __mode = "k" })   -- our fill -> { tex = the client's fill, layer, sub }
local function Paint(health, r, g, b)
    local tex = health.barTexture or (health.GetStatusBarTexture and health:GetStatusBarTexture())
    if not tex then return end
    local fill = ns.OwnTexture(health, "fill", "ARTWORK", 0)
    local pin = pins[fill]
    if not pin or pin.tex ~= tex then
        -- Ours takes the client fill's draw step and it drops one: one above would tie with the heal absorb. Saved for restore.
        if not pin then
            local layer, sub = tex:GetDrawLayer()
            if ns.AnySecret(layer, sub) then layer, sub = nil, nil end
            pin = { layer = layer or "ARTWORK", sub = sub or 0 }
            pins[fill] = pin
        end
        pin.tex = tex
        Dress(fill, "barFill", BAR_FILL)
        tex:SetDrawLayer(pin.layer, math.max(pin.sub - 1, -8))
        fill:SetDrawLayer(pin.layer, pin.sub)
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, 0)
    end
    ns.SetVertexColorIf(fill, r, g, b)
    ns.SetShownIf(fill, true)
    ns.SetAlphaIf(tex, 0)
end

-- Whether a plate wears our fill.
function NP.Painted(unitFrame)
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    local fill = health and health.fcui and health.fcui.fill
    return fill ~= nil and fill:IsShown()
end

-- Show the client's own fill again.
function NP.Unpaint(health)
    local fill = health and health.fcui and health.fcui.fill
    if not fill then return end
    fill:Hide()
    local pin = pins[fill]
    if pin and pin.tex then ns.SetAlphaIf(pin.tex, 1) end
end

-- The client's fill as it was, its draw step and its alpha; ours re-pins if turned on again.
function NP.UnpinFill(health)
    local fill = health and health.fcui and health.fcui.fill
    local pin = fill and pins[fill]
    if not (pin and pin.tex) then return end
    pin.tex:SetDrawLayer(pin.layer, pin.sub)
    ns.SetAlphaIf(pin.tex, 1)
    pin.tex = nil
end

-- Class colour, or nothing while the class is secret (dungeons).
local function ClassRGB(unit)
    local _, class = UnitClass(unit)
    if not class or IsSecret(class) then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
end

-- Our colour for a player plate, nothing to keep the client's, or KEEP while an answer is secret (the plate stays as it
-- was: dropping ours then flashed the client's colour). isPlayer: UnitIsPlayer's answer when already asked.
local KEEP = "keep"
local function WantedColor(unit, isPlayer)
    if not IsSecret(isPlayer) and isPlayer == nil then isPlayer = UnitIsPlayer and UnitIsPlayer(unit) end
    if IsSecret(isPlayer) then return KEEP end
    if not isPlayer then return end
    -- A corpse's fill may be hidden rather than shrunk; ours, pinned to it, would stick at its last width.
    local isDead = _G["UnitIsDead"]
    local dead = isDead and isDead(unit)
    if IsSecret(dead) then dead = false end
    if dead then return end
    if ns.db.classColorPlates then return ClassRGB(unit) end
    -- 1.x friendly players were plain blue (the client's pale blue looks lilac on the old fill); secret: client's colour.
    local friendly = UnitIsFriend and UnitIsFriend("player", unit)
    if IsSecret(friendly) then return KEEP end
    if not friendly then return end
    -- Attackable friend (duel): enemy colour, the class colour if the game's enemy class colours are on, else red.
    local foe = UnitCanAttack("player", unit)
    if IsSecret(foe) then foe = false end
    if foe then
        local r, g, b
        if ns.GetCVarBool(ENEMY_CLASS_CVAR) then
            r, g, b = ClassRGB(unit)
        end
        if r then return r, g, b end
        return 1, 0, 0
    end
    -- 1.x selection colour: blue, green when PvP flagged (like a flagged friendly guard).
    local flagged = UnitIsPVP and UnitIsPVP(unit)
    if IsSecret(flagged) then flagged = false end
    if flagged then return 0, 1, 0 end
    return 0, 0, 1
end

function NP.ClassColor(unitFrame, isPlayer)
    if not NP.active then return end
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    if not health then return end
    local unit = unitFrame.unit or (unitFrame.displayedUnit)
    local r, g, b
    if unit then r, g, b = WantedColor(unit, isPlayer) end
    if r == KEEP then return end
    if r then Paint(health, r, g, b) else NP.Unpaint(health) end
end

-- Builds that set the game's plate style kept the player's: it goes back as the session ends. The game's Classic style
-- does not fit the plates it locks (friends in dungeons). A CVar write runs its listeners as ours.
function ns.GiveBackPlateStyle()
    local db = ns.db
    if not db then return end
    local was = db.cvarWas and db.cvarWas[STYLE_CVAR]
    if was == nil then was = db.savedNamePlateStyle end
    db.savedNamePlateStyle = nil
    if db.cvarWas then db.cvarWas[STYLE_CVAR] = nil end
    if was ~= nil then ns.WriteCVar(STYLE_CVAR, tostring(was)) end
end

local function RestoreColor(unitFrame)
    if type(unitFrame.UpdateHealthColor) == "function" then pcall(unitFrame.UpdateHealthColor, unitFrame) end
end

-- Own toggle: on repaints the visible plates, off asks the client for its colours back; forbidden plates too.
local function ColorApply()
    NP.EachPlate(NP.ClassColor, true)
end

local function ColorRestore()
    NP.EachPlate(RestoreColor, true)
end

ns.RegisterModule("classColorPlates", { apply = ColorApply, restore = ColorRestore })

-- 1.x had no simplified plates (friendlies, minions, minor mobs small until targeted): off, value saved.
local function FullPlatesApply()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local current = ns.GetCVar(SIMPLIFIED_CVAR)
    -- Forever answers an empty string: only save and clear a real non-zero value.
    local value = tonumber(current)
    if not value or value == 0 then return end
    if ns.db.savedSimplifiedTypes == nil then ns.db.savedSimplifiedTypes = current end
    ns.SetCVar(SIMPLIFIED_CVAR, 0)
end

local function FullPlatesRestore()
    local saved = ns.db.savedSimplifiedTypes
    ns.db.savedSimplifiedTypes = nil
    if tonumber(saved) then ns.SetCVar(SIMPLIFIED_CVAR, saved) end
end

ns.RegisterModule("fullPlates", { apply = FullPlatesApply, restore = FullPlatesRestore })

-- Same size near and far: Era's plates kept one size; Forever's shrink with distance and grow when targeted. Game
-- settings, written only on the player's click (held in a fight); the values before come back when it goes off.
local SCALE_CVARS = { "nameplateMinScale", "nameplateSelectedScale" }
ns.OnToggle(function(key)
    if key ~= "platesOneSize" then return end
    local db = ns.db
    if db.platesOneSize then
        db.platesOneSizeWas = db.platesOneSizeWas or {}
        for _, cvar in ipairs(SCALE_CVARS) do
            if db.platesOneSizeWas[cvar] == nil then db.platesOneSizeWas[cvar] = ns.GetCVar(cvar) end
            ns.SetCVarOrHold(cvar, "1")
        end
    else
        local was = db.platesOneSizeWas or {}
        for _, cvar in ipairs(SCALE_CVARS) do ns.SetCVarOrHold(cvar, was[cvar] or ns.GetCVarDefault(cvar)) end
        db.platesOneSizeWas = nil
    end
end)
