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
L["HELP_OPEN"] = "/pyroenc - open or close the lookup window"
L["HELP_SEARCH"] = "/pyroenc <name | id | item link> - open the window and look it up"
L["HELP_PRINT"] = "/pyroenc print <name | id | item link> - print the lookup to chat instead"
L["HELP_STATUS"] = "/pyroenc status - show which databases are loaded"
L["HELP_TOOLTIP"] = "/pyroenc tooltip - turn the extra item tooltip lines on or off"

L["TT_DROPS"] = "Drops:"
L["TT_SOLD_BY"] = "Sold by:"
L["TT_USED_IN"] = "Used in:"
L["TT_RECIPES"] = "%d recipes (%s)"
L["TT_CRAFTED"] = "Crafted:"
L["TT_QUEST"] = "Quest:"
L["TT_REWARD"] = "Reward from:"
L["TT_MORE"] = "+%d more"
L["TT_ENABLED"] = "Item tooltip lines turned on."
L["TT_DISABLED"] = "Item tooltip lines turned off."

L["ON"] = "|cff20ff20on|r"
L["OFF"] = "|cffff5050off|r"
L["BROKER_CLICK"] = "Click: open the lookup window"
L["BROKER_RIGHT_CLICK"] = "Right-click: tooltip lines (%s)"

L["BINDING_LOOKUP"] = "Look up mouseover / target"
L["BINDING_TOGGLE"] = "Open / close window"

L["WIN_SEARCH_HINT"] = "Search items and monsters..."
L["WIN_ITEMS"] = "Items"
L["WIN_NPCS"] = "Monsters & NPCs"
L["WIN_BACK"] = "< Back"
L["WIN_CLICK_TO_OPEN"] = "Click to open"
L["PAGE_UNKNOWN"] = "Nothing is known about this."

L["LEVEL"] = "level %s"
L["REQUIRES_LEVEL"] = "requires level %s"
L["REQUIRES_SKILL"] = "requires %s"
L["FRIENDLY_TO"] = "friendly to %s"
L["HOSTILE"] = "hostile"
L["SPAWNS"] = "(%d spawns)"

L["Q_STARTS"] = "Starts at"
L["Q_ENDS"] = "Ends at"
L["Q_OBJECTIVES"] = "Objectives"
L["Q_REQUIRES"] = "Requires"
L["Q_KILL"] = "Kill: "
L["Q_USE"] = "Use: "
L["Q_COLLECT"] = "Collect: "
L["Q_BRING"] = "Bring: "
L["Q_PROVIDED"] = "Provided: "
L["Q_REWARDS"] = "Item rewards"
L["Q_BEFORE"] = "Requires completing"
L["Q_NEXT"] = "Next in chain"

L["N_LOCATION"] = "Location"
L["N_STARTS"] = "Starts quests"
L["N_ENDS"] = "Ends quests"
L["N_DROPS"] = "Drops"
L["N_SELLS"] = "Sells"

L["R_CREATES"] = "Creates"
L["R_REAGENTS"] = "Reagents"
L["R_SKILLUP"] = "Skill-up range (orange, yellow, green, grey)"
L["R_LEARNED"] = "Learned from"
L["R_TAUGHT_BY"] = "Taught by"
L["WIN_TYPE_MORE"] = "Type at least 3 letters of an item or monster, an item id, or shift-click an item into the box."
L["WIN_NO_RESULTS"] = "Nothing found."
L["WIN_RESULTS_CAPPED"] = "Long list - type more to narrow it down"
L["WIN_WELCOME"] = "Search for an item or monster on the left, or click into the search box and "
    .. "shift-click any item (bags, chat, loot) to look it up."

L["STATUS_HEADER"] = "data sources:"
L["NOT_INSTALLED"] = "not installed"
L["NO_PROVIDERS"] = "No data source is loaded. Install QuestieDB, ProfessionDB (LibProfessionDB) and/or ItemDB (LibItemDB)."
L["ITEM_NOT_FOUND"] = "No item found for '%s'. Use an item id, a shift-clicked item link, or the exact item name."
L["BUILDING"] = "Building indexes for the first lookup, one moment..."
L["ROWS_SET"] = "Rows per section set to %d."
L["WHY_MISSING"] = "not installed"
L["WHY_DISABLED"] = "turned off for this character (AddOns button on the character screen)"
L["WHY_OUTDATED"] = "out of date (tick 'Load out of date AddOns' on the character screen)"
L["WHY_NEEDS"] = "can't start, needs: %s"
L["WHY_RELOAD"] = "turned on but not loaded yet - type /reload"

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
