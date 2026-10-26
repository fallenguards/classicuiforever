local _, ns = ...

-- The chat's tabs and its typing box's border shown, on hover or hidden, and Hide chat buttons' picks shown on hover
-- (#196). Paint only: the tabs' and the border's own textures and text take an alpha of ours, which the game's fading
-- (a tab's frame alpha) never touches; a hidden tab still takes a click where it stands.

local CHAT_EVENTS = { "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "PLAYER_ENTERING_WORLD" }
local PARTS = { friends = "hideChatFriends", channels = "hideChatChannels", menu = "hideChatMenu",
    scroll = "hideChatScroll", bottom = "hideChatBottom" }
-- A chat window's rect stretched over its tabs above, its button column left and its typing box below.
local REACH_TOP, REACH_BOTTOM, REACH_LEFT = 32, -36, -40
local painted = setmetatable({}, { __mode = "k" })   -- region -> faded by us
local H = { frame = 1, tabs = {} }   -- tabs: chat window name -> its tab's last alpha
local events, job

local function ShowState(id) return ns.MM and ns.MM.ShowState(id) end

-- The mouse over this chat window, its tabs, its button column or its typing box, or its typing box in use.
local function NearChat(chat)
    if chat:IsVisible() and chat:IsMouseOver(REACH_TOP, REACH_BOTTOM, REACH_LEFT, 0) then return true end
    local box = chat.editBox
    return box ~= nil and box:IsVisible() and (box:HasFocus() or box:IsMouseOver())
end

-- Near any chat window; docked = near one in the game's dock (they share its tab row).
local function Near(docked)
    local list = _G.CHAT_FRAMES or ns.EMPTY
    for i = 1, #list do
        local chat = _G[list[i]]
        if chat and (not docked or chat.isDocked) and NearChat(chat) then return true end
    end
    return false
end

-- Only what we faded is given back; now: at once (a pick turned, a tab made), else a fade.
local function Paint(region, alpha, now)
    if alpha == 1 and not painted[region] then return end
    painted[region] = alpha < 1 or nil
    ns.FadeTo(region, alpha, nil, now)
end
local function PaintTexture(region, alpha, now)
    if region:IsObjectType("Texture") then Paint(region, alpha, now) end
end

local function Want(id, near)
    local state = ShowState(id)
    if state == "hide" or (state == "hover" and not near) then return 0 end
    return 1
end

-- Each chat window's tab (its new message flash too) on hover of its own window, or of the dock for a docked one;
-- the typing box borders on hover of any. Again only on a change unless forced.
local function Lay(force)
    local frame = Want("ChatEditFrame", H.hovering and Near())
    local boxes = force or frame ~= H.frame
    H.frame = frame
    local dockNear = H.hovering and Near(true)
    local list = _G.CHAT_FRAMES or ns.EMPTY
    for i = 1, #list do
        local name = list[i]
        local chat = _G[name]
        local near = chat ~= nil and H.hovering and (chat.isDocked and dockNear or not chat.isDocked and NearChat(chat))
        local tabs = Want("ChatTabs", near)
        if force or tabs ~= H.tabs[name] then
            H.tabs[name] = tabs
            local tab, flash = _G[name .. "Tab"], _G[name .. "TabFlash"]
            if tab then ns.EachRegion(tab, Paint, tabs, force) end
            if flash then ns.EachRegion(flash, Paint, tabs, force) end
        end
        local box = boxes and _G[name .. "EditBox"]
        if box then ns.EachRegion(box, PaintTexture, frame, force) end
    end
end

-- Hide chat buttons' picks, on hover: the column keeps their slots (Windows/Chat.lua Off); faded while the mouse is away.
function ns.ChatButtonFaded(part)
    local db = ns.db
    if not (db and db.hideChatButtons and db.hideChatButtonsHover) then return false end
    if part == "all" then
        for _, key in pairs(PARTS) do
            if db[key] == false then return false end
        end
    elseif db[PARTS[part]] == false then
        return false
    end
    return not Near()
end

-- Events and the hover check only while a pick is not shown.
local function Watch()
    local tabs, frame = ShowState("ChatTabs"), ShowState("ChatEditFrame")
    H.hovering = tabs == "hover" or frame == "hover"
    if tabs or frame then
        ns.RegisterEvents(events, CHAT_EVENTS)
    else
        events:UnregisterAllEvents()
    end
    if H.hovering then
        job = job or ns.Sched.Job({ name = "chat.hover", every = 0.1, awake = false, fn = function() Lay() end })
        job:Wake()
    elseif job then
        job:Sleep()
    end
    Lay(true)
end

events = ns.EventFrame({ "PLAYER_LOGIN" }, function(_, event)
    if event == "PLAYER_LOGIN" then Watch() else Lay(true) end
end)

local KEYS = { showChatTabs = true, hoverChatTabs = true, hideChatTabs = true, showChatEditFrame = true,
    hoverChatEditFrame = true, hideChatEditFrame = true }
ns.OnToggle(function(key) if KEYS[key] then Watch() end end)
