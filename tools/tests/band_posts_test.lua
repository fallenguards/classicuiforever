-- Offline test under Lua 5.4 for the client's XP bar segment posts under our strips (Bar/BandStatusHide.lua): faded
-- posts that come back at full alpha with no rebuild (the holder's fade-in ending after a login in a fight) are seen,
-- and the band's per-frame trip and its put-back both ask for them (Bar/BandStatus.lua).
-- Run from the addon root: lua tools/tests/band_posts_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Post()
    return { alpha = 1, shown = true, SetAlpha = function(self, a) self.alpha = a end,
        GetAlpha = function(self) return self.alpha end, IsShown = function(self) return self.shown end }
end
local posts = { Post(), Post(), Post() }
local holder = { HorizontalDividersPool = {
    EnumerateActive = function()
        local i = 0
        return function()
            i = i + 1
            return posts[i]
        end
    end,
    GetNumActive = function() return #posts end,
} }

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), band = {} }
ns.SetAlphaIf = function(region, a) region:SetAlpha(a) end
assert(loadfile(ROOT .. "/Bar/BandStatusHide.lua"))("ClassicUIForever", ns)
local B = ns.band

Check(not B.PostsBack(holder), "posts never faded are not counted as back")
B.SetDividers(holder, 0)
Check(posts[1].alpha == 0 and posts[3].alpha == 0, "every post faded")
Check(not B.PostsBack(holder), "faded posts are not back")
for _, post in ipairs(posts) do post.alpha = 1 end
Check(B.PostsBack(holder), "faded posts back at full alpha with no rebuild are seen")
B.SetDividers(holder, 0)
Check(not B.PostsBack(holder), "faded again")
B.SetDividers(holder, 1)
posts[1].alpha = 1
Check(not B.PostsBack(holder), "posts handed back (band off) are not counted as back")

local status = assert(io.open(ROOT .. "/Bar/BandStatus.lua")):read("a")
local trip = status:match("function B%.hot%.StatusTrip%(%)(.-)\nend")
Check(trip ~= nil and trip:find("PostsBack%(") ~= nil, "the per-frame trip looks for posts back")
local back = status:match("function B%.StatusBack%(%)(.-)\nend")
Check(back ~= nil and back:find("PostsBack%(") ~= nil and back:find("SetDividers%(") ~= nil,
    "the put-back fades posts that came back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("band_posts_test: ok")
