-- Offline test under Lua 5.4 for Textured color's mask fit on a cropped piece (Art/ThemeLayers.lua). A layer's mask is
-- made over its piece's own box, then fitted to the whole sheet the piece is cut from, which needs the piece's size. Our
-- Options drop downs were painted before their rows were laid out (size 0): the fit gave up and nothing tried again, so
-- each of the three pieces drew the whole drop down squeezed into itself until a press (his snips 16:15, look339 v2). The
-- fit must come a frame later on its own, and again when the piece's frame changes size.
-- Run from the addon root: lua tools/tests/theme_mask_fit_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

-- Anything the code asks for that this test does not care about.
local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm" }) do AnyMT[op] = function() return 0 end end
AnyMT.__concat = function(a, b) return (type(a) == "table" and "" or tostring(a)) .. (type(b) == "table" and "" or tostring(b)) end
AnyMT.__lt = function() return false end
AnyMT.__le = function() return false end

local UIParent = { name = "UIParent" }
function UIParent:GetParent() return nil end

-- The drop down frame: its textures and masks made on it, its scripts hooked.
local hooks = {}
local dropdown = { name = "dropdown" }
function dropdown:GetParent() return UIParent end
function dropdown:IsVisible() return true end
function dropdown:IsShown() return true end
function dropdown:IsForbidden() return false end
function dropdown:IsProtected() return false end
function dropdown:IsObjectType() return false end
function dropdown:CreateTexture() return Any() end
local masks = {}
function dropdown:CreateMaskTexture()
    local mask = { points = {} }
    function mask:ClearAllPoints() self.points = {} end
    function mask:SetAllPoints(rel) self.points = { { "ALL", rel } } end
    function mask:SetPoint(point, rel, relPoint, x, y) self.points[#self.points + 1] = { point, rel, relPoint, x, y } end
    function mask:SetTexture() end
    masks[#masks + 1] = mask
    return mask
end

-- The left cap: Era's drop down sheet cut to its first 19.5 %, its size 0 until its row is laid out.
local size = { 0, 0 }
local piece = {}
function piece:GetParent() return dropdown end
function piece:GetSize() return size[1], size[2] end
function piece:GetTexCoord() return 0, 0, 0, 1, 0.1953125, 0, 0.1953125, 1 end
function piece:IsVisible() return true end
function piece:IsShown() return true end
function piece:GetAlpha() return 1 end
function piece:GetDrawLayer() return "BACKGROUND", 0 end
function piece:GetBlendMode() return "BLEND" end
function piece:GetNumMaskTextures() return 0 end
function piece:GetHorizTile() return false end
function piece:GetVertTile() return false end
function piece:GetTextureSliceMargins() return 0, 0, 0, 0 end
function piece:SetDesaturated() end
function piece:SetVertexColor() end
function piece:GetVertexColor() return 1, 1, 1 end
function piece:IsDesaturated() return false end
function piece:SetDrawLayer() end

-- The scheduler: the layer job's pass run by hand, next-frame calls queued.
local pass, nextFns = nil, {}
local job = {}
function job:IsAwake() return true end
function job:Kick() self.kicked = true end
function job:Burst() end
function job:Wake() end
function job:Sleep() end
local ns = Any()
rawset(ns, "bronze", { THEMES = {}, tinted = {} })
rawset(ns, "Sched", {
    Job = function(spec) pass = spec.fn return job end,
    NextFrame = function(key, fn) nextFns[key] = fn end,
    OnVisible = function() end,
})
rawset(ns, "HookScriptOnce", function(_, script, fn) hooks[script] = fn end)
rawset(ns, "ThemeFor", function() return { tint = { 0.9, 0.62, 0.32 } } end)
rawset(ns, "FlatOn", function() return false end)
rawset(ns, "ChromeArt", function() return false end)
rawset(ns, "MetalFile", function() return nil end)
rawset(ns, "MetalMask", function() return "theme-mask\\CharacterCreate-LabelFrame" end)
rawset(ns, "ParchMask", function() return nil end)
rawset(ns, "PictureMask", function() return nil end)
rawset(ns, "ThemePartOn", function() return false end)
rawset(ns, "AnySecret", function() return false end)
rawset(ns, "IsSecret", function() return false end)
rawset(ns, "IsForbidden", function() return false end)
rawset(ns, "Safe", function(v) return v end)
rawset(ns, "ThemeName", function() return "custom" end)
rawset(ns, "EachRegion", function() end)

local env = setmetatable({ UIParent = UIParent, GetTime = function() return 100 end }, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local handle = assert(io.open(ROOT .. "/Art/ThemeLayers.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Art/ThemeLayers.lua", "t", env))("ClassicUIForever", ns)

local function NextFrame()
    local fns = nextFns
    nextFns = {}
    for _, fn in pairs(fns) do fn() end
end
-- The fitted mask's right edge past the piece: the sheet's other 80.5 % at the piece's scale.
local function RightReach(mask)
    for _, p in ipairs(mask.points) do
        if p[1] == "BOTTOMRIGHT" then return p[4] end
    end
end

ns.PaintCopy(piece, "theme-base\\CharacterCreate-LabelFrame.tga", "CLAMP", "CLAMP")
local mask = masks[1]
Check(mask ~= nil, "the cap's layer wears a mask")
Check(mask and mask.points[1] and mask.points[1][1] == "ALL", "painted before its row is laid out, the mask lies over the cap's box")

-- The paint's own pass a frame later: the row still not laid out.
if pass then pass(nil, 100) end
Check(mask and mask.points[1] and mask.points[1][1] == "ALL", "still unsized a frame later, the mask waits")
-- Then the row is laid out, after the paint's quarter second burst: 25 x 51. No press on the window.
size[1], size[2] = 25, 51
NextFrame()
if pass then pass(nil, 101) end
local reach = mask and RightReach(mask)
Check(reach ~= nil and math.abs(reach - 25 / 0.1953125 * (1 - 0.1953125)) < 0.01,
    "a frame later the mask spans the whole sheet past the cap (" .. tostring(reach) .. ")")

-- The drop down sized again (wider window): its pieces' masks fitted to the new size.
size[1], size[2] = 30, 51
Check(hooks.OnSizeChanged ~= nil, "the drop down's size change is watched")
if hooks.OnSizeChanged then hooks.OnSizeChanged(dropdown) end
if pass then pass(nil, 102) end
reach = mask and RightReach(mask)
Check(reach ~= nil and math.abs(reach - 30 / 0.1953125 * (1 - 0.1953125)) < 0.01,
    "after a resize the mask is fitted to the new size (" .. tostring(reach) .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("theme_mask_fit_test: ok")
