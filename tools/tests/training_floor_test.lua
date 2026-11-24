-- Offline test under Lua 5.4 for What's Training's page on the professions book (Skills/ProfessionsTraining.lua, the
-- floor from Spells/BookTraining.lua). Under Textured color the book page's quarters carry theme layers one and two
-- sublevels over them; the floor laid at sublevel 1 lost to them, and the quarters' seam and tiles drew lines through the
-- list (look339 v1: a seam 111 down the list, 10 pieces). His pick (2026-11-24): the spellbook's What's Training marble,
-- the same floor, drawn over all of them.
-- Run from the addon root: lua tools/tests/training_floor_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
AnyMT.__concat = function() return "" end

-- The Era art holder the floor goes on, recording the textures made on it.
local made = {}
local holder = Any()
rawset(holder, "CreateTexture", function(_, _, layer, _, sublevel)
    local tex = { layer = layer, sublevel = sublevel or 0, shown = true }
    function tex:SetTexture(path) self.path = path end
    function tex:SetTexCoord(...) self.crop = { ... } end
    function tex:SetDrawLayer(drawLayer, sub) self.layer, self.sublevel = drawLayer, sub end
    function tex:Hide() self.shown = false end
    function tex:Show() self.shown = true end
    function tex:SetShown(on) self.shown = on end
    function tex:SetHorizTile() end
    function tex:SetVertTile() end
    function tex:SetVertexColor() end
    made[#made + 1] = tex
    return tex
end)

local ns = Any()
local T = Any()
rawset(T, "EraKind", function() return "book" end)
rawset(T, "EraHolder", function() return holder end)
rawset(T, "FadePage", function() end)
rawset(ns, "prof", T)
rawset(ns, "TexPath", function(key) return "media\\" .. key end)
rawset(ns, "InkPage", function() end)
rawset(ns, "SetTwoPointsIf", function() end)
rawset(ns, "TradeSkillCover", function() end)
-- The real marble, for the old code: a tiled marble texture at sublevel 1.
rawset(ns, "MarbleFloor", function(parent, sublevel)
    local tex = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel or 0)
    tex:SetTexture("media\\marbleBg")
    return tex
end)
rawset(ns, "TileTex", function(tex) return tex end)
local onShow
rawset(ns, "HookScriptOnce", function(_, script, fn) if script == "OnShow" then onShow = fn end end)

local env = setmetatable({}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local function Load(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local source = handle:read("a")
    handle:close()
    assert(load(source, "@" .. path, "t", env))("ClassicUIForever", ns)
end
Load("Spells/BookTraining.lua")
Load("Skills/ProfessionsTraining.lua")

-- What's Training's crafting list and its page, as its addon makes them.
local page = Any()
rawset(page, "IsShown", function() return true end)
_G.WhatsTrainingCraftingRecipeList = Any()
ns.TrainingPageLook(page, true)
if onShow then onShow(page) end

local shown = {}
for _, tex in ipairs(made) do
    if tex.shown then shown[#shown + 1] = tex end
end
Check(#shown == 1, "one floor shows behind the list (" .. #shown .. ")")
local floor = shown[1]
Check(floor and floor.path == "media\\marbleBg", "the floor is the spellbook page's marble (" .. tostring(floor and floor.path) .. ")")
-- The book page's quarters at sublevel 0 carry Textured color layers at 1 and 2: the floor must be over all of them.
Check(floor and floor.layer == "BACKGROUND" and floor.sublevel > 2,
    "the floor is drawn over the page's quarters and their theme layers (sublevel " .. tostring(floor and floor.sublevel) .. ")")

-- The spellbook's own What's Training page: the same floor (ns.TrainingMarble), over its page art's layers too.
local book = Any()
rawset(book, "CreateTexture", rawget(holder, "CreateTexture"))
local bookFloor = ns.TrainingMarble(book)
Check(bookFloor and bookFloor.path == "media\\marbleBg" and bookFloor.sublevel > 2,
    "the spellbook's page wears the same marble over its art's layers (sublevel " .. tostring(bookFloor and bookFloor.sublevel) .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("training_floor_test: ok")
