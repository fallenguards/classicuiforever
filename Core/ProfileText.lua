local _, ns = ...
local L = ns.L

-- A profile as text for the Profiles page's Export and Import: CUIF1 then one table { n = name, s = settings }, written
-- compact and read back by a small parser, never run as code. Only known profile keys with values of the defaults'
-- type come in, so text from another version or a stranger can plant nothing.

local MARK = "CUIF1"
local TEXT_MAX = 65536
local DEPTH_MAX = 3
local NAME_CUT = 28   -- room under the 32-letter limit for a number when the name is taken

local ESCAPES = { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n" }
local UNESCAPES = { ["\\"] = "\\", ['"'] = '"', n = "\n" }

local function Plain(v)
    local t = type(v)
    return t == "boolean" or t == "number" or t == "string"
end

local function KeyOrder(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
end

local Encode
local function EncodeTable(v, out)
    local keys = {}
    for k, item in pairs(v) do
        if (type(k) == "string" or type(k) == "number") and (Plain(item) or type(item) == "table") then keys[#keys + 1] = k end
    end
    table.sort(keys, KeyOrder)
    out[#out + 1] = "{"
    for i, k in ipairs(keys) do
        if i > 1 then out[#out + 1] = "," end
        if type(k) == "string" and k:find("^[%a_][%w_]*$") then out[#out + 1] = k else Encode(k, out) end
        out[#out + 1] = "="
        Encode(v[k], out)
    end
    out[#out + 1] = "}"
end

Encode = function(v, out)
    local t = type(v)
    if t == "boolean" then
        out[#out + 1] = v and "t" or "f"
    elseif t == "number" then
        out[#out + 1] = string.format("%.14g", v)
    elseif t == "string" then
        out[#out + 1] = '"' .. v:gsub('[\\"\n]', ESCAPES) .. '"'
    elseif t == "table" then
        EncodeTable(v, out)
    end
end

local Value

local function ReadString(text, pos)
    local out, i = {}, pos + 1
    while true do
        local c = text:sub(i, i)
        if c == "" then return nil end
        if c == '"' then return table.concat(out), i + 1 end
        if c == "\\" then
            local plain = UNESCAPES[text:sub(i + 1, i + 1)]
            if not plain then return nil end
            out[#out + 1] = plain
            i = i + 2
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

local function ReadTable(text, pos, depth)
    local out = {}
    pos = pos + 1
    if text:sub(pos, pos) == "}" then return out, pos + 1 end
    while true do
        local key
        local s, e = text:find("^[%a_][%w_]*", pos)
        if s then
            key, pos = text:sub(s, e), e + 1
        else
            key, pos = Value(text, pos, 0)
            if not (type(key) == "string" or type(key) == "number") then return nil end
        end
        if text:sub(pos, pos) ~= "=" then return nil end
        local item
        item, pos = Value(text, pos + 1, depth - 1)
        if item == nil then return nil end
        out[key] = item
        local c = text:sub(pos, pos)
        if c == "}" then return out, pos + 1 end
        if c ~= "," then return nil end
        pos = pos + 1
    end
end

Value = function(text, pos, depth)
    local c = text:sub(pos, pos)
    if c == "t" then return true, pos + 1 end
    if c == "f" then return false, pos + 1 end
    if c == '"' then return ReadString(text, pos) end
    if c == "{" then
        if depth <= 0 then return nil end
        return ReadTable(text, pos, depth)
    end
    local s, e = text:find("^%-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    local n = s and tonumber(text:sub(s, e))
    if n then return n, e + 1 end
    return nil
end

function ns.EncodeProfile(name, shot)
    local out = { MARK }
    Encode({ n = name, s = shot }, out)
    return table.concat(out)
end

-- The name and settings in the text, or nil and why not.
function ns.DecodeProfile(text)
    if type(text) ~= "string" or #text > TEXT_MAX then return nil, L["CORE_NOT_A_PROFILE"] end
    text = text:match("^%s*(.-)%s*$")
    if text:sub(1, #MARK) ~= MARK then return nil, L["CORE_NOT_A_PROFILE"] end
    local data, pos = Value(text, #MARK + 1, DEPTH_MAX)
    if type(data) ~= "table" or pos ~= #text + 1 or type(data.n) ~= "string" or type(data.s) ~= "table" then
        return nil, L["CORE_NOT_A_PROFILE"]
    end
    local shot, defaults = {}, ns.DB_DEFAULTS
    for _, k in ipairs(ns.ProfileKeys()) do
        local v, want = data.s[k], defaults[k]
        if v ~= nil and (want == nil or type(v) == type(want)) and (Plain(v) or type(v) == "table") then
            if type(v) == "table" then
                local copy = {}
                for key, item in pairs(v) do
                    if Plain(key) and Plain(item) then copy[key] = item end
                end
                v = next(copy) ~= nil and copy or nil
            end
            shot[k] = v
        end
    end
    return data.n, shot
end

-- The profile in use, stored fresh first.
function ns.ExportProfile()
    ns.StoreProfile()
    local name = ns.ProfileName()
    return ns.EncodeProfile(name, ns.db.profiles[name] or {})
end

-- A new profile from the text, named as it was (numbered while that name is taken); this character switches to it.
function ns.ImportProfile(text)
    local name, shot = ns.DecodeProfile(text)
    if not name then return nil, shot end
    local base = name:match("^%s*(.-)%s*$"):sub(1, NAME_CUT)
    if base == "" then base = L["CORE_IMPORTED"] end
    local pick, n = base, 1
    while not ns.CheckProfileName(pick) do
        n = n + 1
        if n > 999 then return nil, L["CORE_NOT_A_PROFILE"] end
        pick = base .. " " .. n
    end
    ns.db.profiles[pick] = shot
    ns.UseProfile(pick)
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    return pick
end
