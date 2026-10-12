local _, ns = ...

-- The game's ways into a window, taken for one of ours while its piece is on: its key binding and its micro button.

local KEY_EVENTS = { "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

-- WindowKey(name, binding, press, escName) -> key: key:Set(on) binds or frees the binding's keys (out of combat; a fight
-- waits for its end). press() runs on the key's release; escName arms Escape for the window in a fight (UI/Escape.lua).
-- An override binding onto a secure button of ours, pressed through ns.KeyProxy so it acts on press as the game's own.
function ns.WindowKey(name, binding, press, escName)
    local key = { on = false }
    local button
    local function Bind()
        if not button or InCombatLockdown() then return end
        ClearOverrideBindings(button)
        if not key.on then return end
        for _, k in ipairs({ GetBindingKey(binding) }) do
            SetOverrideBindingClick(button, true, k, ns.KeyProxy(name), "LeftButton")
        end
    end
    function key:Set(on)
        self.on = on and true or false
        -- Secure, so its click can bind Escape in a fight; its events live on a side frame, as a frame with
        -- registrations can be refused by the secure environment.
        if self.on and not button and not InCombatLockdown() then
            button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
            button:RegisterForClicks("AnyDown", "AnyUp")
            button:SetAttribute("useOnKeyDown", false)
            button:SetScript("PostClick", function(_, _, down)
                if not down then press() end
            end)
            if escName and ns.EscArmOnClick then ns.EscArmOnClick(button, escName) end
            ns.EventFrame(KEY_EVENTS, Bind)
        end
        Bind()
    end
    -- A secure click made before press(), in the player's name (the game's spell window's close, UI/WindowCloser.lua), or
    -- none; out of a fight.
    function key.PressFirst(_, target)
        if not button or InCombatLockdown() then return end
        ns.SetAttributeIf(button, "type", target and "click" or nil)
        ns.SetAttributeIf(button, "clickbutton", target)
    end
    key.name = name
    return key
end

-- WindowMicro(names, open) -> take(on): the named micro buttons' clicks run open() while on; off, each gets its own
-- click back, which then runs in our name until a reload (RELOAD_KEYS). In quick keybind mode a click binds instead.
function ns.WindowMicro(names, open)
    local own = {}
    local function Click()
        if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return end
        open()
    end
    return function(on)
        for _, name in ipairs(names) do
            local button = _G[name]
            local click = button and button.GetScript and button:GetScript("OnClick")
            if on and button and button.GetScript and click ~= Click then
                if own[name] == nil then own[name] = click or false end
                button:SetScript("OnClick", Click)
            elseif not on and click == Click then
                button:SetScript("OnClick", own[name] or nil)
            end
        end
    end
end
