local _, ns = ...

-- Map Options at the classic map's foot, in MoP's spot: our box in Era's drop down look, with the game's own filter
-- button laid over it unseen, so a click opens the game's own menu (other addons' entries in it too) as the game's.
-- Shown, on hover (while the mouse is on the map) or hidden.

local MO = {}
ns.MapOptions = MO

local BOX_W, BOX_H = 120, 24
local GLOW_ALPHA = 0.4

local box
local took = setmetatable({}, { __mode = "k" })   -- the game's button -> its points before we laid it
local hidden

local function Mode()
    local db = ns.db
    if db.mapOptionsHidden == true then return "hide" end
    if db.mapOptionsHover == true then return "hover" end
    return "show"
end

local function Box(parent)
    if box then return box end
    box = ns.NewFrame("Frame", nil, parent)
    box:SetSize(BOX_W, BOX_H)
    box.Text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.Text:SetText(MAP_OPTIONS_TEXT)
    local arrow = ns.EraDropdownArt(box, -1, -1, -24)
    box.glow = box:CreateTexture(nil, "OVERLAY", nil, 2)
    box.glow:SetTexture(arrow:GetTexture())
    box.glow:SetTexCoord(arrow:GetTexCoord())
    box.glow:SetAllPoints(arrow)
    box.glow:SetBlendMode("ADD")
    box.glow:SetAlpha(GLOW_ALPHA)
    box.glow:Hide()
    return box
end

-- The box, nil before the first classic lay (Track Quest stands left of it).
function MO.Frame() return box end

-- Hide map help button: the game's tutorial "i" at the map's top left (retail; a game rule leaves Forever none), faded
-- and deaf, as the game shows it again on every restore from maximized.
local helpHidden = false
function MO.HelpButton(map)
    local button = map.BorderFrame and map.BorderFrame.Tutorial
    local hide = ns.db.hideMapHelpButton == true
    if not button or hide == helpHidden then return end
    helpHidden = hide
    button:SetAlpha(hide and 0 or 1)
    button:EnableMouse(not hide)
end

-- The map's coordinates are the game's own settings (retail keeps them off): two rows of ours mirror its CVars, read
-- at every apply and as the game's settings change; a click writes them (Core/Core.lua).
local COORD_CVARS = { mapPlayerCoords = "worldMapShowPlayerCoords", mapCursorCoords = "worldMapShowCursorCoords" }
ns.COORD_CVARS = COORD_CVARS
local function ReadMapCoords()
    if not ns.db then return end
    for key, cvar in pairs(COORD_CVARS) do
        local value = ns.GetCVar(cvar)
        if value ~= nil then ns.db[key] = tostring(value) == "1" end
    end
end
ns.RegisterModule("mapCoords", { apply = ReadMapCoords, restore = ReadMapCoords })
ns.EventFrame("CVAR_UPDATE", function(_, _, name)
    if name ~= COORD_CVARS.mapPlayerCoords and name ~= COORD_CVARS.mapCursorCoords then return end
    ReadMapCoords()
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
end)

-- The map's filter and pin buttons: Forever hangs them on the map by name, retail keeps them only in its overlay
-- list, told apart by a method of their mixin. Found once per map.
local OVERLAY_SIGN = { WorldMapTrackingOptionsButton = { "WorldMapTrackingOptionsButtonMixin", "BuildFilterTable" },
    WorldMapTrackingPinButton = { "WorldMapTrackingPinButtonMixin", "OnClick" } }
local overlays = setmetatable({}, { __mode = "k" })
function ns.MapOverlay(map, key)
    local found = map[key]
    if found then return found end
    local cache = overlays[map]
    if cache and cache[key] ~= nil then return cache[key] or nil end
    cache = cache or {}
    overlays[map] = cache
    local sign = OVERLAY_SIGN[key]
    local mixin = sign and _G[sign[1]]
    for _, frame in ipairs(mixin and map.overlayFrames or ns.EMPTY) do
        if frame[sign[2]] == mixin[sign[2]] then
            found = frame
            break
        end
    end
    cache[key] = found or false
    return found
end

local function Points(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
    return points
end

-- The game's button over the whole box, its own art unseen (its reset X stays).
local function Take(track, scale)
    if not took[track] then
        took[track] = { points = Points(track), w = track:GetWidth(), h = track:GetHeight() }
        -- Retail's button carries a filter counter, its banner, a corner shadow and a ring too: all unseen.
        ns.FadeTextures(track)
        if track.FilterCounter then track.FilterCounter:SetAlpha(0) end
    end
    ns.SetSizeIf(track, BOX_W * scale, BOX_H * scale)
    ns.SetPointIf(track, "TOPLEFT", box, "TOPLEFT", 0, 0)
    if track.Icon then ns.SetAlphaIf(track.Icon, 0) end
    local hl = track:GetHighlightTexture()
    if hl then ns.SetAlphaIf(hl, 0) end
end

-- spot: the frame, x and y the box's bottom right sits at from its top left, and the scale the box is drawn at.
function MO.Place(map, rel, x, y, scale)
    local track = ns.MapOverlay(map, "WorldMapTrackingOptionsButton")
    if not track then return end
    local b = Box(map.BorderFrame)
    ns.SetScaleIf(b, scale)
    ns.SetPointIf(b, "BOTTOMRIGHT", rel, "TOPLEFT", x, y)
    local mode = Mode()
    if mode == "hide" then
        b:Hide()
        if track:IsShown() then
            hidden = true
            track:Hide()
        end
        return
    end
    if hidden then
        hidden = false
        track:Show()
    end
    b:Show()
    Take(track, scale)
    local alpha = (mode == "show" or map:IsMouseOver()) and 1 or 0
    ns.SetAlphaIf(b, alpha)
    ns.SetAlphaIf(track, alpha)
    b.glow:SetShown(alpha > 0 and track:IsMouseOver())
end

-- The game's button back as the game laid it (the game's own layout, or the classic map off).
function MO.Release(map)
    if box then box:Hide() end
    local track = map and ns.MapOverlay(map, "WorldMapTrackingOptionsButton")
    local was = track and took[track]
    if hidden then
        hidden = false
        track:Show()
    end
    if not was then return end
    took[track] = nil
    track:ClearAllPoints()
    for _, p in ipairs(was.points) do track:SetPoint(unpack(p)) end
    track:SetSize(was.w, was.h)
    track:SetAlpha(1)
    ns.FadeTextures(track, 1)
    if track.FilterCounter then track.FilterCounter:SetAlpha(1) end
    if track.Icon then track.Icon:SetAlpha(1) end
    local hl = track:GetHighlightTexture()
    if hl then hl:SetAlpha(1) end
end

-- Ours and the button laid on it, kept when a fight's fade walks the map.
function MO.Keep(into, map)
    if box then into[box] = true end
    local track = ns.MapOverlay(map, "WorldMapTrackingOptionsButton")
    if track and took[track] then into[track] = true end
end
