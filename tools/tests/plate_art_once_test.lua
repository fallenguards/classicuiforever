-- Offline test under Lua 5.4 for the plates' own art (Units/NamePlates.lua): drawn on a bar's first layout and again
-- after a toggle, not on every layout (#127: every re-lay and every cast start and stop drew it all again).
-- Run from the addon root: lua tools/tests/plate_art_once_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Units/NamePlates.lua", "r"))
local source = handle:read("a")
handle:close()
local last = source:find("-- From our passes, never a client hook", 1, true)
Check(last ~= nil, "the layout code is in the file")
local chunk = source:sub(1, (last or 1) - 1) .. "\nreturn NP, Layout, LayCast, Restore"
-- Restore sits further down: the test runs its own lines that forget what was drawn.
local forget = source:match("%-%- Our art is hidden below: the next layout draws it again%.\n(.-)\n    for unitFrame in pairs")
Check(forget ~= nil and forget:find("wipe%(healthDrawn%)") and forget:find("wipe%(castDrawn%)"),
    "Restore forgets what was drawn")
chunk = chunk:gsub("return NP, Layout, LayCast, Restore$", function()
    return "local function Restore()\n" .. (forget or "") .. "\nend\nreturn NP, Layout, LayCast, Restore"
end)

-- A region with the methods the layout calls; its alpha starts shown.
local function Region()
    local r = { alpha = 1 }
    for _, m in ipairs({ "Hide", "Show", "SetShown", "SetIgnoreParentAlpha", "SetColorTexture", "SetAllPoints",
        "SetDrawLayer", "SetText", "SetTextColor", "SetSize", "SetTexture", "SetAtlas", "SetPoint", "ClearAllPoints",
        "SetWidth", "SetJustifyH" }) do
        r[m] = function() end
    end
    function r:GetAlpha() return self.alpha end
    function r:SetAlpha(a) self.alpha = a; self.alphaWrites = (self.alphaWrites or 0) + 1 end
    return r
end

local drawn, toggles = 0, {}
local function Own(frame, key)
    frame.fcui = frame.fcui or {}
    frame.fcui[key] = frame.fcui[key] or Region()
    return frame.fcui[key]
end
local db = {}
local ns = {
    db = db,
    Dress = function() end,
    DressNew = function(parent, _, spec)
        drawn = drawn + 1
        return Own(parent, spec.own)
    end,
    FadeKeys = function(owner, keys, alpha, how)
        alpha = alpha or 0
        for _, key in ipairs(keys) do
            local region = owner[key]
            if region and not (how and how.changed and region:GetAlpha() == alpha) then region:SetAlpha(alpha) end
        end
    end,
    IsSecret = function() return false end,
    IsForbidden = function() return false end,
    OnToggle = function(fn) toggles[#toggles + 1] = fn end,
    OwnTexture = function(frame, key) return Own(frame, key) end,
    GetCVar = function() return "1" end,
    Path = function() end,
    SkullLevel = function() return false end,
}
for _, name in ipairs({ "SetTwoPointsIf", "SetBarColorIf", "SetSizeIf", "SetPointIf", "SetAlphaIf", "SetScaleIf",
    "SetPointOnce", "SetShownIf" }) do
    ns[name] = function() end
end
local env = setmetatable({ GetTime = function() return 0 end, wipe = function(t) for k in pairs(t) do t[k] = nil end end },
    { __index = _G })
local load_ok, NP, Layout, LayCast, Restore = pcall(function() return assert(load(chunk, "plates", "t", env))(nil, ns) end)
Check(load_ok, "the layout code loads (" .. tostring(NP) .. ")")
if not load_ok then os.exit(1) end
NP.active = true
NP.ClassColor = function() end
NP.TextShadow = function() end
NP.NameSize = function() end
local function Toggle() for _, fn in ipairs(toggles) do fn("anyKey") end end

-- One plate: health and cast bars with the game's own pieces on them.
local fill = Region()
local health = { GetStatusBarTexture = function() return fill end, bgTexture = Region(), selectedBorder = Region() }
function health:CreateFontString() return Region() end
function health:CreateTexture() return Region() end
local cast = { Background = Region(), Border = Region() }
local unitFrame = { HealthBarsContainer = { healthBar = health }, CastBarsContainer = { castBar = cast },
    selectionHighlight = Region() }

-- First layout draws the border, the glow and the cast border.
Layout(unitFrame)
local first = drawn
Check(first >= 3, "the first layout draws the plate's own art (" .. first .. ")")
Check(health.fcui and health.fcui.border and cast.fcui and cast.fcui.castBorder, "border and cast border are there")
Check(health.bgTexture.alpha == 0 and cast.Border.alpha == 0, "the game's own art is faded")

-- Later layouts and casts on the same plate draw nothing of ours again. The game's pieces are faded each time: a plain
-- SetAlpha cost less than reading the alpha first (perfy, #127: 14 against 54 us a layout).
for _ = 1, 5 do Layout(unitFrame) LayCast(unitFrame.CastBarsContainer, unitFrame) end
Check(drawn == first, "re-lays and casts draw no art again (" .. drawn - first .. " extra)")

-- The game shows one of its pieces again: the next layout fades it once more.
health.bgTexture.alpha = 1
Layout(unitFrame)
Check(health.bgTexture.alpha == 0, "a piece the game showed again is faded again")

-- A toggle (a theme, the old cast bar, the dragons) draws the art again on the next layout.
Toggle()
Layout(unitFrame)
Check(drawn > first, "after a toggle the art is drawn again")
local after = drawn
Layout(unitFrame)
Check(drawn == after, "and only once")

-- The old cast style draws its two halves once, and hands its left half back as the anchor.
db.plateCastBeside = true
Toggle()
LayCast(unitFrame.CastBarsContainer, unitFrame)
local old = drawn
LayCast(unitFrame.CastBarsContainer, unitFrame)
Check(drawn == old and cast.fcui.borderL ~= nil, "the old cast border is drawn once")

-- Turned off and on again (Restore hid our art): everything is drawn again.
Layout(unitFrame)
local settled = drawn
Layout(unitFrame)
Check(drawn == settled, "a settled plate draws nothing")
Restore()
Layout(unitFrame)
Check(drawn > settled, "after Restore the next layout draws the art again")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("plate_art_once_test: ok")
