-- Offline test under Lua 5.4 for the settings window's Era skin (Options/SettingsPanel.lua): the frame border is our
-- own themed art on the client's pieces (no atlas left for the client-copy path), set by file with its wraps so
-- the theme's repaint keeps them, and every Era sheet the window draws is a themed sheet (masks in Art/ThemeArt.lua).
-- Run from the addon root: lua tools/tests/settings_panel_theme_test.lua (CI runs every tools/tests/*_test.lua).
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

------------------------------------------------------------------ the stub client

local Tex = {}
Tex.__index = Tex
local function NewTex(atlas, parent) return setmetatable({ atlas = atlas, parent = parent }, Tex) end
function Tex:IsObjectType(kind) return kind == "Texture" end
function Tex:GetAtlas() return self.atlas end
function Tex:SetAtlas(atlas)
    self.atlas = atlas
    self.atlasSets = (self.atlasSets or 0) + 1
end
function Tex:SetTexture(file, wrapH, wrapV)
    self.file, self.wrapH, self.wrapV, self.atlas = file, wrapH, wrapV, nil
    return true
end
function Tex:GetTexture() return self.file end
function Tex:SetTexCoord(...) self.coords = { ... } end
function Tex:GetTexCoord() return 0, 1, 0, 1 end
function Tex:SetHorizTile(on) self.tileH = on end
function Tex:SetVertTile(on) self.tileV = on end
function Tex:SetWidth(w) self.w = w end
function Tex:SetHeight(h) self.h = h end
function Tex:GetParent() return self.parent end
function Tex:GetDrawLayer() return "ARTWORK", 0 end
function Tex:SetAllPoints() end
function Tex:Show() end

local Frame = {}
Frame.__index = Frame
local function NewFrame(name) return setmetatable({ name = name, regions = {}, children = {} }, Frame) end
function Frame:IsShown() return true end
function Frame:GetName() return self.name end
function Frame:HookScript(_, fn) self.onShow = fn end
function Frame:CreateTexture() return NewTex(nil, self) end

local panel = NewFrame("SettingsPanel")
panel.NineSlice = NewFrame("NineSlice")
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
    "LeftEdge", "RightEdge" }
for _, name in ipairs(PIECES) do panel.NineSlice[name] = NewTex("UI-Frame-Metal-" .. name, panel.NineSlice) end
panel.ClosePanelButton = NewFrame("ClosePanelButton")
local header = NewTex("Options_CategoryHeader_1", panel)
panel.regions = { header }
SettingsPanel = panel

------------------------------------------------------------------ the addon

local noop = function() end
local ns = { bronze = {} }
assert(loadfile(ROOT .. "/Art/TextureData.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Art/ThemeArt.lua"))("ClassicUIForever", ns)
local MEDIA = "Interface\\AddOns\\ClassicUIForever\\media\\"
-- Textures.lua's path for a key of ours ("!File").
ns.TexPaths = function(key)
    local spec = ns.TEX[key]
    Check(type(spec) == "string" and spec:sub(1, 1) == "!", tostring(key) .. " is a key of our own art")
    return MEDIA .. spec:sub(2), MEDIA .. spec:sub(2), false
end
-- A sheet the theme has: listed in Art/ThemeArt.lua by file name.
local themed = {}
for file in ns.THEME_ART:gmatch("[^\n]+") do themed[file:match("([^\\]+)%.%w+$"):lower()] = true end
local function Themed(path)
    local base = path:match("([^\\/]+)$")
    return base ~= nil and themed[(base:gsub("%.%w+$", "")):lower()] == true
end

local filed = {}
ns.SetFile = function(tex, path, wrapH, wrapV)
    filed[tex] = path
    tex:SetTexture(path, wrapH, wrapV)
end
local keyed = {}
ns.SetTex = function(tex, key, wrapH, wrapV)
    keyed[tex] = key
    tex:SetTexture("key:" .. key, wrapH, wrapV)
end
ns.IsSecret = function() return false end
ns.IsForbidden = function() return false end
ns.SetPointOnce, ns.SetPointIf, ns.SetTwoPointsIf, ns.SetAlphaIf = noop, noop, noop, noop
ns.SkinCloseButton, ns.MissingPiece = noop, noop
ns.Once = function(frame, key)
    if frame[key] then return false end
    frame[key] = true
    return true
end
ns.NewFrame = function() return {} end
ns.OwnTexture = function(frame, key)
    frame[key] = frame[key] or NewTex(nil, frame)
    return frame[key]
end
ns.TileTex = function(tex) return tex end
ns.Sched = { OnFrame = function(_, spec) return { Kick = spec.fn } end }
ns.EachRegion = function(frame, fn, ...)
    for _, region in ipairs(frame.regions) do fn(region, ...) end
end
ns.EachChild = function(frame, fn, ...)
    for _, child in ipairs(frame.children) do fn(child, ...) end
end
local module
ns.RegisterModule = function(_, spec) module = spec end
assert(loadfile(ROOT .. "/Options/SettingsPanel.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ the border

module.apply()

local TILED = { TopEdge = "H", BottomEdge = "H", LeftEdge = "V", RightEdge = "V" }
for _, name in ipairs(PIECES) do
    local tex = panel.NineSlice[name]
    Check(tex.atlasSets == nil and tex.atlas == nil, name .. " carries no atlas (our file, not the client-copy path)")
    Check(filed[tex] ~= nil and filed[tex]:find("theme%-base\\UIFrame%-") ~= nil, name .. " is set by file from a theme copy")
    Check(filed[tex] ~= nil and Themed(filed[tex]), name .. "'s sheet is a themed sheet, so its masks dress it")
    Check(tex.coords and tex.coords[2] <= 1 and tex.coords[4] <= 1, name .. " has its sheet coords")
    Check(tex.tileH == (TILED[name] == "H") and tex.tileV == (TILED[name] == "V"), name .. " tiles as its strip does")
    Check(tex.wrapH == (TILED[name] == "H" and "REPEAT" or "CLAMP") and tex.wrapV == (TILED[name] == "V" and "REPEAT" or "CLAMP"),
        name .. " wraps along its tiled side only")
end

------------------------------------------------------------------ Era's sheets

Check(keyed[header] == "eraOptions" and header.atlas == nil, "a category header draws from Era's options sheet")
-- Every sheet the skin's atlas table names (its "era..." keys) is a themed sheet.
local source = assert(io.open(ROOT .. "/Options/SettingsPanel.lua")):read("a")
local sheets, count = {}, 0
for key in source:gmatch('= { "(era%w+)",') do
    if not sheets[key] then
        sheets[key], count = true, count + 1
        local path = select(1, ns.TexPaths(key))
        Check(Themed(path), key .. " is a themed sheet (run dev/tools/bronze_variants.py)")
    end
end
Check(count >= 6, "the skin names its Era sheets (" .. count .. " found)")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("settings_panel_theme_test: ok")
