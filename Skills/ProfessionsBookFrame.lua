local _, ns = ...

-- Era frames over the window's generic chrome, its border hidden: the small professions book in the spellbook's own
-- frame (that window stands 12 left and 14 up of this one), the trade skill page in Era's trade skill window (12 left,
-- 13 up), each with the portrait, title and close on that window's spots. The full book gets the chrome back.

local T = ns.prof
local ART_W, ART_H = 384, 512
-- Each window's art spot and its pieces' spots, from our window's corner. pieces() is read at first use.
-- ring: the portrait ring drawn again over the portrait (and, on the book, over its page's bands), as the art covers
-- the portrait's edge in Era; above: over the page too.
local KINDS = {
    book = { x = -12, y = 14, pieces = function() return ns.SPELLBOOK_QUARTERS end, above = true,
        ring = { key = "sbRing", layer = "OVERLAY", w = 96, h = 96, point = "TOPLEFT" },
        portrait = { x = -2, y = 6, size = 58 }, title = { x = 186, y = -12 }, close = { x = -11, y = -11 } },
    -- The trade skill page stands 2 in (Skills/TradeSkill.lua): its border on the book's, portrait on the same middle,
    -- title and close where the book has them.
    trade = { x = -10, y = 13, pieces = function() return ns.TradeSkillFrameArt end, tint = true,
        -- The art's own corner, ring and all; its middle is clear.
        ring = { key = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopLeft", set = "raw", layer = "OVERLAY",
            coords = { 0, 72 / 256, 0, 72 / 256 }, w = 72, h = 72, point = "TOPLEFT" },
        portrait = { x = -3, y = 7, size = 60 }, title = { x = 186, y = -12 }, close = { x = -11, y = -11 } },
    -- The double pane (Skills/TradeSkillDual.lua): the 3.x quest log's double frame on the same spot.
    tradeDual = { x = -10, y = 13, pieces = function() return ns.tradeDual and ns.tradeDual.FRAME_ART end,
        ring = { key = "questLogDualLeft", layer = "OVERLAY", coords = { 0, 72 / 512, 0, 72 / 512 }, w = 72, h = 72,
            point = "TOPLEFT" },
        portrait = { x = -3, y = 10, size = 60 }, title = { x = 353, y = -11 }, close = { x = -12, y = -11 } },
}

local holders, rings = {}, {}
local current  -- the kind up now
local saved    -- the chrome's own points, put back when an Era frame comes off

local function Points(region)
    local list = {}
    for i = 1, region:GetNumPoints() do list[i] = { region:GetPoint(i) } end
    return list
end

local function Restore(region, list)
    if not (region and list) then return end
    region:ClearAllPoints()
    for _, p in ipairs(list) do region:SetPoint(unpack(p)) end
end

local function Holder(frame, kind)
    if holders[kind] then return holders[kind] end
    local spec = KINDS[kind]
    local holder = ns.NewFrame("Frame", nil, frame)
    holder:SetSize(ART_W, ART_H)
    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", spec.x, spec.y)
    for _, tex in ipairs(ns.DressPieces(holder, spec.pieces(), nil, true)) do
        if spec.tint then ns.BronzeTint(tex) end
    end
    holder:Hide()
    holders[kind] = holder
    local ring = ns.NewFrame("Frame", nil, frame)
    ring:SetAllPoints(holder)
    for _, tex in ipairs(ns.DressPieces(ring, { spec.ring }, nil, true)) do
        if spec.tint then ns.BronzeTint(tex) end
    end
    ring:Hide()
    rings[kind] = ring
    return holder
end

-- kind: "book" (the small book page up), "trade" (the trade skill page up) or nil (the chrome back). Out of combat
-- only (the close button's window is protected).
function T.EraFrame(kind)
    local frame = T.Host()
    if not frame or InCombatLockdown() then return end
    if kind and not KINDS[kind].pieces() then kind = nil end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    local close = frame.CloseButton
    if current and current ~= kind then
        holders[current]:Hide()
        rings[current]:Hide()
    end
    if kind then
        local spec = KINDS[kind]
        local art = Holder(frame, kind)
        -- Under every piece of the window, the chrome's textures included.
        ns.SetLevelIf(art, frame:GetFrameLevel())
        if not saved then
            saved = { portrait = portrait and Points(portrait), portraitSize = portrait and { portrait:GetSize() },
                title = title and Points(title), close = close and Points(close) }
        end
        ns.SetShownIf(art, true)
        local page = spec.above and T.Page and T.Page()
        local portraitHost = frame.PortraitContainer
        ns.SetLevelIf(rings[kind], math.max(page and page:GetFrameLevel() or 0, portraitHost and portraitHost:GetFrameLevel() or 0)
            + (spec.above and 5 or 1))
        ns.SetShownIf(rings[kind], true)
        if frame.NineSlice then ns.SetAlphaIf(frame.NineSlice, 0) end
        if portrait then
            portrait:SetSize(spec.portrait.size, spec.portrait.size)
            ns.SetPointOnce(portrait, "TOPLEFT", frame, "TOPLEFT", spec.portrait.x, spec.portrait.y)
        end
        if title then ns.SetPointOnce(title, "CENTER", frame, "TOPLEFT", spec.title.x, spec.title.y) end
        if close then ns.SetPointOnce(close, "CENTER", frame, "TOPRIGHT", spec.close.x, spec.close.y) end
    elseif current then
        if frame.NineSlice then ns.SetAlphaIf(frame.NineSlice, 1) end
        if saved then
            Restore(portrait, saved.portrait)
            if portrait and saved.portraitSize then portrait:SetSize(unpack(saved.portraitSize)) end
            Restore(title, saved.title)
            Restore(close, saved.close)
            saved = nil
        end
    end
    current = kind
end

-- Retail's book window: the small book only.
function T.SmallFrame(on) T.EraFrame(on and "book" or nil) end
