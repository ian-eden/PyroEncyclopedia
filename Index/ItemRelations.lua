-- The other direction of QuestieDB's item fields, for NPC and quest pages:
--   drops[npcId]     = { itemId, ... }   items the NPC drops
--   sells[npcId]     = { itemId, ... }   items the NPC sells
--   rewards[questId] = { itemId, ... }   items the quest rewards
-- Built from a pass over every item (about 24,000), only when an NPC or quest page first opens.
local _, ns = ...

local FIELDS = { "npcDrops", "vendors", "questRewards" }

local function push(map, key, value)
    local list = map[key]
    if not list then list = {}; map[key] = list end
    list[#list + 1] = value
end

ns.Index.Register("itemRelations", function()
    local Q = ns.Providers.Questie
    if not Q:IsAvailable() then return nil end
    local drops, sells, rewards = {}, {}, {}
    local ids = Q.Item.GetAllIds()   -- shared, read-only
    for i = 1, #ids do
        local itemId = ids[i]
        local v = Q.Item.GetAll(itemId, FIELDS)
        if v then
            for _, npcId in ipairs(v[1] or {}) do push(drops, npcId, itemId) end
            for _, npcId in ipairs(v[2] or {}) do push(sells, npcId, itemId) end
            for _, questId in ipairs(v[3] or {}) do push(rewards, questId, itemId) end
        end
        if i % 200 == 0 then coroutine.yield() end
    end
    return { drops = drops, sells = sells, rewards = rewards }
end)
