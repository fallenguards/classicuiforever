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

local function Points(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
    return points
end

-- The game's button over the whole box, its own art unseen (its reset X stays).
local function Take(track, scale)
    if not took[track] then
        took[track] = { points = Points(track), w = track:GetWidth(), h = track:GetHeight() }
    end
    ns.SetSizeIf(track, BOX_W * scale, BOX_H * scale)
    ns.SetPointIf(track, "TOPLEFT", box, "TOPLEFT", 0, 0)
    if track.Icon then ns.SetAlphaIf(track.Icon, 0) end
    local hl = track:GetHighlightTexture()
    if hl then ns.SetAlphaIf(hl, 0) end
end

-- spot: the frame, x and y the box's bottom right sits at from its top left, and the scale the box is drawn at.
function MO.Place(map, rel, x, y, scale)
    local track = map.WorldMapTrackingOptionsButton
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
    local track = map and map.WorldMapTrackingOptionsButton
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
    if track.Icon then track.Icon:SetAlpha(1) end
    local hl = track:GetHighlightTexture()
    if hl then hl:SetAlpha(1) end
end

-- Ours and the button laid on it, kept when a fight's fade walks the map.
function MO.Keep(into, map)
    if box then into[box] = true end
    local track = map.WorldMapTrackingOptionsButton
    if track and took[track] then into[track] = true end
end
