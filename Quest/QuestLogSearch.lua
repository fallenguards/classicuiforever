local _, ns = ...

-- The double pane quest log's search: a box in its header between the Double pane switch and Show Map, in the trade
-- skill window's look; the list keeps the quests whose name or zone holds the words (Quest/QuestLogData.lua).

local QL = ns.QL
-- Clear of the switch's label on the left and Show Map's on the right; narrower than this, no box.
local GAP_LEFT, GAP_RIGHT, MIN_W = 14, 14, 60
-- The edit box inside its border (the trade skill search's); its middle this far under the switch label's.
local PAD_LEFT, PAD_RIGHT, DROP = 7, 5, -4

local frame, back, edit

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
    if not back then return end
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
    ns.SetShownIf(back, on)
end

-- Typing refilters the list from its top; a log shut meanwhile is not opened again by it.
local function TextChanged(self, hint, clear)
    local text = self:GetText() or ""
    hint:SetShown(text == "")
    clear:SetShown(text ~= "")
    QL.SetSearch(text)
    if frame.listBar then frame.listBar:SetValue(0) end
    if frame:IsShown() then ns.ShowQuestLog() end
end

-- The words go as the log shuts, as a search is a quick look.
local function LogShut()
    if edit:GetText() ~= "" then edit:SetText("") end
end

function QL.BuildSearch(host)
    if back then return end
    frame = host
    back = ns.SkillInsetBox(frame, 16, true, 0.5)
    back:Hide()
    -- A child of its border: the window's raise lifts both together, the box over the border.
    edit = ns.NewFrame("EditBox", nil, back)
    edit:SetHeight(16)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetMaxLetters(40)
    edit:SetTextInsets(2, 20, 0, 0)
    back:SetPoint("TOPLEFT", edit, "TOPLEFT", -PAD_LEFT, 5)
    back:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", PAD_RIGHT, -5)
    local hint = edit:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", edit, "LEFT", 3, 0)
    hint:SetText(SEARCH or "Search")
    local clear = ns.SearchClear(edit)
    clear:Hide()
    edit:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self) TextChanged(self, hint, clear) end)
    frame:HookScript("OnSizeChanged", Sync)
    frame:HookScript("OnShow", Sync)
    frame:HookScript("OnHide", LogShut)
    Sync()
end

-- The switch and the option answer at once; the window lays its new size first.
ns.OnToggle(function(key)
    if key == "questLogSearch" or key == "questLogDual" or key == "questLog" then ns.Sched.NextFrame("questlog.search", Sync) end
end)
