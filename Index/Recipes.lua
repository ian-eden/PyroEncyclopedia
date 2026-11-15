-- Reverse indexes over LibProfessionDB (about 2,500 recipes on Forever):
--   reagentOf[itemId]  = { profId, spellId, profId, spellId, ... }   recipes that consume it
--   producedBy[itemId] = { profId, spellId, ... }                     recipes that create it
--   taughtBy[itemId]   = { profId, spellId }                          the recipe a scroll teaches
-- Pairs are stored flat to keep the heap small.
local _, ns = ...

local function push(map, key, profId, spellId)
    local list = map[key]
    if not list then list = {}; map[key] = list end
    list[#list + 1] = profId
    list[#list + 1] = spellId
end

ns.Index.Register("recipes", function()
    local P = ns.Providers.Profession
    if not P:IsAvailable() then return nil end
    local lib = P.lib

    local reagentOf, producedBy, taughtBy, profOfSpell = {}, {}, {}, {}
    local n = 0
    for profId, spellId, entry in lib:Iterate() do
        profOfSpell[spellId] = profId
        if entry.reagents then
            for itemId in pairs(entry.reagents) do push(reagentOf, itemId, profId, spellId) end
        end
        if entry.craftedItemId then push(producedBy, entry.craftedItemId, profId, spellId) end
        n = n + 1
        if n % 250 == 0 then coroutine.yield() end
    end

    local scrolls = lib.GetRecipeItems and lib:GetRecipeItems()
    if scrolls then
        for spellId, itemId in pairs(scrolls) do
            local profId = profOfSpell[spellId]
            if profId then taughtBy[itemId] = { profId, spellId } end
        end
    end

    return { reagentOf = reagentOf, producedBy = producedBy, taughtBy = taughtBy, recipeCount = n }
end)
