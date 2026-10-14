-- Offline test under Lua 5.4 for the cast bar fill colors (Units/CastBars.lua Fill).
-- Fill swaps the client's fill atlas for our plain bar; the client's next pass re-dresses the bar and must keep the
-- color its atlas asked for: a channel read gold on that second pass (#167). The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/cast_fill_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Cut(path, from, to)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last - 1)
end

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local function CreateColor(r, g, b)
    return { r = r, g = g, b = b, GetRGB = function(self) return self.r, self.g, self.b end }
end
local env = setmetatable({
    ns = {},
    IsSecret = function(value) return value == SECRET end,
    CreateColor = CreateColor,
}, { __index = _G })
local body = Cut("/Units/CastBars.lua", "local FILL_TEXTURE = ", "-- 1.x spell bar spot")
local Fill = assert(load(body .. "\nactive = true\nreturn Fill", "cast fill", "t", env))()

-- A cast bar: the client sets an atlas, our plain bar is a file and reads no atlas back.
local function Bar()
    local tex = {}
    function tex:GetAtlas() return self.atlas end
    local bar = {}
    function bar:GetStatusBarTexture() return tex end
    function bar:SetStatusBarTexture(art)
        if art == SECRET or not art:find("\\", 1, true) then tex.atlas = art else tex.atlas = nil end
    end
    function bar:SetStatusBarColor(r, g, b) self.r, self.g, self.b = r, g, b end
    return bar
end
local function Green(bar) return bar.r == 0 and bar.g == 1 and bar.b == 0 end
local function Gold(bar) return bar.r == 1 and bar.g == 0.7 and bar.b == 0 end
local function Gray(bar) return bar.r == 0.5 and bar.g == 0.5 and bar.b == 0.5 end

-- The client's cast start: its fill atlas (our hook fills), then its flag, then its shown pass (our re-dress).
local function Start(bar, atlas, channeling)
    bar:SetStatusBarTexture(atlas)
    Fill(bar)
    bar.channeling = channeling
    Fill(bar)
end

local own = Bar()
Start(own, "ui-castingbar-filling-channel", true)
Check(Green(own), "the player's channel stays green after the client's shown pass re-dresses it")
Start(own, "ui-castingbar-filling-standard", nil)
Check(Gold(own), "a plain cast after it is gold again")
Start(own, "ui-castingbar-uninterruptable", nil)
Check(Gray(own), "an uninterruptible cast stays gray")

local other = Bar()
Start(other, SECRET, true)
Check(Green(other), "another unit's channel (secret art) is green by its own flag")
Start(other, SECRET, nil)
Check(Gold(other), "and its plain cast gold")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("cast_fill_test: all checks passed")
