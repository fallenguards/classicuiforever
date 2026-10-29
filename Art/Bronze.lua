local _, ns = ...

-- Custom theme (bronze or dark; "bronze" in names means the theme on). On: our silver art takes the theme's tint or
-- copies, and the client bronze we hide or drain is left as drawn (bronze) or darkened (dark); off (default) is the old
-- silver. Painted pieces are kept in weak tables so a toggle repaints what is on screen.

local B = ns.bronze
local SetWithFallback, BronzeCopy, THEMES, ThemeName = B.SetWithFallback, ns.BronzeCopy, B.THEMES, ns.ThemeName

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

-- Another addon's frame: its global name set outside the game's own code, and not ours.
function B.AddonFrame(frame)
    local name = frame.GetName and frame:GetName()
    if type(name) ~= "string" or ns.IsSecret(name) or issecurevariable(name) then return false end
    return not (name:find("^ForeverClassicUI") or name:find("^ClassicUIForever"))
end

-- A subtree none of whose art the theme copies or tints, left out of the walks over the game's windows: another
-- addon's frame unless Other addons is themed (EasyFind's never: its theme is its own), and the talent tree's nodes
-- and edges, hundreds of frames.
function B.PlainTree(frame)
    -- A forbidden frame may not even be asked its name.
    if ns.IsForbidden(frame) then return true end
    if B.AddonFrame(frame) and (not ns.ThemeAddonsOn() or frame:GetName():find("^EasyFind")) then return true end
    local spells = _G.PlayerSpellsFrame
    local talents = spells and spells.TalentsFrame
    return talents ~= nil and frame == talents.ButtonsParent
end

