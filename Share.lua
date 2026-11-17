-- ControllerCam import / export.
--
-- Format:   CC1:<checksum>:<body>
--   CC1       format version. Strings from a newer version are refused with a clear message.
--   checksum  8 hex digits (Adler-32 of the body) to catch typos and truncated copies.
--   body      n=<name>;<key>=<value>;<key>=<value>...   (the name is %XX-escaped; curves are zoom:value,zoom:value)
--
-- Import never runs the text as code. The whole string is parsed and validated first (known keys only, values
-- inside their ranges, size limits), and only a complete, valid profile is returned. A bad string changes nothing.

local ADDON, ns = ...
local L = ns.L

local VERSION = 1
local MAX_LENGTH = 1500
local MAX_FIELDS = 40

local function adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
ns.ShareChecksum = function(s) return string.format("%08x", adler32(s)) end

local function escape(s)
    return (s:gsub("[^%w_ %-]", function(c) return string.format("%%%02X", c:byte()) end):gsub(" ", "%%20"))
end

local function unescape(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function encodeValue(s, v)
    if s.kind == "curve" then
        local parts = {}
        for _, p in ipairs(v) do
            parts[#parts + 1] = ns.FormatNumber(p[1]) .. ":" .. ns.FormatNumber(p[2])
        end
        return table.concat(parts, ",")
    end
    if type(v) == "number" then return ns.FormatNumber(v) end
    return v
end

-- profile: { name = "...", values = { key = value } }  ->  string
function ns.ExportProfile(profile)
    local parts = { "n=" .. escape(profile.name or "") }
    for _, s in ipairs(ns.SETTINGS) do                    -- schema order: the same profile always gives the same string
        local v = profile.values[s.key]
        if v ~= nil then parts[#parts + 1] = s.key .. "=" .. encodeValue(s, v) end
    end
    local body = table.concat(parts, ";")
    return ("CC%d:%s:%s"):format(VERSION, ns.ShareChecksum(body), body)
end

local function decodeValue(s, raw)
    if s.kind == "curve" then
        local points = {}
        for z, v in raw:gmatch("([^:,]+):([^:,]+)") do
            points[#points + 1] = { tonumber(z), tonumber(v) }
        end
        -- make sure the pattern skipped nothing (e.g. "1:2,3")
        if #points == 0 or select(2, raw:gsub(",", "")) ~= #points - 1 then return nil end
        return points
    end
    if raw == "d" then return "d" end
    if s.kind == "mul" then return raw end                -- "x1.25": checked by ValidateValue
    return tonumber(raw)
end

local REASONS = {
    range   = L["a value is outside its allowed range"],
    type    = L["a value is not valid"],
    curve   = L["a curve is not valid"],
    unknown = L["it contains a setting this version does not know"],
}

-- str -> profile ({ name, values }) or nil, localized error message
function ns.ParseProfile(str)
    if type(str) ~= "string" then return nil, L["That is not a ControllerCam profile string."] end
    str = str:gsub("%s+", "")                             -- pasted text often gains line breaks
    if str == "" then return nil, L["Nothing to import."] end
    if #str > MAX_LENGTH then return nil, L["The string is too long to be a profile."] end

    local ver, sum, body = str:match("^CC(%d+):(%x%x%x%x%x%x%x%x):(.+)$")
    if not ver then return nil, L["That is not a ControllerCam profile string."] end
    ver = tonumber(ver)
    if ver > VERSION then return nil, L["This profile was made with a newer version of ControllerCam. Please update the addon."] end
    if ver < 1 then return nil, L["That is not a ControllerCam profile string."] end
    if ns.ShareChecksum(body) ~= sum:lower() then
        return nil, L["The string is damaged (checksum mismatch). Copy it again, completely."]
    end

    local name, values, count, seen = nil, {}, 0, {}
    for field in body:gmatch("[^;]+") do
        count = count + 1
        if count > MAX_FIELDS then return nil, L["The string is too long to be a profile."] end
        local key, raw = field:match("^(%w+)=(.+)$")
        if not key then return nil, L["That is not a ControllerCam profile string."] end
        if seen[key] then return nil, L["That is not a ControllerCam profile string."] end
        seen[key] = true
        if key == "n" then
            name = ns.CleanName(unescape(raw))
            if not name then return nil, L["The profile has no valid name."] end
        else
            local s = ns.SETTING_BY_KEY[key]
            if not s then return nil, (L["Cannot import: %s (%s)."]):format(REASONS.unknown, key) end
            local decoded = decodeValue(s, raw)
            local clean, why
            if decoded ~= nil then clean, why = ns.ValidateValue(s, decoded) else why = "type" end
            if clean == nil then
                return nil, (L["Cannot import: %s (%s)."]):format((REASONS[why] or REASONS.type), key)
            end
            values[key] = clean
        end
    end
    if not name then return nil, L["The profile has no valid name."] end
    return { name = name, values = values }
end
