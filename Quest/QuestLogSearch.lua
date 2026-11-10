local _, ns = ...

-- The double pane quest log's search: a box in its header between the Double pane switch and Show Map, in the old
-- input look; the list keeps the quests whose name or zone holds the words (Quest/QuestLogData.lua).

local QL = ns.QL
-- Clear of the switch's label on the left and Show Map's on the right; narrower than this, no box.
local GAP_LEFT, GAP_RIGHT, MIN_W = 14, 14, 60
-- The input's art past the box (5 on the left); its middle this far under the switch label's.
local PAD_LEFT, PAD_RIGHT, DROP = 5, 0, -1

local frame, edit

local function Wanted()
    return QL.active and frame.dual == true and ns.db ~= nil and ns.db.questLogSearch ~= false
end

-- A button's label: its font string.
local labelOf = setmetatable({}, { __mode = "k" })
local function TakeLabel(region, button)
    if region:GetObjectType() == "FontString" then labelOf[button] = region end
end
local function Label(button)
    if not button then return nil end
    if labelOf[button] == nil then ns.EachRegion(button, TakeLabel, button) end
    return labelOf[button]
end

-- Up with the double pane and the option, as wide as the room between the two labels once they are laid.
local function Sync()
    if not edit then return end
    local on = Wanted()
    if on then
        local left, right = Label(frame.dualToggle), Label(frame.showMap)
        local from, to = left and left:GetRight(), right and right:GetLeft()
        if not (from and to) then
            ns.Sched.NextFrame("questlog.search", Sync)
            on = false
        else
            local width = to - from - GAP_LEFT - GAP_RIGHT - PAD_LEFT - PAD_RIGHT
            on = width >= MIN_W
            if on then
                ns.SetPointOnce(edit, "LEFT", left, "RIGHT", GAP_LEFT + PAD_LEFT, DROP)
                edit:SetWidth(width)
            end
        end
    end
    if not on and edit:GetText() ~= "" then edit:SetText("") end
    ns.SetShownIf(edit, on)
end

-- Typing refilters the list from its top; a log shut meanwhile is not opened again by it.
local function TextChanged(self)
    local text = self:GetText() or ""
    self.hint:SetShown(text == "")
    self.clear:SetShown(text ~= "")
    QL.SetSearch(text)
    if frame.listBar then frame.listBar:SetValue(0) end
    if frame:IsShown() then ns.ShowQuestLog() end
end

-- The words go as the log shuts, as a search is a quick look.
local function LogShut()
    if edit:GetText() ~= "" then edit:SetText("") end
end

function QL.BuildSearch(host)
    if edit then return end
    frame = host
    edit = ns.SearchBox(frame, MIN_W, SEARCH or "Search")
    edit:Hide()
    edit:SetScript("OnTextChanged", TextChanged)
    frame:HookScript("OnSizeChanged", Sync)
    frame:HookScript("OnShow", Sync)
    frame:HookScript("OnHide", LogShut)
    Sync()
end

-- The switch and the option answer at once; the window lays its new size first.
ns.OnToggle(function(key)
    if key == "questLogSearch" or key == "questLogDual" or key == "questLog" then ns.Sched.NextFrame("questlog.search", Sync) end
end)
