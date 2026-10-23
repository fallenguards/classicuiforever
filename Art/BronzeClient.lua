local _, ns = ...

-- Custom theme on client art (chat buttons, NPC windows, auras): the old sheets at the same coords under the theme's
-- layers when on, the client's art back when off. The client resets art at will, so a light watch keeps it.

local B = ns.bronze
local BronzeCopy = ns.BronzeCopy

-- Atlas sheets the theme has, by file id (BronzeCopy finds the old sheet).
local SHEETS = {
    [1537274] = "QuickJoin-Atlas.tga",
    [1706035] = "ChatFrame-Atlas.tga",
    -- Inset and inner border corners, and the strips tiled across and down.
    [1723831] = "UIFrame-Inner-Atlas.tga",
    [1723832] = "UIFrame-VTile-Atlas.tga",
    [1723833] = "UIFrame-HTile-Atlas.tga",
}
-- Plain files the theme has, by file id.
local FILES = {
    [130949] = "UI-ChatIcon-Chat-Up.tga",
    [130948] = "UI-ChatIcon-Chat-Down.tga",
    [130947] = "UI-ChatIcon-Chat-Disabled.tga",
    -- Mail window: slot frames, bars, money boxes, slot backs, invoice line.
    [136383] = "MailItemBorder.tga",
    [130968] = "UI-ClassTrainer-HorizontalBar.tga",
    [130975] = "Common-Input-Border.tga",
    [130862] = "UI-Slot-Background.tga",
    [136387] = "UI-MailFrame-InvoiceLine.tga",
    -- Page arrows (mail inbox, vendor).
    [130864] = "UI-SpellbookIcon-NextPage-Disabled.tga",
    [130865] = "UI-SpellbookIcon-NextPage-Down.tga",
    [130866] = "UI-SpellbookIcon-NextPage-Up.tga",
    [130867] = "UI-SpellbookIcon-PrevPage-Disabled.tga",
    [130868] = "UI-SpellbookIcon-PrevPage-Down.tga",
    [130869] = "UI-SpellbookIcon-PrevPage-Up.tga",
    -- The square behind the vendor's page arrows.
    [130822] = "UI-PageButton-Background.tga",
    -- Trade, merchant and bank slots: ring, empty slot, name plate.
    [130841] = "UI-Quickslot2.tga",
    [130766] = "UI-EmptySlot.tga",
    [136796] = "UI-QuestItemNameFrame.tga",
    -- Red panel buttons, sliced from the old sheet.
    [130828] = "UI-Panel-Button-Up.tga",
    [130825] = "UI-Panel-Button-Down.tga",
    [130824] = "UI-Panel-Button-Disabled.tga",
    -- Trade window's empty "will not be traded" slot.
    [137072] = "UI-TradeFrame-EnchantIcon.tga",
    -- The bags' sheet: each item slot's background is cut from it.
    [131003] = "UI-Bag-Components.tga",
    -- The game's own checkboxes left unskinned (the group finder's role picks).
    [130755] = "UI-CheckBox-Up.tga",
    [130752] = "UI-CheckBox-Down.tga",
}
-- Atlases on a sheet too big to copy whole, packed into small copies: lower-case atlas -> copy, crop, tiled across.
-- The game menu's red buttons: per state row, the right cap then the left; the middle alone, full width to tile.
local PACKED = {}
for row, state in ipairs({ "", "-pressed", "-disabled" }) do
    local top, bottom = (row - 1) / 4, row / 4
    PACKED["128-redbutton-right" .. state] = { "RedButtonCaps.tga", 0, 292 / 512, top, bottom }
    PACKED["128-redbutton-left" .. state] = { "RedButtonCaps.tga", 296 / 512, 410 / 512, top, bottom }
    PACKED["_128-redbutton-center" .. state] = { "RedButtonCenter.tga", 0, 1, top, bottom, true }
end
local clientWas = setmetatable({}, { __mode = "k" })
B.clientWas = clientWas
local IsSecret = ns.IsSecret

-- Atlas info is static and GetAtlasInfo builds a table per call: per atlas, its info if its sheet has a copy, else false.
local atlasCopy = {}
-- Per texture, the copyless atlas it was last judged on.
local judged = setmetatable({}, { __mode = "k" })

