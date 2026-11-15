-- The lookup window: search box and results on the left, the selected item's page on the
-- right. Built on first use with the same stock templates PyroLooter uses on Forever.
local _, ns = ...

local Window = {}
ns.Window = Window

local U, L = ns.Util, ns.L

local WIDTH, HEIGHT = 840, 540
local LEFT_W = 250
local ROW_H = 20
local PAGE_ROWS = 25          -- rows per section on the item page
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local frame

-- Search --------------------------------------------------------------------------------

local function searchRows(text)
    local IDB, Q = ns.Providers.LibItemDB, ns.Providers.Questie
    if IDB:IsAvailable() and IDB.lib.BuildWhereSearchRows then
        local rows, capped = IDB.lib:BuildWhereSearchRows(text)
        return rows or {}, capped
    end
    local id = Q:FindItemByName(text)          -- exact name only without LibItemDB
    if id then return { { id = id, name = Q:GetItemName(id) } }, false end
    return {}, false
end

local function setResults(rows, capped, message)
    local list = frame.results
    for i, row in ipairs(rows) do
        local b = list.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, list.content)
            b:SetHeight(ROW_H)
            b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            b:SetPoint("RIGHT", list.content, "RIGHT")
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 4, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWordWrap(false)
            b:SetScript("OnClick", function(self) Window.ShowItem(self.itemId) end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.itemId)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            list.buttons[i] = b
        end
        b.itemId = row.id
        local extra = row.itemLevel and row.itemLevel > 0 and U.Gray(" " .. row.itemLevel) or ""
        b.text:SetText((row.name or row.plainName or ("#" .. row.id)) .. extra)
        b:Show()
    end
    for i = #rows + 1, #list.buttons do list.buttons[i]:Hide() end
    list.content:SetHeight(math.max(1, #rows * ROW_H))
    list:SetVerticalScroll(0)

    if message then
        frame.resultInfo:SetText(message)
    elseif #rows == 0 then
        frame.resultInfo:SetText(L["WIN_NO_RESULTS"])
    else
        frame.resultInfo:SetText(L[capped and "WIN_RESULTS_CAPPED" or "WIN_RESULTS"]:format(#rows))
    end
end

local function runSearch()
    local text = (frame.search:GetText() or ""):match("^%s*(.-)%s*$")
    local id = U.ParseItemId(text)
    if id then Window.ShowItem(id); return end
    if #text < 3 then setResults({}, false, L["WIN_TYPE_MORE"]); return end
    setResults(searchRows(text))
end

-- Item page -----------------------------------------------------------------------------

local function renderReport(report)
    local page = frame.page
    local title, facts = ns.ReportText.Header(report)
    page.title:SetText(title)
    page.facts:SetText(facts)
    local _, _, icon = ns.Providers.Client:GetItemInstant(report.id)
    page.icon:SetTexture(icon or QUESTION_ICON)
    page.body:SetText(table.concat(ns.ReportText.Body(report, PAGE_ROWS), "\n"))
    page.content:SetHeight(page.body:GetStringHeight() + 20)
    page.scroll:SetVerticalScroll(0)
end

function Window.ShowItem(itemId)
    itemId = tonumber(itemId)
    if not itemId then return end
    Window.Open()
    local page = frame.page
    page.itemId = itemId
    page.title:SetText(("item %d"):format(itemId))
    page.facts:SetText("")
    page.body:SetText(L["BUILDING"])
    ns.ItemReport.Request(itemId, { maxRows = PAGE_ROWS }, function(report)
        if page.itemId == itemId then renderReport(report) end
    end)
    -- Names and icons of items the client has never seen arrive a moment later.
    ns.Providers.Client:RequestItem(itemId, function()
        if page.itemId == itemId and frame:IsShown() then
            ns.ItemReport.Request(itemId, { maxRows = PAGE_ROWS }, function(report)
                if page.itemId == itemId then renderReport(report) end
            end)
        end
    end)
end

-- Construction --------------------------------------------------------------------------

local function createScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    return scroll
end

local function create()
    local f = CreateFrame("Frame", "PyroEncyclopediaFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "PyroEncyclopediaFrame") -- Escape closes it

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cffff7f00Pyro|rEncyclopedia")

    -- Left: search box, result count, results list.
    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(LEFT_W - 20, 22)
    search:SetPoint("TOPLEFT", 22, -32)
    search:SetAutoFocus(false)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); runSearch() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then return end
        f.searchSerial = (f.searchSerial or 0) + 1
        local serial = f.searchSerial
        C_Timer.After(0.3, function() if f.searchSerial == serial then runSearch() end end)
    end)
    f.search = search

    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(L["WIN_SEARCH_HINT"])
    search:HookScript("OnEditFocusGained", function() hint:Hide() end)
    search:HookScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)

    f.resultInfo = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.resultInfo:SetPoint("TOPLEFT", 16, -60)
    f.resultInfo:SetWidth(LEFT_W - 10)
    f.resultInfo:SetJustifyH("LEFT")

    local results = createScroll(f)
    results:SetPoint("TOPLEFT", 12, -76)
    results:SetPoint("BOTTOMLEFT", 12, 10)
    results:SetWidth(LEFT_W - 28)
    results.content:SetWidth(LEFT_W - 28)
    results.buttons = {}
    f.results = results

    -- Right: icon, title, facts line, scrolling body.
    local page = {}
    local x = LEFT_W + 14
    page.icon = f:CreateTexture(nil, "ARTWORK")
    page.icon:SetSize(36, 36)
    page.icon:SetPoint("TOPLEFT", x, -32)
    page.icon:SetTexture(QUESTION_ICON)

    local titleButton = CreateFrame("Button", nil, f)
    titleButton:SetPoint("TOPLEFT", page.icon, "TOPRIGHT", 8, 0)
    titleButton:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    titleButton:SetHeight(20)
    page.title = titleButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.title:SetAllPoints()
    page.title:SetJustifyH("LEFT")
    titleButton:SetScript("OnEnter", function(self)
        if not page.itemId then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetHyperlink("item:" .. page.itemId)
        GameTooltip:Show()
    end)
    titleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    page.facts = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.facts:SetPoint("BOTTOMLEFT", page.icon, "BOTTOMRIGHT", 8, 2)
    page.facts:SetJustifyH("LEFT")

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", x, -74)
    divider:SetPoint("TOPRIGHT", -16, -74)

    local bodyWidth = WIDTH - x - 40
    page.scroll = createScroll(f)
    page.scroll:SetPoint("TOPLEFT", x, -80)
    page.scroll:SetPoint("BOTTOMRIGHT", -32, 10)
    page.content = page.scroll.content
    page.content:SetWidth(bodyWidth)
    page.body = page.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.body:SetPoint("TOPLEFT")
    page.body:SetWidth(bodyWidth)
    page.body:SetJustifyH("LEFT")
    page.body:SetJustifyV("TOP")
    page.body:SetSpacing(2)
    page.body:SetText(L["WIN_WELCOME"])
    f.page = page

    frame = f   -- setResults below reads the shared `frame`, so register it first
    setResults({}, false, L["WIN_TYPE_MORE"])
    return f
end

-- Shift-clicking an item (bags, chat, loot) while the search box has focus looks it up.
local function onInsertLink(link)
    if not (frame and frame:IsShown() and frame.search:HasFocus() and type(link) == "string") then return end
    local id = link:match("item:(%d+)")
    if not id then return end
    frame.search:SetText(link:match("%[(.-)%]") or id)
    frame.search:ClearFocus()
    Window.ShowItem(id)
end

function Window.Init()
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", onInsertLink) end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink) end
end

function Window.Open()
    frame = frame or create()
    frame:Show()
end

function Window.Toggle()
    frame = frame or create()
    frame:SetShown(not frame:IsShown())
end

--- Open the window on `text`: an item id or link shows that item, anything else searches.
function Window.Search(text)
    Window.Open()
    frame.search:SetText(text or "")
    runSearch()
end
