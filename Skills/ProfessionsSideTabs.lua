local _, ns = ...

-- The professions window's side tabs (the book's and each profession's): the spellbook's classic side tabs while our
-- book is on, shown always, on hover or hidden per the option, What's Training's tab of ours with them.

local T = ns.prof
local EMPTY = ns.EMPTY

-- Forever's side tabs drawn at the size of our Who and group finder tabs (its 50 px icon to their 32); the column keeps
-- its chain, so it tightens with them.
local PROF_TAB_SCALE = 0.64

-- The tabs wearing the classic look this pass (ns.AdoptSideTabs): their icon and size are its.
local adopted = setmetatable({}, { __mode = "k" })

-- Enlarge a side tab's icon with the client's numbers: the client does it when
-- marking a tab picked, which our piecewise turn to the book never does.
local function FillTabIcon(tab)
    local icon = tab and tab.Icon
    if not icon or adopted[tab] then return end
    local extent = tab.interiorExtent or 50
    if math.abs((icon:GetWidth() or 0) - extent) > 0.5 then
        icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
        icon:SetSize(extent, extent)
    end
end

-- fn(tab, a) on the overview tab, then each profession tab; false without the window.
local function EachTab(fn, a)
    local frame = ProfessionsFrame
    if not frame then return false end
    fn(frame.ProfessionsOverviewTab, a)
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do fn(tab, a) end
    return true
end

local function FillTabIcons()
    EachTab(FillTabIcon)
end
T.FillTabIcons = FillTabIcons

-- The game's tabs shown now, top to bottom: What's Training's tab of ours stands under the last.
local shownList = {}
local function AddShown(tab)
    if tab and tab:IsShown() then shownList[#shownList + 1] = tab end
end
function T.ShownSideTabs()
    wipe(shownList)
    EachTab(AddShown)
    return shownList
end

-- Ours with them (the face tab and What's Training's), made by Skills/ProfessionsFootTabs.lua.
local function EachOurs(fn, a)
    if not T.TrainingSideTabs then return end
    local face, train = T.TrainingSideTabs()
    if face then fn(face, a) end
    if train then fn(train, a) end
end

-- Side tabs always up, or (the option off) seen only while the mouse is near one. The client re-shows them on every
-- open, so they are made transparent, never hidden, and keep the mouse to be found.
-- dbVersion 16: the tabs' checkbox became three picks; where Always was ticked, on hover is not on as well.
function ns.OneProfTabsChoice()
    if ns.db.professionTabs == true then ns.db.professionTabsHover = false end
end

-- dbVersion 34: hidden by default (Era had no such tabs); only Always kept, on hover moves to hidden.
function ns.ProfTabsHidden()
    local db = ns.db
    if db.professionTabs ~= true then
        db.professionTabsHover, db.professionTabsHidden = false, true
    end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" and shot.professionTabs ~= true then
            shot.professionTabsHover, shot.professionTabsHidden = nil, nil
        end
    end
    db.dbVersion = 34
end

-- The option's three picks: shown on hover, always (professionTabs), or never (no mouse either, out of combat).
local function TabsMode()
    local db = ns.db
    if not db then return "hidden" end
    if db.professionTabsHidden == true then return "hidden" end
    return db.professionTabs == true and "always" or "hover"
end
T.TabsMode = TabsMode

-- Near: within PAD of a tab (the gaps between them too); up till HOLD after the mouse leaves; FADE in and out.
local TAB_PAD, TAB_HOLD, TAB_FADE, FADE_STEP = 14, 0.4, 0.15, 0.02
local overTab, leftAt = false, 0
local tabAlpha, tabTarget = 0, 0
local function NoteOver(tab)
    if tab and tab:IsMouseOver(TAB_PAD, -TAB_PAD, -TAB_PAD, TAB_PAD) then overTab = true end
end

-- They cast in the client's name: sized and given the mouse out of combat only; a classic one is sized by its look.
local function PrepTab(tab, hidden)
    if not tab or InCombatLockdown() then return end
    ns.SetScaleIf(tab, adopted[tab] and 1 or PROF_TAB_SCALE)
    if tab:IsMouseEnabled() == hidden then tab:EnableMouse(not hidden) end
end

local function SetTabAlpha(tab, alpha)
    if tab then ns.SetAlphaIf(tab, alpha, 0.01) end
end

-- Awake only while a fade runs.
local fadeJob = ns.Sched.Job({ name = "professions.tabFade", every = FADE_STEP, awake = false, fn = function(job)
    local step = FADE_STEP / TAB_FADE
    if tabAlpha < tabTarget then tabAlpha = math.min(tabTarget, tabAlpha + step)
    else tabAlpha = math.max(tabTarget, tabAlpha - step) end
    EachTab(SetTabAlpha, tabAlpha)
    if TabsMode() == "hover" then EachOurs(SetTabAlpha, tabAlpha) end
    if tabAlpha == tabTarget then job:Sleep() end
end })

-- The classic look while our book is on, out of a fight (they are protected): stacked from the spellbook's first side
-- tab spot, just past the window's right edge, 65 down; given back otherwise.
local FIRST = { nil, 2, -65 }
local function Classic() return ns.OnForever() and ns.ModuleInForce("professionsBook") end
local function Adopt(frame)
    if InCombatLockdown() then return end
    local on = Classic()
    FIRST[1] = frame
    ns.AdoptSideTabs(frame, nil, nil, on and FIRST or nil)
    wipe(adopted)
    if not on then return end
    for _, tab in ipairs(ns.AdoptedSideTabs(frame)) do adopted[tab] = true end
end

-- A side tab pressed with What's Training's list up turns back to that tab's face, as our face tab did.
local function ListBack()
    if T.TrainingListUp and T.TrainingListUp() then ns.Sched.NextFrame("prof.sideTabBack", T.CloseTraining) end
end
local function HookBack(tab)
    if tab then ns.HookScriptOnce(tab, "OnMouseUp", ListBack, "profSideTabBack") end
end

-- Forever's tab plate and hover rim are bronze: drained to silver off the theme; the gold selected mark stays.
local TAB_METAL = { "Background", "HighlightTexture" }
local function DrainTab(tab)
    if not tab then return end
    -- Rechecked each pass: art the client resets comes back bronze.
    for i = 1, #TAB_METAL do ns.KeepDrained(tab[TAB_METAL[i]]) end
end

local function DrainTabs()
    return EachTab(DrainTab)
end

-- Each pass of the watch (10 a second while the window is up) looks for the mouse; between fades the alpha is held
-- against the client's re-show.
local function SyncTabs()
    local frame = ProfessionsFrame
    if not frame then return end
    Adopt(frame)
    EachTab(HookBack)
    DrainTabs()
    local mode = TabsMode()
    EachTab(PrepTab, mode == "hidden")
    -- Ours fade with the tabs on hover; hidden or always, ours stay up (the only way to What's Training).
    if mode ~= "hover" then EachOurs(SetTabAlpha, 1) end
    local now = GetTime()
    overTab = false
    if mode == "hover" then
        EachTab(NoteOver)
        EachOurs(NoteOver)
    end
    if overTab then leftAt = now end
    local target = (mode == "always" or (mode == "hover" and now - leftAt < TAB_HOLD)) and 1 or 0
    if target ~= tabTarget then
        tabTarget = target
        fadeJob:Wake()
    elseif tabAlpha == tabTarget then
        EachTab(SetTabAlpha, tabAlpha)
        if mode == "hover" then EachOurs(SetTabAlpha, tabAlpha) end
    end
end
T.SyncTabs = SyncTabs

