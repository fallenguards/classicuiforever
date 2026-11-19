-- Offline test under Lua 5.4 for the classic bar standing down (Bar/BandBars.lua B.ButtonsHome): a button still in our
-- slot goes back to the client's container; one another addon moved onto its own bar stays there (a bar addon that
-- reuses the client's buttons and parks the client's bars hidden lost every bar to the hand-back, 2026-11-15).
-- Run from the addon root: lua tools/tests/band_buttons_home_test.lua (CI runs every tools/tests/*_test.lua).
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

local source = assert(io.open(ROOT .. "/Bar/BandBars.lua")):read("a")
local body = source:match("function B%.ButtonsHome%(%)\n(.-)\nend\n")
Check(body ~= nil, "ButtonsHome is found")

local function Frame(name)
    return { name = name, level = 1, GetFrameLevel = function(self) return self.level end }
end
local function Button(name, container, parent)
    local checked = { layer = "OVERLAY", sub = 1 }
    function checked:SetDrawLayer(layer, sub) self.layer, self.sub = layer, sub end
    return { name = name, container = container, parent = parent, checked = checked,
        GetParent = function(self) return self.parent end,
        SetParent = function(self, p) self.parent = p end,
        SetFrameLevel = function(self, l) self.level = l end,
        GetCheckedTexture = function(self) return self.checked end }
end

local clientContainer, otherBar = Frame("client container"), Frame("other addon's bar")
local ourSlot1, ourSlot2 = Frame("our slot 1"), Frame("our slot 2")
local stillOurs = Button("ActionButton1", clientContainer, ourSlot1)
local taken = Button("MultiBarRightButton1", clientContainer, otherBar)

local backing = { shown = true, Hide = function(self) self.shown = false end }
local env = setmetatable({
    slotOf = { [stillOurs] = ourSlot1, [taken] = ourSlot2 },
    mouseOff = {},
    backingOf = { stance = backing },
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    ns = { SetPointOnce = function() end },
}, { __index = _G })
local ButtonsHome = assert(load(body or "", "ButtonsHome", "t", env))
ButtonsHome()

Check(stillOurs.parent == clientContainer, "a button in our slot goes back to the client's container")
Check(stillOurs.checked.sub == 0, "its checked border goes back to the client's layer")
Check(taken.parent == otherBar, "a button another addon moved onto its bar stays on that bar")
Check(taken.checked.sub == 1, "that addon's button is left untouched")
Check(backing.shown == false, "Era's stance and pet backing goes with the band")

-- The layout's slot: a button another addon moved onto its own bar is never pulled back into ours.
local slotBody = source:match("local function Slot%(button, bar%)\n(.-)\nend\n")
Check(slotBody ~= nil, "Slot is found")
local moved = {}
local slotEnv = setmetatable({
    slotOf = {},
    Holder = function() return Frame("holder") end,
    Move = function(button, slot) moved[button] = slot; button.parent = slot end,
    CreateFrame = function() return { SetSize = function() end, GetParent = function() end, SetParent = function() end } end,
    ns = { AnySecret = function() return false end },
}, { __index = _G })
local Slot = assert(load("local button, bar = ...\n" .. (slotBody or ""), "Slot", "t", slotEnv))
local fresh = Button("ActionButton2", clientContainer, clientContainer)
fresh.GetWidth = function() return 45 end
fresh.GetHeight = function() return 45 end
fresh.checked.GetDrawLayer = function(self) return self.layer, self.sub end
Check(Slot(fresh, {}) ~= nil and moved[fresh] ~= nil, "a button in its own container is taken into our slot")
local foreign = Button("MultiBarRightButton2", clientContainer, otherBar)
Check(Slot(foreign, {}) == nil and moved[foreign] == nil, "a button on another addon's bar is left there")

Check(source:find("local function LayoutButtons%b()\n%s*%-%-[^\n]*\n%s*%-%-[^\n]*\n%s*if not bar or not bar%.actionButtons or ns%.BarsTaken%(%) then return end")
    ~= nil, "the layout touches no button once another addon has taken the bars")

-- Remembered frames (micro and bag buttons on our art): one another addon moved onto its bar is not pulled back
-- (B.TakenAway), and the put-back leaves its place alone (the micro buttons stacked on one spot, 2026-11-15).
local band = assert(io.open(ROOT .. "/Bar/Band.lua")):read("a")
local takenBody = band:match("function B%.TakenAway%(frame%)\n(.-)\nend\n")
Check(takenBody ~= nil, "B.TakenAway is found")
local art, menu, otherMenu = Frame("art"), Frame("client menu"), Frame("other addon's menu bar")
local saved = {}
local B = { art = art, saved = saved }
local TakenAway = assert(load("local frame = ...\n" .. (takenBody or ""), "TakenAway", "t",
    setmetatable({ saved = saved, B = B }, { __index = _G })))
B.TakenAway = TakenAway

local function Micro(name, parent)
    local f = Button(name, nil, parent)
    f.points, f.scale = { { "LEFT", menu, "LEFT", 0, 0 } }, 1
    function f:GetNumPoints() return #self.points end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetScale(s) self.scale = s end
    f.SetSize = function() end
    return f
end
local onArt = Micro("CharacterMicroButton", art)
local gone = Micro("SpellbookMicroButton", otherMenu)
gone.points = { { "CENTER", otherMenu, "CENTER", 0, 0 } }
gone.scale = 0.7
saved[onArt] = { 1, menu, 32, 40, "BOTTOMLEFT", menu, "BOTTOMLEFT", 6, 0 }
saved[gone] = { 1, menu, 32, 40, "BOTTOMLEFT", menu, "BOTTOMLEFT", 32, 0 }
Check(not TakenAway(onArt), "a button on our art is ours")
Check(TakenAway(gone), "a button on another addon's bar is taken away")
Check(not TakenAway(Micro("MainMenuMicroButton", menu)), "a button never remembered is not taken away")

local classic = assert(io.open(ROOT .. "/Bar/ClassicBar.lua")):read("a")
local putBody = classic:match("local function PutBackSaved%(art%)\n(.-)\nend\n")
Check(putBody ~= nil, "PutBackSaved is found")
local putEnv = setmetatable({
    B = B, wipe = env.wipe,
    BaseSetters = function()
        return function(x, s) x:SetScale(s) end, function(x) x:ClearAllPoints() end, function(x, ...) x:SetPoint(...) end
    end,
}, { __index = _G })
local PutBackSaved = assert(load("local art = ...\n" .. (putBody or ""), "PutBackSaved", "t", putEnv))
PutBackSaved(art)
Check(onArt.parent == menu and onArt.points[1] and onArt.points[1][1] == "BOTTOMLEFT" and onArt.points[1][4] == 6,
    "a button on our art goes back to its menu and its own anchor")
Check(gone.parent == otherMenu and #gone.points == 1 and gone.points[1][1] == "CENTER",
    "a button another addon took keeps its parent and its place")
Check(gone.scale == 1, "and gets its own scale back (" .. tostring(gone.scale) .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("band_buttons_home_test: ok")