-- The theme rule in one place. Off: "classic" (1.x art). On: "themed" (1.x shapes in the theme's copies or tints),
-- or "client" for pieces a theme shows in Forever's own art (bronze: tooltips, menus). where: the piece or part asked
-- about (ns.ThemePartOn), its part left out of the theme reads "classic".
function ns.ThemeLook(clientArt, where)
    local theme = ns.ThemeFor(where)
    if not theme then return "classic" end
    return (clientArt and theme.client) and "client" or "themed"
end

-- Pull latch in a module's own pass: true once per theme change; state.on is the theme name last painted (false: off),
-- state.was the one before. where: the module's part, off while left out of the theme.
function ns.ThemeTurned(state, where)
    local on = ns.ThemeFor(where) and ThemeName() or false
    if state.on == on then return false end
    state.was, state.on = state.on, on
    return true
end

-- Softer share for the slots and the band; full bronze read too strong.
ns.BRONZE_SOFT = 0.9
-- A pane's colour (share.pane: parchment, backgrounds) by the Background shade slider: the frames' own at its middle,
-- toward black below it, toward white above it.
local paneTint = {}
local function PaneTint(t)
    local level = (tonumber(ns.db and ns.db.themePaneShade) or ns.PANE_SHADE_DEFAULT) / 50 - 1
    for i = 1, 3 do
        paneTint[i] = level < 0 and t[i] * (1 + level) or t[i] + (1 - t[i]) * level
    end
    return paneTint
end

-- Drained and tinted to the theme (share: of its colour, or by theme name; shade: times this), or as drawn without
-- one (silver: drained grey).
local function Paint(texture, theme, share, silver)
    local pane = type(share) == "table" and share.pane == true
    -- The one color look: the theme's color whole, as every piece of its part (Art/ThemeLayers.lua Ink).
    if theme and ns.FlatOn(texture, theme) then
        local t = pane and PaneTint(theme.tint) or theme.tint
        texture:SetDesaturated(true)
        texture:SetVertexColor(t[1], t[2], t[3])
        return
    end
    if theme then
        local tint = pane and PaneTint(theme.tint) or theme.tint
        local shade = 1
        if pane then
            share = 1
        elseif type(share) == "table" then
            shade, share = share.shade or 1, share[ThemeName()]
        end
        share = type(share) == "number" and share or 1
        texture:SetDesaturated(true)
        local max = math.max
        local r, g, b = max(0, 1 + (tint[1] - 1) * share) * shade, max(0, 1 + (tint[2] - 1) * share) * shade,
            max(0, 1 + (tint[3] - 1) * share) * shade
        texture:SetVertexColor(r, g, b)
    else
        -- share.off: the shade it keeps with no theme (a grey icon).
        local off = type(share) == "table" and share.off or 1
        texture:SetDesaturated(silver == true)
        texture:SetVertexColor(off, off, off)
    end
end

local function PaintTint(texture)
    if texture.SetDesaturated then Paint(texture, ns.ThemeFor(texture), tinted[texture], silvered[texture]) end
end

-- Forever's own art is gold already, so a theme showing client art leaves it; retail's is silver and takes the tint.
local function ClientGold(theme) return theme ~= nil and theme.client and ns.OnForever() end

-- The game's own art (Art/GameArt.lua): as drawn with no theme or one showing Forever's gold art, else tinted like
-- our metal. Art another paint holds is left to it.
local gameArt = setmetatable({}, weak)   -- texture -> share, or true for full
local paintedAt = setmetatable({}, weak)   -- game art -> the frame it was last painted in
local function OnCopy(texture)
    return tinted[texture] or drained[texture] ~= nil or swapped[texture] or (B.clientWas and B.clientWas[texture])
end
-- The game colors much of its own art (a tooltip's dark center, a quality border): white is not its "as drawn".
local gameWas = setmetatable({}, weak)     -- game art -> { desaturated, r, g, b, a } before our first themed paint
local function Remember(texture)
    if gameWas[texture] ~= nil then return end
    local r, g, b, a = texture:GetVertexColor()
    local desat = texture:IsDesaturated()
    gameWas[texture] = not ns.AnySecret(r, g, b, a, desat) and { desat, r, g, b, a } or false
end
-- Ours off it: the game's own desaturation and color back. Art we never painted is left as the game keeps it.
local function GiveBack(texture)
    local was = gameWas[texture]
    if was == nil then return end
    gameWas[texture] = nil
    texture:SetDesaturated(was and was[1] or false)
    if was then texture:SetVertexColor(was[2], was[3], was[4], was[5]) else texture:SetVertexColor(1, 1, 1) end
end
local function PaintGame(texture)
    if OnCopy(texture) then return end
    paintedAt[texture] = GetTime()
    local share = gameArt[texture]
    local theme = ns.ThemeFor(texture)
    -- A pane (broad) is parchment too: as drawn with Parchment pages left out.
    if type(share) == "table" and share.pane and not ns.ThemePartOn("themePartParchment") then theme = nil end
    if theme and not ClientGold(theme) then
        Remember(texture)
        Paint(texture, theme, share)
    else
        GiveBack(texture)
    end
end

-- The game art's walk follows the theme's repaint in the same pass: art painted this frame as it is is left.
function ns.TintGameArt(texture, share)
    if not (texture and texture.SetDesaturated and texture.SetVertexColor) then return end
    local same = gameArt[texture] == (share or true)
    gameArt[texture] = share or true
    if same and paintedAt[texture] == GetTime() then return end
    PaintGame(texture)
end

function ns.UntintGameArt(texture)
    if not texture or gameArt[texture] == nil then return end
    gameArt[texture] = nil
    if OnCopy(texture) then return end
    GiveBack(texture)
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
    if not texture.SetDesaturated then return end
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1)
end

-- A tinted piece back in its theme paint after a color of its own (a spell slot's rim after a passive's black).
function ns.RetintBronze(texture)
    if tinted[texture] then PaintTint(texture) end
end

-- Client bronze hidden for the old look, shown only with the theme.
local function PaintKeep(region)
    region:SetAlpha(ns.ThemeFor(region) and 1 or 0)
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

-- The backdrop with its edge file on the themed sheet (the old art where the client's is new), made once per frame.
local function ThemedInfo(info)
    local themed = info.themed
    if themed then return themed end
    themed = {}
    for k, v in pairs(info.plain) do themed[k] = v end
    themed.edgeFile = BronzeCopy(info.plain.edgeFile)
    info.themed = themed
    return themed
end

-- Border tinted to the theme; a window that greys its own border passes that grey to keep the depth. Edge sheets the
-- theme has (dialog border, slider track) swap to it, keeping the fill colour.
function ns.BronzeBackdrop(frame, r, g, b, a, grey)
    if not frame or not frame.SetBackdropBorderColor then return end
    -- One taken off stays off: the options window inside the game's settings had its dialog back on each repaint (#203).
    if not frame.backdropInfo then return end
    local base = bordered[frame]
    if r or type(base) ~= "table" then
        base = { r or 1, g or r or 1, b or r or 1, a or 1, info = type(base) == "table" and base.info or nil }
    end
    local plain = frame.backdropInfo
    if not base.info and plain and plain.edgeFile and BronzeCopy(plain.edgeFile) then base.info = { plain = plain } end
    if grey then base.grey = grey end
    bordered[frame] = base
    local name = ns.ThemeFor(frame) and ThemeName() or nil
    -- No theme: a box may keep its own grey, as Era's stat boxes.
    local rim = (not name and base.grey) or base
    if base.info and frame.SetBackdrop then
        local want = name and ThemedInfo(base.info) or base.info.plain
        if frame.backdropInfo ~= want then
            local fr, fg, fb, fa = frame:GetBackdropColor()
            frame:SetBackdrop(want)
            if fr then frame:SetBackdropColor(fr, fg, fb, fa) end
        end
    end
    local tint = name and THEMES[name].tint or ONE
    frame:SetBackdropBorderColor(tint[1] * rim[1], tint[2] * rim[2], tint[3] * rim[3], base[4])
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
    local theme = ns.ThemeFor(region)
    if theme and ns.FlatOn(region) and region.SetVertexColor then
        local t = theme.tint
        region:SetDesaturated(true)
        region:SetVertexColor(t[1], t[2], t[3])
        return
    end
    if ClientGold(theme) then
        region:SetDesaturated(false)
        if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
        return
    end
    region:SetDesaturated(true)
    if not region.SetVertexColor then return end
    local r, g, b = 1, 1, 1
    if tint then r, g, b = tint[1], tint[2], tint[3] end
    if theme then
        local t = theme.tint
        r, g, b = r * t[1], g * t[2], b * t[3]
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
    region:SetDesaturated(false)
    if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
end

-- Drained once; drained again when the client resets its desaturation (an unreadable state counts as right).
function ns.KeepDrained(region, r, g, b)
    if not region or not region.SetDesaturated then return end
    local grey = ns.ThemeLook(true, region) ~= "client"
    if drained[region] == nil or (region.IsDesaturated and ns.Safe(region:IsDesaturated(), grey) ~= grey) then
        ns.DrainBronze(region, r, g, b)
    end
end

-- Input box trim: the client's bronze edges drained to the old lighter silver.
ns.INPUT_GREY = 0.85
function ns.DrainInput(box, drain)
    ns.EachKey(box, ns.KEYS.LMR, drain or ns.DrainBronze, ns.INPUT_GREY)
end

-- The theme's layers and masks hang in the slice too: repainted as its edges, a copy's metal went white.
local function Edge(region, center)
    return region ~= center and not ns.IsThemeLayer(region) and region:GetObjectType() ~= "MaskTexture"
end

local function SliceDrain(region, center, grey, drain)
    if Edge(region, center) then drain(region, grey) end
end

local function SliceTint(region, center)
    if Edge(region, center) and region.IsObjectType and region:IsObjectType("Texture") then ns.BronzeTint(region) end
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
    ns.HoldThemeName(true)
    for texture in pairs(tinted) do PaintTint(texture) end
    for texture in pairs(gameArt) do PaintGame(texture) end
    for region, tint in pairs(drained) do
        if region.SetDesaturated then PaintDrain(region, tint or nil) end
    end
    ns.HoldThemeName(false)
end

-- The theme's colour moved (a slider or picker drag): tints and borders only, no file swaps.
function ns.RepaintColours()
    ns.RepaintTints()
    for frame in pairs(bordered) do ns.BronzeBackdrop(frame) end
end

-- The dev addon's tooltip probe: which of the theme's lists hold a piece.
function ns.ThemeListsOf(region)
    local lists = {}
    if tinted[region] then lists[#lists + 1] = silvered[region] and "tinted(silvered)" or "tinted" end
    if gameArt[region] ~= nil then lists[#lists + 1] = "gameArt" end
    if drained[region] ~= nil then lists[#lists + 1] = "drained" end
    if kept[region] then lists[#lists + 1] = "kept" end
    if swapped[region] then lists[#lists + 1] = "swapped" end
    return #lists > 0 and table.concat(lists, ",") or "none"
end

-- Repaint every remembered piece for the current theme.
local repaintedAt   -- the frame the last full repaint ran in
function ns.RepaintBronze()
    repaintedAt = GetTime()
    ns.HoldThemeName(true)
    ns.RepaintTints()
    for region in pairs(kept) do PaintKeep(region) end
    for frame in pairs(bordered) do ns.BronzeBackdrop(frame) end
    for texture, what in pairs(swapped) do
        if what:find("[\\/]") then
            local args = swapArgs[texture]
            -- Most themed sheets are the file itself: the layers, not a new path, tell the theme on.
            local copy = ns.ThemeFor(texture) and ns.BronzeCopy(what) or nil
            local want = copy or what
            if args then SetWithFallback(texture, want, what, unpack(args)) else SetWithFallback(texture, want, what) end
            if args then ns.PaintCopy(texture, copy, unpack(args)) else ns.PaintCopy(texture, copy) end
        else
            local primary, fallback = ns.TexPath(what, texture)
            SetWithFallback(texture, primary, fallback)
            ns.PaintCopy(texture, ns.ThemeFor(texture) and select(3, ns.TexPaths(what)) and primary or nil)
        end
    end
    ns.HoldThemeName(false)
end

-- A part left out of the theme or put back: its tints at once, in a fight too; file swaps with the apply pass. The
-- pass reruns the theme only when its last run read that part (a tooltip's paint waits for one to show): this repaints
-- unless the pass just did.
ns.OnToggle(function(key)
    if not ns.IsThemePart(key) or repaintedAt == GetTime() then return end
    ns.RepaintTints()
    for region in pairs(kept) do PaintKeep(region) end
end)

-- First module, so the repaint runs before every other apply.
ns.RegisterModule("bronzeTheme", { apply = function() ns.RepaintBronze() end, restore = function() ns.RepaintBronze() end })
