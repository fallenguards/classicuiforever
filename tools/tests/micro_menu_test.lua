-- Offline tests for Bar/BarSkins.lua under Lua 5.4: with the game menu or settings open the client disables the other
-- micro buttons, which halves them and grays the portrait; ours keep their look, a hidden seat stays unseen.
-- Run from the addon root: lua tools/tests/micro_menu_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

local function Nothing() end
local VERBS = { "^Set", "^Get", "^Is", "^Clear", "^Hide", "^Show", "^Hook", "^Register", "^Enable" }
-- Any widget call not written out answers nothing; a plain field (Portrait, Background) stays nil.
local function Widget(fields)
    return setmetatable(fields, { __index = function(_, key)
        for _, verb in ipairs(VERBS) do
            if key:find(verb) then return Nothing end
        end
    end })
end

local function Texture()
    local tex = Widget({ gray = false })
    function tex:SetDesaturated(gray) self.gray = gray and true or false end
    function tex:IsDesaturated() return self.gray end
    return tex
end

-- A client micro button: its enable and disable scripts set the alpha and the portrait's gray, on a change only.
local function MicroButton(name, portrait)
    local button = Widget({ name = name, alpha = 1, enabled = true, Normal = Texture(), Disabled = Texture() })
    if portrait then button.Portrait = Texture() end
    function button:GetName() return self.name end
    function button:GetAlpha() return self.alpha end
    function button:SetAlpha(alpha) self.alpha = alpha end
    function button:IsEnabled() return self.enabled end
    function button:GetNormalTexture() return self.Normal end
    function button:GetDisabledTexture() return self.Disabled end
    function button:UpdateMicroButton() end
    function button:SetNormal() end
    function button:SetPushed() end
    function button:Able(enabled)
        if self.enabled == enabled then return end
        self.enabled = enabled
        self.alpha = enabled and 1 or 0.5
        if self.Portrait then self.Portrait:SetDesaturated(not enabled) end
    end
    return button
end

function hooksecurefunc(host, name, hook)
    if type(host) == "string" then return end
    local old = host[name]
    host[name] = function(...)
        old(...)
        hook(...)
    end
end
function CreateFrame() return Widget({}) end

local function Panel()
    return { shown = false, IsShown = function(self) return self.shown end }
end
GameMenuFrame, SettingsPanel = Panel(), Panel()

local edges, afterShow, seatHidden, lastDisabled = {}, {}, {}, {}
local ns = {
    KEYS = { STATES = { "Normal", "Pushed", "Disabled", "Highlight" } },
    StateTexture = function(button, which) return rawget(button, which) end,
    Dress = Nothing, FadeTextures = Nothing, EachState = Nothing, FadeKeys = Nothing, SetButtonTex = Nothing,
    KeepDrained = Nothing, UndrainBronze = Nothing, UnswapBronze = Nothing, SetVertexColorIf = Nothing,
    SetPointOnce = Nothing, EventFrame = Nothing,
    OnForever = function() return true end,
    DressStates = function(button, _, _, disabled) lastDisabled[button] = disabled end,
    SetFrameAlphaIf = function(frame, alpha) frame.alpha = alpha end,
    MicroSeatHidden = function(button) return seatHidden[button] == true end,
    Sched = {
        OnFrame = function() return { Sleep = Nothing, Wake = Nothing } end,
        Attach = function() return {}, false end,
        NextFrame = Nothing,
        OnVisible = function(host, _, fn) edges[host] = fn end,
        AfterShow = function(host, _, fn) afterShow[host] = fn end,
    },
}
assert(loadfile(ROOT .. "/Bar/BarSkins.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Bar/MicroFlash.lua"))("ClassicUIForever", ns)

local character = MicroButton("CharacterMicroButton", true)
local finder = MicroButton("LFDMicroButton")
local seat = MicroButton("SpellbookMicroButton")
-- The client grays the group finder's disabled texture as it loads.
finder.Disabled:SetDesaturated(true)
local buttons = { character, finder, seat }
for _, button in ipairs(buttons) do ns.SkinMicroButton(button) end
seatHidden[seat] = true
seat.alpha = 0

-- The client's update: with a menu up it disables the row and stops, else it enables each and updates it.
local function ClientUpdate()
    local open = GameMenuFrame.shown or SettingsPanel.shown
    for _, button in ipairs(buttons) do
        button:Able(not open)
        if not open then button:UpdateMicroButton() end
    end
end

-- early: our watcher hears of the show before the client's own handler has disabled the row.
local function Open(panel, early)
    panel.shown = true
    if early then edges[panel](true) end
    ClientUpdate()
    if not early then edges[panel](true) end
    afterShow[panel]()
end
local function Close(panel)
    panel.shown = false
    ClientUpdate()
    edges[panel](false)
end

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

for _, early in ipairs({ false, true }) do
    local when = early and " (watcher ahead of the client)" or ""
    Open(GameMenuFrame, early)
    Check(character.alpha == 1 and finder.alpha == 1, "menu open: the row is not halved" .. when)
    Check(character.Portrait.gray == false, "menu open: the portrait keeps its color" .. when)
    Check(finder.Disabled.gray == false, "menu open: the disabled texture is not grayed" .. when)
    Check(lastDisabled[finder] == "microLFGUp", "menu open: the disabled state draws the up sheet" .. when)
    Check(seat.alpha == 0, "menu open: a hidden seat stays unseen" .. when)
    Close(GameMenuFrame)
    Check(character.alpha == 1 and character.Portrait.gray == false, "menu closed: as the client enabled it" .. when)
    Check(finder.Disabled.gray == true, "menu closed: the client's gray is back on the disabled texture" .. when)
    Check(lastDisabled[finder] == "microLFGDisabled", "menu closed: the disabled state draws its own sheet" .. when)
    Check(seat.alpha == 0, "menu closed: a hidden seat stays unseen" .. when)
end

Open(SettingsPanel, true)
Check(character.alpha == 1 and character.Portrait.gray == false, "settings open: the same as the game menu")
Close(SettingsPanel)

-- Disabled with no menu up (a full-screen frame): the client's dim is its own.
character:Able(false)
character:SetNormal()
Check(character.alpha == 0.5 and character.Portrait.gray == true, "disabled with no menu up: left dimmed")
character:Able(true)

-- Our art off while the menu is up: the dim goes back to the client.
Open(GameMenuFrame)
ns.UnskinMicroButton(character)
ns.UnskinMicroButton(finder)
Check(character.alpha == 0.5 and character.Portrait.gray == true, "unskinned under the menu: the client's dim is back")
Check(finder.Disabled.gray == true, "unskinned under the menu: the disabled texture is gray again")

if failures > 0 then
    print(failures .. " check(s) failed")
    os.exit(1)
end
print("micro_menu_test: all checks passed")
