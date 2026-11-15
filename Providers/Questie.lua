-- Adapter for QuestieDB (global LibQuestieDB). Read-only: Pyro never registers corrections.
-- API reference: QuestieDB docs/api.md. Notes that shape this file:
--   * numeric getters return 0 instead of nil -> normalized to nil here;
--   * every table read is a fresh copy, so read only the fields needed;
--   * Entity.GetAll returns a packed table with .n (nullable fields leave holes).
local _, ns = ...

ns.Providers = ns.Providers or {}
local P = { key = "questie", title = "QuestieDB", available = false, status = nil }
ns.Providers.Questie = P

local MIN_CONTRACT = 1

local ITEM_FIELDS = {
    "name", "npcDrops", "objectDrops", "itemDrops", "startQuest", "questRewards",
    "vendors", "relatedQuests", "teachesSpell", "itemLevel", "requiredLevel", "class", "subClass",
}
local NPC_FIELDS = {
    "name", "subName", "minLevel", "maxLevel", "rank", "zoneID", "spawns", "friendlyToFaction",
    "questStarts", "questEnds",
}
local QUEST_DETAIL_FIELDS = {
    "name", "questLevel", "requiredLevel", "startedBy", "finishedBy", "objectivesText", "objectives",
    "sourceItemId", "requiredSourceItems", "preQuestSingle", "preQuestGroup", "nextQuestInChain",
    "zoneOrSort", "requiredSkill",
}
local OBJECT_FIELDS = { "name", "zoneID", "spawns" }
local QUEST_FIELDS = { "name", "questLevel", "requiredLevel" }

local function nz(v) if v == 0 then return nil end return v end

local function unpackFields(fields, values)
    local out = {}
    for i = 1, #fields do out[fields[i]] = values[i] end
    return out
end

function P:Detect()
    local lib = _G.LibQuestieDB
    if type(lib) ~= "table" or type(lib.Item) ~= "table" then
        self.available, self.status = false, ns.L["NOT_INSTALLED"]
        return false
    end
    if lib.RequireContract then
        local ok, msg = lib.RequireContract(MIN_CONTRACT)
        if not ok then
            self.available, self.status = false, msg or "incompatible contract"
            return false
        end
    end
    self.lib = lib
    self.Item, self.Npc, self.Object, self.Quest = lib.Item, lib.Npc, lib.Object, lib.Quest
    self.available = true
    self.status = ("contract %s, %s mode"):format(tostring(lib.contractVersion), tostring(lib.readMode))
    return true
end

function P:IsAvailable() return self.available end

