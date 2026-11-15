-- A few short lines on every item tooltip: where it drops, who sells it, which recipes and
-- quests use it. Runs on every hover, so it only does cheap lookups and caches per item.
local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local U, L = ns.Util, ns.L
local LABEL = "|cffff7f00%s|r "
local cache, cacheSize, CACHE_MAX = {}, 0, 500

local function label(key) return LABEL:format(L[key]) end

local function more(n) return n > 0 and U.Gray(" " .. L["TT_MORE"]:format(n)) or "" end

local function buildLines(itemId)
    local lines = {}
    local IDB, Q = ns.Providers.LibItemDB, ns.Providers.Questie
    local qOk = Q:IsAvailable() and Q.Item.Exists(itemId)
    local function npcName(id) return Q:IsAvailable() and Q.Npc.name(id) or ("#" .. id) end

    -- Drops / vendors: LibItemDB knows the chance; QuestieDB knows the full count.
    local bestDrop, bestVendor, dropIds, vendorIds = nil, nil, {}, {}
    for _, row in ipairs(IDB:GetPlaces(itemId) or {}) do
        if row.kind == "drop" then
            bestDrop = bestDrop or row
            dropIds[row.id] = true
        elseif row.kind == "vendor" then
            bestVendor = bestVendor or row
            vendorIds[row.id] = true
        end
    end
    local function countWith(seen, list)
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        for _, id in ipairs(list or {}) do if not seen[id] then n = n + 1 end end
        return n
    end
    local qDrops = qOk and Q.Item.npcDrops(itemId) or nil
    local qVendors = qOk and Q.Item.vendors(itemId) or nil

    local dropTotal = countWith(dropIds, qDrops)
    if dropTotal > 0 then
        local name = bestDrop and bestDrop.name or npcName(qDrops[1])
        local chance = bestDrop and bestDrop.chance and (" " .. U.Percent(bestDrop.chance)) or ""
        lines[#lines + 1] = label("TT_DROPS") .. name .. chance .. more(dropTotal - 1)
    end
    local vendorTotal = countWith(vendorIds, qVendors)
    if vendorTotal > 0 then
        local name = bestVendor and bestVendor.name or npcName(qVendors[1])
        local price = U.Money(select(1, IDB:GetVendorPrices(itemId)))
        lines[#lines + 1] = label("TT_SOLD_BY") .. name .. more(vendorTotal - 1) .. (price and (" - " .. price) or "")
    end

    -- Recipes that use / make it (needs the recipe index, built shortly after login).
    local recipes = ns.Index.Get("recipes")
    if recipes then
        local function profList(pairsList)
            local seen, names = {}, {}
            for i = 1, #pairsList, 2 do
                local prof = ns.ProfessionNames[pairsList[i]] or tostring(pairsList[i])
                if not seen[prof] then seen[prof] = true; names[#names + 1] = prof end
            end
            table.sort(names)
            return table.concat(names, ", ")
        end
        local using = recipes.reagentOf[itemId]
        if using then
            lines[#lines + 1] = label("TT_USED_IN") .. L["TT_RECIPES"]:format(#using / 2, profList(using))
        end
        local making = recipes.producedBy[itemId]
        if making then lines[#lines + 1] = label("TT_CRAFTED") .. profList(making) end
    end

    -- Quests that need / reward it.
    local function questName(id) return Q.Quest.name(id) or ("#" .. id) end
    local quests = ns.Index.Get("quests")
    local uses = quests and quests[itemId]          -- { questId, reason, questId, reason, ... }
    if uses then lines[#lines + 1] = label("TT_QUEST") .. questName(uses[1]) .. more(#uses / 2 - 1) end
    local rewards = qOk and Q.Item.questRewards(itemId) or nil
    if rewards then lines[#lines + 1] = label("TT_REWARD") .. questName(rewards[1]) .. more(#rewards - 1) end
    return lines
end

local function linesFor(itemId)
    local hit = cache[itemId]
    if hit then return hit end
    local lines = buildLines(itemId)
    -- Only remember complete answers; before the indexes finish, recipe/quest lines are missing.
    if ns.Index.IsReady("recipes") and ns.Index.IsReady("quests") then
        if cacheSize >= CACHE_MAX then cache, cacheSize = {}, 0 end
        cache[itemId] = lines
        cacheSize = cacheSize + 1
    end
    return lines
end

local function addLines(tooltip, itemId)
    if not (ns.db and ns.db.tooltip.enabled and itemId) then return false end
    local ok, lines = pcall(linesFor, itemId)
    if not ok or #lines == 0 then return false end
    for _, text in ipairs(lines) do tooltip:AddLine(text, 1, 1, 1, true) end
    return true
end

local function itemIdOf(tooltip)
    if not tooltip.GetItem then return nil end
    local _, link = tooltip:GetItem()
    return link and tonumber(link:match("item:(%d+)"))
end

-- On Classic-based clients C_TooltipInfo exists but is empty, and data-driven post-calls never
-- fire; only a client with the real getters draws item tooltips that way (see LibItemDB).
local function dataDriven()
    local info = _G.C_TooltipInfo
    return type(info) == "table" and type(info.GetBagItem) == "function"
        and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
end

function Tooltip.SetEnabled(on)
    ns.db.tooltip.enabled = on and true or false
    U.Print(L[on and "TT_ENABLED" or "TT_DISABLED"])
end

function Tooltip.Init()
    if dataDriven() then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            addLines(tooltip, data and data.id)
        end)
        return
    end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tt = _G[name]
        if tt and tt.HookScript then
            -- The game can fire OnTooltipSetItem more than once per item; add lines only once.
            tt:HookScript("OnTooltipSetItem", function(self)
                local id = itemIdOf(self)
                if id and self.pyroEncItem ~= id then
                    self.pyroEncItem = id
                    if addLines(self, id) then self:Show() end
                end
            end)
            tt:HookScript("OnTooltipCleared", function(self) self.pyroEncItem = nil end)
        end
    end
end
