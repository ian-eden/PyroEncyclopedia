-- English strings. Other locales can override entries in their own file; any key without a
-- translation falls back to the key itself, so a missing string never errors.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- Profession skill line ids -> display names (enUS). Used when a provider gives only an id.
ns.ProfessionNames = {
    [129] = "First Aid",
    [164] = "Blacksmithing",
    [165] = "Leatherworking",
    [171] = "Alchemy",
    [182] = "Herbalism",
    [185] = "Cooking",
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [356] = "Fishing",
    [393] = "Skinning",
}

L["HELP_HEADER"] = "commands:"
L["HELP_ITEM"] = "/pyroenc item <id | item link | exact name> - print everything known about an item"
L["HELP_SHORT"] = "/pyroenc <id | item link> - same as /pyroenc item"
L["HELP_STATUS"] = "/pyroenc status - show which data sources are loaded"
L["HELP_ROWS"] = "/pyroenc rows <n> - rows shown per section (currently %d)"

L["STATUS_HEADER"] = "data sources:"
L["NOT_INSTALLED"] = "not installed"
L["NO_PROVIDERS"] = "No data source is loaded. Install QuestieDB, ProfessionDB (LibProfessionDB) and/or ItemDB (LibItemDB)."
L["ITEM_NOT_FOUND"] = "No item found for '%s'. Use an item id, a shift-clicked item link, or the exact item name."
L["BUILDING"] = "Building indexes for the first lookup, one moment..."
L["ROWS_SET"] = "Rows per section set to %d."

L["SEC_DROPS"] = "Dropped by"
L["SEC_BOSSES"] = "Boss loot"
L["SEC_ORIGINS"] = "Other origins"
L["SEC_OBJECTS"] = "Found in (objects / nodes)"
L["SEC_CONTAINERS"] = "Contained in"
L["SEC_VENDORS"] = "Sold by"
L["SEC_QUEST_REWARD"] = "Reward from quests"
L["SEC_QUEST_USE"] = "Needed for quests"
L["SEC_STARTS_QUEST"] = "Starts quest"
L["SEC_RECIPES_USING"] = "Used in recipes"
L["SEC_RECIPES_MAKING"] = "Created by recipes"
L["SEC_TEACHES"] = "Teaches recipe"
L["SEC_NOTES"] = "Notes"
L["NOTHING_KNOWN"] = "No acquisition or usage data is known for this item."
L["AND_MORE"] = "... and %d more"
L["SELLS_FOR"] = "sells for %s"
L["BUY_FOR"] = "buy %s"
L["UNCONFIRMED"] = "unconfirmed"
L["NEVER_IMPLEMENTED"] = "never implemented"
L["QUEST_ONLY"] = "while on quest"
L["NO_KNOWN_LOCATION"] = "no known location"

L["REASON_objective"] = "objective"
L["REASON_provided"] = "provided by quest"
L["REASON_required"] = "required"
L["REASON_starts"] = "starts it"

L["SRC_trainer"] = "Trainer"
L["SRC_vendor"] = "Vendor"
L["SRC_quest"] = "Quest"
L["SRC_container"] = "Container"
L["SRC_drop"] = "Drop"
L["SRC_learned"] = "Learned with profession"
L["SRC_unknown"] = "source unknown"

L["GAP_NO_DROP_RATES"] = "Drop chance unknown for sources listed without a percentage."
L["GAP_CLASSIC_DERIVED"] = "Drop and spawn data is taken from Classic and has not been verified on Forever."
L["GAP_BORROWED"] = "Recipe data marked 'unconfirmed' is borrowed from Vanilla."
L["GAP_NO_SKINNING"] = "Skinning, pickpocketing, fishing and disenchanting yields are not covered by any data source yet."
