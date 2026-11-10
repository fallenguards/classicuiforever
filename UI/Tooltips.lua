local _, ns = ...

-- Client tooltips in the 1.x white rim (tinted with a theme) on Era's fill; bronze keeps Forever's rim over that fill
-- (Forever's gray center read blue and light against Era's near-black). Watch only: our rim is a scriptless child of
-- each NineSlice, so the client's show, hide and re-layout carry it; ApplyLayout never touches the region alpha.

local ART = ns.ART
local pairs, type = pairs, type

-- Load-on-demand ones turn up on ADDON_LOADED. Not globals here: AuraButtonTooltip (styled below),
-- PrivateAurasTooltip and CatalogShopTooltip (unreachable, stay bronze); no NamePlate/SmallTextTooltip.
local TIPS = {
    "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2", "EmbeddedItemTooltip", "GameNoHeaderTooltip", "GameSmallHeaderTooltip",
    "BuffFrameTooltip", "LootHistoryExtraTooltip", "SettingsTooltip", "QuickKeybindTooltip",
    "CustomizationNoHeaderTooltip", "FriendsTooltip", "PartyMemberBuffTooltip", "EncounterJournalTooltip",
    "LFGBrowseSearchEntryTooltip", "ConquestTooltip", "QueueStatusFrame", "BattlePetTooltip",
    "FloatingBattlePetTooltip", "FrameStackTooltip", "EventTraceTooltip", "PerksProgramTooltip",
    -- The popups' text boxes wear the tooltip border (unlearning a profession, deleting an item).
    "StaticPopup1EditBox", "StaticPopup2EditBox", "StaticPopup3EditBox", "StaticPopup4EditBox",
}
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }

-- UI-Tooltip-Border cells as BackdropTemplate cuts them, stretched not tiled: no size math on secret widths.
local S, E = 0.0625, 0.9375
-- The fill reaches the rim line's inner side (texel 3 of 16 is the line; Era's rim pieces carry their fill to it).
local EDGE, INSET = 16, 4
-- Era's tooltip fill as drawn: its flat image (16, 21, 29 at 230) times the tooltip color both clients share (23, 23,
-- 48). Forever's own fill under that name is another image, so it goes while our rim shows.
local ERA_FILL = { 16 * 23 / 65025, 21 * 23 / 65025, 29 * 48 / 65025, 230 / 255 }
ns.ERA_TIP_FILL = ERA_FILL

local rims = {}      -- tooltip -> our rim, false once a dress failed
local active = false
local theme = {}     -- ThemeTurned state
local clientArt      -- last painted: true Forever's own, false our rim, nil never

local function Corner(rim, point, left, right)
    local tex = rim:CreateTexture(nil, "BORDER")
    tex:SetTexture(ART.TIP_BORDER)
    ns.BronzeTint(tex)
    tex:SetTexCoord(left, right, S, E)
    tex:SetSize(EDGE, EDGE)
    tex:SetPoint(point, rim, point)
    return tex
end

local function Edge(rim, from, fromPoint, to, toPoint, ...)
    local tex = rim:CreateTexture(nil, "BORDER")
    tex:SetTexture(ART.TIP_BORDER)
    ns.BronzeTint(tex)
    tex:SetTexCoord(...)
    tex:SetPoint("TOPLEFT", from, fromPoint)
    tex:SetPoint("BOTTOMRIGHT", to, toPoint)
    return tex
end

local function MakeRim(slice)
    local rim = ns.NewFrame("Frame", nil, slice)
    rim:SetAllPoints(slice)
    -- At the tooltip's level so its text and bars draw over the rim.
    if rim.SetUsingParentLevel then rim:SetUsingParentLevel(true) else rim:SetFrameLevel(slice:GetFrameLevel()) end
    local tl = Corner(rim, "TOPLEFT", 0.5078125, 0.6171875)
    local tr = Corner(rim, "TOPRIGHT", 0.6328125, 0.7421875)
    local bl = Corner(rim, "BOTTOMLEFT", 0.7578125, 0.8671875)
    local br = Corner(rim, "BOTTOMRIGHT", 0.8828125, 0.9921875)
    -- Top and bottom cells are stored upright: rotated coords.
    rim.border = { tl, tr, bl, br,
        Edge(rim, tl, "TOPRIGHT", tr, "BOTTOMLEFT", 0.2578125, E, 0.3671875, E, 0.2578125, S, 0.3671875, S),
        Edge(rim, bl, "TOPRIGHT", br, "BOTTOMLEFT", 0.3828125, E, 0.4921875, E, 0.3828125, S, 0.4921875, S),
        Edge(rim, tl, "BOTTOMLEFT", bl, "TOPRIGHT", 0.0078125, 0.1171875, S, E),
        Edge(rim, tr, "BOTTOMLEFT", br, "TOPRIGHT", 0.1328125, 0.2421875, S, E) }
    -- Era's fill in the client's place: one flat color, under the rim line's inner side.
    local fill = rim:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetTexture(ART.WHITE)
    fill:SetVertexColor(ERA_FILL[1], ERA_FILL[2], ERA_FILL[3], ERA_FILL[4])
    fill:SetPoint("TOPLEFT", rim, "TOPLEFT", INSET, -INSET)
    fill:SetPoint("BOTTOMRIGHT", rim, "BOTTOMRIGHT", -INSET, INSET)
    rim.fill = fill
    return rim
end

