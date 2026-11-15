-- Renders an item report to the chat frame. This is the phase-1 UI; the tooltip and the
-- full window will render the same report data.
local _, ns = ...

local ChatReport = {}
ns.ChatReport = ChatReport

local U, L = ns.Util, ns.L

local function zonesText(row)
    if row.zones and #row.zones > 0 then return table.concat(row.zones, ", ") end
    if row.noLocation then return U.Gray(L["NO_KNOWN_LOCATION"]) end
    return nil
end

local function header(title, total)
    if total and total > 0 then
        U.Line(1, "%s (%d):", U.Gold(title), total)
    else
        U.Line(1, "%s:", U.Gold(title))
    end
end

local function more(shown, total)
    if total > shown then U.Line(2, U.Gray(L["AND_MORE"]:format(total - shown))) end
end

local function itemLabel(itemId, name)
    return ("%s %s"):format(name or "?", U.Gray("(" .. itemId .. ")"))
end

local function questLabel(q)
    local lvl = q.questLevel and ("[" .. q.questLevel .. "] ") or ""
    return ("%s%s %s"):format(lvl, q.name or "?", U.Gray("(" .. q.id .. ")"))
end

local function placeRows(section, maxRows)
    local shown = math.min(section.total, maxRows)
    for i = 1, shown do
        local row = section.rows[i]
        local parts = { row.name or ("#" .. row.id) }
        local lvl = U.LevelRange(row.minLevel, row.maxLevel)
        if lvl then parts[#parts + 1] = "(" .. lvl .. ")" end
        if row.chance then parts[#parts + 1] = "|cff20ff20" .. U.Percent(row.chance) .. "|r" end
        if row.questOnly then parts[#parts + 1] = U.Gray(L["QUEST_ONLY"]) end
        if row.profession then parts[#parts + 1] = U.Gray("[" .. row.profession .. "]") end
        if row.condition and row.condition ~= "skill" then parts[#parts + 1] = U.Gray("[" .. row.condition .. "]") end
        local zones = zonesText(row)
        if zones then parts[#parts + 1] = "- " .. zones end
        U.Line(2, table.concat(parts, " "))
    end
    more(shown, section.total)
end

local function sourceSummary(rec)
    if rec.autoLearned then return L["SRC_learned"] end
    local src = rec.sources
    if not src or #src == 0 then return U.Gray(L["SRC_unknown"]) end
    local parts = {}
    for _, kind in ipairs(src) do
        local text = L["SRC_" .. kind.kind]
        local first = kind.entries[1]
        if kind.kind == "vendor" and first then
            local name = first.name
            if not name then
                local npc = ns.Providers.Questie:IsAvailable() and ns.Providers.Questie:GetNpc(first.id)
                name = npc and npc.name
            end
            text = text .. ": " .. (name or ("#" .. first.id))
            if first.faction then text = text .. " (" .. first.faction .. ")" end
        end
        if kind.total > 1 then text = text .. " (" .. kind.total .. ")" end
        parts[#parts + 1] = text
    end
    local out = table.concat(parts, ", ")
    if src.borrowed then out = out .. " " .. U.Gray("(" .. L["UNCONFIRMED"] .. ")") end
    return out
end

local function recipeRows(section, maxRows)
    local shown = math.min(section.total, maxRows)
    for i = 1, shown do
        local rec = section.rows[i]
        local prof = ns.ProfessionNames[rec.profId] or ("Profession " .. rec.profId)
        local skill = rec.requiredSkill and (" " .. rec.requiredSkill) or ""
        if rec.requiredSkillBorrowed then skill = skill .. "?" end
        local qty = rec.qty and (" x" .. rec.qty) or ""
        -- Only name the result when it differs from the recipe ("Bolt of Silk Cloth" vs "Silk Cloth").
        local made = ""
        if rec.craftedName and rec.craftedName ~= rec.name then made = " -> " .. rec.craftedName end
        local hidden = rec.hidden and (" " .. U.Gray("[" .. L["NEVER_IMPLEMENTED"] .. "]")) or ""
        U.Line(2, "%s%s: %s%s%s%s - %s", prof, skill, rec.name or ("spell " .. rec.spellId), qty, made, hidden,
            sourceSummary(rec))
    end
    more(shown, section.total)
end

function ChatReport.Print(r, maxRows)
    maxRows = maxRows or 8
    local title = r.link or (r.name and ("[" .. r.name .. "]")) or "?"
    local facts = {}
    if r.typeName then facts[#facts + 1] = r.typeName end
    if r.itemLevel and r.itemLevel > 0 then facts[#facts + 1] = "ilvl " .. r.itemLevel end
    if r.requiredLevel and r.requiredLevel > 1 then facts[#facts + 1] = "req " .. r.requiredLevel end
    local sell = U.Money(r.sellPrice)
    if sell then facts[#facts + 1] = L["SELLS_FOR"]:format(sell) end
    U.Print("%s %s %s", title, U.Gray("(" .. r.id .. ")"), table.concat(facts, ", "))

    local anything = false
    if r.drops.total > 0 then anything = true; header(L["SEC_DROPS"], r.drops.total); placeRows(r.drops, maxRows) end
    if #r.bosses > 0 then
        anything = true
        header(L["SEC_BOSSES"], #r.bosses)
        for i = 1, math.min(#r.bosses, maxRows) do
            local b = r.bosses[i]
            local rate = b.rate and (" |cff20ff20" .. U.Percent(b.rate) .. "|r") or ""
            U.Line(2, "%s - %s%s", b.boss or "?", b.instance or "?", rate)
        end
        more(math.min(#r.bosses, maxRows), #r.bosses)
    end
    if r.objects.total > 0 then anything = true; header(L["SEC_OBJECTS"], r.objects.total); placeRows(r.objects, maxRows) end
    if r.containers.total > 0 then
        anything = true
        header(L["SEC_CONTAINERS"], r.containers.total)
        for i = 1, math.min(r.containers.total, maxRows) do
            local c = r.containers.rows[i]
            U.Line(2, itemLabel(c.id, c.name))
        end
        more(math.min(r.containers.total, maxRows), r.containers.total)
    end
    if r.vendors.total > 0 then
        anything = true
        local buy = U.Money(r.buyPrice)
        header(L["SEC_VENDORS"] .. (buy and (" - " .. L["BUY_FOR"]:format(buy)) or ""), r.vendors.total)
        placeRows(r.vendors, maxRows)
    end
    if #r.origins > 0 then
        anything = true
        header(L["SEC_ORIGINS"])
        for _, o in ipairs(r.origins) do
            U.Line(2, "%s%s", o.source or "?", o.instance and (" - " .. o.instance) or "")
        end
    end
    if r.recipesMaking.total > 0 then
        anything = true; header(L["SEC_RECIPES_MAKING"], r.recipesMaking.total); recipeRows(r.recipesMaking, maxRows)
    end
    if #r.questRewards > 0 then
        anything = true
        header(L["SEC_QUEST_REWARD"], #r.questRewards)
        for i = 1, math.min(#r.questRewards, maxRows) do U.Line(2, questLabel(r.questRewards[i])) end
        more(math.min(#r.questRewards, maxRows), #r.questRewards)
    end
    if r.startsQuest then anything = true; header(L["SEC_STARTS_QUEST"]); U.Line(2, questLabel(r.startsQuest)) end
    if #r.questUses > 0 then
        anything = true
        header(L["SEC_QUEST_USE"], #r.questUses)
        for i = 1, math.min(#r.questUses, maxRows) do
            local q = r.questUses[i]
            local reasons = {}
            for _, reason in ipairs(q.reasons or {}) do reasons[#reasons + 1] = L["REASON_" .. reason] end
            U.Line(2, "%s %s", questLabel(q), U.Gray("- " .. table.concat(reasons, ", ")))
        end
        more(math.min(#r.questUses, maxRows), #r.questUses)
    end
    if r.recipesUsing.total > 0 then
        anything = true; header(L["SEC_RECIPES_USING"], r.recipesUsing.total); recipeRows(r.recipesUsing, maxRows)
    end
    if r.teaches then
        anything = true
        header(L["SEC_TEACHES"])
        local prof = ns.ProfessionNames[r.teaches.profId] or r.teaches.profId
        U.Line(2, "%s: %s", prof, r.teaches.name or ("spell " .. r.teaches.spellId))
    end

    if not anything then U.Line(1, U.Gray(L["NOTHING_KNOWN"])) end
    if #r.notes > 0 then
        header(L["SEC_NOTES"])
        for _, note in ipairs(r.notes) do U.Line(2, U.Gray(note)) end
    end
end
