-- Prints an item report to the chat frame (/pyroenc print <item>).
local _, ns = ...

local ChatReport = {}
ns.ChatReport = ChatReport

function ChatReport.Print(r, maxRows)
    local U = ns.Util
    local title, facts = ns.ReportText.Header(r)
    U.Print("%s %s %s", title, U.Gray("(" .. r.id .. ")"), facts)
    for _, line in ipairs(ns.ReportText.Body(r, maxRows)) do
        if line ~= " " then DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
    end
end
