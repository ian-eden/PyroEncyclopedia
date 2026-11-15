-- Reverse index over QuestieDB quests (about 5,600 on Forever):
--   [itemId] = { questId, reason, questId, reason, ... }
-- reason: "objective" (collect it), "provided" (quest hands it to you), "required" (needed but
-- not an objective) or "starts" (the item starts the quest).
local _, ns = ...

local FIELDS = { "objectives", "sourceItemId", "requiredSourceItems", "startedBy" }

ns.Index.Register("quests", function()
    local Q = ns.Providers.Questie
    if not Q:IsAvailable() then return nil end
    local QuestDB = Q.Quest

    local byItem = {}
    local function add(itemId, questId, reason)
        if type(itemId) ~= "number" or itemId == 0 then return end
        local list = byItem[itemId]
        if not list then list = {}; byItem[itemId] = list end
        for i = 1, #list, 2 do
            if list[i] == questId and list[i + 1] == reason then return end
        end
        list[#list + 1] = questId
        list[#list + 1] = reason
    end

    local ids = QuestDB.GetAllIds()   -- shared, read-only
    for i = 1, #ids do
        local questId = ids[i]
        local v = QuestDB.GetAll(questId, FIELDS)
        if v then
            local objectives, sourceItem, required, startedBy = v[1], v[2], v[3], v[4]
            local itemRows = type(objectives) == "table" and objectives[3]
            if type(itemRows) == "table" then
                for _, row in ipairs(itemRows) do add(row[1], questId, "objective") end
            end
            add(sourceItem, questId, "provided")
            if type(required) == "table" then
                for _, itemId in ipairs(required) do add(itemId, questId, "required") end
            end
            local starterItems = type(startedBy) == "table" and startedBy[3]
            if type(starterItems) == "table" then
                for _, itemId in ipairs(starterItems) do add(itemId, questId, "starts") end
            end
        end
        if i % 100 == 0 then coroutine.yield() end
    end
    return byItem
end)
