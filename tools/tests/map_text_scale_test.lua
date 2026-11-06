-- Offline test under Lua 5.4 for the classic map's sizes (Map/WorldMapEraLarge.lua): windowed, the sheets shrink to the
-- game's own map height and nothing with text on it (the header, the zoom note, the pane's hole) wears that scale;
-- maximized the sheets are Era's own. The map frame never wears a style scale of its own (UI/WindowHandles.lua).
-- Run from the addon root: lua tools/tests/map_text_scale_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.01 end

------------------------------------------------------------------ the stub client

-- A frame or region: scale and size kept, the points as set, every other call a no-op; a field read answers nil.
local Stub = {}
local function NewStub() return setmetatable({ scale = 1, points = {} }, Stub) end
Stub.__index = function(_, key)
    if key == "Text" or not key:match("^%u") then return nil end
    if key == "SetScale" then return function(self, k) self.scale = k end end
    if key == "GetScale" then return function(self) return self.scale end end
    if key == "SetSize" then return function(self, w, h) self.w, self.h = w, h end end
    if key == "GetWidth" then return function(self) return self.w end end
    if key == "GetHeight" then return function(self) return self.h end end
    if key == "SetPoint" then return function(self, ...) self.points[#self.points + 1] = { ... } end end
    if key == "ClearAllPoints" then return function(self) self.points = {} end end
    if key == "GetNumPoints" then return function(self) return #self.points end end
    if key == "GetPoint" then return function(self, i) return table.unpack(self.points[i] or {}) end end
    if key == "GetStringWidth" then return function() return 50 end end
    if key == "CreateFontString" or key == "CreateTexture" then return function() return NewStub() end end
    return function() end
end

local ns = {}
ns.NewFrame = function() return NewStub() end
ns.EraDropdownArt = function() return NewStub() end
ns.PanelButton = function() return NewStub() end
ns.SetFile = function() end
ns.SetShownIf = function() end
ns.SetLevelIf = function() end
ns.SetSizeIf = function(frame, w, h) frame:SetSize(w, h) end
ns.SetScaleIf = function(frame, k) frame:SetScale(k) end
ns.SetPointIf = function(frame, ...)
    frame:ClearAllPoints()
    frame:SetPoint(...)
end
ns.WindowGripRoom = function() return 0 end
WORLD_MAP, CONTINENT, ZONE, ZOOM_OUT, ZOOM_OUT_BUTTON_TEXT = "World Map", "Continent", "Zone", "Zoom Out", "Right click"
Enum = { UIMapType = { World = 1, Continent = 2, Zone = 3 } }
C_Map = { GetMapInfo = function() return nil end }
MapUtil = {}
WorldMapFrame = NewStub()
WorldMapFrame.BorderFrame = NewStub()

assert(loadfile(ROOT .. "/Map/WorldMapEraLarge.lua"))("ClassicUIForever", ns)
local LM = ns.MapLarge

------------------------------------------------------------------ the checks

local WINDOWED = 534 / 768
local art = LM.Art(WorldMapFrame, 5)
local pieces = {}
LM.Keep(pieces)
local header, note
for piece in pairs(pieces) do
    if rawget(piece, "title") then header = piece elseif rawget(piece, "note") then note = piece end
end
Check(header and note, "the header and the zoom note are kept with the art")

LM.Fit(WINDOWED)
LM.Show(WorldMapFrame, nil, 7, nil)
Check(Near(art.scale, WINDOWED), "windowed, the sheets wear the game's map height")
Check(header.scale == 1 and note.scale == 1, "the header and the note keep the text's scale")
Check(Near(header.w, 1024 * WINDOWED) and Near(header.h, 70 * WINDOWED), "the header spans the sheets' band")
local FOOT = 30   -- the footer's rows stay the text's height
local w, h = LM.Size(nil)
Check(Near(w, 1024 * WINDOWED) and Near(h, 738 * WINDOWED + FOOT), "windowed, the map is the game's height plus the footer")
Check(Near(art.h, 738 + FOOT / WINDOWED), "the art holds the stretched footer")
local withPane = LM.Size(330)
Check(Near(withPane - w, 330 + 7 * WINDOWED), "the pane adds its own width, the divider at the sheets' scale")
local x1, _, x2 = LM.Pane(330)
Check(Near(x2 - x1, 330), "the pane's hole is the pane's width in the map's units")
local x = header.continentLabel.points[1]
Check(x and x[1] == "LEFT" and header.continent.points[1][2] == header.continentLabel,
    "windowed, the labels sit beside their drop downs in one row")
local notePoint = note.note.points[1]
Check(notePoint and Near(notePoint[4], (512 - 468) * WINDOWED) and Near(notePoint[5], -86 * WINDOWED),
    "the note sits over the picture's corner at the sheets' scale")
local rel, fx, fy = LM.FootLeft()
Check(rel == art and Near(fx, 11 * WINDOWED) and Near(fy, -(738 * WINDOWED + FOOT)), "the footer's left is in the map's units")
Check(Near(header.w, 1024 * WINDOWED), "the art lay keeps the header at the sheets' width in the map's units")

LM.Fit(1)
LM.Show(WorldMapFrame, nil, 7, nil)
Check(art.scale == 1 and header.scale == 1, "maximized, the sheets are Era's own")
Check(art.h == 768 and header.w == 1024, "maximized, the art and header are Era's sheets")
Check(Near(header.w, 1024) and Near(header.h, 70), "the header is Era's band")
local label = header.continentLabel.points[1]
Check(label and label[1] == "TOPLEFT" and label[2] == header.continent and label[5] == 12,
    "maximized, Era's labels over the drop downs")
w, h = LM.Size(nil)
Check(w == 1024 and h == 768, "maximized, Era's own size")
w = LM.Size(nil, WINDOWED)
Check(Near(w, 1024 * WINDOWED), "the edit mode box asks the windowed size whatever the map wears")

-- The map frame never wears a style scale: the sheets shrink, the frame stays at the player's size.
for _, file in ipairs({ "UI/WindowHandles.lua", "Map/WorldMapClassic.lua" }) do
    local f = assert(io.open(ROOT .. "/" .. file))
    local text = f:read("a")
    f:close()
    Check(not text:find("MapWindowedScale", 1, true), file .. " scales no map frame for the header style")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("map_text_scale_test: ok")
