local _, ns = ...

-- Custom theme (bronze or dark; "bronze" in names means the theme on). On: our silver art takes the theme's tint or
-- copies, and the client bronze we hide or drain is left as drawn (bronze) or darkened (dark); off (default) is the old
-- silver. Painted pieces are kept in weak tables so a toggle repaints what is on screen.

local B = ns.bronze
local SetWithFallback, BronzeCopy, THEMES, ThemeName = B.SetWithFallback, ns.BronzeCopy, B.THEMES, ns.ThemeName

-- The theme on, or nil.
local function Theme()
    local name = ThemeName()
    return name and THEMES[name]
end

local weak = { __mode = "k" }
local ONE = { 1, 1, 1 }
local tinted = setmetatable({}, weak)    -- texture -> share, or true for full
local silvered = setmetatable({}, weak)  -- tinted gold art, drained grey when off
local kept = setmetatable({}, weak)      -- client bronze shown only with the theme
local drained = setmetatable({}, weak)   -- client bronze drained when off -> {r,g,b} or false
local bordered = setmetatable({}, weak)  -- backdrop -> base colour and backdrop pair
local swapped = setmetatable({}, weak)   -- texture -> TEX key, or a file path (it holds a separator)
local swapArgs = setmetatable({}, weak)  -- file-swapped texture -> its extra SetTexture args, when it had any
B.tinted, B.silvered, B.swapped, B.swapArgs = tinted, silvered, swapped, swapArgs

function ns.BronzeOn()
    return ThemeName() ~= nil
end

-- A subtree none of whose art the theme copies or tints: the talent tree's nodes and edges, hundreds of frames.
-- The walks over the game's windows leave it out.
function B.PlainTree(frame)
    local spells = _G.PlayerSpellsFrame
    local talents = spells and spells.TalentsFrame
    return talents ~= nil and frame == talents.ButtonsParent
end

-- The theme rule in one place. Off: "classic" (1.x art). On: "themed" (1.x shapes in the theme's copies or tints),
-- or "client" for pieces a theme shows in Forever's own art (bronze: tooltips, menus).
function ns.ThemeLook(clientArt)
    local theme = Theme()
    if not theme then return "classic" end
    return (clientArt and theme.client) and "client" or "themed"
end

-- Pull latch in a module's own pass: true once per theme change; state.on is the theme name last painted (false: off),
-- state.was the one before.
function ns.ThemeTurned(state)
    local on = ThemeName() or false
    if state.on == on then return false end
    state.was, state.on = state.on, on
    return true
end

-- Softer share for the slots and the band; full bronze read too strong.
ns.BRONZE_SOFT = 0.9
-- Drained and tinted to the theme (share: of its colour, or by theme name; shade: times this), or as drawn without
-- one (silver: drained grey).
local function Paint(texture, theme, share, silver)
    if theme then
        local tint = theme.tint
        local shade = 1
        if type(share) == "table" then shade, share = share.shade or 1, share[ThemeName()] end
        share = type(share) == "number" and share or 1
        texture:SetDesaturated(true)
        local max = math.max
        local r, g, b = max(0, 1 + (tint[1] - 1) * share) * shade, max(0, 1 + (tint[2] - 1) * share) * shade,
            max(0, 1 + (tint[3] - 1) * share) * shade
        texture:SetVertexColor(r, g, b)
        ns.PaintFlat(texture, r, g, b)
    else
        -- share.off: the shade it keeps with no theme (a grey icon).
        local off = type(share) == "table" and share.off or 1
        texture:SetDesaturated(silver == true)
        texture:SetVertexColor(off, off, off)
        ns.PaintFlat(texture)
    end
end

local function PaintTint(texture)
    if texture.SetDesaturated then Paint(texture, Theme(), tinted[texture], silvered[texture]) end
end

-- The game's own art where our piece is off (Art/GameArt.lua): as drawn with no theme or one showing client art,
-- else tinted like our metal. Art another paint holds is left to it.
local gameArt = setmetatable({}, weak)   -- texture -> share, or true for full
local function OnCopy(texture)
    return tinted[texture] or drained[texture] ~= nil or swapped[texture] or (B.clientWas and B.clientWas[texture])
end
local function PaintGame(texture)
    if OnCopy(texture) then return end
    local theme = Theme()
    Paint(texture, not (theme and theme.client) and theme or nil, gameArt[texture])
end

function ns.TintGameArt(texture, share)
    if not (texture and texture.SetDesaturated and texture.SetVertexColor) then return end
    gameArt[texture] = share or true
    PaintGame(texture)
end

function ns.UntintGameArt(texture)
    if not texture or gameArt[texture] == nil then return end
    gameArt[texture] = nil
    ns.PaintFlat(texture)
    if OnCopy(texture) then return end
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1)
end

