local _, ns = ...
local L = ns.L

-- The theme's own rows in the options list: the custom colour swatch and Dark's slider. O.Describe is OptionsWindow's.

local O = ns.options

-- The custom theme's colour: a swatch opening the game's colour picker (its hex box included).
local function PickColor(r, g, b)
    ns.Sched.NextFrame("options.themeColor", function() ns.SetThemeColor(r, g, b) end)
end

function O.ColorRow(parent, key, label, tooltip)
    local row = ns.NewFrame("Button", nil, parent)
    row:SetSize(24, 24)
    local swatch = row:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(16, 16)
    swatch:SetPoint("LEFT", row, "LEFT", 4, 0)
    local rim = row:CreateTexture(nil, "BACKGROUND")
    rim:SetColorTexture(0, 0, 0, 1)
    rim:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
    rim:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", swatch, "RIGHT", 6, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    function row:Sync()
        local r, g, b = ns.HexColor(ns.db[key])
        swatch:SetColorTexture(r or 1, g or 1, b or 1)
        swatch:SetAlpha(self.on == false and 0.4 or 1)
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled(on)
        self.on = on and true or false
        self:EnableMouse(self.on)
        self:Sync()
    end
    row:SetScript("OnClick", function()
        local r, g, b = ns.HexColor(ns.db[key])
        local was = ns.db[key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r or 1, g = g or 1, b = b or 1,
            swatchFunc = function()
                PickColor(ColorPickerFrame:GetColorRGB())
                row:Sync()
            end,
            cancelFunc = function()
                PickColor(ns.HexColor(was))
                row:Sync()
            end,
        })
    end)
    O.Describe(row, key, label, tooltip)
    return row
end

-- Dark's slider, light grey to black, and a button back to its first shade.
local RESET_TIP = { text = L["OPTWIN_RESET_TO_DEFAULT"], r = 1, g = 1, b = 1 }
local function Darkness() return tonumber(ns.db.themeDarkness) or ns.DARKNESS_DEFAULT end
local function SetDarkness(value)
    ns.Sched.NextFrame("options.themeDarkness", function() ns.SetThemeDarkness(value) end)
end

-- A slider row's frame: its reset button at the right (returned with its icon), the slider's room beside it
-- (width - 34). width: the row's room in its column.
function O.SliderRow(parent, width)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(width, 24)
    row:EnableMouse(true)
    local reset = ns.PanelButton(row, "", 24)
    reset:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    local icon = reset:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER", 0, 0)
    ns.AttachTip(reset, RESET_TIP)
    -- Empty: the list's font and match bar hang on a row's text.
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("RIGHT", reset, "LEFT", 0, 0)
    return row, reset, icon
end

function O.DarknessRow(parent, width)
    local row, reset, icon = O.SliderRow(parent, width)
    local slider = ns.band.StepperSlider(row, width - 34, row, 0)
    local Fill
    if slider then
        ns.SetPointOnce(slider, "LEFT", row, "LEFT", 2, 0)
        Fill = ns.band.GuardedSlider(slider, function() return Darkness(), 0, 100, 20 end, function(value)
            row.shown = math.floor(value + 0.5)
            SetDarkness(row.shown)
        end, { owner = row, enabled = function() return row.on ~= false end })
    end
    -- No refill while the player drags: only when the saved value or the enabled state moved under it.
    function row:Sync()
        if not Fill or (self.shown == Darkness() and self.filledOn == self.on) then return end
        self.shown, self.filledOn = Darkness(), self.on
        Fill()
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled(on)
        self.on = on and true or false
        reset:SetEnabled(self.on)
        icon:SetDesaturated(not self.on)
        self:Sync()
    end
    reset:SetScript("OnClick", function()
        ns.SetThemeDarkness(ns.DARKNESS_DEFAULT)
        row.shown = nil
        row:Sync()
    end)
    O.Describe(row, "themeDarkness", L["OPTWIN_DARKNESS"], L["OPTWIN_DARKNESS_TIP"])
    row.keyLow = row.keyLow .. " dark black grey gray shade slider theme"
    return row
end
