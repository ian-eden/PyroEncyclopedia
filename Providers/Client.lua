-- The game client itself: always present. Item names/links/quality need the item cache,
-- so values may be nil the first time an item is seen.
local _, ns = ...

ns.Providers = ns.Providers or {}
local P = { key = "client", title = "Game client", available = true, status = "always available" }
ns.Providers.Client = P

function P:Detect() return true end
function P:IsAvailable() return true end

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

-- name, link, quality, itemLevel  (nil until the client has cached the item)
function P:GetItem(itemId)
    if not GetItemInfo then return nil end
    local name, link, quality, itemLevel = GetItemInfo(itemId)
    return name, link, quality, itemLevel
end

-- classID, subClassID, icon (synchronous, no cache needed)
function P:GetItemInstant(itemId)
    if not GetItemInfoInstant then return nil end
    local _, _, _, _, icon, classID, subClassID = GetItemInfoInstant(itemId)
    return classID, subClassID, icon
end

-- Ask the client to load an item; `callback()` runs once it is cached.
function P:RequestItem(itemId, callback)
    local exists = C_Item and C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(itemId)
    if exists == false or not (Item and Item.CreateFromItemID) then return false end
    Item:CreateFromItemID(itemId):ContinueOnItemLoad(callback)
    return true
end

function P:ClassName(classID, subClassID)
    local name
    if C_Item and C_Item.GetItemSubClassInfo and subClassID then
        name = C_Item.GetItemSubClassInfo(classID, subClassID)
    elseif GetItemSubClassInfo and subClassID then
        name = GetItemSubClassInfo(classID, subClassID)
    end
    if (not name or name == "") and classID then
        name = (C_Item and C_Item.GetItemClassInfo and C_Item.GetItemClassInfo(classID))
            or (GetItemClassInfo and GetItemClassInfo(classID))
    end
    return name
end