-- false: our rim and fill. true: the client's rim over our fill (bronze). nil: the client's own, whole (restore).
-- Hidden, never faded: the client's hide sets its center's color with alpha 1, the texture's one alpha, so a faded
-- center came back on every tooltip after the first; the item quality border color likewise.
local function Paint(tip, on)
    local slice, rim = tip.NineSlice, rims[tip]
    for i = 1, #PIECES do
        local piece = slice[PIECES[i]]
        if piece then piece:SetShown(on ~= false) end
    end
    if slice.Center then slice.Center:SetShown(on == nil) end
    for i = 1, #rim.border do rim.border[i]:SetShown(on == false) end
    rim:SetShown(on ~= nil)
end

-- Read by the dev addon's probe: a tooltip's rim (its fill at .fill).
function ns.TooltipRim(tip) return rims[tip] or nil end

local function Dress(tip)
    if ns.IsForbidden(tip) then return end
    local slice = tip.NineSlice
    if type(slice) ~= "table" or not slice.GetFrameLevel then return end
    rims[tip] = MakeRim(slice)
    Paint(tip, clientArt == true)
end

-- The item link tooltip's X in Era's art on Era's spot (ItemRef.xml: 32 wide, 1 right of the corner); kept: the game's
-- art, size and spot, handed back as the module goes off.
local CLOSE_STATES = { "Normal", "Pushed", "Disabled", "Highlight" }
local closeKept
local function LinkTipClose(on)
    local tip = _G.ItemRefTooltip
    local close = tip and tip.CloseButton
    if not close or ns.IsForbidden(close) or not ns.SkinCloseButton then return end
    if on and not closeKept then
        closeKept = { w = close:GetWidth(), h = close:GetHeight(), point = { close:GetPoint(1) }, art = {} }
        for _, state in ipairs(CLOSE_STATES) do
            local tex = ns.StateTexture(close, state)
            closeKept.art[state] = tex and (tex:GetAtlas() or tex:GetTexture()) or nil
        end
        ns.SkinCloseButton(close, true)
        ns.SetPointOnce(close, "TOPRIGHT", tip, "TOPRIGHT", 1, 0)
    elseif not on and closeKept then
        for _, state in ipairs(CLOSE_STATES) do
            local tex, art = ns.StateTexture(close, state), closeKept.art[state]
            if tex and type(art) == "string" and C_Texture.GetAtlasInfo(art) then tex:SetAtlas(art) elseif tex and art then tex:SetTexture(art) end
        end
        close:SetSize(closeKept.w, closeKept.h)
        if closeKept.point[1] then ns.SetPointOnce(close, unpack(closeKept.point)) end
        closeKept = nil
    end
end

local function DressNew()
    LinkTipClose(true)
    for i = 1, #TIPS do
        local tip = _G[TIPS[i]]
        if tip and rims[tip] == nil then
            rims[tip] = false
            ns.SafeCall(Dress, tip)
        end
    end
end

-- The target and focus aura tooltip is forbidden; the client's own secure delegate styles it. A backdrop takes a file
-- rim only, so under bronze it wears Era's rim too, over the fill every look shares.
local auraClassic = false
local function StyleAuras()
    local want = active == true
    local inbound = _G.AuraContainerInbound
    if want == auraClassic or not inbound then return end
    if want then
        local ok = pcall(inbound.SetTooltipBackdrop, {
            backdropInfo = { bgFile = ART.WHITE, edgeFile = ART.TIP_BORDER, tile = true, tileEdge = true,
                tileSize = 16, edgeSize = EDGE, insets = { left = INSET, right = INSET, top = INSET, bottom = INSET } },
            borderColor = CreateColor(1, 1, 1, 1),
            centerColor = CreateColor(ERA_FILL[1], ERA_FILL[2], ERA_FILL[3], ERA_FILL[4]),
        })
        if ok then auraClassic = true end
    elseif pcall(inbound.ResetTooltipStyle) then
        auraClassic = false
    end
end

local watch
local function OnAddonLoaded()
    if not active then return end
    DressNew()
    if auraClassic ~= active and _G.AuraContainerInbound then ns.WhenCalm("tooltipAuras", StyleAuras) end
end

-- Every pass calls these: work only on a change.
local function Apply()
    if not watch then watch = ns.EventFrame("ADDON_LOADED", OnAddonLoaded) end
    active = true
    if ns.ThemeTurned(theme, "themePartTooltips") and (ns.ThemeLook(true, "themePartTooltips") == "client") ~= clientArt then
        clientArt = ns.ThemeLook(true, "themePartTooltips") == "client"
        for tip, rim in pairs(rims) do
            if rim then ns.SafeCall(Paint, tip, clientArt) end
        end
        ns.WhenCalm("tooltipAuras", StyleAuras)
    end
    DressNew()
end

local function Restore()
    if not active then return end
    active, theme.on, clientArt = false, nil, nil
    LinkTipClose(false)
    for tip, rim in pairs(rims) do
        if rim then ns.SafeCall(Paint, tip, nil) end
    end
    ns.WhenCalm("tooltipAuras", StyleAuras)
end

ns.RegisterModule("tooltips", { apply = Apply, restore = Restore })

-- A tooltip goes with its owner: a window shut under the mouse (X, Escape, key, a click elsewhere, its parent) never
-- sends OnLeave. Visibility only: the spellbook's spell tips come from buttons in the client's unseen window.
local function OwnerGone()
    local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
    if not ok or type(owner) ~= "table" or owner == UIParent or owner == _G.WorldFrame then return end
    local okVisible, visible = pcall(owner.IsVisible, owner)
    if okVisible and visible == false then GameTooltip:Hide() end
end
if GameTooltip then ns.Sched.Attach(GameTooltip, { name = "tooltip.owner", every = 0, fn = OwnerGone }) end
