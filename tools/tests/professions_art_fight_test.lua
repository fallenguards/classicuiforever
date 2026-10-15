-- Offline test under Lua 5.4 for the professions window's Era frames (Skills/ProfessionsBookFrame.lua T.EraFrame): the
-- trade skill page's art comes up in a fight too (it waited for calm, so a profession opened in combat drew the bare
-- chrome: no list inset, no detail box), the close button alone waiting for the fight's end. The art is made ahead out
-- of combat, kept shown and faded in and out, as a fight protects the window's children.
-- Run from the addon root: lua tools/tests/professions_art_fight_test.lua (CI runs every tools/tests/*_test.lua).
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

local combat = false
function InCombatLockdown() return combat end
unpack = unpack or table.unpack

-- A region or frame: points, size, alpha and level remembered; a protected child refuses points in a fight.
local function Region(name, protectedChild)
    local r = { name = name, points = {}, alpha = 1, level = 10, w = 0, h = 0 }
    function r:SetPoint(...)
        if combat and protectedChild then error(name .. " anchored in a fight") end
        r.points[#r.points + 1] = { ... }
    end
    function r:ClearAllPoints() r.points = {} end
    function r:GetNumPoints() return #r.points end
    function r:GetPoint(i) return unpack(r.points[i]) end
    function r:SetAllPoints() end
    function r:SetSize(w, h) r.w, r.h = w, h end
    function r:GetSize() return r.w, r.h end
    function r:SetAlpha(a) r.alpha = a end
    function r:GetAlpha() return r.alpha end
    function r:SetFrameLevel(l)
        if combat then error(name .. " leveled in a fight") end
        r.level = l
    end
    function r:GetFrameLevel() return r.level end
    function r:GetName() return name end
    return r
end

local host = Region("ProfessionsFrame")
host.PortraitContainer = Region("PortraitContainer")
host.PortraitContainer.portrait = Region("portrait")
host.PortraitContainer.portrait:SetSize(70, 70)
host.PortraitContainer.portrait:SetPoint("TOPLEFT", host, "TOPLEFT", -5, 7)
host.TitleContainer = { TitleText = Region("TitleText") }
host.TitleContainer.TitleText:SetPoint("CENTER", host, "TOP", 0, -10)
host.CloseButton = Region("CloseButton", true)
host.CloseButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -5, -5)
host.NineSlice = Region("NineSlice")

local made = {}
local T = { Host = function() return host end, Page = function() return nil end }
local ns = {
    prof = T,
    SPELLBOOK_QUARTERS = {}, TradeSkillFrameArt = {}, tradeDual = { FRAME_ART = {} },
    NewFrame = function(_, _, parent)
        local f = Region("holder")
        made[#made + 1] = f
        return f
    end,
    DressPieces = function() return {} end,
    BronzeTint = function() end,
    SetLevelIf = function(frame, level) if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end end,
    SetAlphaIf = function(frame, alpha) if frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end end,
    SetPointOnce = function(frame, ...)
        frame:ClearAllPoints()
        frame:SetPoint(...)
    end,
}
assert(loadfile(ROOT .. "/Skills/ProfessionsBookFrame.lua"))("ClassicUIForever", ns)

-- Out of combat the art is made ahead: three kinds, faded out.
T.PrepareEraFrames()
Check(#made == 6, "a holder and a ring for each of the three kinds (" .. #made .. ")")
for _, f in ipairs(made) do Check(f.alpha == 0, "made faded out") end

-- A profession opened in a fight: its art comes up, the portrait and title move, the close button waits.
combat = true
local ok, err = pcall(T.EraFrame, "trade")
Check(ok, "the trade art comes up in a fight (" .. tostring(err) .. ")")
local lit = 0
for _, f in ipairs(made) do if f.alpha == 1 then lit = lit + 1 end end
Check(lit == 2, "the trade holder and ring lit, the rest dark (" .. lit .. ")")
Check(host.NineSlice.alpha == 0, "the chrome's border faded")
local portrait = host.PortraitContainer.portrait
Check(portrait.w == 60 and portrait.points[1][4] == -3, "the portrait at the trade window's spot")
Check(host.CloseButton.points[1][1] == "TOPRIGHT", "the close button waits where it was")

-- The fight ends: the next pass with the same page places the close button.
combat = false
T.EraFrame("trade")
Check(host.CloseButton.points[1][1] == "CENTER" and host.CloseButton.points[1][5] == -11, "the close button moves at calm")

-- The page shuts: the chrome back, the art faded.
T.EraFrame(nil)
lit = 0
for _, f in ipairs(made) do if f.alpha == 1 then lit = lit + 1 end end
Check(lit == 0 and host.NineSlice.alpha == 1, "the chrome back with the page shut")
Check(portrait.w == 70 and host.CloseButton.points[1][1] == "TOPRIGHT", "the portrait and close back on their own spots")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("professions_art_fight_test: all checks passed")
