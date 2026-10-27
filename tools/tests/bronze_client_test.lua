-- Offline tests for Art/BronzeClient.lua under Lua 5.4: client art handed back keeps the client's crop.
-- Run from the addon root: lua tools/tests/bronze_client_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

-- A texture: a file (client file id or our copy's path) or an atlas, which brings its own crop.
local Tex = {}
Tex.__index = Tex
local function NewTex(file, coords) return setmetatable({ file = file, coords = coords }, Tex) end
function Tex:SetTexture(file)
    self.file, self.atlas = file, nil
    return true
end
function Tex:GetTexture() return self.file end
function Tex:SetTexCoord(...) self.coords = { ... } end
function Tex:GetTexCoord() return table.unpack(self.coords) end
function Tex:SetAtlas(atlas)
    self.atlas, self.file, self.coords = atlas, "atlas:" .. atlas, { 0, 1, 0, 1 }
end
function Tex:GetAtlas() return self.atlas end
function Tex:SetHorizTile() end
function Tex:SetVertTile() end
function Tex:IsObjectType(kind) return kind == "Texture" end

C_Texture = { GetAtlasInfo = function() return nil end }

------------------------------------------------------------------ the addon

local themeOn = true
local noop = function() end
local job = { Wake = noop, Kick = noop, Sleep = noop, Burst = noop }
local plainTree              -- the subtree the walks leave out (the talent tree's nodes)
local ns = { db = {}, bronze = { tinted = {}, swapped = {}, THEME_KEYS = {},
    PlainTree = function(frame) return frame == plainTree end } }
ns.BronzeCopy = function(name) return themeOn and ("copy\\" .. name) or nil end
ns.BronzeOn = function() return themeOn end
ns.IsSecret = function() return false end
ns.IsForbidden = function() return false end
local walked = {}            -- window -> times its tree was walked
local passes, edges = {}, {} -- job name -> its pass; window -> its visibility callback
local paints = {}            -- window -> its paint ahead of the first draw
ns.EachRegionProtected = function(frame) walked[frame] = (walked[frame] or 0) + 1 end
ns.EachChildProtected, ns.EachChild = noop, noop
ns.Sched = {
    Job = function(spec)
        passes[spec.name] = spec.fn
        return job
    end,
    OnVisible = function(window, _, fn) edges[window] = fn end,
    AfterShow = function(window, _, fn) paints[window] = fn end,
    AfterPerFrame = noop,
}
ns.OnToggle, ns.RegisterEvents, ns.UntintGameArt, ns.PaintCopy, ns.BronzeRim = noop, noop, noop, noop, noop
ns.FollowLayers = noop
ns.EventFrame = function() return {} end
ns.ThemeTurned = function() return false end
ns.ThemePartOn = function() return true end
-- One client window of the list, open.
CharacterFrame = { GetRegions = noop, IsShown = function() return true end }

assert(loadfile(ROOT .. "/Art/BronzeClient.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end
local function Coords(tex) return table.concat(tex.coords, ",") end

-- A red panel button's middle slice (SecureUIPanelTemplates.xml): file 130828, the sheet's 0.09375 to 0.53125.
local MIDDLE = "0.09375,0.53125,0,0.6875"
local middle = NewTex(130828, { 0.09375, 0.53125, 0, 0.6875 })
ns.BronzeClientTexture(middle)
Check(middle.file == "copy\\UI-Panel-Button-Up.tga", "theme on: the middle slice shows the copy (" .. tostring(middle.file) .. ")")
Check(Coords(middle) == MIDDLE, "theme on: the middle slice keeps its crop (" .. Coords(middle) .. ")")
ns.BronzeClientTexture(middle, true)
Check(middle.file == 130828, "handed back: the client's file again (" .. tostring(middle.file) .. ")")
Check(Coords(middle) == MIDDLE, "handed back: the middle slice keeps its crop, not the whole sheet (" .. Coords(middle) .. ")")
-- One theme to another: handed back, then the new copy on the same crop.
ns.BronzeClientTexture(middle)
Check(Coords(middle) == MIDDLE, "theme turned: the middle slice keeps its crop (" .. Coords(middle) .. ")")

-- An atlas piece (the game menu's red button) gets its atlas back, with the atlas's own crop.
local cap = NewTex(nil, { 0, 1, 0, 1 })
cap:SetAtlas("128-RedButton-Left")
ns.BronzeClientTexture(cap)
Check(cap.file == "copy\\RedButtonLeft.tga", "theme on: the cap shows its own copy (" .. tostring(cap.file) .. ")")
Check(Coords(cap) == "0,1,0,1", "theme on: the cap's whole piece, as its atlas (" .. Coords(cap) .. ")")
-- The game crops a narrow button's cap by its piece's extent after the swap (ThreeSliceButtonMixin.UpdateScale): the
-- crop stays on the copy, which is that extent.
cap:SetTexCoord(0, 0.6, 0, 1)
ns.BronzeClientTexture(cap)
Check(cap.file == "copy\\RedButtonLeft.tga" and Coords(cap) == "0,0.6,0,1", "the game's crop kept on the copy")
local pressed = NewTex(nil, { 0, 1, 0, 1 })
pressed:SetAtlas("128-RedButton-Right-Pressed")
ns.BronzeClientTexture(pressed)
Check(pressed.file == "copy\\RedButtonRight-Pressed.tga", "a pressed cap: its state's copy (" .. tostring(pressed.file) .. ")")
ns.BronzeClientTexture(cap, true)
Check(cap.atlas == "128-RedButton-Left" and Coords(cap) == "0,1,0,1", "handed back: the cap's atlas and its crop")

-- The beat never walks a window (67 thousand calls a pass with one open, read live 2026-10-04): a window is walked
-- three times as it opens and then left alone.
local Pass = passes["bronze.client"]
Pass(job)
Pass(job)
Check(walked[CharacterFrame] == nil, "an open window is not walked on the beat")
Check(edges[CharacterFrame] ~= nil, "the window is watched for its opening")
edges[CharacterFrame](true)
for _ = 1, 5 do Pass(job) end
Check(walked[CharacterFrame] == 3, "an opening window is walked three times, then no more (" .. tostring(walked[CharacterFrame]) .. ")")
edges[CharacterFrame](false)
Pass(job)
Check(walked[CharacterFrame] == 3, "a window going is not walked")

-- A subtree with no art of the theme's (the talent tree: 92 thousand calls a walk, read live 2026-10-04) is left out.
plainTree = CharacterFrame
edges[CharacterFrame](true)
for _ = 1, 3 do Pass(job) end
Check(walked[CharacterFrame] == 3, "a plain subtree is not walked (" .. tostring(walked[CharacterFrame]) .. ")")
plainTree = nil

-- A copy the client reset is put back on the beat, with no walk.
local reset = NewTex(130828, { 0, 1, 0, 1 })
ns.BronzeClientTexture(reset)
reset:SetTexture(130828)
Pass(job)
Check(reset.file == "copy\\UI-Panel-Button-Up.tga", "a reset copy is put back on the beat (" .. tostring(reset.file) .. ")")
Check(walked[CharacterFrame] == 3, "putting a copy back walks no window")

-- Painted after its show pass, ahead of its first draw: no frame of the game's own colors as it opens.
Check(paints[CharacterFrame] ~= nil, "the window's opening is painted before it draws")
local before = walked[CharacterFrame] or 0
if paints[CharacterFrame] then paints[CharacterFrame]() end
Check(walked[CharacterFrame] == before + 1, "the paint ahead of the draw walks the window once")

if failures > 0 then
    print(string.format("bronze client: %d failed", failures))
    os.exit(1)
end
print("bronze client: ok")
