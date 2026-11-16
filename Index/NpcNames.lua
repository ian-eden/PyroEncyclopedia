-- Every NPC / monster name in QuestieDB, lower-cased, so the search box can find mobs by any
-- part of their name (QuestieDB itself only has an exact-name lookup).
--   ids[i], names[i] = npcId, lower-cased name
local _, ns = ...

-- Internal placeholder creatures that exist in the data but never in the world.
local function isJunk(name)
    return name:find("^%[") or name:find("DND") or name:lower():find("^zz")
end

ns.Index.Register("npcNames", function()
    local Q = ns.Providers.Questie
    if not Q:IsAvailable() or not Q.Npc.GetAllIds then return nil end
    local ids, names = {}, {}
    local all = Q.Npc.GetAllIds()   -- shared, read-only
    for i = 1, #all do
        local name = Q.Npc.name(all[i])
        if type(name) == "string" and name ~= "" and not isJunk(name) then
            ids[#ids + 1], names[#names + 1] = all[i], name:lower()
        end
        if i % 500 == 0 then coroutine.yield() end
    end
    return { ids = ids, names = names }
end)

local MAX_RESULTS = 50

--- NPC ids whose name contains `text` (case-insensitive): exact matches first, then names
--- starting with it, then the rest; alphabetical within each group. Second result: capped.
function ns.Index.FindNpcs(text)
    local index = ns.Index.Get("npcNames")
    if not index then return {}, false end
    local needle = text:lower()
    local found = {}
    for i, name in ipairs(index.names) do
        local at = name:find(needle, 1, true)
        if at then
            found[#found + 1] = { id = index.ids[i], name = name, rank = name == needle and 0 or at == 1 and 1 or 2 }
        end
    end
    table.sort(found, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    local capped = #found > MAX_RESULTS
    local out = {}
    for i = 1, math.min(#found, MAX_RESULTS) do out[i] = found[i].id end
    return out, capped
end
