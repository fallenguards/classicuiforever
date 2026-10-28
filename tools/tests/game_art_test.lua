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
    bronze = { BUNDLED = "", PlainTree = function() return false end, AddonFrame = function() return false end },
    MarkAddonPiece = function() end,
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

-- Broad (Fallen's UI Color Picker): every texture of a game window takes the theme but what stays as drawn.
local btinted, bapply = {}, nil
local function Tex(fields)
    local t = { layer = "ARTWORK", blend = "BLEND", w = 100, h = 50, coords = { 0, 0, 0, 1, 1, 0, 1, 1 } }
    for k, v in pairs(fields) do t[k] = v end
    function t:GetTexCoord() return table.unpack(self.coords) end
    function t:GetWidth() return self.w end
    function t:GetHeight() return self.h end
    function t:IsObjectType(kind) return kind == "Texture" or (kind == "MaskTexture" and self.mask == true) end
    function t:GetAtlas() return self.atlas end
    function t:GetTexture() return self.file end
    function t:GetDrawLayer() return self.layer end
    function t:GetBlendMode() return self.blend end
    function t:GetParent() return self.parent end
    function t:GetName() return self.name end
    function t:GetParentKey() return self.key end
    function t:SetTexCoord() end
    function t:SetAllPoints() end
    return t
end
local function Frame(fields)
    function fields:IsObjectType(kind) return kind == self.kind end
    function fields:GetName() return self.name end
    fields.regions, fields.children = fields.regions or {}, fields.children or {}
    return fields
end
local bns = {
    PACKAGE = { broad = true },
    bronze = { BUNDLED = "", PlainTree = function() return false end, tinted = {}, swapped = {}, clientWas = {},
        AddonFrame = function(frame) return frame.addon == true end },
    NP = { EachPlate = noop },
    Sched = { OnVisible = noop, NextFrame = noop },
    IsSecret = function() return false end,
    IsForbidden = function(object) return object.forbidden == true end,
    ModuleInForce = function() return false end,
    ThemeFor = function() return {} end,
    EventFrame = noop,
    OnToggle = noop,
    TintGameArt = function(texture, share) btinted[texture] = share or true end,
    UntintGameArt = function(texture) btinted[texture] = nil end,
    RegisterModule = function(_, spec) bapply = spec.apply end,
    BAG_ICONS = { "Bag%dSlotIconTexture$", "^MainMenuBarBackpackButtonIconTexture$", "^KeyRingButtonIconTexture$" },
    AnySecret = function() return false end,
    SetFile = noop,
    SetAlphaIf = function(region, alpha) region.alpha = alpha end,
}
local pinned, marked = {}, {}
function bns.PinThemePart(region, part) pinned[region] = part end
function bns.MarkAddonPiece(region) marked[region] = true end
function bns.EachRegion(frame, fn, ...) for _, region in ipairs(frame.regions) do fn(region, ...) end end
function bns.EachChild(frame, fn, ...) for _, child in ipairs(frame.children) do fn(child, ...) end end
_G.LootFrame, _G.RaidFrame = nil, nil
local bar = Frame({ kind = "StatusBar" })
local stone, border = Tex({ file = 130652 }), Tex({ atlas = "achievement-frame-border" })
local keep = {
    icon = Tex({ file = 136243, key = "Icon" }), glow = Tex({ atlas = "achievement-gold-glow" }),
    light = Tex({ file = 130652, layer = "HIGHLIGHT", name = "SomeButtonHighlight" }), added = Tex({ file = 130652, blend = "ADD" }),
    mask = Tex({ file = 130652, mask = true }), colour = Tex({}), ours = Tex({ file = "Interface\\AddOns\\x\\y" }),
    fill = Tex({ file = 130652, parent = bar }), picture = Tex({ atlas = "talents-background-druid-feral" }),
    raid = Tex({ file = 1396980, w = 174, h = 96, key = "bgImage" }), tutorial = Tex({ atlas = "adventureguide-tutorial-rpe" }),
    square = Tex({ file = 136243, w = 36, h = 36 }), cropped = Tex({ file = 136243, coords = { 0.07, 0.07, 0.07, 0.93,
        0.93, 0.07, 0.93, 0.93 } }), swords = Tex({ atlas = "pvptalents-warmode-swords" }),
}
-- The micro menu's character button: the player's portrait (a render target by path) in the theme with the icons.
local micro = Frame({ kind = "Button", name = "CharacterMicroButton" })
local portrait = Tex({ file = "RTPortrait1", name = "CharacterMicroButtonPortrait", parent = micro })
micro.regions = { portrait }
_G.CharacterMicroButton = micro
local hover = Tex({ atlas = "UI-HUD-MicroMenu-Achievements-Mouseover", layer = "HIGHLIGHT" })
function bar:GetStatusBarTexture() return keep.fill end
local inModel = Tex({ file = 130652 })
local parchment = Tex({ atlas = "spellbook-background-evergreen-left" })
local page, bigArt = Tex({ file = 383588, w = 512, h = 512 }), Tex({ file = 130662, w = 195, h = 454 })
-- A quest's campaign parchment: blank until a campaign quest opens, after the walk.
local campaign, questBg = Tex({ key = "SealMaterialBG" }), Tex({ atlas = "questbg-light" })
local window = Frame({ name = "AchievementFrame", regions = { stone, border, hover, parchment, page, bigArt, campaign,
    questBg },
    children = { bar, micro, Frame({ kind = "Model", regions = { inModel } }) } })
for _, tex in pairs(keep) do window.regions[#window.regions + 1] = tex end
-- The bag bar: a bag's picture by its name; the backpack's ring and bag, one picture of the game's.
local bagIcon = Tex({ file = 136243, w = 30, h = 30, key = "icon", name = "CharacterBag0SlotIconTexture" })
window.children[#window.children + 1] = Frame({ kind = "Button", name = "CharacterBag0Slot", regions = { bagIcon } })
-- Forever's backpack: its frame metal and a bag icon by file, as the bags beside it.
local foreverPack = Tex({ file = 5214261, w = 45, h = 45, key = "icon", name = "MainMenuBarBackpackButtonIconTexture" })
window.children[#window.children + 1] = Frame({ kind = "Button", regions = { foreverPack } })
local packNormal, packPushed = Tex({ atlas = "bag-main" }), Tex({ atlas = "bag-main" })
local pack = Frame({ kind = "Button", name = "MainMenuBarBackpackButton", regions = { packNormal, packPushed } })
packNormal.parent, packPushed.parent = pack, pack
local pieces = {}
function pack:CreateTexture()
    pieces[#pieces + 1] = Tex({ file = "Interface\\AddOns\\x\\BackpackParts" })
    return pieces[#pieces]
end
window.children[#window.children + 1] = pack
-- Another addon's frame on the window, walked as with Other addons checked: what it takes is marked as its.
local addonMetal = Tex({ file = 130652 })
window.children[#window.children + 1] = Frame({ kind = "Frame", addon = true, regions = { addonMetal } })
local oursWindow = Frame({ name = "ForeverClassicUIQuestLog", regions = { Tex({ file = 130652 }) } })
-- A forbidden frame may not be asked its name from addon code: it errors (the game's secure frames).
local forbidden = Frame({ forbidden = true })
function forbidden:GetName() error("forbidden frame asked its name") end
window.children[#window.children + 1] = forbidden
_G.UIParent = Frame({ children = { forbidden, window, oursWindow } })
assert(loadfile(ROOT .. "/Art/GameArt.lua"))("ClassicUIForever", bns)
bapply()
Check(btinted[stone] == true and btinted[border] == true, "broad: a game window's frame art takes the theme whole")
Check(type(btinted[parchment]) == "table" and type(btinted[page]) == "table" and type(btinted[bigArt]) == "table",
    "broad: parchment and big art behind content take the lighter pane share")
Check(type(btinted[campaign]) == "table" and type(btinted[questBg]) == "table",
    "broad: a quest's campaign parchment is a pane, painted before it has art")
Check(btinted[hover], "broad: a hover image on the highlight layer takes the theme with its button")
Check(btinted[portrait], "broad: the micro menu's character button wears the theme, portrait and all")
for what, tex in pairs(keep) do Check(not btinted[tex], "broad: " .. what .. " is left as drawn") end
Check(not btinted[inModel], "broad: a model's insides are never walked")
Check(btinted[addonMetal] and marked[addonMetal], "broad: another addon's piece it takes is marked as its")
Check(not marked[stone], "broad: the game's own art is never marked as another addon's")
Check(not btinted[oursWindow.regions[1]], "broad: our own windows are left to the theme's own paint")
Check(btinted[bagIcon] == true, "broad: a bag's picture takes the theme as frame art, with Bag icons")
Check(btinted[foreverPack] == true, "broad: Forever's backpack picture goes with the bags'")
Check(packNormal.alpha == 0 and packPushed.alpha == 0, "broad: the backpack's one picture is hidden")
Check(#pieces == 2 and btinted[pieces[1]] == true and btinted[pieces[2]] == true,
    "broad: our ring and bag take its place, made once, both painted")
Check(pinned[pieces[1]] == nil and pinned[pieces[2]] == "themePartBagIcons",
    "broad: the ring is its button's part (Bag borders), the bag Bag icons")
_G.UIParent, _G.CharacterMicroButton = nil, nil

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("game_art_test: ok")
