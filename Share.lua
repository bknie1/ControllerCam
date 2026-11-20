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

---------------------------------------------------------------------------
-- The whole setup: which profile each situation uses, your own profiles, the built-in ones you edited.
--
-- Format:   CCS1:<checksum>:<field>&<field>...
--   a=<situation>><ref>,...   ref: a built-in profile's id, or #n for the n-th own profile further on
--   c=<ref>                   the profile used everywhere regardless, if any
--   d=<seconds>  f=0|1  v=0|1   exit delay, flipped shoulder, advanced editing
--   s=<form>><share>,...      your share of the shoulder offset per shapeshift form
--   p=<profile string>        an own profile (a whole CC1 string as above), any number of them
--   o=<id>><profile string>   a built-in profile you edited
--
-- Checked the same way as a profile: all of it first, and a bad string changes nothing.
---------------------------------------------------------------------------
local SETUP_VERSION = 1
local MAX_SETUP_LENGTH = 30000
local MAX_SETUP_PROFILES = 40

local function refText(r) return type(r) == "number" and ("#" .. r) or r end

-- setup: { assign = { situation = ref }, force = ref, exitDelay, flipShoulder, advanced, formOffset = { id = share },
--          profiles = { { name, values } }, overrides = { id = values } }   (ref: a built-in id, or an index into profiles)
function ns.FormatSetup(setup)
    local parts, list = {}, {}
    for _, sit in ipairs(ns.SITUATIONS) do
        if setup.assign[sit] then list[#list + 1] = sit .. ">" .. refText(setup.assign[sit]) end
    end
    parts[#parts + 1] = "a=" .. table.concat(list, ",")
    if setup.force then parts[#parts + 1] = "c=" .. refText(setup.force) end
    parts[#parts + 1] = "d=" .. ns.FormatNumber(setup.exitDelay or 0)
    parts[#parts + 1] = "f=" .. (setup.flipShoulder and 1 or 0)
    parts[#parts + 1] = "v=" .. (setup.advanced and 1 or 0)
    local forms = {}
    for id in pairs(setup.formOffset or {}) do forms[#forms + 1] = id end
    table.sort(forms)
    list = {}
    for _, id in ipairs(forms) do list[#list + 1] = ("%d>%s"):format(id, ns.FormatNumber(setup.formOffset[id])) end
    if #list > 0 then parts[#parts + 1] = "s=" .. table.concat(list, ",") end
    for _, p in ipairs(setup.profiles or {}) do parts[#parts + 1] = "p=" .. ns.ExportProfile(p) end
    local ids = {}
    for id in pairs(setup.overrides or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        parts[#parts + 1] = "o=" .. id .. ">" .. ns.ExportProfile({ name = id, values = setup.overrides[id] })
    end
    local body = table.concat(parts, "&")
    return ("CCS%d:%s:%s"):format(SETUP_VERSION, ns.ShareChecksum(body), body)
end

-- str -> setup (as above) or nil, localized error message
function ns.ParseSetup(str)
    local NOT = L["That is not a ControllerCam profile string."]
    if type(str) ~= "string" then return nil, NOT end
    str = str:gsub("%s+", "")
    if #str > MAX_SETUP_LENGTH then return nil, L["The string is too long to be a profile."] end
    local ver, sum, body = str:match("^CCS(%d+):(%x%x%x%x%x%x%x%x):(.+)$")
    if not ver then return nil, NOT end
    ver = tonumber(ver)
    if ver > SETUP_VERSION then return nil, L["This profile was made with a newer version of ControllerCam. Please update the addon."] end
    if ver < 1 then return nil, NOT end
    if ns.ShareChecksum(body) ~= sum:lower() then
        return nil, L["The string is damaged (checksum mismatch). Copy it again, completely."]
    end

    local setup = { assign = {}, formOffset = {}, profiles = {}, overrides = {} }
    local function ref(raw)
        local n = raw:match("^#(%d+)$")
        if n then return tonumber(n) end
        if ns.BUILTIN[raw] then return raw end
    end
    for field in body:gmatch("[^&]+") do
        local key, raw = field:match("^(%a)=(.*)$")
        if key == "a" then
            for pair in raw:gmatch("[^,]+") do
                local sit, r = pair:match("^(%w+)>(.+)$")
                r = r and ref(r)
                if not (r and ns.SITUATION_LABEL[sit]) then return nil, NOT end
                setup.assign[sit] = r
            end
        elseif key == "c" then
            setup.force = ref(raw)
            if not setup.force then return nil, NOT end
        elseif key == "d" then
            local n = tonumber(raw)
            if not n or n < 0 or n > 10 then return nil, NOT end
            setup.exitDelay = n
        elseif key == "f" or key == "v" then
            if raw ~= "0" and raw ~= "1" then return nil, NOT end
            setup[key == "f" and "flipShoulder" or "advanced"] = (raw == "1")
        elseif key == "s" then
            for pair in raw:gmatch("[^,]+") do
                local id, share = pair:match("^(%d+)>([%d%.]+)$")
                id, share = tonumber(id), tonumber(share)
                if not (id and share and share >= 0 and share <= 2) then return nil, NOT end
                setup.formOffset[id] = share
            end
        elseif key == "p" then
            if #setup.profiles >= MAX_SETUP_PROFILES then return nil, L["The string is too long to be a profile."] end
            local p, err = ns.ParseProfile(raw)
            if not p then return nil, err end
            setup.profiles[#setup.profiles + 1] = p
        elseif key == "o" then
            local id, rest = raw:match("^(%w+)>(.+)$")
            local p, err
            if id and ns.BUILTIN[id] then p, err = ns.ParseProfile(rest) end
            if not p then return nil, err or NOT end
            setup.overrides[id] = p.values
        else
            return nil, NOT
        end
    end
    local function there(r) return type(r) ~= "number" or setup.profiles[r] ~= nil end   -- every #n came along
    if not there(setup.force) then return nil, NOT end
    for _, r in pairs(setup.assign) do
        if not there(r) then return nil, NOT end
    end
    return setup
end