local function AskCopy(atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    return info and SHEETS[info.file] and info or false
end

local function CopyInfo(atlas)
    local info = atlasCopy[atlas]
    if info == nil then
        info = AskCopy(atlas)
        atlasCopy[atlas] = info
    end
    return info
end

-- Reuses the texture's record: no table per client reset.
local function Remember(texture, was, atlas, file)
    was = was or {}
    was.atlas, was.file, was.copyID = atlas, file, texture:GetTexture()
    clientWas[texture] = was
end

local function SwapPacked(texture, was, atlas, packed)
    local copy = BronzeCopy(packed[1])
    local across = packed[6] == true
    local wrap = across and "REPEAT" or "CLAMP"
    if copy and texture:SetTexture(copy, wrap, "CLAMP") ~= false then
        texture:SetTexCoord(packed[2], packed[3], packed[4], packed[5])
        if texture.SetHorizTile then texture:SetHorizTile(across) end
        Remember(texture, was, atlas, nil)
        ns.UntintGameArt(texture)
        ns.PaintCopy(texture, copy, wrap, "CLAMP")
    else
        texture:SetAtlas(atlas)
    end
end

-- The theme on, read once a pass, not per texture.
local themeOn = false
-- Our own pieces on the game's atlases (the inset border): on the theme's copies as the game's are, across every turn.
local ours = setmetatable({}, { __mode = "k" })

local function BronzeClient(texture, off)
    if not texture or not texture.GetAtlas then return end
    -- Our own pieces: the theme already handles them.
    if B.tinted[texture] or B.swapped[texture] then return end
    local was = clientWas[texture]
    if off or not themeOn or not ns.ThemePartOn(texture) then
        if was then
            clientWas[texture] = nil
            if was.atlas then
                -- Clear first: SetAtlas of the atlas a texture still names is a no-op and draws nothing.
                texture:SetTexture(nil)
                texture:SetTexCoord(0, 1, 0, 1)
                texture:SetAtlas(was.atlas)
            else
                -- A file keeps its crop: the client's (a red panel button's three slices), never changed under our copy.
                texture:SetTexture(was.file)
            end
            ns.PaintCopy(texture, nil)
        end
        return
    end
    -- Still on our copy: the client has not reset it.
    if was and texture:GetTexture() == was.copyID then return end
    local atlas = texture:GetAtlas()
    -- A secret atlas is never a key: asked each time.
    local secret = atlas and IsSecret(atlas)
    if atlas and not secret and judged[texture] == atlas then return end
    local packed = atlas and not secret and atlas:find("128%-[Rr]ed[Bb]utton") and PACKED[atlas:lower()]
    if packed then
        SwapPacked(texture, was, atlas, packed)
        return
    end
    if atlas and C_Texture and C_Texture.GetAtlasInfo then
        local info
        if secret then info = AskCopy(atlas) else info = CopyInfo(atlas) end
        if not info then
            if not secret then judged[texture] = atlas end
            return
        end
        -- Only if the copy loads (a failed load draws nothing); tiled strips stay tiled.
        local across, down = info.tilesHorizontally, info.tilesVertically
        local copy = BronzeCopy(SHEETS[info.file])
        if texture:SetTexture(copy, across and "REPEAT" or "CLAMP", down and "REPEAT" or "CLAMP") ~= false then
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            if texture.SetHorizTile then texture:SetHorizTile(across and true or false) end
            if texture.SetVertTile then texture:SetVertTile(down and true or false) end
            Remember(texture, was, atlas, nil)
            ns.UntintGameArt(texture)
            ns.PaintCopy(texture, copy, across and "REPEAT" or "CLAMP", down and "REPEAT" or "CLAMP")
        else
            texture:SetAtlas(atlas)
        end
        return
    end
    local file = texture:GetTexture()
    local copy = type(file) == "number" and BronzeCopy(FILES[file])
    if copy then
        if texture:SetTexture(copy) ~= false then
            Remember(texture, was, nil, file)
            ns.UntintGameArt(texture)
            ns.PaintCopy(texture, copy)
        else
            texture:SetTexture(file)
        end
    end
end

-- Re-gathered each pass (the client may give a button a new texture) into one reused table.
local CHAT_BUTTONS = { "ChatFrameChannelButton", "TextToSpeechButton", "ChatFrameMenuButton" }
local STATE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }
local chatList, chatCount = {}, 0

local function ChatTextures()
    local list, n = chatList, 0
    local quick = _G["QuickJoinToastButton"]
    if quick and quick.FriendsButton then
        n = n + 1
        list[n] = quick.FriendsButton
    end
    for i = 1, #CHAT_BUTTONS do
        local button = _G[CHAT_BUTTONS[i]]
        if button and button.GetNormalTexture then
            for j = 1, #STATE_GETTERS do
                local tex = button[STATE_GETTERS[j]](button)
                if tex then
                    n = n + 1
                    list[n] = tex
                end
            end
        end
    end
    -- Drop stale entries past this pass's count.
    for i = n + 1, chatCount do list[i] = nil end
    chatCount = n
    return list, n
end

