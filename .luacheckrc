std = "lua51"
max_line_length = 130
exclude_files = { ".release/", "docs/" }
ignore = {
    "212/self",   -- unused self in method-style provider functions
}

globals = {
    "PyroEncyclopedia",
    "PyroEncyclopediaDB",
    "SLASH_PYROENCYCLOPEDIA1",
    "SLASH_PYROENCYCLOPEDIA2",
    "SlashCmdList",
}

read_globals = {
    -- Libraries
    "LibStub",
    "LibQuestieDB",
    -- WoW API
    "C_AddOns",
    "C_Item",
    "C_Map",
    "C_Timer",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GetAddOnDependencies",
    "GetAddOnInfo",
    "GetAddOnMetadata",
    "IsAddOnLoaded",
    "GetCoinTextureString",
    "GetItemClassInfo",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetItemSubClassInfo",
    "Item",
    "debugprofilestop",
    "geterrorhandler",
}
