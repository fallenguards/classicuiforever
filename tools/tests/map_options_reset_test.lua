-- Offline test under Lua 5.4 for the map filter's reset X under our Map Options box (Map/WorldMapOptions.lua). The game's
-- filter button (Camelot WorldMapTrackingOptionsButtonTemplate) carries a ResetButton at its top right, shown while a
-- map filter is off its default. Laid over our Era-style box it stood on the box's corner (#332): Era's drop down has
-- none. Under our box it stays unseen and takes no clicks, through the game's own shows; given back with the box.
-- Run from the addon root: lua tools/tests/map_options_reset_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end
unpack = table.unpack

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local Region = {}
local RegionMT = { __index = Region }
local function New(parent)
    return setmetatable({ _parent = parent, _alpha = 1, _shown = true, _mouse = true, _points = {}, _w = 0, _h = 0,
        _scale = 1 }, RegionMT)
end
function Region:SetSize(w, h) self._w, self._h = w, h end
function Region:GetWidth() return self._w end
function Region:GetHeight() return self._h end
function Region:SetScale(s) self._scale = s end
function Region:GetScale() return self._scale end
function Region:ClearAllPoints() self._points = {} end
function Region:SetPoint(...) self._points[#self._points + 1] = { ... } end
function Region:GetNumPoints() return #self._points end
function Region:GetPoint(i) return unpack(self._points[i]) end
function Region:SetAlpha(a) self._alpha = a end
function Region:GetAlpha() return self._alpha end
function Region:Show() self._shown = true end
function Region:Hide() self._shown = false end
function Region:SetShown(on) self._shown = on and true or false end
function Region:IsShown() return self._shown end
function Region:IsMouseOver() return false end
function Region:IsMouseEnabled() return self._mouse end
function Region:EnableMouse(on) self._mouse = on and true or false end
function Region:CreateFontString() local f = New(self) function f:SetText() end return f end
function Region:CreateTexture()
    local t = New(self)
    function t:SetTexture() end
    function t:GetTexture() return 1 end
    function t:SetTexCoord() end
    function t:GetTexCoord() return 0, 1, 0, 1 end
    function t:SetAllPoints() end
    function t:SetBlendMode() end
    return t
end
function Region:GetHighlightTexture() return self._hl end

MAP_OPTIONS_TEXT = "Map Options"

local ns = { db = {}, EMPTY = {} }
function ns.NewFrame(_, _, parent) return New(parent) end
function ns.EraDropdownArt(box) return box:CreateTexture() end
function ns.SetScaleIf(r, s) r:SetScale(s) end
function ns.SetPointIf(r, ...) r:ClearAllPoints() r:SetPoint(...) end
function ns.SetSizeIf(r, w, h) r:SetSize(w, h) end
function ns.SetAlphaIf(r, a) r:SetAlpha(a) end
function ns.FadeTextures() end
function ns.RegisterModule() end
function ns.EventFrame() end
assert(loadfile(ROOT .. "/Map/WorldMapOptions.lua"))("ClassicUIForever", ns)
local MO = ns.MapOptions

-- The map and the game's filter button as Forever hangs it, its reset X shown (a filter off its default).
local map = New()
map.BorderFrame = New(map)
local track = New(map)
track._hl = New(track)
track.Icon = New(track)
track.ResetButton = New(track)
map.WorldMapTrackingOptionsButton = track
track:SetPoint("TOPRIGHT", map, "TOPRIGHT", -4, -2)
local reset = track.ResetButton

MO.Place(map, map, 300, -400, 1)
Check(reset:GetAlpha() == 0, "under our box: the reset X unseen (it stood on the box's corner)")
Check(not reset:IsMouseEnabled(), "under our box: the reset X takes no clicks")

-- The game shows it again as a filter changes: still unseen, and nothing written twice.
reset:Hide()
reset:Show()
MO.Place(map, map, 300, -400, 1)
Check(reset:GetAlpha() == 0 and not reset:IsMouseEnabled(), "the game's own show: still unseen and deaf")

-- Hover mode and back: the X stays out of it.
ns.db.mapOptionsHover = true
MO.Place(map, map, 300, -400, 1)
Check(reset:GetAlpha() == 0, "on hover: the reset X still unseen")
ns.db.mapOptionsHover = nil

-- The game's own layout: its button whole again, the reset X with it.
MO.Release(map)
Check(reset:GetAlpha() == 1 and reset:IsMouseEnabled(), "the game's own layout: its reset X back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("map_options_reset_test: ok")
