-- Offline test for the colour themes' layers (Art/ThemeLayers.lua) under Lua 5.4.
-- The pass has no timer: it runs when told pieces may have moved (a paint, a window showing or going, a press on the
-- interface, a game event that restyles bars) and every frame only for a short burst after one or while a layer moves.
-- Read live 2026-10-04: 0 of 113 visible pieces changed in 10 s idle while the every-frame pass cost 1.04 ms a frame.
-- Run from the addon root: lua tools/tests/theme_layers_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

unpack = table.unpack

local failures = 0
local function Check(what, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: got %s, want %s", what, tostring(got), tostring(want)))
    end
end

------------------------------------------------------------------ the stub client

local asks = 0   -- calls on pieces and frames, the game's side of the cost
local Texture = {}
Texture.__index = Texture
local function NewTexture(parent)
    return setmetatable({ parent = parent, shown = true, alpha = 1, layer = "ARTWORK", sub = 0, crop = 1, crops = 0 }, Texture)
end
function Texture:GetParent() return self.parent end
function Texture:IsShown() asks = asks + 1 return self.shown end
function Texture:IsVisible() asks = asks + 1 return self.shown and self.parent.visible end
function Texture:GetAlpha() asks = asks + 1 return self.alpha end
function Texture:SetAlpha(alpha) self.alpha = alpha end
function Texture:SetShown(shown) self.shown = shown end
function Texture:Hide() self.shown = false end
function Texture:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, self.crop end
function Texture:SetTexCoord(_, _, _, _, _, _, _, crop) self.crop, self.crops = crop, self.crops + 1 end
function Texture:GetDrawLayer() return self.layer, self.sub end
function Texture:SetDrawLayer(layer, sub) self.layer, self.sub = layer, sub end
function Texture:SetAllPoints() end
function Texture:SetTexture() self.files = (self.files or 0) + 1 end
function Texture:SetBlendMode() end
function Texture:GetBlendMode() return "BLEND" end
function Texture:SetVertexColor() end
function Texture:AddMaskTexture(mask) self.mask = mask end
function Texture:RemoveMaskTexture(mask) if self.mask == mask then self.mask = nil end end

UIParent = { name = "UIParent" }
function UIParent:GetParent() return nil end
WorldFrame = { name = "WorldFrame" }
function WorldFrame:GetParent() return nil end

local function NewFrame(visible, parent)
    local frame = { visible = visible, regions = {}, parent = parent, asked = 0 }
    function frame:IsVisible()
        asks, self.asked = asks + 1, self.asked + 1
        return self.visible
    end
    function frame:GetParent() return self.parent end
    function frame:CreateTexture()
        local tex = NewTexture(self)
        self.regions[#self.regions + 1] = tex
        return tex
    end
    return frame
end

------------------------------------------------------------------ the stub addon

local pass, every, awake, kicks, bursts = nil, nil, false, 0, 0
local clock = 1000
function GetTime() return clock end
local edges = {}        -- root -> the visibility callback set on it
local onEvent, heard = nil, false
local focus
function GetMouseFoci() return { focus } end
local job = {
    Wake = function() awake = true end,
    Sleep = function() awake = false end,
    IsAwake = function() return awake end,
    Kick = function() kicks = kicks + 1 end,
    Burst = function() bursts = bursts + 1 end,
}
local ns = {
    bronze = { THEMES = { test = { colorCopies = true, tint = { 1, 1, 1 } } }, THEME_KEYS = {}, artKey = {} },
    ThemeName = function() return "test" end,
    FlatOn = function() return false end,
    FlatCopy = function() return nil end,
    IsSecret = function() return false end,
    AnySecret = function() return false end,
    IsForbidden = function() return false end,
    Safe = function(value) return value end,
    SetShownIf = function(tex, shown)
        shown = shown and true or false
        if tex.shown == shown then return false end
        tex.shown = shown
        return true
    end,
    SetAlphaIf = function(tex, alpha)
        if tex.alpha == alpha then return false end
        tex.alpha = alpha
        return true
    end,
    EachRegion = function(frame, fn) for _, region in ipairs(frame.regions) do fn(region) end end,
    OnToggle = function() end,
    EventFrame = function(_, fn)
        onEvent = fn
        return { UnregisterAllEvents = function() heard = false end }
    end,
    RegisterEvents = function() heard = true end,
    Sched = {
        Job = function(spec)
            pass, every = spec.fn, spec.every
            return job
        end,
        OnVisible = function(host, _, fn) edges[host] = fn end,
    },
}
assert(loadfile(ROOT .. "/Art/ThemeLayers.lua"))("ClassicUIForever", ns)
-- One pass of the job, a second later unless told.
local jobPass = pass
pass = function(after)
    clock = clock + (after or 1)
    jobPass(nil, clock)
end
-- A whole pass asked for, then run.
local function Whole()
    ns.FollowLayers()
    pass()
end

------------------------------------------------------------------ the cases

local COPY = "Interface\\AddOns\\ClassicUIForever\\media\\custom\\piece.tga"
Check("the pass has no timer", every, math.huge)
Check("no events before a layer is on", heard, false)

local shutRoot, openRoot = NewFrame(false, UIParent), NewFrame(true, UIParent)
local shut, open = NewFrame(false, shutRoot), NewFrame(true, openRoot)
local shutPieces, openPiece = {}, open:CreateTexture()
for i = 1, 50 do
    shutPieces[i] = shut:CreateTexture()
    ns.PaintCopy(shutPieces[i], COPY)
end
ns.PaintCopy(openPiece, COPY)
Check("the pass is awake with layers on", awake, true)
Check("events are heard with layers on", heard, true)
Check("each window's root is watched, not its inner frame", edges[shutRoot] ~= nil and edges[openRoot] ~= nil
    and edges[shut] == nil and edges[open] == nil, true)
Check("a paint asks for one pass, no burst", kicks > 0 and bursts == 0, true)

-- At rest: a pass nobody asked for does nothing at all.
pass()
asks = 0
pass()
Check("with nothing said a pass asks the game nothing", asks, 0)

-- A whole pass: a shut window's frame is asked once, its pieces never; nothing moved, so no burst.
ns.FollowLayers()
kicks, bursts, asks = 0, 0, 0
pass()
Check("a shut window's 50 pieces cost one ask a pass", asks <= 8, true)
Check("a quiet pass asks for no burst", bursts, 0)

-- A press on a window follows that window's pieces alone through the burst; no other window's frame is asked.
local shut2 = NewFrame(false, shutRoot)
local shut2Piece = shut2:CreateTexture()
ns.PaintCopy(shut2Piece, COPY)
local other = NewFrame(true, UIParent)
local otherPiece = other:CreateTexture()
ns.PaintCopy(otherPiece, COPY)
pass()
focus = open
onEvent(nil, "GLOBAL_MOUSE_DOWN")
shut.asked, shut2.asked, other.asked, open.asked = 0, 0, 0, 0
pass(0.01)
Check("a press follows its own window", open.asked, 1)
Check("a press asks no other window's frames", shut.asked + shut2.asked + other.asked, 0)
ns.FollowLayers()
pass(0.01)
Check("the pass a window edge asks for asks every frame", shut.asked == 1 and shut2.asked == 1 and other.asked == 1, true)

-- A visible frame's layer follows its piece, and a pass that moved one keeps going.
local metal
for _, region in ipairs(open.regions) do
    if region ~= openPiece then metal = region end
end
Check("the open piece has its metal layer", metal ~= nil, true)
pass(5)
openPiece.shown = false
ns.FollowLayers()
bursts = 0
pass()
Check("the layer hides with its piece", metal.shown, false)
Check("a pass that moved a layer bursts", bursts, 1)
openPiece.shown, openPiece.alpha = true, 0.5
pass(0.01)
Check("the burst's next pass follows the piece again", metal.shown, true)
Check("the layer takes its piece's alpha", metal.alpha, 0.5)

-- The crop is written when it changes, not on every pass.
Whole()
local written = metal.crops
Whole()
Whole()
Check("an unchanged crop is not written again", metal.crops, written)
openPiece.crop = 0.5
Whole()
Check("a changed crop reaches the layer", metal.crop, 0.5)

-- The same art painted again (the client reset a button's texture and crop, we put ours back, once a second on the
-- game menu button): the layers are not rebuilt, and the pass after it follows that piece alone and moves nothing.
pass(5)
local files, crops = metal.files, metal.crops
kicks, bursts = 0, 0
local ours = openPiece.crop
openPiece.crop = 0.9
ns.PaintCopy(openPiece, COPY)
openPiece.crop = ours
Check("the same art again does not rebuild the layer", metal.files, files)
Check("the same art again asks for one pass", kicks == 1 and bursts == 0, true)
asks, shut.asked = 0, 0
pass()
Check("the pass after a repaint of the same art moves nothing", metal.crops == crops and bursts == 0, true)
Check("that pass follows the painted piece alone, no whole pass", asks <= 4 and shut.asked == 0, true)

-- The signals: a window showing or going and a press on the interface burst; a game event asks one pass; a press on
-- the world asks nothing.
kicks, bursts = 0, 0
edges[shutRoot](true)
Check("a window showing asks for a burst", kicks == 1 and bursts == 1, true)
edges[shutRoot](false)
Check("a window going asks for a burst", kicks == 2 and bursts == 2, true)
focus = open
onEvent(nil, "GLOBAL_MOUSE_DOWN")
Check("a press on the interface asks for a burst", kicks == 3 and bursts == 3, true)
focus = WorldFrame
onEvent(nil, "GLOBAL_MOUSE_DOWN")
Check("a press on the world asks for none", kicks, 3)
focus = nil
onEvent(nil, "GLOBAL_MOUSE_UP")
Check("a press on nothing asks for none", kicks, 3)
onEvent(nil, "PLAYER_TARGET_CHANGED")
Check("a game event asks for one pass, no burst", kicks == 4 and bursts == 3, true)
ns.FollowLayers()
Check("the shared signal with no window asks for one pass", kicks == 5 and bursts == 3, true)
ns.FollowLayers(open)
Check("the shared signal with a window bursts that window", kicks == 6 and bursts == 4, true)

-- A window opening: its pieces are followed in the pass its root's edge asked for.
pass(5)
shutPieces[1].alpha = 0.25
shut.visible, shutRoot.visible = true, true
edges[shutRoot](true)
pass(0.01)
local followed = false
for _, region in ipairs(shut.regions) do
    if region.alpha == 0.25 and region ~= shutPieces[1] then followed = true end
end
Check("an opened window's layers follow at once", followed, true)

-- A bar page or stance change restyles that bar's buttons alone: only what stands in its holder is followed.
MainActionBar, StanceBar = {}, {}
local holder, stanceHolder = NewFrame(true, UIParent), NewFrame(true, UIParent)
local button, stanceButton = NewFrame(true, holder), NewFrame(true, stanceHolder)
local buttonPiece, stancePiece = button:CreateTexture(), stanceButton:CreateTexture()
ns.PaintCopy(buttonPiece, COPY)
ns.PaintCopy(stancePiece, COPY)
ns.band = { HolderOf = function(bar)
    if bar == MainActionBar then return holder end
    if bar == StanceBar then return stanceHolder end
end }
pass(5)
pass(5)
button.asked, stanceButton.asked, open.asked, other.asked, shut.asked = 0, 0, 0, 0, 0
onEvent(nil, "UPDATE_BONUS_ACTIONBAR")
pass(0.01)
Check("a page change follows bar 1's buttons", button.asked, 1)
Check("a page change asks no other bar's or window's frames", stanceButton.asked + open.asked + other.asked + shut.asked, 0)
onEvent(nil, "UPDATE_SHAPESHIFT_FORMS")
pass(0.01)
Check("a stance change follows the stance bar's buttons alone", stanceButton.asked == 1 and button.asked == 1, true)
onEvent(nil, "PLAYER_TARGET_CHANGED")
pass(0.01)
Check("another game event follows every frame", open.asked == 1 and other.asked == 1 and button.asked == 2, true)
ns.PaintCopy(buttonPiece, nil)
ns.PaintCopy(stancePiece, nil)
ns.band, MainActionBar, StanceBar = nil, nil, nil

-- A piece off UIParent (a nameplate) gets no watcher and still paints.
local plate = NewFrame(true, WorldFrame)
local platePiece = plate:CreateTexture()
ns.PaintCopy(platePiece, COPY)
Check("a frame off UIParent is not watched", edges[plate], nil)

-- A mask on a piece (a minimap button's ring cut off) goes on its layer too, made before or after it (#194).
local ring = NewFrame(true, UIParent)
local ringPiece, disc = ring:CreateTexture(), {}
ns.PaintCopy(ringPiece, COPY)
ns.WearMask(ringPiece, disc, true)
Check("a mask reaches the piece's layer", ring.regions[2].mask, disc)
ns.WearMask(ringPiece, disc, false)
Check("a mask off leaves the layer whole", ring.regions[2].mask == nil and ringPiece.mask == nil, true)
local ring2 = NewFrame(true, UIParent)
local ring2Piece = ring2:CreateTexture()
ns.WearMask(ring2Piece, disc, true)
ns.PaintCopy(ring2Piece, COPY)
Check("a layer made after the mask wears it", ring2.regions[2].mask, disc)
ns.PaintCopy(ringPiece, nil)
ns.PaintCopy(ring2Piece, nil)

-- Every layer off: the next whole pass puts the job to sleep and drops the events.
for i = 1, 50 do ns.PaintCopy(shutPieces[i], nil) end
ns.PaintCopy(openPiece, nil)
ns.PaintCopy(platePiece, nil)
ns.PaintCopy(shut2Piece, nil)
ns.PaintCopy(otherPiece, nil)
Whole()
Check("the pass sleeps with no layer on", awake, false)
Check("events are not heard with no layer on", heard, false)
kicks = 0
ns.FollowLayers()
Check("a signal with the pass asleep asks for nothing", kicks, 0)

print(failures == 0 and "theme layers: ok" or ("theme layers: " .. failures .. " failures"))
if failures > 0 then os.exit(1) end
