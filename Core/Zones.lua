-- Zone naming. QuestieDB keys spawns by AreaTable id; LibItemDB uses UiMap ids. Both are
-- turned into the client's own localized map name where possible.
local _, ns = ...

local Zones = {}
ns.Zones = Zones

local cache = {}

local function prettify(constant)
    -- "STONETALON_MOUNTAINS" -> "Stonetalon Mountains"
    return (constant:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

function Zones.NameForUiMap(uiMapId)
    if not uiMapId or uiMapId == 0 then return nil end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapId)
    return info and info.name or nil
end

function Zones.NameForArea(areaId)
    if not areaId or areaId == 0 then return nil end
    if cache[areaId] ~= nil then return cache[areaId] or nil end
    local name
    local Q = ns.Providers.Questie
    if Q:IsAvailable() then
        name = Zones.NameForUiMap(Q:GetUiMapForArea(areaId))
        if not name then
            local constant = Q:GetZoneConstant(areaId)
            name = constant and prettify(constant)
        end
    end
    name = name or ("Area " .. areaId)
    cache[areaId] = name
    return name
end
