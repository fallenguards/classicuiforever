-- Offline test under Lua 5.4 for the theme's walk over the game's own windows (Art/GameArt.lua). The flat panel
-- background's bottom corners (the loot window's, among others) are fill the client colors, not metal: tinted as metal
-- they drew as two white squares with Loot Window off.
-- Run from the addon root: lua tools/tests/game_art_test.lua (CI runs every tools/tests/*_test.lua).
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

function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

local function IsTexture(_, kind) return kind == "Texture" end
local function Atlas(name) return { atlas = name, IsObjectType = IsTexture, GetAtlas = function(self) return self.atlas end } end
local function File(id)
    return { IsObjectType = IsTexture, GetAtlas = function() return nil end, GetTexture = function() return id end }
end

local tinted = {}
local noop = function() end
local apply
local ns = {
    bronze = { BUNDLED = "", PlainTree = function() return false end },
    panels = { WINDOWS = { { "LootFrame" } }, skinned = {} },
    NP = { EachPlate = noop },
    Sched = { OnVisible = noop, NextFrame = noop },
    IsSecret = function() return false end,
    ModuleInForce = function() return false end,
    BronzeOn = function() return false end,
    EventFrame = noop,
    OnToggle = noop,
    TintGameArt = function(texture) tinted[texture] = true end,
    UntintGameArt = function(texture) tinted[texture] = nil end,
    RegisterModule = function(_, spec) apply = spec.apply end,
}
function ns.EachRegion(frame, fn)
    for _, region in ipairs(frame.regions) do fn(region) end
end
function ns.EachChild() end
assert(loadfile(ROOT .. "/Art/GameArt.lua"))("ClassicUIForever", ns)

-- The loot window with Loot Window off: FlatPanelBackgroundTemplate's corners next to its border metal.
local cornerLeft = Atlas("uiframebackground-nineslice-cornerbottomleft")
local cornerRight = Atlas("uiframebackground-nineslice-cornerbottomright")
local metal = Atlas("UI-Frame-Metal-CornerTopLeft")
_G.LootFrame = { regions = { cornerLeft, cornerRight, metal }, IsObjectType = function() return false end }
apply()
Check(tinted[metal], "the loot window's border metal is tinted")
Check(not tinted[cornerLeft] and not tinted[cornerRight], "the flat background's corners keep the client's color")
-- Dressed by us, the window's leftover metal still takes the theme (a search box, a tab).
ns.panels.skinned[_G.LootFrame] = true
tinted[metal] = nil
apply()
Check(tinted[metal], "a dressed window's leftover metal is tinted too")

-- The guild roster's header strip: the game's column tabs and the rock behind them, by file.
local columnTab, rock, icon = File(131139), File(374155), File(136243)
_G.LootFrame.regions = { columnTab, rock, icon }
apply()
Check(tinted[columnTab] and tinted[rock], "the game's column tabs and rock strip are tinted")
Check(not tinted[icon], "an icon by file is left as drawn")
-- The raid tab hangs on the social window only once picked: walked on its own.
local raidBar = Atlas("minimal-scrollbar-track-middle")
_G.RaidFrame = { regions = { raidBar }, IsObjectType = function() return false end }
apply()
Check(tinted[raidBar], "the raid tab's scroll bar is tinted")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("game_art_test: ok")
