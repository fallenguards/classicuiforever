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

local RESET_TIP = { text = L["OPTWIN_RESET_TO_DEFAULT"], r = 1, g = 1, b = 1 }

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

-- A slider's name on a line of its own above it (key: its search entry's).
function O.SliderHead(parent, width, key, label, tip, words)
    local head = ns.NewFrame("Frame", nil, parent)
    head:SetSize(width, 24)
    head:EnableMouse(true)
    head.text = head:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    head.text:SetPoint("LEFT", head, "LEFT", 4, 0)
    head.text:SetJustifyH("LEFT")
    head.text:SetWordWrap(false)
    head.text:SetText(label)
    function head.SetChecked() end
    function head.SetEnabled() end
    O.Describe(head, key, label, tip)
    head.keyLow = head.keyLow .. " " .. words
    return head
end

-- A theme's 0-100 slider (spec: key, default, set, label, tip, words) and a button back to its default.
local function ThemeSlider(parent, width, spec)
    local function Value() return tonumber(ns.db[spec.key]) or spec.default end
    local row, reset, icon = O.SliderRow(parent, width)
    local slider = ns.band.StepperSlider(row, width - 34, row, 0)
    local Fill
    if slider then
        ns.SetPointOnce(slider, "LEFT", row, "LEFT", 2, 0)
        Fill = ns.band.GuardedSlider(slider, function() return Value(), 0, 100, 20 end, function(value)
            row.shown = math.floor(value + 0.5)
            ns.Sched.NextFrame("options." .. spec.key, function() spec.set(row.shown) end)
        end, { owner = row, enabled = function() return row.on ~= false end })
    end
    -- No refill while the player drags: only when the saved value or the enabled state moved under it.
    function row:Sync()
        if not Fill or (self.shown == Value() and self.filledOn == self.on) then return end
        self.shown, self.filledOn = Value(), self.on
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
        spec.set(spec.default)
        row.shown = nil
        row:Sync()
    end)
    O.Describe(row, spec.key, spec.label, spec.tip)
    row.keyLow = row.keyLow .. " " .. spec.words
    return row
end

-- Dark's slider, light grey to black.
function O.DarknessRow(parent, width)
    return ThemeSlider(parent, width, { key = "themeDarkness", default = ns.DARKNESS_DEFAULT, set = ns.SetThemeDarkness,
        label = L["OPTWIN_DARKNESS"], tip = L["OPTWIN_DARKNESS_TIP"], words = "dark black grey gray shade slider theme" })
end

-- Background shade (broad mode): its name on a line of its own, the slider under it, as the camera's.
function O.PaneRow(parent, width)
    local label, tip = L["OPTWIN_BACKGROUND_SHADE"], L["OPTWIN_BACKGROUND_SHADE_TIP"]
    local words = "pane parchment background secondary second color colour dark light shade contrast slider theme"
    local head = O.SliderHead(parent, width, "themePaneShadeHead", label, tip, words)
    local row = ThemeSlider(parent, width, { key = "themePaneShade", default = ns.PANE_SHADE_DEFAULT,
        set = ns.SetThemePaneShade, label = label, tip = tip, words = words })
    return head, row
end
