-- Offline tests for Character/PvPDetail.lua under Lua 5.4: the PvP tab's side panel opens from its arrow, stays shut
-- or open as it was left, and lists the rank, the season's points and the next rank's rewards as the game reads them.
-- Run from the addon root: lua tools/tests/pvp_detail_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

local Region = {}
Region.__index = function(_, key) return Region[key] or function() end end
local function New() return setmetatable({ scripts = {}, shown = false }, Region) end
-- What a page makes is kept in order: a line, then its picture (the first texture after it).
local madeText
function Region:CreateFontString()
    local r = New()
    r.shown, r.kind = true, "text"
    local made = rawget(self, "made") or {}
    self.made = made
    made[#made + 1] = r
    madeText = r
    return r
end
function Region:CreateTexture()
    local r = New()
    r.shown = true
    if madeText and not rawget(madeText, "mate") then madeText.mate = r end
    return r
end
function Region:SetText(text) self.text = text end
function Region:SetTexture(file) self.file = file end
function Region:GetStringHeight() return 12 end
function Region:GetFrameLevel() return 1 end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:Show() self:SetShown(true) end
function Region:Hide() self:SetShown(false) end
function Region:SetShown(shown)
    if shown == self.shown then return end
    self.shown = shown
    local fn = self.scripts[shown and "OnShow" or "OnHide"]
    if fn then fn(self) end
end

PVPRankFrame = New()
SOUNDKIT = {}
function PlaySound() end
function UnitFactionGroup() return "Alliance" end
function UnitSex() return 2 end
function GetText(key) return "title of " .. key end
Enum = { PvPRanks = { Rank_1 = 5 } }
PVP_RANK_0_NAME = "Civilian"
PVP_RANK_NUMBER = "Rank %d"
PVP_RANK_SEASON_RANKUP_DESCRIPTION = "cap up to %d for Rank %d"
PVP_RANK_SEASON_PROGRESS = "%d of %d"
PVP_RANK_SEASON_PROGRESS_NO_MAX = "%d so far"
PVP_RANK_WEEKLY_CAP_INCREASE = "cap up by %d"
PVP_RANK_NEXT_REWARD = "Next Rewards at Rank %d"
PVP_RANK_REWARDS_VENDOR_ALLIANCE = "sold in Stormwind"
PVP_RANK_REWARDS_VENDOR_HORDE = "sold in Orgrimmar"
PVP_RANK_DETAIL_UNAVAILABLE = "unavailable"

local info
local TOTALS = { [0] = 0, [1] = 750, [2] = 2000, [3] = 4000, [14] = 24750 }
C_MajorFactions = {
    GetMajorFactionProgressionInfo = function() return info end,
    GetTotalReputationForRenownLevel = function(_, rank) return TOTALS[rank] or 0 end,
    GetRenownRewardsForLevel = function(_, rank)
        if rank == 3 then return { { description = "Faction Tabard", icon = 135026 }, { description = "A cloak" } } end
        return {}
    end,
}

local chrome, laid, flip, arrow = 0, 0, nil, New()
local page
-- The 1.x pieces by key: the rule's stat box edge, the reward's slot ring; the heading's iron box.
local art = {}
local heading
local ns = {
    sheet = { active = true },
    db = {},
    Sched = { NextFrame = function(_, fn) fn() end },
    NewFrame = function()
        local frame = New()
        page = page or frame
        return frame
    end,
    SkillInsetBox = function(_, edge)
        heading = New()
        heading.edge = edge
        function heading:CreateFontString()
            local label = New()
            heading.label = label
            return label
        end
        return heading
    end,
    SetTex = function(tex, key)
        art[key] = art[key] or {}
        table.insert(art[key], tex)
    end,
    SidePanel = function() return New(), 198, -77, -429 end,
    SidePanelArrow = function(_, _, _, _, Flip) flip = Flip return arrow end,
    SidePanelArrowFace = function(_, open) arrow.open = open end,
    SetShownIf = function(region, shown) region:SetShown(shown) end,
    SetPointOnce = function() end,
    SetTwoPointsIf = function() end,
    RegisterEvents = function() end,
    PlaceSheetChrome = function() chrome = chrome + 1 end,
    SignalSheetLaid = function() laid = laid + 1 end,
}
assert(loadfile(ROOT .. "/Character/PvPDetail.lua"))("ClassicUIForever", ns)
local T = ns.sheet

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

-- The page's shown lines, in order; a reward's picture rides its line.
local function Lines()
    local out, pictures = {}, {}
    local n = 0
    for _, line in ipairs(rawget(page, "made") or {}) do
        if line.shown then
            n = n + 1
            out[n] = line.text
            pictures[n] = line.mate.shown and line.mate.file or nil
        end
    end
    return out, pictures
end
-- Shut by default: the tab's skin makes the arrow, no panel shows.
info = { renownLevel = 0, maxLevel = 14, renownReputationEarned = 0, currentWeekProgressiveMaxLevel = 0,
    previousWeekProgressiveMaxLevel = 0 }
T.PvPPane()
Check(arrow.shown and arrow.open == false, "the arrow shows, facing shut")
Check(not ns.PvPPaneSeen(), "shut: the sheet is not widened")

-- Opened from the arrow: the panel shows, the sheet's chrome moves out, the state is kept.
flip()
Check(ns.PvPPaneSeen() == true and ns.db.pvpPaneOpen == true, "opened: the sheet is widened and the state kept")
Check(chrome > 0 and laid > 0, "opened: the title and close button move, docked windows hear of it")
local lines, pictures = Lines()
Check(lines[1] == "Civilian", "unranked: the title is the unranked name (" .. tostring(lines[1]) .. ")")
Check(lines[2] == "cap up to 24750 for Rank 14", "the season's cap line (" .. tostring(lines[2]) .. ")")
Check(heading and heading.shown and heading.label.text == "Next Rewards at Rank 3",
    "the first rank that pays out heads the rewards, on the iron box")
Check(lines[3] == "Faction Tabard" and pictures[3] == 135026, "a reward with its picture")
Check(lines[4] == "A cloak" and pictures[4] == nil, "a reward without a picture has none")
Check(lines[5] == "sold in Stormwind" and #lines == 5, "the faction's vendor line ends the page")
local function Shown(key)
    local n = 0
    for _, tex in ipairs(art[key] or {}) do
        if tex.shown then n = n + 1 end
    end
    return n
end
Check(Shown("charStatBox") == 1, "the rule: one piece of the stat box's straight top edge")
Check(Shown("slotNormal") == 1, "one slot ring, around the one reward picture")

-- Ranked, with points this week: rank number, progress and the week's cap rise; shorter pages hide the spare lines.
info = { renownLevel = 3, maxLevel = 14, renownReputationEarned = 100, currentWeekProgressiveMaxLevel = 3,
    previousWeekProgressiveMaxLevel = 2 }
flip()
Check(not ns.PvPPaneSeen() and ns.db.pvpPaneOpen == false, "shut again: the sheet goes back")
flip()
lines = Lines()
Check(lines[1] == "title of PVP_RANK_7_1" and lines[2] == "Rank 3", "ranked: the faction's title and the rank number")
Check(lines[4] == "4100 of 4000" and lines[5] == "cap up by 2000", "points so far against the week's cap, and its rise")
Check(#lines == 5, "no rank above pays out: no rewards block, spare lines hidden (" .. #lines .. ")")
Check(Shown("slotNormal") == 0, "no rewards: no slot ring")
Check(not heading.shown, "no rewards: no heading box")

-- The sheet turned off: panel and arrow go, nothing widened.
T.active = false
T.PvPPaneOff()
Check(not arrow.shown and not ns.PvPPaneSeen(), "sheet off: the arrow and the panel are gone")

if failures > 0 then
    print(string.format("pvp detail: %d failed", failures))
    os.exit(1)
end
print("pvp detail: ok")
