-- Builds one normalized report for an item by merging every available provider.
-- The report is plain data; UI modules (chat now, tooltip and window later) only render it.
--
-- Merge rules (see docs/research/01-technical-assessment.md, section 6):
--   drops/vendors/objects: LibItemDB rows first (they carry chance/price), then any extra
--   ids QuestieDB lists that LibItemDB's capped list does not. Detail is only resolved for
--   the rows that will be shown (`opts.maxRows`), so items with 1,000+ droppers stay cheap.
local _, ns = ...

local Report = {}
ns.ItemReport = Report

local REQUIRED_INDEXES = { "recipes", "quests" }

local function sortByChance(a, b)
    if (a.chance ~= nil) ~= (b.chance ~= nil) then return a.chance ~= nil end
    if a.chance and b.chance and a.chance ~= b.chance then return a.chance > b.chance end
    return (a.id or 0) < (b.id or 0)
end

-- LibItemDB place list -> zone display names
local function zonesFromPlaces(places)
    local zones = {}
    for _, p in ipairs(places or {}) do
        local name = p.instance or ns.Zones.NameForUiMap(p.uiMapID)
        if name then ns.Util.AddUnique(zones, name) end
    end
    return zones
end

local function zonesFromQuestie(zoneList, limit)
    local zones = {}
    for i = 1, math.min(#(zoneList or {}), limit or 3) do
        local name = ns.Zones.NameForArea(zoneList[i].areaId)
        if name then ns.Util.AddUnique(zones, name) end
    end
    return zones
end

-- Fill in NPC detail from QuestieDB for one displayed row.
local function enrichNpc(row)
    local Q = ns.Providers.Questie
    local npc = Q:IsAvailable() and Q:GetNpc(row.id)
    if not npc then return end
    row.name = row.name or npc.name
    row.subName = npc.subName
    row.minLevel, row.maxLevel = npc.minLevel, npc.maxLevel
    row.rank = npc.rank
    if not row.zones or #row.zones == 0 then
        row.zones = zonesFromQuestie(npc.zones)
        if #npc.zones == 0 and npc.zoneID then row.zones = { ns.Zones.NameForArea(npc.zoneID) } end
    end
    row.noLocation = #npc.zones == 0
end

local function enrichObject(row)
    local Q = ns.Providers.Questie
    local obj = Q:IsAvailable() and Q:GetObject(row.id)
    if not obj then return end
    row.name = row.name or obj.name
    if not row.zones or #row.zones == 0 then row.zones = zonesFromQuestie(obj.zones) end
end

local function itemName(itemId)
    return ns.Providers.LibItemDB:GetName(itemId)
        or ns.Providers.Questie:GetItemName(itemId)
        or (ns.Providers.Client:GetItem(itemId))
end

-- Merge LibItemDB rows of `kind` with a QuestieDB id list into report section `section`.
local function mergeSection(section, placesByKind, kind, questieIds, enrich, maxRows)
    local byId = {}
    for _, row in ipairs(placesByKind[kind] or {}) do
        local entry = {
            id = row.id, name = row.name, chance = row.chance, questOnly = row.questOnly,
            condition = row.condition, profession = row.profession ~= "" and row.profession or nil,
            side = row.side, zones = zonesFromPlaces(row.places), source = "LibItemDB",
        }
        byId[row.id] = entry
        section.rows[#section.rows + 1] = entry
    end
    for _, id in ipairs(questieIds or {}) do
        if not byId[id] then
            local entry = { id = id, source = "QuestieDB" }
            byId[id] = entry
            section.rows[#section.rows + 1] = entry
        end
    end
    table.sort(section.rows, sortByChance)
    section.total = #section.rows
    for i = 1, math.min(section.total, maxRows) do enrich(section.rows[i]) end
end

local function recipeList(pairsList, itemId, maxRows)
    local P = ns.Providers.Profession
    local out = { rows = {}, total = 0 }
    if not pairsList then return out end
    for i = 1, #pairsList, 2 do
        local info = P:GetRecipeInfo(pairsList[i], pairsList[i + 1], itemId)
        if info then out.rows[#out.rows + 1] = info end
    end
    table.sort(out.rows, function(a, b)
        if a.profId ~= b.profId then return a.profId < b.profId end
        return (a.requiredSkill or 0) < (b.requiredSkill or 0)
    end)
    out.total = #out.rows
    for i = 1, math.min(out.total, maxRows) do
        local r = out.rows[i]
        r.sources = P:GetSources(r.spellId)
        r.craftedName = r.craftedItemId and itemName(r.craftedItemId)
    end
    return out
end

--- Build the report synchronously. Indexes that are not built yet are simply skipped;
--- use Report.Request to wait for them.
function Report.Build(itemId, opts)
    opts = opts or {}
    local maxRows = opts.maxRows or 8
    local Q, PDB, IDB, Client = ns.Providers.Questie, ns.Providers.Profession,
        ns.Providers.LibItemDB, ns.Providers.Client
    local L = ns.L

    local r = {
        id = itemId,
        drops = { rows = {}, total = 0 }, vendors = { rows = {}, total = 0 },
        objects = { rows = {}, total = 0 }, containers = { rows = {}, total = 0 },
        bosses = {}, origins = {}, questRewards = {}, questUses = {},
        recipesUsing = { rows = {}, total = 0 }, recipesMaking = { rows = {}, total = 0 },
        notes = {},
    }

    -- Identity ------------------------------------------------------------------------
    local name, quality, classID, subClassID, _, itemLevel, reqLevel = IDB:GetInfo(itemId)
    r.name, r.quality, r.classID, r.subClassID = name, quality, classID, subClassID
    r.itemLevel, r.requiredLevel = itemLevel, reqLevel
    r.link = IDB:GetLink(itemId)
    r.buyPrice, r.sellPrice = IDB:GetVendorPrices(itemId)

    local qi = Q:IsAvailable() and Q:GetItem(itemId) or nil
    if qi then
        r.name = r.name or qi.name
        r.itemLevel = r.itemLevel or qi.itemLevel
        r.classID = r.classID or qi.class
        r.subClassID = r.subClassID or qi.subClass
    end
    local cName, cLink, cQuality, cLevel = Client:GetItem(itemId)
    r.name, r.link = r.name or cName, r.link or cLink
    r.quality, r.itemLevel = r.quality or cQuality, r.itemLevel or cLevel
    if not r.classID then r.classID, r.subClassID = Client:GetItemInstant(itemId) end
    r.typeName = r.classID and Client:ClassName(r.classID, r.subClassID)
    r.known = r.name ~= nil

    -- Acquisition ---------------------------------------------------------------------
    local placesByKind = {}
    for _, row in ipairs(IDB:GetPlaces(itemId) or {}) do
        placesByKind[row.kind] = placesByKind[row.kind] or {}
        table.insert(placesByKind[row.kind], row)
    end
    mergeSection(r.drops, placesByKind, "drop", qi and qi.npcDrops, enrichNpc, maxRows)
    mergeSection(r.vendors, placesByKind, "vendor", qi and qi.vendors, enrichNpc, maxRows)
    mergeSection(r.objects, placesByKind, "object", qi and qi.objectDrops, enrichObject, maxRows)

    for _, containerId in ipairs(qi and qi.itemDrops or {}) do
        r.containers.rows[#r.containers.rows + 1] = { id = containerId, name = itemName(containerId) }
    end
    r.containers.total = #r.containers.rows

    for _, src in ipairs(IDB:GetSources(itemId) or {}) do
        if src.encounterID then
            r.bosses[#r.bosses + 1] = src
        elseif src.instance or src.source then
            r.origins[#r.origins + 1] = src
        end
    end

    -- Quests --------------------------------------------------------------------------
    if qi then
        for _, questId in ipairs(qi.questRewards or {}) do
            r.questRewards[#r.questRewards + 1] = Q:GetQuest(questId) or { id = questId }
        end
        if qi.startQuest then r.startsQuest = Q:GetQuest(qi.startQuest) or { id = qi.startQuest } end
    end
    local questIndex = ns.Index.Get("quests")
    local uses = questIndex and questIndex[itemId]
    if uses then
        local byQuest, order = {}, {}
        for i = 1, #uses, 2 do
            local questId, reason = uses[i], uses[i + 1]
            if not (reason == "starts" and r.startsQuest and r.startsQuest.id == questId) then
                if not byQuest[questId] then
                    byQuest[questId] = Q:GetQuest(questId) or { id = questId }
                    byQuest[questId].reasons = {}
                    order[#order + 1] = questId
                end
                ns.Util.AddUnique(byQuest[questId].reasons, reason)
            end
        end
        for _, questId in ipairs(order) do r.questUses[#r.questUses + 1] = byQuest[questId] end
    end

    -- Recipes -------------------------------------------------------------------------
    local recipeIndex = PDB:IsAvailable() and ns.Index.Get("recipes")
    if recipeIndex then
        r.recipesUsing = recipeList(recipeIndex.reagentOf[itemId], itemId, maxRows)
        r.recipesMaking = recipeList(recipeIndex.producedBy[itemId], nil, maxRows)
        local taught = recipeIndex.taughtBy[itemId]
        if taught then r.teaches = PDB:GetRecipeInfo(taught[1], taught[2]) end
    elseif qi and qi.teachesSpell then
        r.teachesSpellId = qi.teachesSpell
    end

    -- Data-quality notes --------------------------------------------------------------
    local anyNoChance, anyChance, anyBorrowed = false, false, false
    for _, row in ipairs(r.drops.rows) do
        if row.chance then anyChance = true else anyNoChance = true end
    end
    for _, rec in ipairs(r.recipesUsing.rows) do
        if rec.requiredSkillBorrowed or (rec.sources and rec.sources.borrowed) then anyBorrowed = true end
    end
    if anyNoChance and r.drops.total > 0 then r.notes[#r.notes + 1] = L["GAP_NO_DROP_RATES"] end
    if anyChance or r.drops.total > 0 then r.notes[#r.notes + 1] = L["GAP_CLASSIC_DERIVED"] end
    if anyBorrowed then r.notes[#r.notes + 1] = L["GAP_BORROWED"] end
    if r.classID == 7 then r.notes[#r.notes + 1] = L["GAP_NO_SKINNING"] end

    return r
end

--- Build indexes if needed, then call `callback(report)`. Returns true if it had to wait.
function Report.Request(itemId, opts, callback)
    return ns.Index.Ensure(REQUIRED_INDEXES, function()
        callback(Report.Build(itemId, opts))
    end)
end