-- Spawns {[areaId] = {{x, y}, ...}} -> list of { areaId = id, count = n }, most spawns first.
local function zonesFromSpawns(spawns)
    local zones = {}
    if type(spawns) ~= "table" then return zones end
    for areaId, points in pairs(spawns) do
        zones[#zones + 1] = { areaId = areaId, count = type(points) == "table" and #points or 0 }
    end
    table.sort(zones, function(a, b) return a.count > b.count end)
    return zones
end

function P:GetItem(itemId)
    if not self.available or not self.Item.Exists(itemId) then return nil end
    local v = self.Item.GetAll(itemId, ITEM_FIELDS)
    if not v then return nil end
    local item = unpackFields(ITEM_FIELDS, v)
    item.startQuest = nz(item.startQuest)
    item.teachesSpell = nz(item.teachesSpell)
    return item
end

function P:GetItemName(itemId)
    if not self.available then return nil end
    return self.Item.name(itemId)
end

function P:GetNpc(npcId)
    if not self.available or not self.Npc.Exists(npcId) then return nil end
    local v = self.Npc.GetAll(npcId, NPC_FIELDS)
    if not v then return nil end
    local npc = unpackFields(NPC_FIELDS, v)
    npc.zones = zonesFromSpawns(npc.spawns)
    npc.spawns = nil
    npc.zoneID = nz(npc.zoneID)
    return npc
end

function P:GetObject(objectId)
    if not self.available or not self.Object.Exists(objectId) then return nil end
    local v = self.Object.GetAll(objectId, OBJECT_FIELDS)
    if not v then return nil end
    local obj = unpackFields(OBJECT_FIELDS, v)
    obj.zones = zonesFromSpawns(obj.spawns)
    obj.spawns = nil
    obj.zoneID = nz(obj.zoneID)
    return obj
end

function P:GetQuest(questId)
    if not self.available or not self.Quest.Exists(questId) then return nil end
    local v = self.Quest.GetAll(questId, QUEST_FIELDS)
    if not v then return nil end
    local q = unpackFields(QUEST_FIELDS, v)
    q.id = questId
    q.questLevel = nz(q.questLevel)
    q.requiredLevel = nz(q.requiredLevel)
    return q
end

-- Everything the quest page shows. startedBy = {npcIds, objectIds, itemIds}, finishedBy =
-- {npcIds, objectIds}, objectives = {creatures, objects, items, rep, killcredit, spell}.
function P:GetQuestDetails(questId)
    if not self.available or not self.Quest.Exists(questId) then return nil end
    local v = self.Quest.GetAll(questId, QUEST_DETAIL_FIELDS)
    if not v then return nil end
    local q = unpackFields(QUEST_DETAIL_FIELDS, v)
    q.id = questId
    q.questLevel, q.requiredLevel = nz(q.questLevel), nz(q.requiredLevel)
    q.sourceItemId, q.nextQuestInChain, q.zoneOrSort = nz(q.sourceItemId), nz(q.nextQuestInChain), nz(q.zoneOrSort)
    return q
end

function P:GetObjectName(objectId)
    return self.available and self.Object.name(objectId) or nil
end

-- Exact-name lookup (QuestieDB's index is exact match only). Returns the lowest id or nil.
function P:FindItemByName(name)
    if not self.available or not self.Item.IdsByName then return nil end
    local ids = self.Item.IdsByName(name)
    return ids and ids[1] or nil
end

-- AreaTable id -> UiMap id, from QuestieDB's support data (shipped as Lua source strings).
local function loadMapTable(src, into)
    if type(src) == "string" then
        local fn = loadstring(src)
        if not fn then return end
        local ok, t = pcall(fn)
        src = ok and t or nil
    end
    if type(src) == "table" then
        for k, v in pairs(src) do into[k] = v end
    end
end

function P:GetUiMapForArea(areaId)
    if not self.available then return nil end
    if not self.areaToUiMap then
        self.areaToUiMap = {}
        local support = self.lib.Support
        local ok, zoneDB = pcall(function() return support and support.Get("ZoneDB") end)
        local private = ok and type(zoneDB) == "table" and zoneDB.private
        if type(private) == "table" then
            loadMapTable(private.areaIdToUiMapId, self.areaToUiMap)
            loadMapTable(private.areaIdToUiMapIdOverride, self.areaToUiMap)
        end
    end
    return nz(self.areaToUiMap[areaId])
end

-- AreaTable id -> QuestieDB's English zone constant (e.g. "DUSKWOOD"); fallback naming only.
function P:GetZoneConstant(areaId)
    if not self.available then return nil end
    if not self.zoneConstants then
        self.zoneConstants = {}
        local enum = self.lib.Enum and self.lib.Enum.zoneIDs
        if type(enum) == "table" then
            for constant, id in pairs(enum) do
                if self.zoneConstants[id] == nil then self.zoneConstants[id] = constant end
            end
        end
    end
    return self.zoneConstants[areaId]
end

-- Cache key fragment so persisted indexes rebuild when QuestieDB changes.
function P:VersionTag()
    if not self.available then return "none" end
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("QuestieDB", "Version")
    return ("%s/%s"):format(tostring(version), tostring(self.lib.contractVersion))
end
