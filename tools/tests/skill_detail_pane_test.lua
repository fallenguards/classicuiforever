-- Offline test under Lua 5.4: the client's skill detail pane (SkillsFrame.SkillDetailFrame) is never shown, hidden,
-- moved, re-parented or refreshed by our code, and its words box is never ours to lay. A Show from here ran the pane's
-- refresh in our name; what that run wrote, the client's own later refresh read, and a weapon skill rising in a fight
-- then stopped the client's sums on a secret number (#295). The skills tab's lower section is a frame of ours.
-- Run from the addon root: lua tools/tests/skill_detail_pane_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end

-- In these files `detail` and `SkillDetailFrame` name the client's pane.
local PANE_CALLS = { "Show(", "Hide(", "SetShown(", "SetParent(", "ClearAllPoints(", "SetPoint(", "SetHeight(",
    "SetSize(", "SetFrameLevel(", "SetClipsChildren(", "Refresh(", "HookScript(" }
for _, path in ipairs({ "Character/SkillDetail.lua", "Character/CharacterLists.lua", "Character/CharacterSheet.lua" }) do
    local text = Source(path)
    for _, call in ipairs(PANE_CALLS) do
        Check(not text:find("detail:" .. call, 1, true), path .. ": the client's pane is called with " .. call)
        Check(not text:find("SkillDetailFrame:" .. call, 1, true), path .. ": SkillDetailFrame is called with " .. call)
    end
    for _, piece in ipairs({ "detail.Description", "detail.DescriptionScrollBar", "detail.Content", "detail.fcui" }) do
        Check(not text:find(piece, 1, true), path .. ": touches " .. piece)
    end
end

local detail = Source("Character/SkillDetail.lua")
Check(not detail:find("FullUpdate", 1, true), "no scroll box of the client's is updated from the section")
Check(not detail:find("KeepSidePane", 1, true), "the client's pane is not held open for the section")
Check(detail:find('ns.NewFrame("Frame", nil, CharacterFrame)', 1, true) ~= nil, "the section is a frame of ours on the window")
Check(detail:find("bar:SetParent(holder)", 1, true) ~= nil, "the client's rank bar is carried into our frame")
Check(detail:find("holder:SetShown(onSkills)", 1, true) ~= nil, "our frame shows with the skills tab")

local sheet = Source("Character/CharacterSheet.lua")
Check(sheet:find("for _, pane in ipairs(frame.SidePanes or EMPTY) do Quiet(pane) end", 1, true) ~= nil,
    "every side pane of the client's is quieted, the skill detail too")

-- The quieting walk reaches the client's pane, whose lines the client now writes in a fight from secret numbers: a
-- line that answers secret about its mouse is never tested and never touched.
local first = assert(sheet:find("local quieted = {}", 1, true), "the quieting walk is in the file")
local last = assert(sheet:find("local function LoudMouse", first, true))
local SECRET = {}
local stubs = { IsSecret = function(value) return value == SECRET end, EachChild = function() end }
local QuietMouse = assert(load("local catchers = {}\n" .. sheet:sub(first, last - 1) .. "\nreturn QuietMouse", "quiet", "t",
    setmetatable({ ns = stubs }, { __index = _G })))()
local function Piece(answer)
    local piece = { calls = 0 }
    piece.IsMouseEnabled = function() return answer end
    piece.IsMouseWheelEnabled = function() return answer end
    piece.EnableMouse = function(self) self.calls = self.calls + 1 end
    piece.EnableMouseWheel = function(self) self.calls = self.calls + 1 end
    return piece
end
local secret = Piece(SECRET)
QuietMouse(secret, 10)
Check(secret.calls == 0 and secret.fcuiMouseWas == nil and secret.fcuiWheelWas == nil,
    "a piece answering secret about its mouse is left as it is")
local plain = Piece(true)
QuietMouse(plain, 10)
Check(plain.calls == 2 and plain.fcuiMouseWas == true and plain.fcuiWheelWas == true,
    "a piece with the mouse on loses it and is marked for the hand back")
local off = Piece(false)
QuietMouse(off, 10)
Check(off.calls == 0 and off.fcuiMouseWas == nil, "a piece with the mouse off is left alone")
Check(not sheet:find("frame:IsMouseEnabled() then", 1, true) and not sheet:find("frame:IsMouseWheelEnabled() then", 1, true),
    "no mouse answer is tested bare in the quieting code")

if failed > 0 then
    print(string.format("skill detail pane: %d failed", failed))
    os.exit(1)
end
print("skill detail pane: ok")
