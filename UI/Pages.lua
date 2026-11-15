-- Page builders for the window. Each kind returns { title, facts, icon, lines } and lists the
-- indexes it needs (built in the background before the page is drawn).
local _, ns = ...

local Pages = {}
ns.Pages = Pages

local U, L = ns.Util, ns.L
local INDENT = "    "
local MAX_ROWS = 40
local ICON_QUEST = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_NPC = "Interface\\Icons\\INV_Misc_Head_Human_01"
local ICON_RECIPE = "Interface\\Icons\\INV_Scroll_03"
local RANKS = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }
local FACTIONS = { A = "Alliance", H = "Horde", AH = "Alliance and Horde" }

-- Small line-list builder shared by every page.
local function newPage()
    local lines = {}
    local p = { lines = lines }
    function p.add(level, text) lines[#lines + 1] = INDENT:rep(level) .. text end
    function p.header(title, total)
        if #lines > 0 then lines[#lines + 1] = " " end
        p.add(0, U.Gold(title) .. ((total and total > 0) and (" (" .. total .. ")") or ""))
    end
    function p.list(title, items, render)
        if not items or #items == 0 then return end
        p.header(title, #items)
        for i = 1, math.min(#items, MAX_ROWS) do p.add(1, render(items[i])) end
        if #items > MAX_ROWS then p.add(1, U.Gray(L["AND_MORE"]:format(#items - MAX_ROWS))) end
    end
    return p
end

local function unknownPage(kind, id)
    return { title = ("%s %s"):format(kind, tostring(id)), facts = "", lines = { U.Gray(L["PAGE_UNKNOWN"]) } }
end

local function questLink(questId)
    local q = ns.Providers.Questie:GetQuest(questId)
    return ns.ReportText.QuestLabel(q or { id = questId })
end

local function npcLink(npcId)
    local npc = ns.Providers.Questie:GetNpc(npcId)
    local zone = npc and npc.zones[1] and ns.Zones.NameForArea(npc.zones[1].areaId)
    return U.Link("npc", npcId, npc and npc.name or ("#" .. npcId)) .. (zone and U.Gray(" - " .. zone) or "")
end

local function objectName(objectId)
    return ns.Providers.Questie:GetObjectName(objectId) or ("#" .. objectId)
end

-- Item -------------------------------------------------------------------------------------

Pages.item = { needs = { "recipes", "quests" } }

function Pages.item.build(itemId)
    local report = ns.ItemReport.Build(itemId, { maxRows = 25 })
    local title, facts = ns.ReportText.Header(report)
    local _, _, icon = ns.Providers.Client:GetItemInstant(itemId)
    return { title = title, facts = facts, icon = icon, lines = ns.ReportText.Body(report, 25) }
end

-- Quest ------------------------------------------------------------------------------------

Pages.quest = { needs = { "itemRelations" } }

function Pages.quest.build(questId)
    local Q = ns.Providers.Questie
    local q = Q:GetQuestDetails(questId)
    if not q then return unknownPage("Quest", questId) end
    local p = newPage()

    local facts = {}
    if q.questLevel then facts[#facts + 1] = L["LEVEL"]:format(q.questLevel) end
    if q.requiredLevel then facts[#facts + 1] = L["REQUIRES_LEVEL"]:format(q.requiredLevel) end
    if q.zoneOrSort and q.zoneOrSort > 0 then facts[#facts + 1] = ns.Zones.NameForArea(q.zoneOrSort) end

    local starts, ends = {}, {}
    local sb, fb = q.startedBy or {}, q.finishedBy or {}
    for _, id in ipairs(sb[1] or {}) do starts[#starts + 1] = npcLink(id) end
    for _, id in ipairs(sb[2] or {}) do starts[#starts + 1] = objectName(id) end
    for _, id in ipairs(sb[3] or {}) do starts[#starts + 1] = U.ItemLink(id) end
    for _, id in ipairs(fb[1] or {}) do ends[#ends + 1] = npcLink(id) end
    for _, id in ipairs(fb[2] or {}) do ends[#ends + 1] = objectName(id) end
    p.list(L["Q_STARTS"], starts, tostring)
    p.list(L["Q_ENDS"], ends, tostring)

    if q.objectivesText and #q.objectivesText > 0 then
        p.header(L["Q_OBJECTIVES"])
        for _, text in ipairs(q.objectivesText) do if text ~= "" then p.add(1, text) end end
    end

    local needs, obj = {}, q.objectives or {}
    local function note(row) return type(row[2]) == "string" and U.Gray(" - " .. row[2]) or "" end
    for _, row in ipairs(obj[1] or {}) do needs[#needs + 1] = L["Q_KILL"] .. npcLink(row[1]) .. note(row) end
    for _, row in ipairs(obj[2] or {}) do needs[#needs + 1] = L["Q_USE"] .. objectName(row[1]) .. note(row) end
    for _, row in ipairs(obj[3] or {}) do needs[#needs + 1] = L["Q_COLLECT"] .. U.ItemLink(row[1]) .. note(row) end
    for _, id in ipairs(q.requiredSourceItems or {}) do needs[#needs + 1] = L["Q_BRING"] .. U.ItemLink(id) end
    if q.sourceItemId then needs[#needs + 1] = L["Q_PROVIDED"] .. U.ItemLink(q.sourceItemId) end
    p.list(L["Q_REQUIRES"], needs, tostring)

    local relations = ns.Index.Get("itemRelations")
    p.list(L["Q_REWARDS"], relations and relations.rewards[questId], function(id) return U.ItemLink(id) end)

    local before = {}
    for _, id in ipairs(q.preQuestSingle or {}) do before[#before + 1] = id end
    for _, id in ipairs(q.preQuestGroup or {}) do before[#before + 1] = id end
    p.list(L["Q_BEFORE"], before, questLink)
    if q.nextQuestInChain then p.list(L["Q_NEXT"], { q.nextQuestInChain }, questLink) end

    local title = (q.questLevel and ("[" .. q.questLevel .. "] ") or "") .. (q.name or "?")
    return { title = "|cffffe066" .. title .. "|r", facts = table.concat(facts, ", "), icon = ICON_QUEST, lines = p.lines }
end

-- NPC --------------------------------------------------------------------------------------

Pages.npc = { needs = { "itemRelations" } }

-- Drop chance of `itemId` from `npcId`, from LibItemDB's capped place list (nil = unknown).
local function dropChance(itemId, npcId)
    for _, row in ipairs(ns.Providers.LibItemDB:GetPlaces(itemId) or {}) do
        if row.kind == "drop" and row.id == npcId then return row.chance end
    end
end

function Pages.npc.build(npcId)
    local Q, IDB = ns.Providers.Questie, ns.Providers.LibItemDB
    local npc = Q:GetNpc(npcId)
    if not npc then return unknownPage("NPC", npcId) end
    local p = newPage()

    local facts = {}
    if npc.subName then facts[#facts + 1] = "<" .. npc.subName .. ">" end
    local lvl = U.LevelRange(npc.minLevel, npc.maxLevel)
    if lvl then facts[#facts + 1] = L["LEVEL"]:format(lvl) end
    if RANKS[npc.rank] then facts[#facts + 1] = RANKS[npc.rank] end
    facts[#facts + 1] = npc.friendlyToFaction and L["FRIENDLY_TO"]:format(FACTIONS[npc.friendlyToFaction]
        or npc.friendlyToFaction) or L["HOSTILE"]

    if #npc.zones > 0 then
        p.list(L["N_LOCATION"], npc.zones, function(z)
            return ns.Zones.NameForArea(z.areaId) .. U.Gray(" " .. L["SPAWNS"]:format(z.count))
        end)
    else
        p.header(L["N_LOCATION"])
        p.add(1, U.Gray(L["NO_KNOWN_LOCATION"]))
    end
    p.list(L["N_STARTS"], npc.questStarts, questLink)
    p.list(L["N_ENDS"], npc.questEnds, questLink)

    local relations = ns.Index.Get("itemRelations")
    local drops = relations and relations.drops[npcId]
    if drops then
        local rows = {}
        for _, itemId in ipairs(drops) do
            rows[#rows + 1] = { id = itemId, chance = #drops <= 150 and dropChance(itemId, npcId) or nil,
                name = ns.ItemName(itemId) or "" }
        end
        table.sort(rows, function(a, b)
            if (a.chance ~= nil) ~= (b.chance ~= nil) then return a.chance ~= nil end
            if a.chance and b.chance and a.chance ~= b.chance then return a.chance > b.chance end
            return a.name < b.name
        end)
        p.list(L["N_DROPS"], rows, function(r)
            return U.ItemLink(r.id, r.name) .. (r.chance and (" |cff20ff20" .. U.Percent(r.chance) .. "|r") or "")
        end)
    end
    local sells = relations and relations.sells[npcId]
    if sells then
        p.list(L["N_SELLS"], sells, function(itemId)
            local price = U.Money((IDB:GetVendorPrices(itemId)))
            return U.ItemLink(itemId) .. (price and U.Gray(" - ") .. price or "")
        end)
    end
    if #p.lines == 0 then p.add(0, U.Gray(L["NOTHING_KNOWN"])) end

    return { title = "|cff7fc8ff" .. (npc.name or "?") .. "|r", facts = table.concat(facts, ", "), icon = ICON_NPC,
        lines = p.lines }
end

-- Recipe (id = "profId-spellId") -----------------------------------------------------------

Pages.recipe = { needs = {} }

function Pages.recipe.build(key)
    local P = ns.Providers.Profession
    local profId, spellId = tostring(key):match("^(%d+)%-(%d+)$")
    profId, spellId = tonumber(profId), tonumber(spellId)
    local info = P:IsAvailable() and profId and P:GetRecipeInfo(profId, spellId)
    if not info then return unknownPage("Recipe", key) end
    local p = newPage()
    local prof = ns.ProfessionNames[profId] or ("Profession " .. profId)

    local facts = { prof }
    if info.requiredSkill then
        facts[#facts + 1] = L["REQUIRES_SKILL"]:format(info.requiredSkill)
            .. (info.requiredSkillBorrowed and U.Gray(" (" .. L["UNCONFIRMED"] .. ")") or "")
    end

    if info.craftedItemId then
        p.header(L["R_CREATES"])
        p.add(1, U.ItemLink(info.craftedItemId))
    end

    local reagents = {}
    for itemId, qty in pairs(info.reagents or {}) do
        reagents[#reagents + 1] = { id = itemId, qty = qty, name = ns.ItemName(itemId) or "" }
    end
    table.sort(reagents, function(a, b) return a.name < b.name end)
    p.list(L["R_REAGENTS"], reagents, function(r) return r.qty .. " x " .. U.ItemLink(r.id, r.name) end)

    local d = P.lib.GetDifficulty and P.lib:GetDifficulty(profId, spellId)
    if d and d[1] then
        p.header(L["R_SKILLUP"])
        p.add(1, ("|cffff8040%s|r  |cffffff00%s|r  |cff40c040%s|r  |cff808080%s|r"):format(
            d[1], d[2] or "?", d[3] or "?", d[4] or "?"))
    end

    if info.autoLearned then
        p.header(L["R_LEARNED"])
        p.add(1, L["SRC_learned"])
    else
        local sources = P:GetSources(spellId)
        if sources and #sources > 0 then
            p.header(L["R_LEARNED"] .. (sources.borrowed and U.Gray(" (" .. L["UNCONFIRMED"] .. ")") or ""))
            for _, kind in ipairs(sources) do
                local names = {}
                for i = 1, math.min(#kind.entries, 6) do
                    local e = kind.entries[i]
                    local npc = not e.name and ns.Providers.Questie:GetNpc(e.id)
                    names[#names + 1] = U.Link("npc", e.id, e.name or (npc and npc.name) or ("#" .. e.id))
                        .. (e.faction and U.Gray(" (" .. e.faction .. ")") or "")
                end
                local rest = kind.total - #names
                p.add(1, L["SRC_" .. kind.kind] .. ": " .. table.concat(names, ", ")
                    .. (rest > 0 and U.Gray(" " .. L["TT_MORE"]:format(rest)) or ""))
            end
        else
            p.header(L["R_LEARNED"])
            p.add(1, U.Gray(L["SRC_unknown"]))
        end
    end

    local scroll = P.lib.GetRecipeItem and P.lib:GetRecipeItem(spellId)
    if scroll then
        p.header(L["R_TAUGHT_BY"])
        p.add(1, U.ItemLink(scroll))
    end
    if info.hidden then
        p.header(L["SEC_NOTES"])
        p.add(1, U.Gray(L["NEVER_IMPLEMENTED"]))
    end

    local icon
    if info.craftedItemId then _, _, icon = ns.Providers.Client:GetItemInstant(info.craftedItemId) end
    return { title = "|cffff9f40" .. (info.name or "?") .. "|r", facts = table.concat(facts, ", "),
        icon = icon or ICON_RECIPE, lines = p.lines }
end
