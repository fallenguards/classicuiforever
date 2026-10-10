local _, ns = ...
local L = ns.L
local O = ns.options

-- Max camera distance past the game's own slider (it stops at 2.0; the client takes up to 4.0). A game setting, written
-- only as the player moves this (held in a fight); reset gives the client's default back.

local CVAR = "cameraDistanceMaxZoomFactor"
local LOW, HIGH, STEPS = 1, 4, 30

local function Current() return tonumber(ns.GetCVar(CVAR)) or LOW end
local function Write(value)
    ns.Sched.NextFrame("options.camera", function() ns.SetCVarOrHold(CVAR, string.format("%.1f", value)) end)
end
local function Tenths(value) return string.format("%.1f", value) end
local function Quiet() end

-- Its name on a line of its own, the slider under it indented as the theme's darkness slider. width: the slider row's.
function O.CameraRow(parent, width)
    local head = ns.NewFrame("Frame", nil, parent)
    head:SetSize(width, 24)
    head:EnableMouse(true)
    head.text = head:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    head.text:SetPoint("LEFT", head, "LEFT", 4, 0)
    head.text:SetJustifyH("LEFT")
    head.text:SetWordWrap(false)
    head.text:SetText(L["OPTWIN_CAMERA_DISTANCE"])
    head.SetChecked, head.SetEnabled = Quiet, Quiet
    O.Describe(head, "cameraDistance", L["OPTWIN_CAMERA_DISTANCE"], L["OPTWIN_CAMERA_DISTANCE_TIP"])
    head.keyLow = head.keyLow .. " camera zoom distance far out view max slider"

    local row, reset = O.SliderRow(parent, width)
    local slider, formatters = ns.band.StepperSlider(row, width - 34, row, 4, Tenths)
    local Fill
    if slider then
        ns.SetPointOnce(slider, "LEFT", row, "LEFT", 2, 0)
        Fill = ns.band.GuardedSlider(slider, function() return Current(), LOW, HIGH, STEPS end, function(value)
            row.shown = math.floor(value * 10 + 0.5) / 10
            Write(row.shown)
        end, { owner = row, formatters = formatters })
    end
    -- No refill while the player drags: only when the setting moved under it (the game's slider, a command).
    function row:Sync()
        if not Fill or self.shown == Current() then return end
        self.shown = Current()
        Fill()
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled() self:Sync() end
    reset:SetScript("OnClick", function()
        ns.SetCVarOrHold(CVAR, ns.GetCVarDefault(CVAR))
        row.shown = nil
        ns.Sched.NextFrame("options.cameraReset", function() row:Sync() end)
    end)
    O.Describe(row, "cameraDistanceValue", L["OPTWIN_CAMERA_DISTANCE"], L["OPTWIN_CAMERA_DISTANCE_TIP"])
    row.keyLow = head.keyLow
    return head, row
end
