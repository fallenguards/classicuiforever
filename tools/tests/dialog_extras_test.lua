-- Offline test under Lua 5.4 for our panels under the game's edit mode dialog (UI/DialogExtras.lua): a panel is filled
-- on its first open (one built shown skipped the fill, and the totem bar's sliders came up empty), and its last row
-- stands clear of its border (a Buffs On Top check sat on the bottom edge).
-- Run from the addon root: lua tools/tests/dialog_extras_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local function Frame()
    local f = { shown = true, height = 0 }
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:SetPoint() end
    function f:SetHeight(h) self.height = h end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:CreateFontString()
        local s = {}
        function s:SetPoint() end
        function s:SetText() end
        function s:SetWidth() end
        function s:SetJustifyH() end
        return s
    end
    return f
end

CreateFrame = function() return Frame() end
UIParent = Frame()
local follow
local dialog = Frame()
dialog.Border = Frame()
_G.EditModeSystemSettingsDialog = dialog

local ns = {
    band = { PanelBorder = function() end },
    Sched = {
        Attach = function(_, spec) follow = spec.fn end,
        OnVisible = function() end,
    },
    SetPointOnce = function() end,
    EventFrame = function() end,
    EMPTY = {},
}
assert(loadfile(ROOT .. "/UI/DialogExtras.lua"))("ClassicUIForever", ns)

local system = {}
local fills = 0
ns.DialogExtra({
    title = "test",
    match = function(s) return s == system end,
    -- One check row, as Buffs On Top's panel.
    build = function(panel) panel.rows = panel.rows + 1 end,
    fill = function() fills = fills + 1 end,
})
Check(follow ~= nil, "the panel follows the dialog")

dialog.attachedToSystem = system
follow()
Check(fills == 1, "first open: the panel is filled, got " .. fills .. " fills")
follow()
Check(fills == 1, "still open: no second fill under the hand, got " .. fills)
dialog.shown = false
follow()
dialog.shown = true
follow()
Check(fills == 2, "opened again: filled again, got " .. fills)

-- One row: the title (about 32 down) and a 32 tall row 10 under it end near 74; the border takes about 12.
local CONTENT_FOOT, BORDER = 74, 12
local panel
local seen = {}
local real = CreateFrame
CreateFrame = function()
    local f = real()
    seen[#seen + 1] = f
    return f
end
local other = {}
ns.DialogExtra({ title = "test2", match = function(s) return s == other end,
    build = function(p) p.rows = p.rows + 1 end, fill = function() end })
dialog.attachedToSystem = other
follow()
panel = seen[#seen]
Check(panel and panel.height >= CONTENT_FOOT + BORDER + 8,
    "one row: the panel runs past it and its border, height " .. tostring(panel and panel.height))

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("dialog_extras_test: all checks passed")
