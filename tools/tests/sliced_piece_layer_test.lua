-- Offline test under Lua 5.4 for Textured color on a sliced piece (Art/ThemeLayers.lua ns.PaintCopy). The game slices
-- the Options window's drop down buttons (24 px kept at each end, the middle stretched); Textured color laid a copy over
-- each under a mask of the whole sheet stretched over its box, which cannot be sliced, so a stretched button showed
-- inside every drop down (#339; his /fcuidev dump: a 1536x256 mask on each 234x39 button, slice339: margins 24,0,24,0;
-- composited offline from our files, the screenshot's look exactly). A sliced piece takes the theme's color whole and
-- gets no layer; a plain piece still gets its layer. The whole file is loaded against stand-ins.
-- Run from the addon root: lua tools/tests/sliced_piece_layer_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
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

local TINT = { 0.9, 0.62, 0.32 }
local THEME = { tint = TINT }

-- A drop down button: its piece (sliced or not) and the textures made on it.
local function Button(margins)
    local made = {}
    local parent = setmetatable({}, { __index = function(_, k)
        if k == "CreateTexture" then
            return function()
                local tex = Any()
                made[#made + 1] = tex
                return tex
            end
        end
        if k == "CreateMaskTexture" then return function() return Any() end end
        return function() return Any() end
    end })
    local piece = { desat = false, color = { 1, 1, 1 } }
    setmetatable(piece, { __index = function(_, k)
        if k == "GetParent" then return function() return parent end end
        if k == "GetTextureSliceMargins" then return function() return table.unpack(margins) end end
        if k == "SetDesaturated" then return function(self, on) self.desat = on end end
        if k == "SetVertexColor" then return function(self, r, g, b) self.color = { r, g, b } end end
        if k == "IsVisible" or k == "IsShown" then return function() return true end end
        if k == "GetBlendMode" then return function() return "BLEND" end end
        if k == "GetNumMaskTextures" then return function() return 0 end end
        if k == "GetHorizTile" or k == "GetVertTile" then return function() return false end end
        if type(k) == "string" and k:match("^%u") then return function() return nil end end
    end })
    return piece, made
end

local ns = Any()
rawset(ns, "bronze", { THEMES = {}, tinted = {} })
rawset(ns, "ThemeFor", function() return THEME end)
rawset(ns, "FlatOn", function() return false end)
rawset(ns, "ChromeArt", function() return false end)
rawset(ns, "MetalFile", function() return nil end)
rawset(ns, "MetalMask", function() return "Interface\\AddOns\\ClassicUIForever\\media\\theme-mask\\EraDropdownC" end)
rawset(ns, "ParchMask", function() return nil end)
rawset(ns, "PictureMask", function() return nil end)
rawset(ns, "ThemePartOn", function() return false end)
rawset(ns, "AnySecret", function() return false end)
rawset(ns, "Safe", function(v) return v end)
rawset(ns, "ThemeName", function() return "bronze" end)

local env = setmetatable({}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local handle = assert(io.open(ROOT .. "/Art/ThemeLayers.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Art/ThemeLayers.lua", "t", env))("ClassicUIForever", ns)

local COPY = "Interface\\AddOns\\ClassicUIForever\\media\\EraDropdownC"

local sliced, slicedMade = Button({ 24, 0, 24, 0 })
pcall(ns.PaintCopy, sliced, COPY, "CLAMP", "CLAMP")
Check(#slicedMade == 0, "a sliced drop down gets no layer over it (" .. #slicedMade .. " texture(s) made)")
Check(sliced.desat == true and sliced.color[1] == TINT[1] and sliced.color[2] == TINT[2] and sliced.color[3] == TINT[3],
    "a sliced drop down takes the theme's color whole")

local plain, plainMade = Button({ 0, 0, 0, 0 })
pcall(ns.PaintCopy, plain, COPY, "CLAMP", "CLAMP")
Check(#plainMade > 0, "a piece that is not sliced still gets its Textured color layer")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("sliced_piece_layer_test: ok")
