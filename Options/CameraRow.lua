local _, ns = ...
local L = ns.L
local O = ns.options

-- Max camera distance past the game's own slider (it stops at 2.0; the client takes up to 4.0). A game setting, written
-- only as the player moves this (held in a fight); reset gives the client's default back.

local CVAR = "cameraDistanceMaxZoomFactor"
local LOW, HIGH, STEPS, LABEL_W = 1, 4, 30, 130

local function Current() return tonumber(ns.GetCVar(CVAR)) or LOW end
local function Write(value)
    ns.Sched.NextFrame("options.camera", function() ns.SetCVarOrHold(CVAR, string.format("%.1f", value)) end)
end
local function Tenths(value) return string.format("%.1f", value) end

-- width: the row's room in its column.
function O.CameraRow(parent, width)
    local row, reset = O.SliderRow(parent, width)
    -- Alone in its section, so its name before it (the theme's slider sits under its toggle).
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", row, "LEFT", 4, 0)
    name:SetWidth(LABEL_W)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText(L["OPTWIN_CAMERA_DISTANCE"])
    local slider, formatters = ns.band.StepperSlider(row, width - 34 - LABEL_W - 8, name, 4, Tenths)
    local Fill
    if slider then
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
    O.Describe(row, "cameraDistance", L["OPTWIN_CAMERA_DISTANCE"], L["OPTWIN_CAMERA_DISTANCE_TIP"])
    row.keyLow = row.keyLow .. " camera zoom distance far out view max slider"
    return row
end
