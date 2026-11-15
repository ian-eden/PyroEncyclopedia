local _, ns = ...

local Util = {}
ns.Util = Util

local PREFIX = "|cffff7f00PyroEnc|r: "

function Util.Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

-- Indented line without the prefix, for multi-line reports.
function Util.Line(indent, fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
    DEFAULT_CHAT_FRAME:AddMessage(("  "):rep(indent or 0) .. msg)
end

function Util.Money(copper)
    copper = tonumber(copper)
    if not copper or copper <= 0 then return nil end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

function Util.Percent(p)
    if not p then return nil end
    if p >= 10 then return ("%.0f%%"):format(p) end
    if p >= 0.1 then return ("%.1f%%"):format(p) end
    return "<0.1%"
end

function Util.LevelRange(minL, maxL)
    if not minL or minL == 0 then return nil end
    if not maxL or maxL == 0 or maxL == minL then return tostring(minL) end
    return minL .. "-" .. maxL
end

function Util.Gray(text) return "|cff9d9d9d" .. tostring(text) .. "|r" end

local function plainName(name, itemId)
    return (tostring(name or ("#" .. itemId)):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", "")
        :gsub("|h", ""):gsub("^%[", ""):gsub("%]$", ""))
end

-- "|cffRRGGBB" for an item's quality (white when unknown).
local function qualityColor(itemId)
    local IDB = ns.Providers.LibItemDB
    local quality = IDB:IsAvailable() and select(2, IDB:GetInfo(itemId)) or nil
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return color and color.hex or "|cffffffff"
end

-- Item name without brackets, coloured by its quality.
function Util.QualityName(itemId, name)
    return qualityColor(itemId) .. plainName(name, itemId) .. "|r"
end

-- Clickable links inside the PyroEncyclopedia window: |Hpyroenc:<kind>:<id>|h. They only
-- work in our own window, so chat output strips them (Util.StripLinks).
local LINK_COLORS = { quest = "|cffffe066", npc = "|cff7fc8ff", recipe = "|cffff9f40" }

function Util.Link(kind, id, text)
    local color = kind == "item" and qualityColor(id) or LINK_COLORS[kind] or "|cffffffff"
    if kind == "item" then text = plainName(text, id) end
    return ("%s|Hpyroenc:%s:%s|h%s|h|r"):format(color, kind, tostring(id), tostring(text))
end

function Util.ItemLink(itemId, name)
    return Util.Link("item", itemId, name or ns.ItemName(itemId))
end

function Util.StripLinks(text)
    return (text:gsub("|Hpyroenc:[^|]*|h(.-)|h", "%1"))
end
function Util.Gold(text) return "|cffffd100" .. tostring(text) .. "|r" end

-- Item id from a number, a numeric string, an item link or "item:<id>".
function Util.ParseItemId(text)
    if type(text) == "number" then return text end
    if type(text) ~= "string" then return nil end
    local trimmed = text:match("^%s*(.-)%s*$")
    return tonumber(trimmed) or tonumber(trimmed:match("item:(%d+)"))
end

-- Inserts `value` into a list unless an equal value is already present.
function Util.AddUnique(list, value)
    for i = 1, #list do if list[i] == value then return end end
    list[#list + 1] = value
end
