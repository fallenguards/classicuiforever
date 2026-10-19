local _, ns = ...

-- Colour themes in layers: a piece's copy as drawn (custom/) under its metal alone (custom-metal/) in the theme's
-- colour, and a sheet's parchment alone (custom-parch/) in it too. The one color look inks chrome whole instead. Each
-- layer takes its piece's shown state, alpha, crop and draw layer on a signal, not every frame.

local B = ns.bronze
local THEMES = B.THEMES

local weak = { __mode = "k" }
local layers = setmetatable({}, weak)   -- copy piece -> { tex, parch, on, metal, parched, copy, wrap, drawLayer, sub }
local own = setmetatable({}, weak)       -- our layer textures
-- A piece's frame -> { layer -> piece }: the layers hang on that frame and go with it, so an unseen frame's are left alone.
local frames = setmetatable({}, weak)
local job
-- No timer. A paint follows its own piece; one whole pass runs when a window shows or goes or the game restyles its
-- bars; one window's pieces are followed every frame for BURST after it showed, was pressed or had a layer move.
local BURST = 0.25
local wantWhole = false
local wantHolders = setmetatable({}, weak)   -- a bar's holder (Bar/BandBars.lua) whose layers the next pass follows
local dirty = setmetatable({}, weak)    -- layer -> piece, painted since the last pass
local groups = setmetatable({}, weak)   -- root (a window under UIParent) -> { piece's frame -> its layers }
local rootOf = setmetatable({}, weak)   -- a piece's frame -> its root
local hot = setmetatable({}, weak)      -- root -> when its burst ends

-- A paint: its piece alone on the next pass, once the caller is done with it (it may still crop or fade it).
local function Kick(piece, layer)
    if not job:IsAwake() then return end
    dirty[layer] = piece
    job:Kick()
end

-- One whole pass on the next frame.
local function Look()
    if not job:IsAwake() then return end
    wantWhole = true
    job:Kick()
end

-- One bar's buttons alone on the next frame (a page or stance change restyles nothing else).
local function LookBar(bar)
    local band = ns.band
    local holder = bar and band and band.HolderOf and band.HolderOf(bar)
    if not (holder and job:IsAwake()) then return end
    wantHolders[holder] = true
    job:Kick()
end

-- A window's pieces every frame for BURST from now.
local function Heat(root, now)
    hot[root] = now + BURST
    job:Burst(BURST)
end

-- The frame a frame hangs from under UIParent; nil off it (a nameplate, a menu).
local function RootOf(frame)
    local root, parent = frame, frame:GetParent()
    while parent and parent ~= UIParent do
        if ns.IsForbidden(parent) then return nil end
        root, parent = parent, parent:GetParent()
    end
    return parent and root or nil
end

-- A root's group, made with the watcher that looks at its layers as it shows or goes.
local Edge
local function Group(root)
    local group = groups[root]
    if not group then
        group = setmetatable({}, weak)
        groups[root] = group
        ns.Sched.OnVisible(root, "theme.layers", function() Edge(root) end)
    end
    return group
end

-- A root moved into a window after its layers joined it (the spellbook into the game's): its group joins the window's,
-- else a press there never followed them (the page arrows kept the last page's look).
local stale = {}
local function Regroup()
    for root in pairs(groups) do
        if root:GetParent() ~= UIParent then stale[#stale + 1] = root end
    end
    for i = #stale, 1, -1 do
        local root = stale[i]
        stale[i] = nil
        local group, now = groups[root], RootOf(root)
        groups[root] = nil
        if hot[root] and now then hot[now] = math.max(hot[now] or 0, hot[root]) end
        hot[root] = nil
        local into = now and Group(now)
        for frame, set in pairs(group) do
            if into then into[frame] = set end
            rootOf[frame] = now
        end
    end
end

-- A window showed or went (frame: it, or anything in it): its pieces for a while, and all once (the micro buttons
-- follow their windows).
function Edge(frame)
    if not job:IsAwake() then return end
    Regroup()
    local root = frame and RootOf(frame)
    if root and groups[root] then Heat(root, GetTime()) end
    Look()
end
ns.FollowLayers = Edge

-- Presses, and the events on which the game restyles bars and unit frames with no press.
local EVENTS = { "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }
-- Each bar event's bar, by name: bar 1 pages, the stance and pet bars refill.
local BAR_EVENTS = { ACTIONBAR_PAGE_CHANGED = "MainActionBar", UPDATE_BONUS_ACTIONBAR = "MainActionBar",
    UPDATE_VEHICLE_ACTIONBAR = "MainActionBar", UPDATE_OVERRIDE_ACTIONBAR = "MainActionBar",
    UPDATE_SHAPESHIFT_FORMS = "StanceBar", PET_BAR_UPDATE = "PetActionBar" }
local listener = ns.EventFrame({}, function(_, event)
    if BAR_EVENTS[event] then return LookBar(_G[BAR_EVENTS[event]]) end
    if event ~= "GLOBAL_MOUSE_DOWN" and event ~= "GLOBAL_MOUSE_UP" then return Look() end
    -- A press moves pieces of the window under the mouse only; on the world (the camera) none.
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = foci and foci[1]
    if not focus or focus == _G.WorldFrame or ns.IsForbidden(focus) then return end
    Regroup()
    local root = RootOf(focus)
    if root and groups[root] then
        Heat(root, GetTime())
        job:Kick()
    end
end)

-- The pass and its events, only while a layer is on.
local function Listen(on)
    if on == job:IsAwake() then return end
    if on then
        job:Wake()
        ns.RegisterEvents(listener, EVENTS)
    else
        job:Sleep()
        listener:UnregisterAllEvents()
    end
end

-- A piece's frame joins its root's group; a root gets one watcher, so its layers are looked at as it shows or goes.
local function Index(piece, layer)
    local frame = piece:GetParent()
    local set = frames[frame]
    if not set then
        set = setmetatable({}, weak)
        frames[frame] = set
        local root = RootOf(frame)
        if root then Group(root)[frame], rootOf[frame] = set, root end
    end
    set[layer] = piece
end

local function Theme()
    return THEMES[ns.ThemeName() or ""]
end

-- Parchment's row under the theme's Parts: off, every page and sheet's parchment as drawn, and its text; a sheet's
-- frame still wears the theme, its parchment laid over it as drawn.
local function ParchOn() return ns.ThemePartOn("themePartParchment") end

-- The metal-only copy of a theme copy, whatever theme folder the copy is in.
local function MetalPath(copyPath)
    return (copyPath:gsub("\\[^\\]+\\([^\\]+)$", "\\custom-metal\\%1"))
end

-- A layer wears the piece's masks, the client's too: the bag portrait's round one cut the icon's square rim.
local function NewTex(piece)
    local tex = piece:GetParent():CreateTexture(nil, "ARTWORK")
    own[tex] = true
    tex:SetAllPoints(piece)
    for i = 1, piece:GetNumMaskTextures() do tex:AddMaskTexture(piece:GetMaskTexture(i)) end
    return tex
end

local function Wear(tex, mask, on)
    if not tex then return end
    if on then tex:AddMaskTexture(mask) else tex:RemoveMaskTexture(mask) end
end
-- A mask on or off a piece and its layers: a layer draws the whole copy, so a ring the mask cuts showed on it (#194).
function ns.WearMask(piece, mask, on)
    Wear(piece, mask, on)
    local layer = layers[piece]
    if layer then
        Wear(layer.tex, mask, on)
        Wear(layer.parch, mask, on)
    end
end

-- True when the layer had to change.
local function FollowOne(tex, on, shown, alpha)
    if not tex then return false end
    local moved = ns.SetShownIf(tex, on and shown)
    if on and shown and alpha and ns.SetAlphaIf(tex, alpha) then moved = true end
    return moved
end

-- The piece's crop onto its layers when it differs from the one they took; a secret crop is handed on unread.
local function Crop(layer, ulx, uly, llx, lly, urx, ury, lrx, lry)
    local secret = ns.IsSecret(ulx)
    if not secret then
        local c = layer.crop
        if not c then
            c = {}
            layer.crop = c
        elseif c[1] == ulx and c[2] == uly and c[3] == llx and c[4] == lly and c[5] == urx and c[6] == ury and c[7] == lrx
            and c[8] == lry then
            return false
        end
        c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8] = ulx, uly, llx, lly, urx, ury, lrx, lry
    end
    if layer.tex and layer.metal then layer.tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry) end
    if layer.parch and layer.parched then layer.parch:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry) end
    return not secret
end

-- The lowest sublevel above the piece's that another of its parent's regions holds in its draw layer (an action
-- button's icon over its slot art); nil when none.
local ceiling, ceilingPiece, ceilingLayer, ceilingSub
local function Above(region)
    if region == ceilingPiece or own[region] or not region.GetDrawLayer then return end
    local drawLayer, sub = region:GetDrawLayer()
    -- A nameplate's pieces can answer secret (0.16.1: compared, 1381 errors a session).
    if ns.AnySecret(drawLayer, sub) then return end
    if drawLayer == ceilingLayer and sub and sub > ceilingSub and (not ceiling or sub < ceiling) then ceiling = sub end
end
local function Ceiling(piece, drawLayer, sub)
    ceiling, ceilingPiece, ceilingLayer, ceilingSub = nil, piece, drawLayer, sub or 0
    ns.EachRegion(piece:GetParent(), Above)
    return ceiling
end

-- Our layers take the two sublevels over the piece; where a region drawn above the piece holds one of them (same
-- sublevel: the game picks the order, and the dark layer covered the icon), the piece steps down under it first.
local function MakeRoom(piece, drawLayer, sub)
    sub = sub or 0
    local top = Ceiling(piece, drawLayer, sub)
    if top and sub + 2 >= top and top - 3 >= -8 then
        sub = top - 3
        piece:SetDrawLayer(drawLayer, sub)
    end
    return sub
end

-- seen: the piece's frame is known to be visible (the pass asks each frame once). True when a layer had to change.
local function Follow(piece, layer, seen)
    local shown = piece:IsShown() and (seen or piece:IsVisible())
    local alpha = shown and piece:GetAlpha() or nil
    if ns.IsSecret(alpha) then alpha = nil end
    local moved = FollowOne(layer.tex, layer.metal, shown, alpha)
    if FollowOne(layer.parch, layer.parched, shown, alpha) then moved = true end
    if not shown then return moved end
    if Crop(layer, piece:GetTexCoord()) then moved = true end
    local drawLayer, sub = piece:GetDrawLayer()
    if ns.AnySecret(drawLayer, sub) then return moved end
    if drawLayer ~= layer.drawLayer or sub ~= layer.sub then sub = MakeRoom(piece, drawLayer, sub) end
    if drawLayer ~= layer.drawLayer or sub ~= layer.sub then
        layer.drawLayer, layer.sub = drawLayer, sub
        if layer.tex then layer.tex:SetDrawLayer(drawLayer, math.min(7, (sub or 0) + 1)) end
        if layer.parch then layer.parch:SetDrawLayer(drawLayer, math.min(7, (sub or 0) + 2)) end
        moved = true
    end
    return moved
end

-- One frame's layers, when it shows. Returns whether a layer is on, and whether one had to change.
local function FollowFrame(frame, set)
    local any, moved, visible = false, false, nil
    for layer, piece in pairs(set) do
        if layer.on then
            any = true
            if visible == nil then visible = ns.Safe(frame:IsVisible(), true) and true or false end
            if not visible then break end
            if Follow(piece, layer, true) then moved = true end
        end
    end
    return any, moved
end

-- Painted pieces first, each alone; then every frame once when asked, else only the windows in a burst. A layer
-- that moved keeps its window's burst going (a fade is followed each frame).
local function Pass(_, now)
    for layer, piece in pairs(dirty) do
        dirty[layer] = nil
        local frame = piece:GetParent()
        -- On a hidden frame the layer waits as it is: it shows with the frame.
        if layer.on and ns.Safe(frame:IsVisible(), true) and Follow(piece, layer, true) and rootOf[frame] then
            Heat(rootOf[frame], now)
        end
    end
    -- A bar's holder alone; a whole pass covers them too.
    for holder in pairs(wantHolders) do
        wantHolders[holder] = nil
        local group = not wantWhole and groups[holder]
        if group then
            for frame, set in pairs(group) do
                local _, moved = FollowFrame(frame, set)
                if moved then Heat(holder, now) end
            end
        end
    end
    if wantWhole then
        wantWhole = false
        local any = false
        for frame, set in pairs(frames) do
            local on, moved = FollowFrame(frame, set)
            any = any or on
            if moved and rootOf[frame] then Heat(rootOf[frame], now) end
        end
        if not any then Listen(false) end
        return
    end
    for root, ends in pairs(hot) do
        if now >= ends then
            hot[root] = nil
        elseif ns.Safe(root:IsVisible(), true) then
            local moved = false
            for frame, set in pairs(groups[root]) do
                local _, changed = FollowFrame(frame, set)
                moved = moved or changed
            end
            if moved then Heat(root, now) end
        end
    end
end
-- Kick-only: off the frame loop at rest.
job = ns.Sched.Job({ name = "theme.layers", every = math.huge, awake = false, fn = Pass })

local function Hide(layer)
    if not (layer and layer.on) then return end
    layer.on = false
    if layer.tex then layer.tex:Hide() end
    if layer.parch then layer.parch:Hide() end
end

local function Tiles(tex, piece)
    if not piece.GetHorizTile then return end
    tex:SetHorizTile(piece:GetHorizTile())
    tex:SetVertTile(piece:GetVertTile())
end

-- The layer over the sheet (layer.parch): its parchment grayed in the theme's color, or as drawn (parchment's row
-- off, or a painted picture).
local function Tint(layer, theme)
    local t = theme.tint
    if layer.tex then layer.tex:SetVertexColor(t[1], t[2], t[3]) end
    if not layer.parch then return end
    local tinted = layer.overTinted == true
    layer.parch:SetDesaturated(tinted)
    if tinted then layer.parch:SetVertexColor(t[1], t[2], t[3]) else layer.parch:SetVertexColor(1, 1, 1) end
end

-- What a sheet wears over it: its parchment (tinted while parchment's row is on) or its painted picture (as drawn).
local function OverCopy(copy)
    local parch = ns.ParchCopy(copy)
    if parch then return parch, ParchOn() end
    return ns.PictureCopy(copy), false
end

-- The one color look: a chrome sheet's piece (frames, floors, parchment pages) desaturated whole in the theme's color,
-- its layers off, as a dark mode does; buttons and icons keep their colors under the metal layer.
local inked = setmetatable({}, weak)
local WHITE = { 1, 1, 1 }
-- A live button's art (a page arrow that can be pressed): inked LIVE_LIFT of the way from the theme's color to white, so
-- it stands apart from its spent state.
local LIVE = { ["ui-spellbookicon-nextpage-up"] = true, ["ui-spellbookicon-nextpage-down"] = true,
    ["ui-spellbookicon-prevpage-up"] = true, ["ui-spellbookicon-prevpage-down"] = true }
local LIVE_LIFT = 0.4
local function Live(path)
    local base = type(path) == "string" and path:match("([^\\/]+)$")
    return base and LIVE[(base:lower():gsub("%.%w+$", ""))] == true or false
end
local function Ink(piece, theme, path)
    Hide(layers[piece])
    inked[piece] = true
    -- A shading layer multiplies: in the color its white would darken its whole box.
    local t = piece:GetBlendMode() == "MOD" and WHITE or theme.tint
    local lift = Live(path) and LIVE_LIFT or 0
    piece:SetDesaturated(true)
    piece:SetVertexColor(t[1] + (1 - t[1]) * lift, t[2] + (1 - t[2]) * lift, t[3] + (1 - t[3]) * lift)
end
-- Textured color: the piece under its metal layer in gray, so what is neither metal nor parchment (a tab's fill, the
-- book's stitched edge) keeps its grain, not its own color.
local function Gray(piece)
    inked[piece] = "gray"
    piece:SetDesaturated(true)
    piece:SetVertexColor(1, 1, 1)
end
-- Out of it: as drawn, unless a tint holds the piece (its repaint colours it).
local function Uninked(piece)
    if not inked[piece] then return end
    inked[piece] = nil
    if B.tinted[piece] then return end
    piece:SetDesaturated(false)
    piece:SetVertexColor(1, 1, 1)
end

-- Parchment the game draws or we draw by hand (an atlas, a file off the generated lists): whole under any theme, as
-- PARCH_WHOLE's sheets. Off the theme, its own vertex color (base) back, or white.
local pages = setmetatable({}, weak)   -- piece -> its base color, or true
function ns.InkPage(piece, base)
    pages[piece] = base or pages[piece] or true
    local theme = ParchOn() and ns.ThemeFor(piece)
    if theme then
        Ink(piece, theme)
        return
    end
    Uninked(piece)
    local own = pages[piece]
    if own ~= true then piece:SetVertexColor(own[1], own[2], own[3]) end
end

-- Art with no theme copy inks the same way, from ns.SetTex: chrome in the one color look, all-over parchment (the
-- spellbook's empty slot) under any theme. A page of ns.InkPage's keeps its paint, a piece wearing its copy's layers
-- the paint they gave it (Textured color's gray).
local chromeOf = setmetatable({}, weak)
function ns.InkChrome(piece, path)
    local layer = layers[piece]
    if pages[piece] or (layer and layer.on) then return end
    local whole = ns.ParchWhole(path)
    chromeOf[piece] = (whole or ns.ChromeArt(path)) and path or nil
    local theme = chromeOf[piece] and not (whole and not ParchOn()) and ns.ThemeFor(piece)
    if theme and (whole or ns.FlatOn(piece)) then Ink(piece, theme, path) else Uninked(piece) end
end

local function Inks(piece, copy)
    return ns.FlatOn(piece) and ns.ChromeArt(copy)
end

local function Shape(piece, layer)
    local theme = ns.ThemeFor(piece)
    local parch, tinted
    if theme then parch, tinted = OverCopy(layer.copy) end
    layer.overTinted = tinted
    if theme and Inks(piece, layer.copy) then
        Ink(piece, theme, layer.copy)
        -- The sheet one color; what keeps its own look over it (parchment with its row off, a picture), the layer alone.
        if not parch or tinted then return end
        layer.metal, layer.parched = nil, true
    else
        layer.metal, layer.parched = theme and theme.colorCopies or nil, parch and true or nil
        if layer.metal and ns.ChromeArt(layer.copy) then Gray(piece) else Uninked(piece) end
        if not (layer.metal or layer.parched) then
            Hide(layer)
            return
        end
    end
    local wrap = layer.wrap
    if layer.metal then
        layer.tex = layer.tex or NewTex(piece)
        layer.tex:SetTexture(MetalPath(layer.copy), unpack(wrap, 1, 3))
        layer.tex:SetBlendMode(piece:GetBlendMode())
        Tiles(layer.tex, piece)
    end
    if parch then
        layer.parch = layer.parch or NewTex(piece)
        layer.parch:SetTexture(parch, unpack(wrap, 1, 3))
        Tiles(layer.parch, piece)
    end
    layer.on, layer.drawLayer, layer.crop = true, nil, nil
    Tint(layer, theme)
end

-- copyPath: the theme copy the piece now shows (extra args as its SetTexture had), or nil for none.
function ns.PaintCopy(piece, copyPath, ...)
    if not (piece and piece.GetParent) then return end
    local layer = layers[piece]
    local theme = copyPath and ns.ThemeFor(piece)
    if not (theme and (theme.colorCopies or ns.FlatOn(piece) or ns.ParchCopy(copyPath) or ns.PictureCopy(copyPath))) then
        Hide(layer)
        Uninked(piece)
        return
    end
    if not layer then
        layer = { wrap = {} }
        layers[piece] = layer
        Index(piece, layer)
    end
    local wrap = layer.wrap
    local a, b, c = ...
    -- The same art again (a client reset put back, once a second on the game menu button): the layers hold it.
    if layer.on and layer.copy == copyPath and wrap[1] == a and wrap[2] == b and wrap[3] == c
        and layer.metal == (theme.colorCopies or nil) and not Inks(piece, copyPath) then
        if layer.metal then
            layer.tex:SetBlendMode(piece:GetBlendMode())
            Tiles(layer.tex, piece)
        end
        if layer.parched then Tiles(layer.parch, piece) end
        Kick(piece, layer)
        return
    end
    layer.copy, wrap[1], wrap[2], wrap[3] = copyPath, a, b, c
    Shape(piece, layer)
    if not layer.on then return end
    Follow(piece, layer)
    Listen(true)
    Kick(piece, layer)
end

-- The theme or Textured color changed: copy layers shaped again, the tinted pieces repainted now, even in a fight.
ns.OnToggle(function(key)
    if not B.THEME_KEYS[key] then return end
    for piece, layer in pairs(layers) do
        if layer.copy then
            Shape(piece, layer)
            if layer.on then Follow(piece, layer) end
        end
    end
    for piece, path in pairs(chromeOf) do ns.InkChrome(piece, path) end
    for piece in pairs(pages) do ns.InkPage(piece) end
    Listen(true)
    Look()
    if key == "themeTextured" or key:find("^textured") then ns.RepaintTints() end
end)

-- Read by the dev addon's themedump probe: how the theme's layers hold a texture.
function ns.FlatState(texture)
    if own[texture] then return "our layer" end
    if inked[texture] == true then return "inked" end
    local layer = layers[texture]
    if not layer then return nil end
    if not layer.on then return "copy off" end
    return (layer.parched and "copy parchment" or "copy metal") .. (inked[texture] and " gray" or "")
end

-- Read by the dev addon's colour probes: how many copy layers are on, and a few seen ones as { file, r, g, b, shown }.
function ns.ThemeLayerSample(most)
    local on, out = 0, {}
    for _, layer in pairs(layers) do
        if layer.on and layer.tex then
            on = on + 1
            if #out < (most or 3) and layer.tex:IsVisible() then
                local r, g, b = layer.tex:GetVertexColor()
                out[#out + 1] = { file = layer.tex:GetTexture(), r = r, g = g, b = b, shown = layer.tex:IsShown() }
            end
        end
    end
    return on, out
end

-- Read by the dev addon's layerwatch probe: fn(piece, layer, isCopy) for every layer.
function ns.EachThemeLayer(fn)
    for piece, layer in pairs(layers) do fn(piece, layer, true) end
end

-- Read by the dev addon: inked chrome shown (all-over parchment inks in both looks), and parchment layers shown.
function ns.ThemeInkShown()
    local inks, parch = 0, 0
    for piece in pairs(inked) do
        if inked[piece] == true and piece:IsShown() and not ns.ParchWhole(chromeOf[piece]) then inks = inks + 1 end
    end
    for _, layer in pairs(layers) do
        if layer.on and layer.parched and layer.parch:IsShown() then parch = parch + 1 end
    end
    return inks, parch
end

local function Recolour()
    local theme = Theme()
    if theme then
        for _, layer in pairs(layers) do
            if layer.on then Tint(layer, theme) end
        end
    end
    ns.RepaintColours()
end

-- Each step of a drag only recolours; the full repaint and apply pass run once the control rests (they lagged a drag).
local SETTLE = 0.4
local movedAt = 0
local function Settle()
    if GetTime() - movedAt < SETTLE - 0.01 then return end
    ns.RepaintBronze()
    if ns.QueueApply then ns.QueueApply() end
end

local function Retint()
    Recolour()
    movedAt = GetTime()
    ns.Sched.AfterPerFrame("theme.settle", SETTLE, Settle)
end

-- The picked custom colour, saved and painted.
function ns.SetThemeColor(r, g, b)
    ns.db.themeColor = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
    Retint()
end

-- Dark's slider (0-100), saved and painted.
function ns.SetThemeDarkness(level)
    ns.db.themeDarkness = math.max(0, math.min(100, math.floor((tonumber(level) or ns.DARKNESS_DEFAULT) + 0.5)))
    Retint()
end
