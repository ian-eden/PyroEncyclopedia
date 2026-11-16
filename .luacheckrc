std = "lua51"
max_line_length = 130
exclude_files = { ".release/", "docs/", "Libs/" }
ignore = {
    "212/self",   -- unused self in method-style provider functions
}

globals = {
    "PyroEncyclopedia",
    "PyroEncyclopediaDB",
    "BINDING_HEADER_PYROENCYCLOPEDIA",
    "BINDING_NAME_PYROENCYCLOPEDIA_LOOKUP",
    "BINDING_NAME_PYROENCYCLOPEDIA_TOGGLE",
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
    "ChatEdit_InsertLink",
    "ChatFrameUtil",
    "CreateFrame",
    "Enum",
    "TooltipDataProcessor",
    "GameTooltip",
    "UIParent",
    "UnitExists",
    "UnitGUID",
    "UISpecialFrames",
    "hooksecurefunc",
    "tinsert",
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
    "ITEM_QUALITY_COLORS",
    "Item",
    "debugprofilestop",
    "geterrorhandler",
}
