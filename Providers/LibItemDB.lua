-- Adapter for LibItemDB-1.0 (addon folder "ItemDB"). Supplies offline item properties,
-- drop chances, vendor prices and boss-loot sources. Note: QuestieDB's global `ItemDB` is a
-- different thing; this adapter only goes through LibStub.
local _, ns = ...

ns.Providers = ns.Providers or {}
local P = { key = "itemdb", title = "LibItemDB", available = false, status = nil }
ns.Providers.LibItemDB = P

local MAJOR = "LibItemDB-1.0"

function P:Detect()
    local lib, minor
    if LibStub then lib, minor = LibStub:GetLibrary(MAJOR, true) end
    if not lib then
        self.available, self.status = false, ns.L["NOT_INSTALLED"]
        return false
    end
    if not lib:IsReady() then
        self.available, self.status = false, "loaded, but no item data for this client"
        return false
    end
    self.lib, self.minor = lib, minor
    self.available = true
    self.status = ("MINOR %s, %d items"):format(tostring(minor), lib:Count())
    return true
end

function P:IsAvailable() return self.available end

-- name, quality, classID, subClassID, equipLoc, itemLevel, requiredLevel  (or nil)
function P:GetInfo(itemId)
    if not self.available then return nil end
    return self.lib:GetInfo(itemId)
end

function P:GetName(itemId)
    return self.available and self.lib:GetName(itemId) or nil
end

function P:GetLink(itemId)
    return self.available and self.lib.GetLink and self.lib:GetLink(itemId) or nil
end

function P:GetVendorPrices(itemId)
    if not self.available then return nil, nil end
    local lib = self.lib
    local buy = lib.GetVendorBasePrice and lib:GetVendorBasePrice(itemId)
    local sell = lib.GetVendorSellPrice and lib:GetVendorSellPrice(itemId)
    return buy, sell
end

-- Rows: {kind = "drop"|"vendor"|"object"|"quest", id, name, chance, questOnly, condition,
--        side, profession, places = {{uiMapID, count, points} | {instance, count}}}
-- Capped upstream (8 drops, 8 vendors, 6 objects). Fresh tables per call.
function P:GetPlaces(itemId)
    if not self.available or not self.lib.GetItemPlaces then return nil end
    return self.lib:GetItemPlaces(itemId)
end

-- Rows: {encounterID, boss, instanceKey, instance, source, rate} for boss drops, or
--       {instance, source} for other origins (crafted / drop / reputation / pvp / ...).
function P:GetSources(itemId)
    if not self.available or not self.lib.GetSources then return nil end
    return self.lib:GetSources(itemId)
end

function P:FindByName(name)
    if not self.available or not self.lib.GetID then return nil end
    return self.lib:GetID(name)
end

function P:VersionTag()
    return self.available and ("MINOR" .. tostring(self.minor)) or "none"
end
