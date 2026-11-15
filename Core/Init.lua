-- Startup, saved settings, slash commands and the small public API. Loaded last.
local ADDON_NAME, ns = ...

local U, L = ns.Util, ns.L

local DEFAULTS = {
    schema = 1,
    chat = { maxRows = 8 },
    prewarmIndexes = true,   -- build the cheap indexes a few seconds after login
}

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            applyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local function getMetadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    return get and get(ADDON_NAME, field)
end

ns.version = getMetadata("Version") or "dev"
if ns.version:find("^@") then ns.version = "dev" end

ns.ProviderOrder = { "Questie", "Profession", "LibItemDB", "Client" }

function ns.DetectProviders()
    local any = false
    for _, key in ipairs(ns.ProviderOrder) do
        local p = ns.Providers[key]
        local ok, err = pcall(p.Detect, p)
        if not ok then p.available, p.status = false, "error: " .. tostring(err) end
        if p.available and key ~= "Client" then any = true end
    end
    ns.hasData = any
    return any
end

-- Commands --------------------------------------------------------------------------------

local function resolveItem(text)
    local id = U.ParseItemId(text)
    if id then return id end
    if not text or text == "" then return nil end
    return ns.Providers.LibItemDB:FindByName(text) or ns.Providers.Questie:FindItemByName(text)
end

local function showItem(text)
    if not ns.hasData then U.Print(L["NO_PROVIDERS"]) end
    local itemId = resolveItem(text)
    if not itemId then
        U.Print(L["ITEM_NOT_FOUND"], tostring(text))
        return
    end
    local maxRows = ns.db.chat.maxRows
    local waited = ns.ItemReport.Request(itemId, { maxRows = maxRows }, function(report)
        ns.ChatReport.Print(report, maxRows)
    end)
    if waited then U.Print(L["BUILDING"]) end
end

local function showStatus()
    U.Print("v%s %s", ns.version, L["STATUS_HEADER"])
    for _, key in ipairs(ns.ProviderOrder) do
        local p = ns.Providers[key]
        local color = p.available and "|cff20ff20" or "|cffff5050"
        U.Line(1, "%s%s|r: %s", color, p.title, tostring(p.status))
    end
    local states = {}
    for name in pairs(ns.Index.builders) do states[#states + 1] = name .. "=" .. ns.Index.state[name] end
    table.sort(states)
    U.Line(1, "indexes: %s", table.concat(states, ", "))
end

local function showHelp()
    U.Print(L["HELP_HEADER"])
    U.Line(1, L["HELP_ITEM"])
    U.Line(1, L["HELP_SHORT"])
    U.Line(1, L["HELP_STATUS"])
    U.Line(1, L["HELP_ROWS"]:format(ns.db.chat.maxRows))
end

SLASH_PYROENCYCLOPEDIA1 = "/pyroenc"
SLASH_PYROENCYCLOPEDIA2 = "/pyroencyclopedia"
SlashCmdList["PYROENCYCLOPEDIA"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "help" then
        showHelp()
    elseif cmd == "status" then
        showStatus()
    elseif cmd == "item" then
        showItem(rest)
    elseif cmd == "rows" then
        local n = tonumber(rest)
        if n and n >= 1 and n <= 50 then
            ns.db.chat.maxRows = math.floor(n)
            U.Print(L["ROWS_SET"], ns.db.chat.maxRows)
        else
            showHelp()
        end
    elseif U.ParseItemId(msg) then
        showItem(msg)
    else
        showHelp()
    end
end

-- Events ----------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PyroEncyclopediaDB = PyroEncyclopediaDB or {}
        applyDefaults(PyroEncyclopediaDB, DEFAULTS)
        ns.db = PyroEncyclopediaDB
    elseif event == "PLAYER_LOGIN" then
        ns.DetectProviders()
        if ns.db.prewarmIndexes and C_Timer then
            C_Timer.After(5, function() ns.Index.Ensure({ "recipes" }) end)
        end
    end
end)

-- Public API ------------------------------------------------------------------------------
-- Stable surface for other addons and for /dump debugging. Everything else is internal.

PyroEncyclopedia = {
    version = ns.version,
    --- Build a report for `itemId` and pass it to `callback(report)` (may be deferred while
    --- indexes are built on first use).
    RequestItemReport = function(itemId, callback, opts)
        return ns.ItemReport.Request(itemId, opts, callback)
    end,
    --- Synchronous report; sections that need unbuilt indexes are empty.
    GetItemReport = function(itemId, opts)
        return ns.ItemReport.Build(itemId, opts)
    end,
    GetProviderStatus = function()
        local out = {}
        for _, key in ipairs(ns.ProviderOrder) do
            local p = ns.Providers[key]
            out[key] = { available = p.available, status = p.status }
        end
        return out
    end,
}