function ns.GameArtTinted(texture) return gameArt[texture] ~= nil end

-- silver: the art is gold, drained grey when the theme is off.
function ns.BronzeTint(texture, share, silver)
    if not texture then return end
    tinted[texture] = share or true
    silvered[texture] = silver and true or nil
    PaintTint(texture)
end

-- Out of the repaint, back to as drawn.
function ns.UntintBronze(texture)
    if not texture then return end
    tinted[texture] = nil
    silvered[texture] = nil
    ns.PaintFlat(texture)
    if not texture.SetDesaturated then return end
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1)
end

-- Client bronze hidden for the old look, shown only with the theme.
local function PaintKeep(region)
    region:SetAlpha(ns.BronzeOn() and 1 or 0)
end

function ns.BronzeKeep(region)
    if not region or not region.SetAlpha then return end
    kept[region] = true
    PaintKeep(region)
end

-- The thin theme rim over an icon's grey bevel, theme only, as dark as the window metal (its white art at full
-- colour read tan beside it). outset puts it just past the quality border so both show.
local RIM_SHADE = { shade = 0.55 }
function ns.BronzeRim(button, icon, outset, share)
    if not button then return end
    outset = outset or 0
    icon = icon or button.icon or button.Icon
        or (button.GetName and button:GetName() and _G[button:GetName() .. "IconTexture"])
    if not icon then return end
    local rim = button.fcuiBronzeRim
    if not rim then
        rim = button:CreateTexture(nil, "ARTWORK", nil, 7)
        rim:SetTexture(ns.TexPath("iconFrame"))
        button.fcuiBronzeRim = rim
    end
    rim:ClearAllPoints()
    rim:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
    rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
    ns.BronzeTint(rim, share or RIM_SHADE)
    ns.BronzeKeep(rim)
end

-- The backdrop with its edge file swapped for the theme's copy, made once per frame and theme.
local function ThemedInfo(info, name)
    local themed = info[name]
    if themed then return themed end
    themed = {}
    for k, v in pairs(info.plain) do themed[k] = v end
    themed.edgeFile = BronzeCopy(info.plain.edgeFile)
    info[name] = themed
    return themed
end

-- Border tinted to the theme; a window that greys its own border passes that grey to keep the depth.
-- Edge sheets with a theme copy (dialog border, slider track) swap instead, keeping the fill colour.
function ns.BronzeBackdrop(frame, r, g, b, a)
    if not frame or not frame.SetBackdropBorderColor then return end
    local base = bordered[frame]
    if r or type(base) ~= "table" then
        base = { r or 1, g or r or 1, b or r or 1, a or 1, info = type(base) == "table" and base.info or nil }
    end
    local plain = frame.backdropInfo
    if not base.info and plain and plain.edgeFile and BronzeCopy(plain.edgeFile) then base.info = { plain = plain } end
    bordered[frame] = base
    local name = ThemeName()
    if base.info and frame.SetBackdrop then
        local want = name and ThemedInfo(base.info, name) or base.info.plain
        if frame.backdropInfo ~= want then
            local fr, fg, fb, fa = frame:GetBackdropColor()
            frame:SetBackdrop(want)
            if fr then frame:SetBackdropColor(fr, fg, fb, fa) end
        end
        local tint = name and THEMES[name].colorCopies and THEMES[name].tint or ONE
        frame:SetBackdropBorderColor(tint[1] * base[1], tint[2] * base[2], tint[3] * base[3], base[4])
    elseif name then
        local tint = THEMES[name].tint
        frame:SetBackdropBorderColor(tint[1] * base[1], tint[2] * base[2], tint[3] * base[3], base[4])
    else
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    end
end

