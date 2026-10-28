-- Offline test under Lua 5.4: a texture the game locks against addon art (forbidden aspect SetTexture: the rotating
-- minimap's compass in an instance) is never set from our code; the set errored six times a layout (#208).
-- Run from the addon root: lua tools/tests/art_locked_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Read(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
    local text = handle:read("a"):gsub("\r\n", "\n")
    handle:close()
    return text
end

-- ns.ArtLocked from Core/Util.lua itself, on stub textures.
local util = Read("Core/Util.lua")
local body = util:match("\nlocal SET_TEXTURE = .-\nfunction ns%.ArtLocked%(texture%)\n.-\nend\n")
Check(body ~= nil, "ns.ArtLocked is found in Core/Util.lua")
if body then
    local ns = {}
    local env = setmetatable({ ns = ns, Enum = { ForbiddenAspect = { SetTexture = 2048 } } }, { __index = _G })
    assert(load(body, "ArtLocked", "t", env))()
    local function Tex(mask)
        return { HasAnyForbiddenAspects = function(_, aspects) return mask & aspects ~= 0 end }
    end
    Check(ns.ArtLocked(Tex(2048)) == true, "a texture with SetTexture forbidden is locked")
    Check(ns.ArtLocked(Tex(4096)) == false, "another forbidden aspect alone (QueryRotation) leaves art free")
    Check(ns.ArtLocked(Tex(0)) == false, "a plain texture is free")
    Check(ns.ArtLocked({}) == false, "a client without forbidden aspects: free")
end

-- Every way our code sets art on a texture asks first.
local textures, dress = Read("Art/Textures.lua"), Read("UI/Dress.lua")
Check(textures:find("function ns.SetTex(texture, key, ...)\n    if ns.ArtLocked(texture) then return false end", 1, true),
    "ns.SetTex leaves a locked texture alone")
Check(textures:find("if not texture or not path or ns.ArtLocked(texture) then return end", 1, true),
    "ns.SetFile leaves a locked texture alone")
Check(dress:find('if set == "raw" then return not ns.ArtLocked(tex) and tex:SetTexture(art) ~= false end', 1, true),
    "a raw set leaves a locked texture alone")
Check(dress:find("if key ~= nil and ns.ArtLocked(tex) then return false end", 1, true),
    "a dressing leaves a locked texture whole, crop and size included")

-- The locked compass is the game's own big ring over our border (#208, in a dungeon): not dressed, faded.
local minimap = Read("Map/Minimap.lua")
Check(minimap:find("if not compassLocked then ns.Dress(MinimapCompassTexture", 1, true)
    and minimap:find("ns.SetAlphaIf(MinimapCompassTexture, compassLocked and 0 or 1)", 1, true),
    "the locked compass ring is faded, not dressed")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("art_locked_test: ok")
