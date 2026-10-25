-- Offline test under Lua 5.4 for draining and tinting a nine-slice's edges (Art/Bronze.lua): the theme's own layers and
-- masks hang in the same frame and keep their paint. Drained as edges, the social inset's metal layers went white.
-- Run from the addon root: lua tools/tests/slice_drain_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Region(kind)
    local r = { kind = kind, painted = 0 }
    function r:GetObjectType() return self.kind end
    function r:IsObjectType(k) return k == "Texture" end
    function r:SetDesaturated() self.painted = self.painted + 1 end
    function r:SetVertexColor() self.painted = self.painted + 1 end
    return r
end

local layer = Region("Texture")
local noop = function() end
local ns = {
    bronze = { THEMES = { bronze = { tint = { 0.9, 0.62, 0.32 } } } },
    ThemeName = function() return "bronze" end,
    ThemeFor = function() return { tint = { 0.9, 0.62, 0.32 } } end,
    FlatOn = function() return false end,
    OnForever = function() return true end,
    IsThemeLayer = function(region) return region == layer end,
    OnToggle = noop,
    RegisterModule = noop,
}
function ns.EachRegion(frame, fn, ...)
    for _, region in ipairs(frame.regions) do fn(region, ...) end
end
assert(loadfile(ROOT .. "/Art/Bronze.lua"))("ClassicUIForever", ns)

local edge, center, mask = Region("Texture"), Region("Texture"), Region("MaskTexture")
local slice = { Center = center, regions = { edge, center, layer, mask } }
ns.DrainSlice(slice)
Check(edge.painted > 0, "the slice's edge is drained")
Check(center.painted == 0, "the slice's center keeps its paint")
Check(layer.painted == 0, "the theme's layer in the slice keeps its paint when drained")
Check(mask.painted == 0, "a mask in the slice is left alone when drained")

edge.painted = 0
ns.TintSlice(slice)
Check(edge.painted > 0, "the slice's edge is tinted")
Check(layer.painted == 0 and mask.painted == 0, "the theme's layer and masks keep their paint when tinted")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("slice_drain_test: ok")
