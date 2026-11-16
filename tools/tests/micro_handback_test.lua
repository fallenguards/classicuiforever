-- Offline test under Lua 5.4 for handing a micro button its own art back (Bar/MicroFlash.lua ns.ClientMicroArt): the
-- four atlases and the tabard tint as the client's LoadMicroButtonTextures draws them, with no field written on the
-- button. That call writes textureName, and written by us the client's next micro pass ran in our name: the character
-- window refused its health text and the game menu its Log Out and Exit (2026-11-15). No file of ours calls it.
-- Run from the addon root: lua tools/tests/micro_handback_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local ns = {}
assert(loadfile(ROOT .. "/Bar/MicroFlash.lua"))("ClassicUIForever", ns)
Check(type(ns.ClientMicroArt) == "function", "ns.ClientMicroArt exists")

local function Tex()
    local t = {}
    function t:SetVertexColor(r, g, b) self.color = { r, g, b } end
    return t
end
local textures = { Normal = Tex(), Pushed = Tex(), Disabled = Tex(), Highlight = Tex() }
local atlases, writes = {}, {}
local fields = {
    textureName = "Guild",
    Emblem = { IsShown = function() return true end },
}
for _, kind in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
    fields["Set" .. kind .. "Atlas"] = function(_, atlas) atlases[kind] = atlas end
    fields["Get" .. kind .. "Texture"] = function() return textures[kind] end
end
-- The button: every read answered from fields, every write recorded.
local button = setmetatable({}, {
    __index = fields,
    __newindex = function(_, k, v) writes[#writes + 1] = k; fields[k] = v end,
})
rawset(_G, "C_GuildInfo", { GetGuildTabardInfo = function() return { backgroundColor = { r = 0.2, g = 0.4, b = 0.6 } } end })

ns.ClientMicroArt(button)
Check(atlases.Normal == "UI-HUD-MicroMenu-Guild-Up", "the up art (" .. tostring(atlases.Normal) .. ")")
Check(atlases.Pushed == "UI-HUD-MicroMenu-Guild-Down", "the down art")
Check(atlases.Disabled == "UI-HUD-MicroMenu-Guild-Disabled", "the disabled art")
Check(atlases.Highlight == "UI-HUD-MicroMenu-Guild-Mouseover", "the mouseover art")
Check(textures.Normal.color and textures.Normal.color[3] == 0.6 and textures.Highlight.color ~= nil,
    "the tabard tint on every state")
Check(#writes == 0, "no field written on the button (" .. table.concat(writes, ", ") .. ")")

-- No file of ours calls the client's loader (a hook on it by name is fine).
local listing = io.popen(package.config:sub(1, 1) == "\\" and ('dir /s /b "' .. ROOT .. '\\*.lua"') or ('find "' .. ROOT .. '" -name "*.lua"'))
for path in listing:lines() do
    if not path:find("[\\/]tools[\\/]") and not path:find("[\\/]dev[\\/]") then
        local text = assert(io.open(path)):read("a")
        for line in text:gmatch("[^\n]+") do
            local code = line:gsub("%-%-.*", "")
            if code:find("LoadMicroButtonTextures%s*%(") then
                Check(false, path .. " calls LoadMicroButtonTextures: " .. line)
            end
        end
    end
end
listing:close()

-- A button with no state textures of its own and a portrait (Forever's character button): what the client gave it is
-- kept before our first dress and put back after, our 1.x textures cleared and the portrait at its own size and place.
local cleared = {}
local portrait = {
    w = 32, h = 40, points = { { "TOPLEFT", "button", "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", "button", "BOTTOMRIGHT", 0, 0 } },
}
function portrait:GetSize() return self.w, self.h end
function portrait:SetSize(w, h) self.w, self.h = w, h end
function portrait:GetNumPoints() return #self.points end
function portrait:GetPoint(i) return table.unpack(self.points[i]) end
function portrait:ClearAllPoints() self.points = {} end
function portrait:SetPoint(...) self.points[#self.points + 1] = { ... } end
local char = { Portrait = portrait, normal = nil }
function char:GetNormalTexture() return self.normal end
char.ClearNormalTexture = function() cleared[#cleared + 1] = "Normal" end
char.ClearPushedTexture = function() cleared[#cleared + 1] = "Pushed" end
char.ClearDisabledTexture = function() cleared[#cleared + 1] = "Disabled" end
local state = {}
ns.KeepClientMicro(char, state)
-- Our dress: textures of ours, the portrait shrunk and hung by its top.
char.normal = {}
portrait:SetSize(18, 25)
portrait:ClearAllPoints()
portrait:SetPoint("TOP", "button", "TOP", 0, -7)
ns.ClientMicroBack(char, state)
Check(#cleared == 3, "our state textures on a bare button are cleared (" .. #cleared .. ")")
Check(portrait.w == 32 and portrait.h == 40, "the portrait gets its own size back (" .. portrait.w .. ")")
Check(#portrait.points == 2 and portrait.points[1][1] == "TOPLEFT" and portrait.points[2][1] == "BOTTOMRIGHT",
    "the portrait gets its own anchors back")
-- Texture objects with nothing set on them (Forever's character button): bare too.
local empty = { GetTexture = function() return nil end, GetAtlas = function() return nil end }
local hollow = { normal = empty }
function hollow:GetNormalTexture() return self.normal end
local hollowState = {}
ns.KeepClientMicro(hollow, hollowState)
Check(hollowState.bare == true, "texture objects with nothing set count as bare")
local own = { GetTexture = function() return 123 end, GetAtlas = function() return nil end }
local dressed = { Portrait = nil, normal = own }
function dressed:GetNormalTexture() return self.normal end
dressed.ClearNormalTexture = function() cleared[#cleared + 1] = "dressed" end
local dressedState = {}
ns.KeepClientMicro(dressed, dressedState)
ns.ClientMicroBack(dressed, dressedState)
Check(cleared[4] == nil, "a button with its own textures keeps them")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("micro_handback_test: ok")
