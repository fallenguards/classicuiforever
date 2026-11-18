-- Offline test under Lua 5.4: a standalone left off (Core/Package.lua's inert part) says so in chat and in one popup;
-- several copies left off at once share that popup, every title in it, shown once.
-- Run from the addon root: lua tools/tests/inert_popup_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local L = {
    PKG_OFF_FULL = "%s off, full on.",
    PKG_OFF_OTHER = "%s off, another on.",
    PKG_POPUP_FULL_MANY = "Full on:\n\n%s",
    PKG_POPUP_OTHER = "One at a time:\n\n%s",
}

-- One login: each copy's file run, then the game's two login events to every copy, as the client sends them.
local function Login(inert, titles)
    local frames, chat, shown = {}, {}, {}
    local env = setmetatable({
        OKAY = "Okay",
        StaticPopupDialogs = {},
        DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) chat[#chat + 1] = text end },
        CreateFrame = function()
            local frame = { events = {} }
            function frame:RegisterEvent(event) self.events[event] = true end
            function frame:UnregisterEvent(event) self.events[event] = nil end
            function frame:SetScript(_, fn) self.onEvent = fn end
            frames[#frames + 1] = frame
            return frame
        end,
    }, { __index = _G })
    env.StaticPopup_Show = function(name) shown[#shown + 1] = env.StaticPopupDialogs[name].text end
    for _, title in ipairs(titles) do
        local chunk = assert(loadfile(ROOT .. "/Core/Package.lua", "t", env))
        chunk("ClassicUIForever" .. title, { INERT = inert, L = L, PACKAGE = { title = title } })
    end
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_ENTERING_WORLD" }) do
        for _, frame in ipairs(frames) do
            if frame.events[event] then frame.onEvent(frame, event) end
        end
    end
    return chat, shown
end

local chat, shown = Login("full", { "Windows" })
Check(#chat == 1 and chat[1] == "Windows off, full on.", "one copy beside the full addon: its chat line")
Check(#shown == 1 and shown[1] == "Windows off, full on.", "one copy beside the full addon: one popup saying why")

chat, shown = Login("full", { "Windows", "Bags" })
Check(#chat == 2, "two copies beside the full addon: a chat line each")
Check(#shown == 1 and shown[1] == "Full on:\n\nWindows\nBags", "two copies beside the full addon: one popup, both named")

chat, shown = Login("other", { "Windows", "Bags", "Chat" })
Check(#chat == 3, "three copies on their own: a chat line each")
Check(#shown == 1 and shown[1] == "One at a time:\n\nWindows\nBags\nChat", "three copies on their own: one popup, all named")

if failed > 0 then
    print(failed .. " inert popup check(s) failed")
    os.exit(1)
end
print("inert popup: all checks passed")