local CLIENT_WINDOWS = { "MailFrame", "OpenMailFrame", "TradeFrame", "MerchantFrame", "BankFrame", "GossipFrame", "QuestFrame",
    "ClassTrainerFrame", "LootFrame", "GameMenuFrame", "CharacterFrame", "PlayerSpellsFrame", "FriendsFrame", "PVEFrame",
    "LFGParentFrame", "WorldMapFrame", "SettingsPanel", "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2",
    "ContainerFrame3", "ContainerFrame4", "ContainerFrame5", "ContainerFrame6", "ProfessionsFrame", "ProfessionsBookFrame",
    "CalendarFrame", "CommunitiesFrame", "AchievementFrame", "MacroFrame", "AddonList", "InspectFrame", "AuctionHouseFrame",
    "GuildBankFrame", "ItemSocketingFrame", "DressUpFrame", "TaxiFrame", "PetStableFrame", "HelpFrame", "TimeManagerFrame",
    "ChannelFrame", "ItemTextFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

-- Forbidden pieces (trade window money boxes) may not be asked for regions.
local Forbidden = ns.IsForbidden

-- pcall-guarded walk, no tables built, five levels deep at most.
local EachRegionProtected, EachChildProtected = ns.EachRegionProtected, ns.EachChildProtected

-- Whether a region is a texture we may ask, worked out once.
local askable = setmetatable({}, { __mode = "k" })
local function ClientRegion(region)
    local ask = askable[region]
    if ask == nil then
        ask = not Forbidden(region) and region.IsObjectType ~= nil and region:IsObjectType("Texture")
        askable[region] = ask
    end
    if ask then pcall(BronzeClient, region) end
end

-- One client texture to the theme (off = back to the client's), for watchers of our own.
function ns.BronzeClientTexture(texture, off)
    themeOn = ns.BronzeOn()
    if texture and not Forbidden(texture) then pcall(BronzeClient, texture, off) end
end

local WalkClient, Watch
local function ClientChild(child, depth)
    WalkClient(child, depth + 1)
end

WalkClient = function(frame, depth)
    if Forbidden(frame) or depth > 5 or not frame.GetRegions or B.PlainTree(frame) then return end
    EachRegionProtected(frame, ClientRegion)
    EachChildProtected(frame, ClientChild, depth)
end

-- Theme last seen by the client pass; turning it on wakes the aura rims.
local themeSeen = {}
local WakeAuras

-- A window is walked when something says its art may have changed, never on the beat: as it opens (that frame, a
-- moment later and on the next beat, as its rows arrive), on a press inside it, on the game's window events.
local clientJob
local SETTLE, OPEN_WALKS = 0.15, 3
local watched = setmetatable({}, { __mode = "k" })
local walks = setmetatable({}, { __mode = "k" })   -- window -> walks still owed
local pressed = setmetatable({}, { __mode = "k" }) -- frames to walk once: where a press landed
local function KickPass()
    clientJob:Kick()
end
local function Owe(window, count)
    if (walks[window] or 0) < count then walks[window] = count end
    clientJob:Kick()
end
local function Opened(window, shown)
    ns.FollowLayers(window)
    if shown and clientJob then
        Owe(window, OPEN_WALKS)
        ns.Sched.AfterPerFrame("bronze.client.settle", SETTLE, KickPass)
    end
end
Watch = function(window)
    if watched[window] then return end
    watched[window] = true
    ns.Sched.OnVisible(window, "bronze.client", function(shown) Opened(window, shown) end)
end

-- Every 0.5 s: only the textures on a copy are asked (the client reset one: a list row reused on a scroll), and a
-- window is walked only when owed. Off, asleep once every copy is handed back.
local function ClientPass(job)
    if not ns.db then return end
    if ns.ThemeTurned(themeSeen) then
        -- One theme to another: every copy handed back so this pass puts on the new theme's.
        if themeSeen.was and themeSeen.on then
            for tex in pairs(clientWas) do BronzeClient(tex, true) end
        end
        if themeSeen.on then WakeAuras() end
    end
    themeOn = ns.BronzeOn()
    if not themeOn then
        -- Restore everything on a copy, window open or not.
        for tex in pairs(clientWas) do BronzeClient(tex) end
        if next(clientWas) == nil then job:Sleep() end
        return
    end
    local list, n = ChatTextures()
    for i = 1, n do BronzeClient(list[i]) end
    for tex in pairs(clientWas) do pcall(BronzeClient, tex) end
    for tex in pairs(ours) do BronzeClient(tex) end
    -- Each window watched so its opening asks for its walk at once.
    for _, name in ipairs(CLIENT_WINDOWS) do
        local window = _G[name]
        if window then
            Watch(window)
            local owed = walks[window]
            if owed then
                walks[window] = owed > 1 and owed - 1 or nil
                if window:IsShown() then WalkClient(window, 0) end
            end
        end
    end
    for frame in pairs(pressed) do
        pressed[frame] = nil
        WalkClient(frame, 0)
    end
end

clientJob = ns.Sched.Job({ name = "bronze.client", every = 0.5, awake = true, fn = ClientPass })

function ns.ThemeClientArt(texture)
    ours[texture] = true
    themeOn = ns.BronzeOn()
    BronzeClient(texture)
    if themeOn then clientJob:Wake() end
end

-- Every open window owes a walk: the theme turned, or the game filled a window.
local function OweOpen()
    for window in pairs(watched) do
        if window:IsShown() then Owe(window, OPEN_WALKS) end
    end
    ns.Sched.AfterPerFrame("bronze.client.settle", SETTLE, KickPass)
end
ns.OnToggle(function(key)
    if not B.THEME_KEYS[key] then return end
    clientJob:Wake()
    clientJob:Kick()
    OweOpen()
end)
ns.EventFrame({ "TRADE_SHOW", "MAIL_SHOW", "MERCHANT_SHOW", "BANKFRAME_OPENED", "GOSSIP_SHOW",
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "TRAINER_SHOW", "LOOT_OPENED" }, OweOpen)

-- A press inside a client window restyles the pressed piece and its row: the pressed frame's parent is walked once
-- (the pressed frame alone when that parent is the window), never the whole window.
ns.EventFrame({ "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP" }, function()
    if not ns.BronzeOn() then return end
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = foci and foci[1]
    local frame = focus
    for _ = 1, 12 do
        if not frame or Forbidden(frame) or not frame.GetParent then return end
        if watched[frame] then break end
        frame = frame:GetParent()
    end
    if not (frame and watched[frame]) then return end
    local spot = focus:GetParent()
    if focus == frame or spot == frame or not spot or Forbidden(spot) then spot = focus end
    pressed[spot] = true
    clientJob:Kick()
end)

-- Buffs have only the icon's grey bevel, so the theme adds the thin rim as on action buttons; debuff borders stay.
-- A rim stays and follows every toggle (ns.BronzeKeep), so only buttons made since the last pass need one.
local EachChild = ns.EachChild
local function AuraRim(button)
    if button == nil then return end
    local icon = button.Icon or button.icon
    if icon and icon.IsObjectType and icon:IsObjectType("Texture") and not button.fcuiBronzeRim then
        ns.BronzeRim(button, icon)
    end
end

local function AuraRims(container)
    if not container or not container.GetChildren then return end
    EachChild(container, AuraRim)
end

-- Looked up each pass, in order; a missing name ends its list.
local BUFF_FRAMES = { "BuffFrame", "DebuffFrame" }
local AURA_UNIT_FRAMES = { "TargetFrame", "FocusFrame" }
-- The player's buttons are made once (BuffFrame.lua AuraFrame_OnLoad): one pass with the theme on rims them all.
local rimmed = setmetatable({}, { __mode = "k" })
-- Passes left after the last trigger: a second one catches buttons made after the first.
local passesLeft = 0

local function AuraPass(job)
    if ns.BronzeOn() then
        for i = 1, #BUFF_FRAMES do
            local frame = _G[BUFF_FRAMES[i]]
            if frame == nil then break end
            local container = frame and (frame.AuraContainer or frame)
            if container and not rimmed[container] then
                AuraRims(container)
                rimmed[container] = true
            end
        end
        -- Target and focus buttons come from pools that grow on their aura changes.
        for i = 1, #AURA_UNIT_FRAMES do
            local unitFrame = _G[AURA_UNIT_FRAMES[i]]
            if unitFrame == nil then break end
            local auras = unitFrame and unitFrame.GetAuraContainer and unitFrame:GetAuraContainer()
            if auras then AuraRims(auras) end
        end
    end
    passesLeft = passesLeft - 1
    if passesLeft <= 0 then job:Sleep() end
end

local auraJob = ns.Sched.Job({ name = "bronze.auras", every = 0.5, awake = false, fn = AuraPass })

-- From asleep a pass at once; a stream of triggers keeps it at twice a second, as the old poll ran.
WakeAuras = function()
    if not ns.BronzeOn() then return end
    passesLeft = 2
    if auraJob:IsAwake() then return end
    auraJob:Wake()
    auraJob:Kick()
end

-- The pools grow on these; edit mode switches the aura source to its fakes.
local auraEvents = ns.EventFrame({ "UNIT_AURA" }, function() WakeAuras() end, "target", "focus")
ns.RegisterEvents(auraEvents, { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD",
    "AURA_DATA_PROVIDER_SWITCH" })