-- Client trim bronze where 1.x was silver (input boxes, macro text, slider arrows, guild detail border): drained to
-- the old metal (tint: its grey) when off, as drawn with a theme showing client art, drained and tinted with another.
local SILVER = { 1, 1, 1, plain = true }
local function PaintDrain(region, tint)
    if tint == SILVER then
        region:SetDesaturated(true)
        if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
        return
    end
    local theme = Theme()
    if theme and theme.client then
        region:SetDesaturated(false)
        if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
        ns.PaintFlat(region)
        return
    end
    region:SetDesaturated(true)
    if not region.SetVertexColor then return end
    local r, g, b = 1, 1, 1
    if tint then r, g, b = tint[1], tint[2], tint[3] end
    if theme then
        local t = theme.tint
        r, g, b = r * t[1], g * t[2], b * t[3]
        ns.PaintFlat(region, r, g, b)
    else
        ns.PaintFlat(region)
    end
    region:SetVertexColor(r, g, b)
end

-- Drained grey under every theme (sliders: tinted, they vanished at full darkness and recoloured under the hand).
function ns.DrainSilver(region)
    if not region or not region.SetDesaturated then return end
    drained[region] = SILVER
    PaintDrain(region, SILVER)
end

function ns.DrainBronze(region, r, g, b)
    if not region or not region.SetDesaturated then return end
    local tint = r and { r, g or r, b or r } or false
    drained[region] = tint
    PaintDrain(region, tint)
end

-- Back to as drawn, out of the repaint.
function ns.UndrainBronze(region)
    if not region or not region.SetDesaturated then return end
    drained[region] = nil
    ns.PaintFlat(region)
    region:SetDesaturated(false)
    if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
end

-- Drained once; drained again when the client resets its desaturation (an unreadable state counts as right).
function ns.KeepDrained(region, r, g, b)
    if not region or not region.SetDesaturated then return end
    local grey = ns.ThemeLook(true) ~= "client"
    if drained[region] == nil or (region.IsDesaturated and ns.Safe(region:IsDesaturated(), grey) ~= grey) then
        ns.DrainBronze(region, r, g, b)
    end
end

-- Input box trim: the client's bronze edges drained to the old lighter silver.
ns.INPUT_GREY = 0.85
function ns.DrainInput(box, drain)
    ns.EachKey(box, ns.KEYS.LMR, drain or ns.DrainBronze, ns.INPUT_GREY)
end

local function SliceDrain(region, center, grey, drain)
    if region ~= center then drain(region, grey) end
end

local function SliceTint(region, center)
    if region ~= center and region.IsObjectType and region:IsObjectType("Texture") then ns.BronzeTint(region) end
end

-- NineSlice edges; the Center stays as drawn.
function ns.DrainSlice(slice, grey, drain)
    if slice then ns.EachRegion(slice, SliceDrain, slice.Center, grey, drain or ns.DrainBronze) end
end

function ns.TintSlice(slice)
    if slice then ns.EachRegion(slice, SliceTint, slice.Center) end
end

-- The tinted, game and drained pieces with their flat layers: textures only, so a flat row answers in a fight.
function ns.RepaintTints()
    for texture in pairs(tinted) do PaintTint(texture) end
    for texture in pairs(gameArt) do PaintGame(texture) end
    for region, tint in pairs(drained) do
        if region.SetDesaturated then PaintDrain(region, tint or nil) end
    end
end

-- The theme's colour moved (a slider or picker drag): tints and borders only, no file swaps.
function ns.RepaintColours()
    ns.RepaintTints()
    for frame in pairs(bordered) do ns.BronzeBackdrop(frame) end
end

-- Repaint every remembered piece for the current theme.
function ns.RepaintBronze()
    ns.RepaintTints()
    for region in pairs(kept) do PaintKeep(region) end
    for frame in pairs(bordered) do ns.BronzeBackdrop(frame) end
    for texture, what in pairs(swapped) do
        if what:find("[\\/]") then
            local args = swapArgs[texture]
            local want = ns.BronzeOn() and ns.BronzeCopy(what) or what
            if args then SetWithFallback(texture, want, what, unpack(args)) else SetWithFallback(texture, want, what) end
            local copy = want ~= what and want or nil
            if args then ns.PaintCopy(texture, copy, unpack(args)) else ns.PaintCopy(texture, copy) end
        else
            local primary, fallback = ns.TexPath(what)
            SetWithFallback(texture, primary, fallback)
            ns.PaintCopy(texture, ns.BronzeOn() and select(3, ns.TexPaths(what)) and primary or nil)
        end
    end
end

-- First module, so the repaint runs before every other apply.
ns.RegisterModule("bronzeTheme", { apply = function() ns.RepaintBronze() end, restore = function() ns.RepaintBronze() end })
